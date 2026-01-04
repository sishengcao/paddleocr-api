"""FastAPI 主应用"""
import os
import uuid
import shutil
import json
import logging
from pathlib import Path
from typing import List
from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
from fastapi.openapi.utils import get_openapi

from .schemas import (
    OcrResponse, HealthResponse, StatusResponse, OcrOptions, TextBox,
    BatchScanRequest, BatchScanResponse, TaskStatusResponse, ExportRequest, ExportResponse
)
from .ocr_service import ocr_service
from .batch_scan_service import batch_scan_service

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


# 自定义 OpenAPI 配置
def custom_openapi():
    if app.openapi_schema:
        return app.openapi_schema

    openapi_schema = get_openapi(
        title="📄 PaddleOCR 文字识别 API",
        version="2.0.0",
        description="""
## 🎯 功能简介

基于 PaddleOCR 的图片文字识别 API 服务，支持中英文识别、竖排文字识别、批量扫描等功能。

### ✨ 主要功能

- **单图识别**：上传单张图片进行文字识别
- **批量识别**：一次上传最多10张图片
- **竖排文字**：支持古书、族谱等从右到左的竖排文字
- **批量扫描**：指定目录自动扫描所有文件，适合族谱数字化
- **多种格式**：支持导出 JSON、CSV 格式

### 📌 使用说明

1. **单图识别**：使用 `/api/ocr/recognize` 接口
2. **批量扫描**：使用 `/api/ocr/batch/scan` 接口创建扫描任务
3. **查询进度**：使用 `/api/ocr/batch/status/{task_id}` 查询任务状态
4. **导出结果**：使用 `/api/ocr/batch/export` 导出识别结果

### 🔧 文字排版说明

- `horizontal` - 横排从左到右（默认）
- `vertical_rl` - 竖排从右到左（适合古书、族谱）
- `vertical_lr` - 竖排从左到右

### 📦 接口返回格式

```json
{
  "success": true,
  "text": "识别的完整文字",
  "details": [
    {
      "text": "每行文字",
      "confidence": 0.99,
      "box": [[x1, y1], [x2, y2], [x3, y3], [x4, y4]]
    }
  ],
  "processing_time": 1.23
}
```
        """,
        routes=app.routes,
    )

    # 中文标签映射
    openapi_schema["tags"] = [
        {"name": "OCR", "description": "文字识别接口"},
        {"name": "批量扫描", "description": "批量扫描目录，适合族谱数字化"},
        {"name": "系统", "description": "系统健康检查和状态查询"},
        {"name": "根路径", "description": "根路径和首页"}
    ]

    # 服务器信息
    openapi_schema["servers"] = [
        {"url": "http://localhost:8000", "description": "本地开发环境"},
        {"url": "http://localhost:80", "description": "生产环境"},
    ]

    # 联系方式
    openapi_schema["info"]["contact"] = {
        "name": "API 支持",
        "email": "support@example.com"
    }

    app.openapi_schema = openapi_schema
    return app.openapi_schema


# 创建 FastAPI 应用
app = FastAPI(
    title="PaddleOCR API",
    description="基于 PaddleOCR 的图片文字识别 API 服务",
    version="2.0.0",
    docs_url="/docs",  # Swagger UI
    redoc_url="/redoc"  # ReDoc
)

app.openapi = custom_openapi

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


# 自定义增强文档界面
@app.get("/docs-enhanced", include_in_schema=False)
async def enhanced_docs():
    """增强版 API 文档界面"""
    return FileResponse(STATIC_DIR / "docs.html")


@app.get("/docs", include_in_schema=False)
async def docs_redirect():
    """重定向到增强文档"""
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url="/docs-enhanced")


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


# ============ 批量扫描 API 端点 ============

