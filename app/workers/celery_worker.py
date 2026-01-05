"""Celery Worker for OCR Processing"""
from celery import Celery, shared_task
from celery.exceptions import SoftTimeLimitExceeded
from typing import List, Dict, Any
import logging
import traceback
from pathlib import Path
import uuid
from datetime import datetime
import sys

from app.config import settings
from app.database.session import get_db
from app.database.repositories import BatchTaskRepository, OcrResultRepository, BookRepository
from app.ocr_service import ocr_service, OcrOptions

# 配置日志输出到文件
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('/mnt/d/project/github/paddleocr-api/logs/celery_worker.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

# Initialize Celery with Redis broker
celery_app = Celery(
    "paddleocr_worker",
    broker=settings.CELERY_BROKER_URL,
    backend=settings.CELERY_RESULT_BACKEND,
)

celery_app.conf.update(
    task_serializer=settings.CELERY_TASK_SERIALIZER,
    result_serializer=settings.CELERY_RESULT_SERIALIZER,
    accept_content=settings.CELERY_ACCEPT_CONTENT,
    timezone=settings.CELERY_TIMEZONE,
    enable_utc=settings.CELERY_ENABLE_UTC,
    task_track_started=settings.CELERY_TASK_TRACK_STARTED,
    task_time_limit=settings.CELERY_TASK_TIME_LIMIT,
    task_soft_time_limit=settings.CELERY_TASK_SOFT_TIME_LIMIT,
    worker_prefetch_multiplier=settings.CELERY_WORKER_PREFETCH_MULTIPLIER,
    worker_max_tasks_per_child=settings.CELERY_WORKER_MAX_TASKS_PER_CHILD,
    task_acks_late=True,
)


@shared_task(bind=True, name="app.process_batch_scan", max_retries=settings.TASK_MAX_RETRIES)
def process_batch_scan_task(
    self,
    task_id: str,
    book_id: str,
    directory: str,
    lang: str = "ch",
    use_angle_cls: bool = True,
    text_layout: str = "horizontal",
    output_format: str = "line_by_line",
    recursive: bool = True,
    file_patterns: List[str] = None,
    priority: int = 5
) -> Dict[str, Any]:
    """
    Process batch scan task - Main Celery task

    Args:
        task_id: Unique task identifier
        book_id: Book identifier
        directory: Directory to scan
        lang: OCR language
        use_angle_cls: Use angle classification
        text_layout: Text layout direction
        output_format: Output format
        recursive: Recursive directory scan
        file_patterns: File patterns to match
        priority: Task priority

    Returns:
        Task result dictionary
    """
    db = next(get_db())
    task_repo = BatchTaskRepository(db)
    ocr_repo = OcrResultRepository(db)
    book_repo = BookRepository(db)

    try:
        # Ensure book exists
        book = book_repo.get_or_create(book_id)

        # Update task status to processing
        task_repo.update_status(task_id, "processing", celery_task_id=self.request.id)
        logger.info(f"Processing batch scan task: {task_id}")

        # Scan directory for files
        files = scan_directory(directory, recursive, file_patterns)
        task_repo.update_total_files(task_id, len(files))

        # Process files
        results = []
        for file_path in files:
            try:
                # Create OCR options
                options = OcrOptions(
                    lang=lang,
                    use_angle_cls=use_angle_cls,
                    return_details=True,
                    text_layout=text_layout,
                    output_format=output_format
                )

                # Execute OCR
                ocr_result = ocr_service.recognize(file_path, options)

                # Extract metadata from filename
                file_name = Path(file_path).name
                from app.batch_scan_service import FileNameParser
                volume, page_num = FileNameParser.parse(file_name)

                # Prepare JSON data with box coordinates
                json_data = None
                if ocr_result.get("details"):
                    json_data = [
                        {
                            "text": item.text,
                            "confidence": float(item.confidence) if item.confidence else 0.0,
                            "box": item.box
                        }
                        for item in ocr_result["details"]
                    ]

                # Save to database
                page_id = str(uuid.uuid4())
                ocr_repo.create(
                    page_id=page_id,
                    task_id=task_id,
                    book_id=book_id,
                    file_name=file_name,
                    page_number=page_num,
                    volume=volume,
                    raw_text=ocr_result.get("text", ""),
                    json_data=json_data,
                    confidence=ocr_result.get("confidence", 0.0),
                    success=ocr_result.get("success", False),
                    processing_time=ocr_result.get("processing_time", 0.0)
                )

                results.append({
                    "file_path": file_path,
                    "page_id": page_id,
                    "success": ocr_result.get("success", False)
                })

                # Update progress
                progress = (len(results) / len(files)) * 100
                task_repo.update_progress(task_id, progress, len(results))

            except Exception as e:
                logger.error(f"Failed to process file {file_path}: {e}")
                results.append({
                    "file_path": file_path,
                    "success": False,
                    "error": str(e)
                })

        # Mark task as completed
        success_count = sum(1 for r in results if r.get("success"))
        failed_count = len(results) - success_count

        task_repo.complete_task(
            task_id=task_id,
            status="completed",
            success_files=success_count,
            failed_files=failed_count
        )

        logger.info(f"Batch scan task {task_id} completed: {success_count} success, {failed_count} failed")

        return {
            "task_id": task_id,
            "status": "completed",
            "total_files": len(files),
            "success_files": success_count,
            "failed_files": failed_count
        }

    except SoftTimeLimitExceeded:
        # Task timeout
        logger.error(f"Task {task_id} exceeded time limit")
        task_repo.update_status(task_id, "failed", error_message="Task timeout")
        self.retry(countdown=60)  # Retry after 1 minute

    except Exception as e:
        logger.exception(f"Task {task_id} failed: {e}")

        # Check if we should retry
        if self.request.retries < settings.TASK_MAX_RETRIES:
            task_repo.update_status(task_id, "retrying")
            raise self.retry(exc=e, countdown=settings.TASK_RETRY_DELAY)
        else:
            task_repo.update_status(
                task_id,
                "failed",
                error_message=str(e),
                error_stack=traceback.format_exc()
            )
            raise

    finally:
        db.close()


def scan_directory(directory: str, recursive: bool = True, patterns: List[str] = None) -> List[str]:
    """Scan directory for matching files"""
    if patterns is None:
        patterns = ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.pdf",
                   "*.JPG", "*.JPEG", "*.PNG", "*.BMP", "*.PDF"]

    dir_path = Path(directory)
    if not dir_path.exists():
        raise FileNotFoundError(f"Directory not found: {directory}")

    files = []
    for pattern in patterns:
        if recursive:
            files.extend(dir_path.rglob(pattern))
        else:
            files.extend(dir_path.glob(pattern))

    return [str(f.absolute()) for f in set(files)]


@shared_task(name="app.cleanup_expired_exports")
def cleanup_expired_exports():
    """Clean up expired export files"""
    db = next(get_db())
    try:
        from app.database.models import Export
        from sqlalchemy import and_

        expired = db.query(Export).filter(
            and_(
                Export.status == "completed",
                Export.expires_at < datetime.now()
            )
        ).all()

        for export in expired:
            # Delete file
            if export.file_path and Path(export.file_path).exists():
                Path(export.file_path).unlink()

            # Update database
            export.status = "expired"

        db.commit()
        logger.info(f"Cleaned up {len(expired)} expired exports")

    except Exception as e:
        logger.error(f"Export cleanup failed: {e}")
        db.rollback()
    finally:
        db.close()
