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
    lang: str = Field(
        default="ch",
        description="语言类型",
        json_schema_extra={
            "examples": ["ch", "en"],
            "x-enumDescriptions": {
                "ch": "中文（简体/繁体）",
                "en": "英文",
                "ch_tra": "繁体中文",
                "japan": "日文",
                "korean": "韩文"
            }
        }
    )
    use_angle_cls: bool = Field(
        default=True,
        description="是否使用文字方向分类器（检测倒置文字）"
    )
    return_details: bool = Field(
        default=True,
        description="是否返回详细识别结果（文字框坐标、置信度等）"
    )
    text_layout: Literal["horizontal", "vertical_rl", "vertical_lr"] = Field(
        default="horizontal",
        description="文字排版方向",
        json_schema_extra={
            "x-enumDescriptions": {
                "horizontal": "横排从左到右（适用于普通排版）",
                "vertical_rl": "竖排从右到左（适用于古书、族谱等传统排版）⭐",
                "vertical_lr": "竖排从左到右"
            }
        }
    )
    output_format: Literal["line_by_line", "char_by_char", "column_by_column"] = Field(
        default="line_by_line",
        description="输出格式",
        json_schema_extra={
            "x-enumDescriptions": {
                "line_by_line": "逐行输出（默认，每行识别结果单独一行）",
                "char_by_char": "逐字排列（所有文字连接在一起，适合阅读）",
                "column_by_column": "逐列排列（按列分组，保留原始列结构）"
            }
        }
    )


class TextBox(BaseModel):
    """单个文本框的详细信息"""
    text: str = Field(
        ...,
        description="识别出的文字内容",
        json_schema_extra={"example": "静夜思"}
    )
    confidence: float = Field(
        ...,
        description="识别置信度（0-1之间，越接近1越准确）",
        ge=0,
        le=1,
        json_schema_extra={"example": 0.98}
    )
    box: List[List[float]] = Field(
        ...,
        description="文字框四个角的坐标 [[x1,y1], [x2,y2], [x3,y3], [x4,y4]]",
        json_schema_extra={
            "example": [[100, 50], [200, 50], [200, 80], [100, 80]]
        }
    )


class OcrResponse(BaseModel):
    """OCR 识别结果响应"""
    success: bool = Field(
        ...,
        description="识别是否成功（true=成功，false=失败）"
    )
    text: str = Field(
        ...,
        description="完整识别的文本内容（按行排列，使用\\n换行）"
    )
    details: Optional[List[TextBox]] = Field(
        default=None,
        description="详细的识别结果列表（每个文字框的信息，仅在 return_details=true 时返回）"
    )
    processing_time: float = Field(
        ...,
        description="处理耗时（单位：秒）",
        ge=0,
        json_schema_extra={"example": 1.23}
    )
    error: Optional[str] = Field(
        default=None,
        description="错误信息（仅在 success=false 时有值）"
    )


class HealthResponse(BaseModel):
    """健康检查响应"""
    status: str = Field(
        ...,
        description="服务状态（healthy=正常）",
        json_schema_extra={"example": "healthy"}
    )
    version: str = Field(
        ...,
        description="API 版本号",
        json_schema_extra={"example": "2.0.0"}
    )


class StatusResponse(BaseModel):
    """服务统计状态响应"""
    ocr_loaded: bool = Field(
        ...,
        description="OCR 模型是否已加载完成"
    )
    total_requests: int = Field(
        ...,
        description="累计总请求数",
        ge=0
    )
    total_images: int = Field(
        ...,
        description="累计处理的图片总数",
        ge=0
    )


# ============ 批量扫描相关模型 ============

class PageInfo(BaseModel):
    """单个页面的识别结果"""
    file_path: str = Field(
        ...,
        description="文件的完整路径",
        json_schema_extra={"example": "D:/scans/卷一/001.jpg"}
    )
    file_name: str = Field(
        ...,
        description="文件名（含扩展名）",
        json_schema_extra={"example": "001.jpg"}
    )
    page_number: Optional[int] = Field(
        default=None,
        description="页码（从文件名自动识别，如无法识别则为null）",
        ge=1,
        json_schema_extra={"example": 1}
    )
    volume: Optional[str] = Field(
        default=None,
        description="卷号/册号（从文件名自动识别，如：卷一、volume1）",
        json_schema_extra={"example": "卷一"}
    )
    text: str = Field(
        default="",
        description="识别出的文字内容"
    )
    confidence: float = Field(
        default=0.0,
        description="平均识别置信度（所有文字框的平均值）",
        ge=0,
        le=1
    )
    success: bool = Field(
        default=True,
        description="该页是否识别成功"
    )
    error: Optional[str] = Field(
        default=None,
        description="错误信息（仅在该页识别失败时有值）"
    )
    processing_time: float = Field(
        default=0.0,
        description="该页处理耗时（单位：秒）",
        ge=0
    )


