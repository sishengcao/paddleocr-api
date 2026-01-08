"""SQLAlchemy ORM Models"""
from sqlalchemy import Column, String, Integer, BigInteger, DateTime, Text, Float, JSON, Enum, ForeignKey, Index, DECIMAL, TIMESTAMP, func
from sqlalchemy.orm import relationship, declarative_base
from datetime import datetime
import uuid

Base = declarative_base()


class Book(Base):
    """Books table"""
    __tablename__ = "books"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    book_id = Column(String(255), unique=True, nullable=False, index=True, comment='External book identifier')
    title = Column(String(500), comment='Book title')
    author = Column(String(255), comment='Author name')
    category = Column(String(100), index=True, comment='Category')
    description = Column(Text, comment='Book description')
    source_directory = Column(String(1000), comment='Source directory path')
    total_pages = Column(Integer, default=0, comment='Total pages')
    total_volumes = Column(Integer, default=0, comment='Total volumes')
    # 使用 'metadata' 作为数据库列名（metadata 是 Python 保留字，所以用不同的属性名）
    metadata_json = Column("metadata", JSON, comment='Additional metadata')
    created_at = Column(TIMESTAMP, default=func.now(), comment='Creation time')
    updated_at = Column(TIMESTAMP, default=func.now(), onupdate=func.now(), comment='Update time')

    # Relationships
    batch_tasks = relationship("BatchTask", back_populates="book", cascade="all, delete-orphan")
    ocr_results = relationship("OcrResult", back_populates="book", cascade="all, delete-orphan")
    exports = relationship("Export", back_populates="book", cascade="all, delete-orphan")


class BatchTask(Base):
    """Batch tasks table"""
    __tablename__ = "batch_tasks"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    task_id = Column(String(36), unique=True, nullable=False, index=True, comment='UUID task identifier')
    book_id = Column(String(255), ForeignKey("books.book_id", ondelete="CASCADE"), nullable=False, index=True, comment='Associated book ID')
    task_name = Column(String(500), comment='Task name')
    source_directory = Column(String(1000), nullable=False, comment='Source directory')

    # Configuration
    lang = Column(String(10), default="ch", comment='OCR language')
    use_angle_cls = Column(Integer, default=1, comment='Use angle classification')
    text_layout = Column(String(20), default="horizontal", comment='Text layout')
    output_format = Column(String(30), default="line_by_line", comment='Output format')
    recursives = Column(Integer, default=1, comment='Recursive scan')
    file_patterns = Column(JSON, comment='File patterns')

    # Status
    status = Column(Enum("pending", "queued", "processing", "completed", "failed", "cancelled", "retrying", name="batchtask_status"),
                   default="pending", index=True, comment='Task status')
    priority = Column(Integer, default=5, index=True, comment='Task priority')

    # Statistics
    total_files = Column(Integer, default=0, comment='Total files')
    processed_files = Column(Integer, default=0, comment='Processed files')
    success_files = Column(Integer, default=0, comment='Success files')
    failed_files = Column(Integer, default=0, comment='Failed files')
    progress = Column(DECIMAL(5, 2), default=0.00, comment='Progress percentage')

    # Celery tracking
    celery_task_id = Column(String(255), index=True, comment='Celery task ID')
    worker_name = Column(String(255), comment='Worker name')
    retry_count = Column(Integer, default=0, comment='Retry count')
    max_retries = Column(Integer, default=3, comment='Max retries')

    # Timestamps
    created_at = Column(TIMESTAMP, default=func.now(), index=True, comment='Created at')
    queued_at = Column(TIMESTAMP, comment='Queued at')
    started_at = Column(TIMESTAMP, comment='Started at')
    completed_at = Column(TIMESTAMP, comment='Completed at')
    updated_at = Column(TIMESTAMP, default=func.now(), onupdate=func.now(), comment='Updated at')

    # Errors
    error_message = Column(Text, comment='Error message')
    error_stack = Column(Text, comment='Error stack')

    # Duplicate detection
    task_hash = Column(String(64), index=True, comment='Task hash for duplicate detection')

    # Relationships
    book = relationship("Book", back_populates="batch_tasks")
    ocr_results = relationship("OcrResult", back_populates="batch_task", cascade="all, delete-orphan")
    exports = relationship("Export", back_populates="batch_task", cascade="all, delete-orphan")

    __table_args__ = (
        Index("idx_batchtask_status_priority", "status", "priority"),
    )


