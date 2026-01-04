"""Pydantic 数据模型定义"""
from typing import List, Optional
from pydantic import BaseModel, Field


class OcrOptions(BaseModel):
    """OCR 识别选项"""
    lang: str = Field(default="ch", description="语言类型：ch-中文, en-英文")
    use_angle_cls: bool = Field(default=True, description="是否使用文字方向分类")
    return_details: bool = Field(default=True, description="是否返回详细信息")


class TextBox(BaseModel):
    """文本框信息"""
    text: str = Field(..., description="识别的文字")
    confidence: float = Field(..., description="置信度")
    box: List[List[float]] = Field(..., description="文字框坐标 [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]")


class OcrResponse(BaseModel):
    """OCR 识别响应"""
    success: bool = Field(..., description="是否成功")
    text: str = Field(..., description="完整识别文本")
    details: Optional[List[TextBox]] = Field(default=None, description="详细识别结果")
    processing_time: float = Field(..., description="处理耗时（秒）")
    error: Optional[str] = Field(default=None, description="错误信息")


class HealthResponse(BaseModel):
    """健康检查响应"""
    status: str = Field(..., description="服务状态")
    version: str = Field(..., description="版本号")


class StatusResponse(BaseModel):
    """服务状态响应"""
    ocr_loaded: bool = Field(..., description="OCR 模型是否已加载")
    total_requests: int = Field(..., description="总请求数")
    total_images: int = Field(..., description="处理图片总数")