class BatchScanRequest(BaseModel):
    """批量扫描任务创建请求"""
    directory: str = Field(
        ...,
        description="要扫描的目录路径（绝对路径或相对路径）",
        json_schema_extra={"example": "D:/scans/李氏族谱"}
    )
    book_id: str = Field(
        ...,
        description="书籍/族谱的唯一标识ID，用于区分不同书籍",
        json_schema_extra={"example": "李氏族谱_卷一"}
    )
    lang: str = Field(
        default="ch",
        description="识别语言类型",
        json_schema_extra={"example": "ch"}
    )
    use_angle_cls: bool = Field(
        default=True,
        description="是否使用文字方向分类"
    )
    text_layout: Literal["horizontal", "vertical_rl", "vertical_lr"] = Field(
        default="horizontal",
        description="文字排版方向（古书建议使用 vertical_rl）"
    )
    output_format: Literal["line_by_line", "char_by_char", "column_by_column"] = Field(
        default="line_by_line",
        description="输出格式"
    )
    recursive: bool = Field(
        default=True,
        description="是否递归扫描子目录（true=扫描所有子文件夹）"
    )
    file_patterns: List[str] = Field(
        default=["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.pdf"],
        description="文件匹配模式（glob模式，只处理匹配的文件）"
    )


class BatchScanTask(BaseModel):
    """批量扫描任务详情"""
    task_id: str = Field(
        ...,
        description="任务唯一标识ID（UUID格式）"
    )
    book_id: str = Field(
        ...,
        description="书籍/族谱ID"
    )
    directory: str = Field(
        ...,
        description="扫描的目录路径"
    )
    status: Literal["pending", "running", "completed", "failed", "cancelled"] = Field(
        default="pending",
        description="任务状态",
        json_schema_extra={
            "x-enumDescriptions": {
                "pending": "等待开始",
                "running": "正在处理",
                "completed": "已完成",
                "failed": "处理失败",
                "cancelled": "已取消"
            }
        }
    )
    total_files: int = Field(
        default=0,
        description="待处理的总文件数",
        ge=0
    )
    processed_files: int = Field(
        default=0,
        description="已处理的文件数",
        ge=0
    )
    success_files: int = Field(
        default=0,
        description="成功识别的文件数",
        ge=0
    )
    failed_files: int = Field(
        default=0,
        description="识别失败的文件数",
        ge=0
    )
    pages: List[PageInfo] = Field(
        default_factory=list,
        description="所有已识别的页面结果列表"
    )
    created_at: str = Field(
        ...,
        description="任务创建时间（ISO 8601格式）"
    )
    started_at: Optional[str] = Field(
        default=None,
        description="任务开始时间（ISO 8601格式）"
    )
    completed_at: Optional[str] = Field(
        default=None,
        description="任务完成时间（ISO 8601格式）"
    )
    error: Optional[str] = Field(
        default=None,
        description="错误信息（仅在任务失败时有值）"
    )
    progress: float = Field(
        default=0.0,
        description="任务进度百分比（0-100）",
        ge=0,
        le=100
    )


class BatchScanResponse(BaseModel):
    """创建批量扫描任务的响应"""
    success: bool = Field(
        ...,
        description="是否成功创建任务"
    )
    task_id: str = Field(
        ...,
        description="创建的任务ID（保存此ID用于查询进度和获取结果）"
    )
    message: str = Field(
        ...,
        description="提示信息（包含文件数量等信息）"
    )


class TaskStatusResponse(BaseModel):
    """任务状态查询响应"""
    task_id: str = Field(..., description="任务ID")
    status: str = Field(..., description="任务状态")
    progress: float = Field(
        ...,
        description="任务进度百分比（0-100）",
        ge=0,
        le=100
    )
    total_files: int = Field(..., description="总文件数", ge=0)
    processed_files: int = Field(..., description="已处理文件数", ge=0)
    success_files: int = Field(..., description="成功文件数", ge=0)
    failed_files: int = Field(..., description="失败文件数", ge=0)
    pages: List[PageInfo] = Field(
        default_factory=list,
        description="已完成的页面列表（仅返回最近10条，完整结果请导出获取）"
    )
    total_pages: int = Field(
        default=0,
        description="总页面数",
        ge=0
    )
    error: Optional[str] = Field(
        default=None,
        description="错误信息（仅在任务失败时有值）"
    )


class ExportRequest(BaseModel):
    """导出任务结果请求"""
    task_id: str = Field(
        ...,
        description="要导出的任务ID"
    )
    format: Literal["json", "excel", "csv"] = Field(
        default="json",
        description="导出格式",
        json_schema_extra={
            "x-enumDescriptions": {
                "json": "JSON格式（适合程序处理）",
                "csv": "CSV格式（适合Excel打开查看）",
                "excel": "Excel格式（.xlsx文件，适合人工编辑）"
            }
        }
    )
    include_details: bool = Field(
        default=False,
        description="是否包含详细信息（如文字框坐标、置信度等）"
    )


class ExportResponse(BaseModel):
    """导出结果响应"""
    success: bool = Field(
        ...,
        description="导出是否成功"
    )
    download_url: Optional[str] = Field(
        default=None,
        description="下载链接（使用此URL下载导出文件）"
    )
    file_path: Optional[str] = Field(
        default=None,
        description="导出文件的存储路径"
    )
    file_size: Optional[int] = Field(
        default=None,
        description="导出文件的大小（单位：字节）"
    )
    total_pages: int = Field(
        default=0,
        description="导出的总页面数",
        ge=0
    )
    message: str = Field(
        ...,
        description="提示信息"
    )
