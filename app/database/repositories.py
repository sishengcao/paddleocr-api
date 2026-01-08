"""Database Repositories - Data Access Layer"""
from sqlalchemy.orm import Session
from sqlalchemy import and_, or_, func, text
from typing import List, Dict, Any, Optional
from datetime import datetime, timedelta
import uuid

from app.database.models import (
    Book, BatchTask, OcrResult,
    Export, TaskLock, ProcessingLog
)


class BaseRepository:
    """Base repository with common methods"""

    def __init__(self, db: Session):
        self.db = db


class BookRepository(BaseRepository):
    """Book repository"""

    def get_by_id(self, book_id: str) -> Optional[Book]:
        """Get book by book_id"""
        return self.db.query(Book).filter(Book.book_id == book_id).first()

    def create(self, book_id: str, **kwargs) -> Book:
        """Create new book"""
        book = Book(book_id=book_id, **kwargs)
        self.db.add(book)
        self.db.commit()
        self.db.refresh(book)
        return book

    def get_or_create(self, book_id: str) -> Book:
        """Get existing book or create new one"""
        book = self.get_by_id(book_id)
        if not book:
            book = self.create(book_id=book_id)
        return book

    def list_books(self, category: Optional[str] = None,
                   limit: int = 100, offset: int = 0) -> List[Dict]:
        """List books"""
        query = self.db.query(Book)
        if category:
            query = query.filter(Book.category == category)
        books = query.offset(offset).limit(limit).all()
        return [
            {
                "book_id": b.book_id,
                "title": b.title,
                "author": b.author,
                "category": b.category,
                "total_pages": b.total_pages,
                "created_at": b.created_at.isoformat() if b.created_at else None
            }
            for b in books
        ]

    def get_statistics(self, book_id: str) -> Optional[Dict]:
        """Get book statistics"""
        book = self.get_by_id(book_id)
        if not book:
            return None

        stats = self.db.query(
            func.count(BatchTask.id).label('total_tasks'),
            func.sum(BatchTask.total_files).label('total_pages'),
            func.sum(func.case((BatchTask.status == 'completed', 1), else_=0)).label('completed'),
            func.sum(func.case((BatchTask.status == 'processing', 1), else_=0)).label('processing')
        ).filter(BatchTask.book_id == book_id).first()

        return {
            "book_id": book.book_id,
            "title": book.title,
            "total_tasks": stats.total_tasks or 0,
            "total_pages": stats.total_pages or 0,
            "completed_tasks": stats.completed or 0,
            "processing_tasks": stats.processing or 0
        }


class BatchTaskRepository(BaseRepository):
    """Batch task repository"""

    def get_by_id(self, task_id: str) -> Optional[BatchTask]:
        """Get task by task_id"""
        return self.db.query(BatchTask).filter(BatchTask.task_id == task_id).first()

    def create(self, **kwargs) -> BatchTask:
        """Create new task"""
        task = BatchTask(**kwargs)
        self.db.add(task)
        self.db.commit()
        self.db.refresh(task)
        return task

    def find_by_hash(self, task_hash: str) -> Optional[BatchTask]:
        """Find task by hash (for duplicate detection)"""
        return self.db.query(BatchTask).filter(
            and_(
                BatchTask.task_hash == task_hash,
                BatchTask.status.in_(['pending', 'queued', 'processing'])
            )
        ).first()

    def update_status(self, task_id: str, status: str, **kwargs) -> bool:
        """Update task status"""
        task = self.get_by_id(task_id)
        if not task:
            return False

        task.status = status
        if status == 'processing' and not task.started_at:
            task.started_at = datetime.now()
        if status in ['completed', 'failed', 'cancelled']:
            task.completed_at = datetime.now()

        for key, value in kwargs.items():
            setattr(task, key, value)

        self.db.commit()
        return True

    def update_total_files(self, task_id: str, total: int) -> bool:
        """Update total files count"""
        task = self.get_by_id(task_id)
        if not task:
            return False
        task.total_files = total
        self.db.commit()
        return True

    def update_progress(self, task_id: str, progress: float, processed: int) -> bool:
        """Update task progress"""
        task = self.get_by_id(task_id)
        if not task:
            return False
        task.progress = progress
        task.processed_files = processed
        self.db.commit()
        return True

    def complete_task(self, task_id: str, status: str,
                     success_files: int, failed_files: int) -> bool:
        """Complete task"""
        task = self.get_by_id(task_id)
        if not task:
            return False

        task.status = status
        task.success_files = success_files
        task.failed_files = failed_files
        task.progress = 100.0
        task.completed_at = datetime.now()
        self.db.commit()
        return True

    def delete(self, task_id: str) -> bool:
        """Delete task by task_id (will cascade delete related records)"""
        task = self.get_by_id(task_id)
        if not task:
            return False
        self.db.delete(task)
        self.db.commit()
        return True

    def create_task_lock(self, task_id: str, book_id: str,
                        lock_key: str, ttl_minutes: int) -> bool:
        """Create task lock for duplicate detection"""
        try:
            lock = TaskLock(
                task_id=task_id,
                book_id=book_id,
                lock_key=lock_key,
                expires_at=datetime.now() + timedelta(minutes=ttl_minutes)
            )
            self.db.add(lock)
            self.db.commit()
            return True
        except Exception:
            self.db.rollback()
            return False

    def list_active_tasks(self, limit: int = 100) -> List[BatchTask]:
        """List active tasks"""
        return self.db.query(BatchTask).filter(
            BatchTask.status.in_(['pending', 'queued', 'processing'])
        ).order_by(BatchTask.priority.desc(), BatchTask.created_at).limit(limit).all()


