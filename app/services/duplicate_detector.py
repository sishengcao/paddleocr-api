"""Duplicate Task Detection Service"""
import hashlib
import json
from typing import Optional, Dict, Any
from pathlib import Path

from app.database.session import get_db
from app.database.repositories import BatchTaskRepository
from app.config import settings


class DuplicateDetector:
    """Detect duplicate batch scan tasks"""

    def __init__(self):
        self.repo = BatchTaskRepository(next(get_db()))

    def generate_task_hash(self, directory: str, options: Dict[str, Any]) -> str:
        """
        Generate hash for duplicate detection

        Args:
            directory: Source directory path
            options: Task options dictionary

        Returns:
            SHA256 hash string
        """
        # Normalize directory path
        normalized_dir = str(Path(directory).absolute())

        # Create hash input
        hash_input = {
            "directory": normalized_dir,
            "lang": options.get("lang", "ch"),
            "text_layout": options.get("text_layout", "horizontal"),
            "output_format": options.get("output_format", "line_by_line"),
            "recursive": options.get("recursive", True),
            "file_patterns": sorted(options.get("file_patterns", ["*.jpg", "*.png"]))
        }

        # Generate SHA256 hash
        hash_string = json.dumps(hash_input, sort_keys=True)
        return hashlib.sha256(hash_string.encode()).hexdigest()

    def check_duplicate(
        self,
        directory: str,
        book_id: str,
        options: Dict[str, Any]
    ) -> Optional[Dict[str, Any]]:
        """
        Check if duplicate task exists

        Args:
            directory: Source directory
            book_id: Book identifier
            options: Task options

        Returns:
            Dictionary with duplicate info if found, None otherwise
        """
        task_hash = self.generate_task_hash(directory, options)

        # Check for active/processing tasks with same hash
        duplicate = self.repo.find_by_hash(task_hash)

        if duplicate and duplicate.status in ["pending", "queued", "processing"]:
            return {
                "is_duplicate": True,
                "existing_task_id": duplicate.task_id,
                "existing_status": duplicate.status,
                "existing_progress": float(duplicate.progress) if duplicate.progress else 0.0,
                "message": f"Duplicate task detected. Task {duplicate.task_id} is already {duplicate.status}"
            }

        return None

    def create_task_lock(
        self,
        task_id: str,
        book_id: str,
        directory: str,
        options: Dict[str, Any]
    ) -> bool:
        """
        Create task lock to prevent duplicates

        Args:
            task_id: New task ID
            book_id: Book ID
            directory: Source directory
            options: Task options

        Returns:
            True if lock created, False if duplicate exists
        """
        # Check for duplicate first
        duplicate = self.check_duplicate(directory, book_id, options)
        if duplicate:
            return False

        # Create lock
        task_hash = self.generate_task_hash(directory, options)
        return self.repo.create_task_lock(
            task_id=task_id,
            book_id=book_id,
            lock_key=task_hash,
            ttl_minutes=settings.TASK_LOCK_TTL // 60
        )
