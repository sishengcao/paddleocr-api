"""Pydantic 数据模型定义"""
from typing import List, Optional, Literal
from pydantic import BaseModel, Field


class TextLayout(str):
    """文字排版方向"""
    HORIZONTAL = "horizontal"  # 横排从左到右
    VERTICAL_RL = "vertical_rl"  # 竖排从右到左
    VERTICAL_LR = "vertical_lr"  # 竖排从左到右


class OutputFormat(str):
    """输出格式"""
    LINE_BY_LINE = "line_by_line"  # 逐行（默认）
    CHAR_BY_CHAR = "char_by_char"  # 逐字排列
    COLUMN_BY_COLUMN = "column_by_column"  # 逐列排列


class OcrOptions(BaseModel):
    """OCR 识别选项"""
    lang: str = Field(default="ch", description="语言类型：ch-中文, en-英文")
    use_angle_cls: bool = Field(default=True, description="是否使用文字方向分类")
    return_details: bool = Field(default=True, description="是否返回详细信息")
    text_layout: Literal["horizontal", "vertical_rl", "vertical_lr"] = Field(
        default="horizontal",
        description="文字排版方向：horizontal-横排, vertical_rl-竖排从右到左, vertical_lr-竖排从左到右"
    )
    output_format: Literal["line_by_line", "char_by_char", "column_by_column"] = Field(
        default="line_by_line",
        description="输出格式：line_by_line-逐行, char_by_char-逐字, column_by_column-逐列"
    )


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


# ============ 批量扫描相关模型 ============

class PageInfo(BaseModel):
    """页面信息"""
    file_path: str = Field(..., description="文件路径")
    file_name: str = Field(..., description="文件名")
    page_number: Optional[int] = Field(default=None, description="页码（从文件名识别）")
    volume: Optional[str] = Field(default=None, description="卷号（从文件名识别）")
    text: str = Field(default="", description="识别的文字")
    confidence: float = Field(default=0.0, description="平均置信度")
    success: bool = Field(default=True, description="是否识别成功")
    error: Optional[str] = Field(default=None, description="错误信息")
    processing_time: float = Field(default=0.0, description="处理耗时（秒）")


class BatchScanRequest(BaseModel):
    """批量扫描请求"""
    directory: str = Field(..., description="扫描目录路径")
    book_id: str = Field(..., description="书籍/族谱ID")
    lang: str = Field(default="ch", description="语言类型")
    use_angle_cls: bool = Field(default=True, description="是否使用文字方向分类")
    text_layout: Literal["horizontal", "vertical_rl", "vertical_lr"] = Field(
        default="horizontal", description="文字排版方向"
    )
    output_format: Literal["line_by_line", "char_by_char", "column_by_column"] = Field(
        default="line_by_line", description="输出格式"
    )
    recursive: bool = Field(default=True, description="是否递归扫描子目录")
    file_patterns: List[str] = Field(default=["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.pdf"], description="文件匹配模式")


class BatchScanTask(BaseModel):
    """批量扫描任务"""
    task_id: str = Field(..., description="任务ID")
    book_id: str = Field(..., description="书籍/族谱ID")
    directory: str = Field(..., description="扫描目录")
    status: Literal["pending", "running", "completed", "failed", "cancelled"] = Field(
        default="pending", description="任务状态"
    )
    total_files: int = Field(default=0, description="总文件数")
    processed_files: int = Field(default=0, description="已处理文件数")
    success_files: int = Field(default=0, description="成功文件数")
    failed_files: int = Field(default=0, description="失败文件数")
    pages: List[PageInfo] = Field(default_factory=list, description="识别结果页面列表")
    created_at: str = Field(..., description="创建时间")
    started_at: Optional[str] = Field(default=None, description="开始时间")
    completed_at: Optional[str] = Field(default=None, description="完成时间")
    error: Optional[str] = Field(default=None, description="错误信息")
    progress: float = Field(default=0.0, description="进度百分比")


class BatchScanResponse(BaseModel):
    """批量扫描响应"""
    success: bool = Field(..., description="是否成功创建任务")
    task_id: str = Field(..., description="任务ID")
    message: str = Field(..., description="提示信息")


class TaskStatusResponse(BaseModel):
    """任务状态响应"""
    task_id: str = Field(..., description="任务ID")
    status: str = Field(..., description="任务状态")
    progress: float = Field(..., description="进度百分比")
    total_files: int = Field(..., description="总文件数")
    processed_files: int = Field(..., description="已处理文件数")
    success_files: int = Field(..., description="成功文件数")
    failed_files: int = Field(..., description="失败文件数")
    pages: List[PageInfo] = Field(default_factory=list, description="已完成的页面列表（限制数量）")
    total_pages: int = Field(default=0, description="总页面数")
    error: Optional[str] = Field(default=None, description="错误信息")


class ExportRequest(BaseModel):
    """导出请求"""
    task_id: str = Field(..., description="任务ID")
    format: Literal["json", "excel", "csv"] = Field(default="json", description="导出格式")
    include_details: bool = Field(default=False, description="是否包含详细信息（坐标等）")


class ExportResponse(BaseModel):
    """导出响应"""
    success: bool = Field(..., description="是否成功")
    download_url: Optional[str] = Field(default=None, description="下载链接")
    file_path: Optional[str] = Field(default=None, description="文件路径")
    file_size: Optional[int] = Field(default=None, description="文件大小（字节）")
    total_pages: int = Field(default=0, description="总页数")
    message: str = Field(..., description="提示信息")