class OcrResult(Base):
    """OCR results table - Simplified for genealogy project"""
    __tablename__ = "ocr_results"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    task_id = Column(String(36), ForeignKey("batch_tasks.task_id", ondelete="CASCADE"), nullable=False, index=True, comment='Task ID')
    book_id = Column(String(255), ForeignKey("books.book_id", ondelete="CASCADE"), nullable=False, index=True, comment='Book ID')
    page_id = Column(String(36), unique=True, nullable=False, index=True, comment='Page ID')

    # Core fields (required by user)
    file_name = Column(String(255), nullable=False, comment='File name (名称)')
    page_number = Column(Integer, index=True, comment='Page number (页数)')
    raw_text = Column(Text, comment='OCR recognized text (识别后的数据)')
    json_data = Column(JSON, comment='OCR JSON data with box coordinates (包含box坐标的JSON数据)')

    # Auxiliary fields (decided for functionality)
    volume = Column(String(100), index=True, comment='Volume number (卷号)')
    confidence = Column(DECIMAL(5, 4), default=0.0000, comment='Recognition confidence')
    success = Column(Integer, default=1, index=True, comment='Recognition success status')
    processing_time = Column(DECIMAL(10, 3), default=0.000, comment='Processing time in seconds')

    # Timestamps
    created_at = Column(TIMESTAMP, default=func.now(), comment='Created at')

    # Relationships
    batch_task = relationship("BatchTask", back_populates="ocr_results")
    book = relationship("Book", back_populates="ocr_results")

    __table_args__ = (
        Index("idx_ocrresult_book_page", "book_id", "page_number"),
        Index("idx_ocrresult_volume", "volume"),
    )


class Export(Base):
    """Exports tracking table"""
    __tablename__ = "exports"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    export_id = Column(String(36), unique=True, nullable=False, index=True, comment='Export ID')
    task_id = Column(String(36), ForeignKey("batch_tasks.task_id", ondelete="CASCADE"), nullable=False, index=True, comment='Task ID')
    book_id = Column(String(255), ForeignKey("books.book_id", ondelete="CASCADE"), nullable=False, index=True, comment='Book ID')

    # Export configuration
    export_format = Column(Enum("json", "csv", "excel", "xml", name="exportformat"),
                          default="json", comment='Export format')
    include_images = Column(Integer, default=0, comment='Include images')
    include_details = Column(Integer, default=0, comment='Include details')
    include_structured = Column(Integer, default=0, comment='Include structured')

    # Status
    status = Column(Enum("pending", "processing", "completed", "failed", name="exportstatus"),
                   default="pending", index=True, comment='Export status')
    progress = Column(DECIMAL(5, 2), default=0.00, comment='Progress')

    # File info
    file_path = Column(String(1000), comment='File path')
    file_size = Column(BigInteger, default=0, comment='File size')
    file_count = Column(Integer, default=0, comment='File count')
    download_url = Column(String(1000), comment='Download URL')

    # Expiration
    expires_at = Column(TIMESTAMP, index=True, comment='Expires at')

    # Statistics
    total_records = Column(Integer, default=0, comment='Total records')

    # Timestamps
    created_at = Column(TIMESTAMP, default=func.now(), comment='Created at')
    completed_at = Column(TIMESTAMP, comment='Completed at')

    # Relationships
    batch_task = relationship("BatchTask", back_populates="exports")
    book = relationship("Book", back_populates="exports")


class TaskLock(Base):
    """Task locks for duplicate detection"""
    __tablename__ = "task_locks"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    lock_key = Column(String(255), unique=True, nullable=False, index=True, comment='Lock key')
    task_id = Column(String(36), nullable=False, comment='Task ID')
    book_id = Column(String(255), nullable=False, comment='Book ID')
    status = Column(Enum("active", "completed", "expired", name="lockstatus"),
                   default="active", index=True, comment='Lock status')
    locked_at = Column(TIMESTAMP, default=func.now(), comment='Locked at')
    expires_at = Column(TIMESTAMP, nullable=False, index=True, comment='Expires at')


class ProcessingLog(Base):
    """Processing logs"""
    __tablename__ = "processing_logs"

    id = Column(BigInteger, primary_key=True, autoincrement=True)
    task_id = Column(String(36), ForeignKey("batch_tasks.task_id", ondelete="CASCADE"), nullable=False, index=True, comment='Task ID')
    page_id = Column(String(36), comment='Page ID')

    log_level = Column(Enum("DEBUG", "INFO", "WARNING", "ERROR", "CRITICAL", name="loglevel"),
                      default="INFO", index=True, comment='Log level')
    message = Column(Text, nullable=False, comment='Message')
    module = Column(String(255), comment='Module')
    function_name = Column(String(255), comment='Function name')
    line_number = Column(Integer, comment='Line number')
    context = Column(JSON, comment='Context')
    created_at = Column(TIMESTAMP, default=func.now(), index=True, comment='Created at')
