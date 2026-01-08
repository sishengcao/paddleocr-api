"""批量扫描服务 - 重构版：集成数据库存储和 Celery 队列"""
import os
import re
import json
import uuid
import logging
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional
from celery import current_app

from .schemas import (
    PageInfo, BatchScanTask, BatchScanRequest,
    TaskStatusResponse, ExportRequest
)
from .ocr_service import ocr_service, OcrOptions
from .database.session import get_db
from .database.repositories import BatchTaskRepository, OcrResultRepository, BookRepository
from .services.duplicate_detector import DuplicateDetector

logger = logging.getLogger(__name__)


class FileNameParser:
    """文件名解析器 - 从文件名提取卷号和页码"""

    # 常见族谱文件名模式
    PATTERNS = [
        # 卷一_001.jpg, 卷二_005.jpg
        (r'[\u767e\u4e07卷](\d+)[_\-._](\d+)', 'volume_page'),
        # volume1_page001.jpg
        (r'volume(\d+)[_\-._]page(\d+)', 'volume_page'),
        # v1_p001.jpg, v2-p005.jpg
        (r'v(\d+)[_\-._]p(\d+)', 'volume_page'),
        # 李氏族谱_卷一_第001页.jpg
        (r'.*[\u767e\u4e07卷](.+?)第(\d+)[\u9875\u5f20张]', 'volume_page'),
        # 001.jpg, 005.jpg (纯页码)
        (r'^(\d+)', 'page_only'),
        # page-001.jpg
        (r'page[\-_]?(\d+)', 'page_only'),
        # 扫描件_001.jpg
        (r'.*[\-_](\d+)\.(jpg|png|jpeg|bmp|pdf)$', 'page_only'),
    ]

    @staticmethod
    def parse(file_name: str) -> tuple[Optional[str], Optional[int]]:
        """
        解析文件名，提取卷号和页码

        Returns:
            (volume, page_number): 卷号和页码
        """
        name_without_ext = Path(file_name).stem

        for pattern, pattern_type in FileNameParser.PATTERNS:
            match = re.search(pattern, name_without_ext, re.IGNORECASE)
            if match:
                groups = match.groups()

                if pattern_type == 'volume_page' and len(groups) >= 2:
                    volume = groups[0]
                    page_num = int(groups[1]) if groups[1].isdigit() else None
                    return volume, page_num

                elif pattern_type == 'page_only' and groups[0].isdigit():
                    return None, int(groups[0])

        return None, None