class OcrResultRepository(BaseRepository):
    """OCR result repository"""

    def create(self, **kwargs) -> OcrResult:
        """Create new OCR result"""
        result = OcrResult(**kwargs)
        self.db.add(result)
        self.db.commit()
        self.db.refresh(result)
        return result

    def get_by_page_id(self, page_id: str) -> Optional[OcrResult]:
        """Get result by page_id"""
        return self.db.query(OcrResult).filter(OcrResult.page_id == page_id).first()

    def get_by_task(self, task_id: str, limit: int = 100) -> List[OcrResult]:
        """Get results by task_id"""
        return self.db.query(OcrResult).filter(
            OcrResult.task_id == task_id
        ).order_by(OcrResult.page_number).limit(limit).all()

    def full_text_search(self, book_id: str, query: str,
                        volume: Optional[str] = None,
                        page_number: Optional[int] = None,
                        limit: int = 50, offset: int = 0) -> List[Dict]:
        """Full text search in OCR results"""
        # Build base query
        filters = [OcrResult.book_id == book_id]
        if volume:
            filters.append(OcrResult.volume == volume)
        if page_number is not None:
            filters.append(OcrResult.page_number == page_number)

        # Use FULLTEXT search
        results = self.db.query(OcrResult).filter(
            and_(*filters)
        ).filter(
            text(f"raw_text LIKE '%{query}%'")
        ).offset(offset).limit(limit).all()

        return [
            {
                "page_id": r.page_id,
                "task_id": r.task_id,
                "file_name": r.file_name,
                "page_number": r.page_number,
                "volume": r.volume,
                "raw_text": r.raw_text[:500] + "..." if r.raw_text and len(r.raw_text) > 500 else r.raw_text,
                "confidence": float(r.confidence) if r.confidence else 0,
                "success": r.success
            }
            for r in results
        ]

    def get_pages(self, filters: Dict[str, Any],
                 limit: int = 100, offset: int = 0) -> List[Dict]:
        """Get pages with filters"""
        query = self.db.query(OcrResult)

        # Apply filters
        for key, value in filters.items():
            if hasattr(OcrResult, key) and value is not None:
                if key == "min_confidence":
                    query = query.filter(OcrResult.confidence >= value)
                else:
                    query = query.filter(getattr(OcrResult, key) == value)

        pages = query.offset(offset).limit(limit).all()

        return [
            {
                "page_id": p.page_id,
                "file_name": p.file_name,
                "page_number": p.page_number,
                "volume": p.volume,
                "raw_text": p.raw_text[:200] + "..." if p.raw_text and len(p.raw_text) > 200 else p.raw_text,
                "confidence": float(p.confidence) if p.confidence else 0,
                "success": p.success
            }
            for p in pages
        ]