@app.post("/api/ocr/batch/scan", response_model=BatchScanResponse, tags=["批量扫描"])
async def create_batch_scan(request: BatchScanRequest):
    """
    创建批量扫描任务

    扫描指定目录下的所有图片文件，自动识别文件名中的卷号和页码，
    并在后台执行 OCR 识别。

    **请求示例：**
    ```json
    {
        "directory": "/path/to/scans",
        "book_id": "李氏族谱卷一",
        "text_layout": "vertical_rl",
        "output_format": "char_by_char",
        "recursive": true
    }
    ```
    """
    logger.info(f"创建批量扫描任务 - 目录: {request.directory}, 书籍ID: {request.book_id}")

    try:
        task = batch_scan_service.create_task(request)

        # 自动启动任务
        batch_scan_service.start_task(task.task_id)

        return BatchScanResponse(
            success=True,
            task_id=task.task_id,
            message=f"批量扫描任务已创建并启动，共 {task.total_files} 个文件"
        )

    except FileNotFoundError as e:
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"创建任务失败: {str(e)}")


@app.post("/api/ocr/batch/start/{task_id}", tags=["批量扫描"])
async def start_batch_scan(task_id: str):
    """手动启动已创建的任务"""
    success = batch_scan_service.start_task(task_id)
    if not success:
        raise HTTPException(status_code=400, detail="任务不存在或无法启动")
    return {"success": True, "message": "任务已启动"}


@app.get("/api/ocr/batch/status/{task_id}", response_model=TaskStatusResponse, tags=["批量扫描"])
async def get_batch_scan_status(task_id: str):
    """获取批量扫描任务状态"""
    status = batch_scan_service.get_task_status(task_id)
    if status is None:
        raise HTTPException(status_code=404, detail="任务不存在")
    return status


@app.post("/api/ocr/batch/cancel/{task_id}", tags=["批量扫描"])
async def cancel_batch_scan(task_id: str):
    """取消批量扫描任务"""
    success = batch_scan_service.cancel_task(task_id)
    if not success:
        raise HTTPException(status_code=400, detail="任务不存在或无法取消")
    return {"success": True, "message": "任务已取消"}


@app.delete("/api/ocr/batch/task/{task_id}", tags=["批量扫描"])
async def delete_batch_scan_task(task_id: str):
    """删除批量扫描任务"""
    success = batch_scan_service.delete_task(task_id)
    if not success:
        raise HTTPException(status_code=404, detail="任务不存在")
    return {"success": True, "message": "任务已删除"}


@app.get("/api/ocr/batch/tasks", tags=["批量扫描"])
async def list_batch_scan_tasks():
    """列出所有批量扫描任务"""
    tasks = batch_scan_service.list_tasks()
    return {"tasks": tasks}


@app.post("/api/ocr/batch/export", response_model=ExportResponse, tags=["批量扫描"])
async def export_batch_scan(request: ExportRequest):
    """
    导出批量扫描结果

    支持导出为 JSON、CSV 格式，供族谱项目导入使用。
    """
    logger.info(f"导出任务结果 - task_id: {request.task_id}, format: {request.format}")

    export_file = batch_scan_service.export_task(
        request.task_id,
        request.format,
        request.include_details
    )

    if export_file is None:
        raise HTTPException(status_code=404, detail="任务不存在或导出失败")

    # 获取任务信息
    task = batch_scan_service.tasks.get(request.task_id)
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    file_size = Path(export_file).stat().st_size

    return ExportResponse(
        success=True,
        download_url=f"/api/ocr/batch/download/{request.task_id}",
        file_path=export_file,
        file_size=file_size,
        total_pages=len(task.pages),
        message=f"导出成功，共 {len(task.pages)} 页"
    )


@app.get("/api/ocr/batch/download/{task_id}", tags=["批量扫描"])
async def download_batch_scan_result(task_id: str, format: str = "json"):
    """下载批量扫描结果文件"""
    task = batch_scan_service.tasks.get(task_id)
    if not task:
        raise HTTPException(status_code=404, detail="任务不存在")

    # 导出文件
    export_file = batch_scan_service.export_task(task_id, format)
    if not export_file:
        raise HTTPException(status_code=404, detail="导出失败")

    return FileResponse(
        export_file,
        media_type="application/octet-stream",
        filename=Path(export_file).name
    )


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)