class BatchScanService:
    """批量扫描服务 - 使用数据库和 Celery 队列"""

    def __init__(self):
        self.detector = DuplicateDetector()

    def _scan_directory(
        self,
        directory: str,
        recursive: bool = True,
        patterns: List[str] = None
    ) -> List[str]:
        """扫描目录，获取所有匹配的文件"""
        if patterns is None:
            patterns = ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.pdf",
                       "*.JPG", "*.JPEG", "*.PNG", "*.BMP", "*.PDF"]

        files = []
        dir_path = Path(directory)

        if not dir_path.exists():
            raise FileNotFoundError(f"目录不存在: {directory}")

        for pattern in patterns:
            if recursive:
                files.extend(dir_path.rglob(pattern))
            else:
                files.extend(dir_path.glob(pattern))

        # 返回绝对路径字符串列表，并排序
        return [str(f) for f in set(files)]

    def create_task(self, request: BatchScanRequest) -> Dict:
        """
        创建批量扫描任务

        使用重复检测服务，如果检测到重复任务则返回错误
        """
        db = next(get_db())
        try:
            task_repo = BatchTaskRepository(db)
            book_repo = BookRepository(db)

            # 确保书籍存在
            book = book_repo.get_or_create(request.book_id)

            # 生成任务 hash（用于重复检测）
            task_hash = self.detector.generate_task_hash(
                request.directory,
                {
                    "lang": request.lang or "ch",
                    "text_layout": request.text_layout or "horizontal",
                    "output_format": request.output_format or "line_by_line",
                    "recursive": request.recursive,
                    "file_patterns": request.file_patterns or ["*.jpg", "*.png"]
                }
            )

            # 检查是否已有重复任务
            existing_task = task_repo.find_by_hash(task_hash)
            if existing_task:
                logger.warning(f"检测到重复任务: {existing_task.task_id}")
                return {
                    "success": False,
                    "error": "DUPLICATE_TASK",
                    "message": "相同目录的扫描任务已在执行中",
                    "existing_task": {
                        "task_id": existing_task.task_id,
                        "status": existing_task.status,
                        "progress": float(existing_task.progress) if existing_task.progress else 0
                    }
                }

            # 扫描目录获取文件列表
            files = self._scan_directory(
                request.directory,
                request.recursive,
                request.file_patterns
            )

            # 创建任务
            task_id = str(uuid.uuid4())
            task = task_repo.create(
                task_id=task_id,
                book_id=request.book_id,
                task_name=f"扫描任务: {request.book_id}",
                source_directory=request.directory,
                lang=request.lang or "ch",
                use_angle_cls=request.use_angle_cls if request.use_angle_cls is not None else True,
                text_layout=request.text_layout or "horizontal",
                output_format=request.output_format or "line_by_line",
                recursives=1 if request.recursive else 0,
                file_patterns=request.file_patterns,
                status="pending",
                total_files=len(files),
                task_hash=task_hash,
                priority=request.priority or 5
            )

            logger.info(f"创建批量扫描任务: {task_id}, 文件数: {len(files)}")

            return {
                "success": True,
                "task_id": task_id,
                "book_id": request.book_id,
                "total_files": len(files),
                "status": "pending",
                "message": f"批量扫描任务已创建，共 {len(files)} 个文件"
            }

        except Exception as e:
            error_msg = str(e)
            logger.error(f"创建任务失败 - 目录: {request.directory}, 书籍: {request.book_id}, 错误: {error_msg}", exc_info=True)
            return {
                "success": False,
                "error": "TASK_CREATION_FAILED",
                "message": f"创建任务失败: {error_msg}",
                "details": {
                    "directory": request.directory,
                    "book_id": request.book_id,
                    "error_type": type(e).__name__
                }
            }
        finally:
            db.close()

    def submit_to_celery(self, task_id: str) -> bool:
        """提交任务到 Celery 队列"""
        db = next(get_db())
        try:
            task_repo = BatchTaskRepository(db)
            task = task_repo.get_by_id(task_id)

            if not task:
                logger.error(f"任务不存在: {task_id}")
                return False

            if task.status != "pending":
                logger.warning(f"任务状态不是 pending，无法提交: {task_id}, 当前状态: {task.status}")
                return False

            # 使用 send_task 提交任务
            from app.workers.celery_worker import celery_app
            celery_task = celery_app.send_task(
                "app.process_batch_scan",
                args=[
                    task_id,
                    task.book_id,
                    task.source_directory,
                    task.lang,
                    task.use_angle_cls,
                    task.text_layout,
                    task.output_format,
                    bool(task.recursives),
                    task.file_patterns,
                    task.priority
                ],
                priority=task.priority
            )

            # 更新任务状态
            task_repo.update_status(
                task_id,
                "queued",
                celery_task_id=celery_task.id,
                queued_at=datetime.now()
            )

            logger.info(f"任务已提交到 Celery 队列: {task_id}, Celery 任务ID: {celery_task.id}")
            return True

        except Exception as e:
            logger.error(f"提交任务到 Celery 失败: {e}", exc_info=True)
            return False
        finally:
            db.close()

    def start_task(self, task_id: str) -> Dict:
        """启动任务（提交到 Celery 队列）"""
        result = self.submit_to_celery(task_id)
        if result:
            return {
                "success": True,
                "message": "任务已启动",
                "task_id": task_id
            }
        else:
            return {
                "success": False,
                "message": "任务启动失败，请检查任务状态"
            }

    def get_task_status(self, task_id: str) -> Optional[Dict]:
        """获取任务状态（从数据库）"""
        db = next(get_db())
        try:
            task_repo = BatchTaskRepository(db)
            ocr_repo = OcrResultRepository(db)

            task = task_repo.get_by_id(task_id)
            if not task:
                return None

            # 获取最近处理的页面（用于预览）
            recent_pages = ocr_repo.get_by_task(task_id, limit=10)

            return {
                "task_id": task.task_id,
                "book_id": task.book_id,
                "status": task.status,
                "progress": float(task.progress) if task.progress else 0,
                "total_files": task.total_files,
                "processed_files": task.processed_files,
                "success_files": task.success_files,
                "failed_files": task.failed_files,
                "created_at": task.created_at.isoformat() if task.created_at else None,
                "started_at": task.started_at.isoformat() if task.started_at else None,
                "completed_at": task.completed_at.isoformat() if task.completed_at else None,
                "error": task.error_message,
                "recent_pages": [
                    {
                        "file_name": p.file_name,
                        "page_number": p.page_number,
                        "volume": p.volume,
                        "success": p.success,
                        "confidence": float(p.confidence) if p.confidence else 0
                    }
                    for p in recent_pages
                ]
            }

        except Exception as e:
            logger.error(f"获取任务状态失败: {e}", exc_info=True)
            return None
        finally:
            db.close()

    def cancel_task(self, task_id: str) -> bool:
        """取消任务"""
        db = next(get_db())
        try:
            task_repo = BatchTaskRepository(db)
            task = task_repo.get_by_id(task_id)

            if not task:
                return False

            if task.status in ["pending", "queued"]:
                # 取消 Celery 任务
                if task.celery_task_id:
                    try:
                        current_app.control.revoke(task.celery_task_id, terminate=True)
                    except Exception as e:
                        logger.warning(f"取消 Celery 任务失败: {e}")

                # 更新数据库状态
                task_repo.update_status(task_id, "cancelled")
                return True

            return False

        except Exception as e:
            logger.error(f"取消任务失败: {e}", exc_info=True)
            return False
        finally:
            db.close()

    def delete_task(self, task_id: str) -> bool:
        """删除任务及其所有关联数据"""
        db = next(get_db())
        try:
            task_repo = BatchTaskRepository(db)
            task = task_repo.get_by_id(task_id)

            if not task:
                return False

            # 只有 pending, completed, failed, cancelled 状态的任务可以删除
            if task.status in ["queued", "processing"]:
                logger.warning(f"任务正在处理中，无法删除: {task_id}")
                return False

            # 删除任务（会级联删除关联的 OCR 结果）
            task_repo.delete(task_id)
            logger.info(f"任务已删除: {task_id}")
            return True

        except Exception as e:
            logger.error(f"删除任务失败 - task_id: {task_id}, 错误: {e}", exc_info=True)
            return False
        finally:
            db.close()

    def list_tasks(self, book_id: Optional[str] = None, limit: int = 100) -> List[Dict]:
        """列出所有任务"""
        db = next(get_db())
        try:
            task_repo = BatchTaskRepository(db)

            if book_id:
                from app.database.models import BatchTask
                tasks = db.query(BatchTask).filter(
                    BatchTask.book_id == book_id
                ).order_by(BatchTask.created_at.desc()).limit(limit).all()
            else:
                from app.database.models import BatchTask
                tasks = db.query(BatchTask).order_by(
                    BatchTask.created_at.desc()
                ).limit(limit).all()

            return [
                {
                    "task_id": t.task_id,
                    "book_id": t.book_id,
                    "task_name": t.task_name,
                    "status": t.status,
                    "progress": float(t.progress) if t.progress else 0,
                    "total_files": t.total_files,
                    "processed_files": t.processed_files,
                    "success_files": t.success_files,
                    "failed_files": t.failed_files,
                    "created_at": t.created_at.isoformat() if t.created_at else None
                }
                for t in tasks
            ]

        except Exception as e:
            logger.error(f"列出任务失败: {e}", exc_info=True)
            return []
        finally:
            db.close()

    def export_task(
        self,
        task_id: str,
        format: str = "json",
        include_details: bool = False
    ) -> Optional[str]:
        """
        导出任务结果

        Returns:
            导出文件的路径
        """
        db = next(get_db())
        try:
            ocr_repo = OcrResultRepository(db)
            task_repo = BatchTaskRepository(db)

            task = task_repo.get_by_id(task_id)
            if not task:
                return None

            # 获取所有 OCR 结果
            results = ocr_repo.get_by_task(task_id, limit=10000)

            # 创建导出目录
            export_dir = Path(__file__).parent.parent / "exports"
            export_dir.mkdir(exist_ok=True)

            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

            if format == "json":
                export_file = export_dir / f"{task.book_id}_{timestamp}.json"

                # 准备导出数据（简化版：只包含名称、页数、识别后的数据）
                data = {
                    "book_id": task.book_id,
                    "task_id": task.task_id,
                    "export_time": datetime.now().isoformat(),
                    "total_pages": len(results),
                    "source_directory": task.source_directory,
                    "pages": [
                        {
                            "file_name": r.file_name,
                            "page_number": r.page_number,
                            "volume": r.volume,
                            "raw_text": r.raw_text,
                            "confidence": float(r.confidence) if r.confidence else 0,
                            "success": r.success
                        }
                        for r in results
                    ]
                }

                with open(export_file, 'w', encoding='utf-8') as f:
                    json.dump(data, f, ensure_ascii=False, indent=2)

                return str(export_file)

            elif format == "csv":
                import csv
                export_file = export_dir / f"{task.book_id}_{timestamp}.csv"

                with open(export_file, 'w', encoding='utf-8-sig', newline='') as f:
                    writer = csv.writer(f)
                    writer.writerow([
                        "文件名", "卷号", "页码", "识别文字", "置信度", "状态"
                    ])

                    for r in results:
                        writer.writerow([
                            r.file_name,
                            r.volume or "",
                            r.page_number or "",
                            r.raw_text,
                            f"{float(r.confidence):.2%}" if r.confidence else "0%",
                            "成功" if r.success else "失败"
                        ])

                return str(export_file)

            return None

        except Exception as e:
            logger.error(f"导出任务失败: {e}", exc_info=True)
            return None
        finally:
            db.close()


# 全局批量扫描服务实例
batch_scan_service = BatchScanService()
