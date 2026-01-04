"""FastAPI 主应用"""
import os
import uuid
import shutil
import logging
from pathlib import Path
from typing import List
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse
from fastapi.staticfiles import StaticFiles

from .schemas import OcrResponse, HealthResponse, StatusResponse, OcrOptions, TextBox
from .ocr_service import ocr_service

# 配置日志
LOG_DIR = Path(__file__).parent.parent / "logs"
LOG_DIR.mkdir(exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(LOG_DIR / "api.log", encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# 创建 FastAPI 应用
app = FastAPI(
    title="PaddleOCR API",
    description="基于 PaddleOCR 的图片文字识别 API 服务",
    version="1.0.0"
)

# 配置 CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 项目路径
BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"
TEMP_DIR = BASE_DIR / "temp"
STATIC_DIR = BASE_DIR / "static"

# 确保目录存在
UPLOAD_DIR.mkdir(exist_ok=True)
TEMP_DIR.mkdir(exist_ok=True)
STATIC_DIR.mkdir(exist_ok=True)

# 挂载静态文件目录
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")


@app.get("/", tags=["根路径"])
async def root():
    """根路径 - 重定向到识别工具页面"""
    return FileResponse(STATIC_DIR / "index.html")


@app.get("/api/ocr/health", response_model=HealthResponse, tags=["系统"])
async def health_check():
    """健康检查"""
    return HealthResponse(
        status="healthy",
        version="1.0.0"
    )


@app.get("/api/ocr/status", response_model=StatusResponse, tags=["系统"])
async def get_status():
    """获取服务状态"""
    status = ocr_service.get_status()
    return StatusResponse(**status)


@app.post("/api/ocr/recognize", response_model=OcrResponse, tags=["OCR"])
async def recognize_image(
    file: UploadFile = File(..., description="图片文件"),
    lang: str = Form(default="ch", description="语言类型"),
    use_angle_cls: bool = Form(default=True, description="是否使用文字方向分类"),
    return_details: bool = Form(default=True, description="是否返回详细信息"),
    text_layout: str = Form(default="horizontal", description="文字排版方向：horizontal-横排, vertical_rl-竖排从右到左, vertical_lr-竖排从左到右"),
    output_format: str = Form(default="line_by_line", description="输出格式：line_by_line-逐行, char_by_char-逐字, column_by_column-逐列")
):
    """
    识别单张图片

    支持的图片格式：jpg, png, bmp, jpeg

    **新增参数说明：**
    - **text_layout**: 文字排版方向
      - `horizontal`: 横排从左到右（默认）
      - `vertical_rl`: 竖排从右到左（古书传统排版）
      - `vertical_lr`: 竖排从左到右
    - **output_format**: 输出格式
      - `line_by_line`: 逐行输出（默认）
      - `char_by_char`: 逐字排列，所有文字连在一起
      - `column_by_column`: 逐列排列，保留列结构
    """
    logger.info(f"收到识别请求 - 文件名: {file.filename}, 语言: {lang}, 角度分类: {use_angle_cls}, 排版: {text_layout}, 格式: {output_format}")

    # 检查文件格式
    allowed_extensions = {".jpg", ".jpeg", ".png", ".bmp"}
    file_ext = Path(file.filename).suffix.lower()
    if file_ext not in allowed_extensions:
        logger.warning(f"不支持的文件格式: {file_ext}")
        return OcrResponse(
            success=False,
            text="",
            details=None,
            processing_time=0,
            error=f"不支持的文件格式：{file_ext}，支持的格式：{', '.join(allowed_extensions)}"
        )

    # 生成唯一文件名
    unique_filename = f"{uuid.uuid4()}{file_ext}"
    file_path = TEMP_DIR / unique_filename

    try:
        # 保存上传的文件
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)

        logger.info(f"文件已保存: {file_path}, 大小: {file_path.stat().st_size} bytes")

        # 创建 OCR 选项
        options = OcrOptions(
            lang=lang,
            use_angle_cls=use_angle_cls,
            return_details=return_details,
            text_layout=text_layout,
            output_format=output_format
        )

        # 执行识别
        result = ocr_service.recognize(str(file_path), options)

        logger.info(f"OCR 识别结果 - success: {result.get('success')}, text 长度: {len(result.get('text', ''))}, details 数量: {len(result.get('details', []))}")

        if result["success"]:
            logger.info(f"识别成功 - 文件: {file.filename}, 耗时: {result['processing_time']:.2f}秒")
        else:
            logger.error(f"识别失败 - 文件: {file.filename}, 错误: {result['error']}")

        # 将 details 中的 TextBox 对象转换为字典，以便 JSON 序列化
        if result.get("details"):
            result["details"] = [detail.dict() for detail in result["details"]]
            logger.info(f"转换后 details 数量: {len(result['details'])}")

        # 记录完整响应用于调试
        logger.debug(f"完整响应: {result}")

        return JSONResponse(content=result)

    except Exception as e:
        logger.error(f"处理请求时发生异常 - 文件: {file.filename}, 错误: {str(e)}", exc_info=True)
        return OcrResponse(
            success=False,
            text="",
            details=None,
            processing_time=0,
            error=str(e)
        )
    finally:
        # 删除临时文件
        if file_path.exists():
            file_path.unlink()
            logger.debug(f"临时文件已删除: {file_path}")


@app.post("/api/ocr/recognize-batch", response_model=List[OcrResponse], tags=["OCR"])
async def recognize_images_batch(
    files: List[UploadFile] = File(..., description="图片文件列表（最多10张）"),
    lang: str = Form(default="ch", description="语言类型"),
    use_angle_cls: bool = Form(default=True, description="是否使用文字方向分类"),
    return_details: bool = Form(default=True, description="是否返回详细信息"),
    text_layout: str = Form(default="horizontal", description="文字排版方向：horizontal-横排, vertical_rl-竖排从右到左, vertical_lr-竖排从左到右"),
    output_format: str = Form(default="line_by_line", description="输出格式：line_by_line-逐行, char_by_char-逐字, column_by_column-逐列")
):
    """
    批量识别图片（最多10张）

    **新增参数说明：**
    - **text_layout**: 文字排版方向
    - **output_format**: 输出格式
    """
    # 限制文件数量
    if len(files) > 10:
        raise HTTPException(
            status_code=400,
            detail="最多支持同时上传10张图片"
        )

    results = []
    for file in files:
        # 检查文件格式
        allowed_extensions = {".jpg", ".jpeg", ".png", ".bmp"}
        file_ext = Path(file.filename).suffix.lower()
        if file_ext not in allowed_extensions:
            results.append(OcrResponse(
                success=False,
                text="",
                details=None,
                processing_time=0,
                error=f"不支持的文件格式：{file_ext}"
            ))
            continue

        # 生成唯一文件名
        unique_filename = f"{uuid.uuid4()}{file_ext}"
        file_path = TEMP_DIR / unique_filename

        try:
            # 保存上传的文件
            with open(file_path, "wb") as buffer:
                shutil.copyfileobj(file.file, buffer)

            # 创建 OCR 选项
            options = OcrOptions(
                lang=lang,
                use_angle_cls=use_angle_cls,
                return_details=return_details,
                text_layout=text_layout,
                output_format=output_format
            )

            # 执行识别
            result = ocr_service.recognize(str(file_path), options)
            results.append(OcrResponse(**result))

        except Exception as e:
            results.append(OcrResponse(
                success=False,
                text="",
                details=None,
                processing_time=0,
                error=str(e)
            ))
        finally:
            # 删除临时文件
            if file_path.exists():
                file_path.unlink()

    return results


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
