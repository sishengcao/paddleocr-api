"""PaddleOCR 服务封装"""
import os
import time
import threading
import logging
from typing import List, Dict, Any, Optional
from paddleocr import PaddleOCR
from .schemas import TextBox, OcrOptions

# 配置日志
LOG_DIR = os.path.join(os.path.dirname(os.path.dirname(__file__)), "logs")
os.makedirs(LOG_DIR, exist_ok=True)

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler(os.path.join(LOG_DIR, "ocr_service.log"), encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)


class OcrService:
    """OCR 服务单例类"""
    _instance = None
    _lock = threading.Lock()
    _ocr_engine = None
    total_requests = 0
    total_images = 0

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        """初始化 OCR 服务（懒加载）"""
        pass

    def _get_ocr_engine(self, lang: str = "ch", use_angle_cls: bool = True):
        """获取 OCR 引擎（懒加载）"""
        if self._ocr_engine is None:
            # 暂时使用 CPU 模式，WSL2 GPU 存在兼容性问题
            logger.info(f"正在加载 PaddleOCR 模型（语言：{lang}，文字方向分类：{use_angle_cls}，使用 CPU）...")
            start_time = time.time()
            try:
                self._ocr_engine = PaddleOCR(
                    use_angle_cls=use_angle_cls,
                    lang=lang,
                    use_gpu=False,  # WSL2 GPU 存在兼容性问题，暂时使用 CPU
                )
                load_time = time.time() - start_time
                logger.info(f"PaddleOCR 模型加载完成，耗时：{load_time:.2f} 秒")
            except Exception as e:
                logger.error(f"PaddleOCR 模型加载失败: {str(e)}", exc_info=True)
                raise
        return self._ocr_engine

    def recognize(
        self,
        image_path: str,
        options: OcrOptions = None
    ) -> Dict[str, Any]:
        """
        识别图片文字

        Args:
            image_path: 图片路径
            options: OCR 选项

        Returns:
            识别结果字典
        """
        if options is None:
            options = OcrOptions()

        start_time = time.time()

        logger.info(f"开始识别图片: {image_path}, 语言: {options.lang}, 使用角度分类: {options.use_angle_cls}")

        try:
            # 获取 OCR 引擎
            ocr = self._get_ocr_engine(
                lang=options.lang,
                use_angle_cls=options.use_angle_cls
            )

            # 执行识别（PaddleOCR 2.7.0 需要 cls 参数）
            result = ocr.ocr(image_path, cls=options.use_angle_cls)

            # 提取文本和详细信息
            texts = []
            details = []

            if result and result[0]:
                for line in result[0]:
                    if line:
                        box_coords = line[0]
                        text_info = line[1]
                        text = text_info[0]
                        confidence = float(text_info[1])

                        texts.append(text)

                        if options.return_details:
                            details.append(TextBox(
                                text=text,
                                confidence=confidence,
                                box=[[float(x), float(y)] for x, y in box_coords]
                            ))

            # 拼接完整文本
            full_text = "\n".join(texts)

            # 更新统计
            self.total_requests += 1
            self.total_images += 1

            processing_time = time.time() - start_time

            logger.info(f"识别成功: {image_path}, 识别到 {len(texts)} 行文字, 耗时: {processing_time:.2f}秒")
            logger.debug(f"识别文本: {full_text[:100]}...")  # 只记录前100个字符

            return {
                "success": True,
                "text": full_text,
                "details": details if options.return_details else None,
                "processing_time": processing_time,
                "error": None
            }

        except Exception as e:
            processing_time = time.time() - start_time
            logger.error(f"识别失败: {image_path}, 错误: {str(e)}", exc_info=True)
            return {
                "success": False,
                "text": "",
                "details": None,
                "processing_time": processing_time,
                "error": str(e)
            }

    def recognize_batch(
        self,
        image_paths: List[str],
        options: OcrOptions = None
    ) -> List[Dict[str, Any]]:
        """
        批量识别图片

        Args:
            image_paths: 图片路径列表
            options: OCR 选项

        Returns:
            识别结果列表
        """
        results = []
        for image_path in image_paths:
            result = self.recognize(image_path, options)
            results.append(result)
        return results

    def get_status(self) -> Dict[str, Any]:
        """获取服务状态"""
        return {
            "ocr_loaded": self._ocr_engine is not None,
            "total_requests": self.total_requests,
            "total_images": self.total_images,
        }


# 全局 OCR 服务实例
ocr_service = OcrService()
