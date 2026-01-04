"""批量扫描服务"""
import os
import re
import json
import uuid
import time
import threading
from datetime import datetime
from pathlib import Path
from typing import List, Dict, Optional
import glob

from .schemas import (
    PageInfo, BatchScanTask, BatchScanRequest,
    TaskStatusResponse, ExportRequest
)
from .ocr_service import ocr_service, OcrOptions


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
    """批量扫描服务单例类"""
    _instance = None
    _lock = threading.Lock()

    def __new__(cls):
        if cls._instance is None:
            with cls._lock:
                if cls._instance is None:
                    cls._instance = super().__new__(cls)
        return cls._instance

    def __init__(self):
        if not hasattr(self, '_initialized'):
            self.tasks: Dict[str, BatchScanTask] = {}
            self.tasks_dir = Path(__file__).parent.parent / "batch_tasks"
            self.tasks_dir.mkdir(exist_ok=True)
            self._load_tasks()
            self._initialized = True

    def _load_tasks(self):
        """从磁盘加载任务"""
        for task_file in self.tasks_dir.glob("*.json"):
            try:
                with open(task_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                    task = BatchScanTask(**data)
                    self.tasks[task.task_id] = task
            except Exception as e:
                print(f"加载任务失败 {task_file}: {e}")

    def _save_task(self, task: BatchScanTask):
        """保存任务到磁盘"""
        task_file = self.tasks_dir / f"{task.task_id}.json"
        with open(task_file, 'w', encoding='utf-8') as f:
            json.dump(task.dict(), f, ensure_ascii=False, indent=2)

    def _scan_directory(
        self,
        directory: str,
        recursive: bool = True,
        patterns: List[str] = None
    ) -> List[str]:
        """扫描目录，获取所有匹配的文件"""
        if patterns is None:
            patterns = ["*.jpg", "*.jpeg", "*.png", "*.bmp", "*.pdf"]

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

    def create_task(self, request: BatchScanRequest) -> BatchScanTask:
        """创建批量扫描任务"""
        task_id = str(uuid.uuid4())

        # 扫描目录获取文件列表
        files = self._scan_directory(
            request.directory,
            request.recursive,
            request.file_patterns
        )

        # 创建任务
        task = BatchScanTask(
            task_id=task_id,
            book_id=request.book_id,
            directory=request.directory,
            status="pending",
            total_files=len(files),
            created_at=datetime.now().isoformat()
        )

        self.tasks[task_id] = task
        self._save_task(task)

        return task

    def start_task(self, task_id: str) -> bool:
        """启动任务（异步执行）"""
        if task_id not in self.tasks:
            return False

        task = self.tasks[task_id]
        if task.status != "pending":
            return False

        # 在后台线程中执行
        thread = threading.Thread(target=self._execute_task, args=(task_id,))
        thread.daemon = True
        thread.start()

        return True

    def _execute_task(self, task_id: str):
        """执行扫描任务"""
        task = self.tasks[task_id]

        try:
            task.status = "running"
            task.started_at = datetime.now().isoformat()
            self._save_task(task)

            # 扫描文件
            files = self._scan_directory(task.directory, recursive=True)
            task.total_files = len(files)

            # 创建 OCR 选项（默认配置）
            options = OcrOptions(
                lang="ch",
                use_angle_cls=True,
                return_details=True,
                text_layout="horizontal",
                output_format="line_by_line"
            )

            for file_path in files:
                if task.status == "cancelled":
                    break

                try:
                    # 解析文件名
                    file_name = Path(file_path).name
                    volume, page_num = FileNameParser.parse(file_name)

                    # 执行 OCR
                    result = ocr_service.recognize(file_path, options)

                    # 计算平均置信度
                    confidence = 0.0
                    if result.get('details'):
                        confidences = [d.confidence for d in result['details']]
                        confidence = sum(confidences) / len(confidences)

                    # 创建页面信息
                    page = PageInfo(
                        file_path=file_path,
                        file_name=file_name,
                        page_number=page_num,
                        volume=volume,
                        text=result.get('text', ''),
                        confidence=confidence,
                        success=result.get('success', False),
                        error=result.get('error'),
                        processing_time=result.get('processing_time', 0.0)
                    )

                    task.pages.append(page)
                    task.processed_files += 1

                    if page.success:
                        task.success_files += 1
                    else:
                        task.failed_files += 1

                    # 更新进度
                    task.progress = (task.processed_files / task.total_files) * 100

                    # 每处理 5 个文件保存一次
                    if task.processed_files % 5 == 0:
                        self._save_task(task)

                except Exception as e:
                    task.failed_files += 1
                    task.processed_files += 1
                    page = PageInfo(
                        file_path=file_path,
                        file_name=Path(file_path).name,
                        success=False,
                        error=str(e)
                    )
                    task.pages.append(page)

            # 完成
            task.status = "completed"
            task.completed_at = datetime.now().isoformat()
            task.progress = 100.0
            self._save_task(task)

        except Exception as e:
            task.status = "failed"
            task.error = str(e)
            task.completed_at = datetime.now().isoformat()
            self._save_task(task)

    def get_task_status(self, task_id: str) -> Optional[TaskStatusResponse]:
        """获取任务状态"""
        if task_id not in self.tasks:
            return None

        task = self.tasks[task_id]

        return TaskStatusResponse(
            task_id=task.task_id,
            status=task.status,
            progress=task.progress,
            total_files=task.total_files,
            processed_files=task.processed_files,
            success_files=task.success_files,
            failed_files=task.failed_files,
            pages=task.pages[-10:] if task.pages else [],  # 返回最近 10 个页面
            total_pages=len(task.pages),
            error=task.error
        )

    def cancel_task(self, task_id: str) -> bool:
        """取消任务"""
        if task_id not in self.tasks:
            return False

        task = self.tasks[task_id]
        if task.status in ["pending", "running"]:
            task.status = "cancelled"
            self._save_task(task)
            return True

        return False

    def delete_task(self, task_id: str) -> bool:
        """删除任务"""
        if task_id not in self.tasks:
            return False

        task = self.tasks[task_id]

        # 删除任务文件
        task_file = self.tasks_dir / f"{task_id}.json"
        if task_file.exists():
            task_file.unlink()

        del self.tasks[task_id]
        return True

    def list_tasks(self) -> List[Dict]:
        """列出所有任务"""
        return [
            {
                "task_id": t.task_id,
                "book_id": t.book_id,
                "status": t.status,
                "progress": t.progress,
                "total_files": t.total_files,
                "processed_files": t.processed_files,
                "created_at": t.created_at
            }
            for t in self.tasks.values()
        ]

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
        if task_id not in self.tasks:
            return None

        task = self.tasks[task_id]

        # 创建导出目录
        export_dir = Path(__file__).parent.parent / "exports"
        export_dir.mkdir(exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")

        if format == "json":
            export_file = export_dir / f"{task.book_id}_{timestamp}.json"

            # 准备导出数据
            data = {
                "book_id": task.book_id,
                "task_id": task.task_id,
                "export_time": datetime.now().isoformat(),
                "total_pages": len(task.pages),
                "total_files": task.total_files,
                "success_files": task.success_files,
                "failed_files": task.failed_files,
                "pages": [
                    {
                        "file_name": p.file_name,
                        "page_number": p.page_number,
                        "volume": p.volume,
                        "text": p.text,
                        "confidence": p.confidence,
                        "success": p.success,
                        "error": p.error
                    }
                    for p in task.pages
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
                    "文件名", "卷号", "页码", "识别文字", "置信度", "状态", "错误信息"
                ])

                for p in task.pages:
                    writer.writerow([
                        p.file_name,
                        p.volume or "",
                        p.page_number or "",
                        p.text,
                        f"{p.confidence:.2%}",
                        "成功" if p.success else "失败",
                        p.error or ""
                    ])

            return str(export_file)

        # TODO: 添加 Excel 导出
        return None


# 全局批量扫描服务实例
batch_scan_service = BatchScanService()
