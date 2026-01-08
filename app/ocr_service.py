"""PaddleOCR 服务封装"""
import os
import time
import threading
import logging
from typing import List, Dict, Any, Optional
import numpy as np
from paddleocr import PaddleOCR
from .schemas import TextBox, OcrOptions


def _calculate_box_center(box: List[List[float]]) -> tuple:
    """计算文字框的中心点坐标"""
    center_x = sum(p[0] for p in box) / 4
    center_y = sum(p[1] for p in box) / 4
    return center_x, center_y


def _sort_horizontal(details: List[Dict]) -> List[Dict]:
    """横排从左到右排序"""
    for item in details:
        item['_center_x'], item['_center_y'] = _calculate_box_center(item['box'])
    # 先按Y升序（从上到下），再按X升序（从左到右）
    sorted_items = sorted(details, key=lambda x: (x['_center_y'], x['_center_x']))
    for item in sorted_items:
        del item['_center_x'], item['_center_y']
    return sorted_items


def _sort_vertical_rl(details: List[Dict]) -> List[Dict]:
    """竖排从右到左排序"""
    for item in details:
        item['_center_x'], item['_center_y'] = _calculate_box_center(item['box'])
    # 先按X降序（从右到左），再按Y升序（从上到下）
    sorted_items = sorted(details, key=lambda x: (-x['_center_x'], x['_center_y']))
    for item in sorted_items:
        del item['_center_x'], item['_center_y']
    return sorted_items


def _sort_vertical_lr(details: List[Dict]) -> List[Dict]:
    """竖排从左到右排序"""
    for item in details:
        item['_center_x'], item['_center_y'] = _calculate_box_center(item['box'])
    # 先按X升序（从左到右），再按Y升序（从上到下）
    sorted_items = sorted(details, key=lambda x: (x['_center_x'], x['_center_y']))
    for item in sorted_items:
        del item['_center_x'], item['_center_y']
    return sorted_items


def _format_text_by_layout(details: List[Dict], text_layout: str, output_format: str) -> str:
    """
    根据排版方向和输出格式生成文本

    Args:
        details: 识别结果列表
        text_layout: 文字排版方向 (horizontal, vertical_rl, vertical_lr)
        output_format: 输出格式 (line_by_line, char_by_char, column_by_column)

    Returns:
        格式化后的文本
    """
    if not details:
        return ""

    # 转换为字典列表以便处理
    items = [item.dict() if hasattr(item, 'dict') else item for item in details]

    # 根据排版方向排序
    if text_layout == "vertical_rl":
        sorted_items = _sort_vertical_rl(items)
    elif text_layout == "vertical_lr":
        sorted_items = _sort_vertical_lr(items)
    else:  # horizontal
        sorted_items = _sort_horizontal(items)

    # 根据输出格式生成文本
    if output_format == "char_by_char":
        # 逐字排列：将所有文字连在一起
        return "".join(item['text'] for item in sorted_items)

    elif output_format == "column_by_column":
        # 逐列排列：需要按列分组
        if text_layout == "vertical_rl" or text_layout == "vertical_lr":
            # 竖排版：按X坐标分列
            columns = {}
            for item in sorted_items:
                center_x, _ = _calculate_box_center(item['box'])
                # 使用X坐标作为列的键（四舍五入以处理精度问题）
                col_key = round(center_x, 0)
                if col_key not in columns:
                    columns[col_key] = []
                columns[col_key].append(item['text'])
            # 将每列的文字连成一行
            return "\n".join("".join(col) for col in columns.values())
        else:
            # 横排版：按行分组
            lines = {}
            for item in sorted_items:
                _, center_y = _calculate_box_center(item['box'])
                line_key = round(center_y, 0)
                if line_key not in lines:
                    lines[line_key] = []
                lines[line_key].append(item['text'])
            return "\n".join("".join(line) for line in lines.values())

    else:  # line_by_line (默认)
        # 逐行排列：每个识别结果一行
        return "\n".join(item['text'] for item in sorted_items)

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
            result = ocr.ocr(image_path)

            # 提取文本和详细信息
            texts = []
            details = []

            if result and result[0]:
                # 兼容新版 PaddleOCR 返回格式（字典）
                if isinstance(result[0], dict):
                    logger.info("检测到新版 PaddleOCR 格式（字典）")
                    rec_texts = result[0].get('rec_texts', [])
                    rec_scores = result[0].get('rec_scores', [])
                    rec_polys = result[0].get('rec_polys', [])

                    for i, text in enumerate(rec_texts):
                        if not text:
                            continue

                        texts.append(text)

                        if options.return_details:
                            confidence = float(rec_scores[i]) if i < len(rec_scores) else 1.0

                            if i < len(rec_polys):
                                poly = rec_polys[i]
                                if isinstance(poly, np.ndarray):
                                    box = [[float(x), float(y)] for x, y in poly.tolist()]
                                else:
                                    box = [[float(x), float(y)] for x, y in poly]
                            else:
                                box = [[0, 0], [0, 0], [0, 0], [0, 0]]

                            details.append(TextBox(
                                text=text,
                                confidence=confidence,
                                box=box
                            ))

                # 兼容旧版 PaddleOCR 返回格式（列表）
                elif isinstance(result[0], list):
                    logger.info("检测到旧版 PaddleOCR 格式（列表）")
                    for line in result[0]:
                        if line:
                            try:
                                box_coords = line[0]
                                text_info = line[1]

                                # 兼容不同版本的 PaddleOCR 返回格式
                                if isinstance(text_info, list) and len(text_info) >= 2:
                                    text = text_info[0]
                                    confidence = float(text_info[1])
                                elif isinstance(text_info, str):
                                    text = text_info
                                    confidence = 1.0
                                else:
                                    continue

                                if not text:
                                    continue

                                texts.append(text)

                                if options.return_details:
                                    try:
                                        box = [[float(x), float(y)] for x, y in box_coords]
                                    except (ValueError, TypeError):
                                        box = [[0, 0], [0, 0], [0, 0], [0, 0]]

                                    details.append(TextBox(
                                        text=text,
                                        confidence=confidence,
                                        box=box
                                    ))
                            except Exception as e:
                                logger.warning(f"跳过无法解析的识别结果: {e}")
                                continue

            # 根据排版方向和输出格式生成文本
            if details and (options.text_layout != "horizontal" or options.output_format != "line_by_line"):
                full_text = _format_text_by_layout(details, options.text_layout, options.output_format)
                logger.info(f"使用自定义排版: layout={options.text_layout}, format={options.output_format}")
            else:
                # 默认拼接方式
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
