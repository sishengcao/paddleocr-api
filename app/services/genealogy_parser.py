"""Genealogy Data Parser - Extract structured data from OCR text"""
import re
import uuid
import logging
from typing import List, Dict, Any, Optional
from datetime import datetime

from app.database.session import get_db
from app.database.models import OcrResult, GenealogyData
from app.database.repositories import GenealogyRepository

logger = logging.getLogger(__name__)


class GenealogyParser:
    """Parse OCR text into structured genealogy data"""

    # Chinese date patterns
    DATE_PATTERNS = [
        r'(\d{4})年([甲乙丙丁戊己庚辛壬癸])([子丑寅卯辰巳午未申酉戌亥])岁(.+)',
        r'(\d{4})年(.+)',
        r'生于(.{2,10})',
        r'卒于(.{2,10})',
        r'葬于(.{2,30})',
    ]

    # Generation patterns
    GENERATION_PATTERNS = [
        r'第(\d+)世',
        r'(\d+)代',
        r'珠岩(\d+)世',
    ]

    # Name patterns
    NAME_PATTERNS = [
        r'(.{1,2})名(.{1,3})',
        r'号(.{1,3})',
        r'字(.{1,3})',
        r'乳名(.{1,3})',
    ]

    # Relationship patterns
    RELATIONSHIP_PATTERNS = [
        r'长子(.{1,3})',
        r'次子(.{1,3})',
        r'三子(.{1,3})',
        r'四子(.{1,3})',
        r'五子(.{1,3})',
        r'配(.{1,3})(.{1,3})',
        r'配偶(.{1,3})(.{1,3})',
        r'妻(.{1,3})(.{1,3})',
    ]

    def __init__(self, db=None):
        self.db = db or next(get_db())
        self.genealogy_repo = GenealogyRepository(self.db)

    def parse_task_results(self, task_id: str, book_id: str) -> int:
        """
        Parse all OCR results for a task and create genealogy entries

        Args:
            task_id: Task ID
            book_id: Book ID

        Returns:
            Number of entries created
        """
        from app.database.repositories import OcrResultRepository
        ocr_repo = OcrResultRepository(self.db)

        ocr_results = ocr_repo.get_by_task(task_id)
        entries_created = 0

        for result in ocr_results:
            if result.success and result.raw_text:
                entries = self.parse_page(
                    page_id=result.page_id,
                    task_id=task_id,
                    book_id=book_id,
                    raw_text=result.raw_text,
                    source_page_number=result.page_number,
                    source_volume=result.volume,
                    confidence=float(result.confidence) if result.confidence else 0
                )
                entries_created += len(entries)

        logger.info(f"Created {entries_created} genealogy entries for task {task_id}")
        return entries_created

    def parse_page(
        self,
        page_id: str,
        task_id: str,
        book_id: str,
        raw_text: str,
        source_page_number: Optional[int] = None,
        source_volume: Optional[str] = None,
        confidence: float = 0.0
    ) -> List[GenealogyData]:
        """
        Parse a single page of OCR text

        Args:
            page_id: Page ID
            task_id: Task ID
            book_id: Book ID
            raw_text: Raw OCR text
            source_page_number: Source page number
            source_volume: Source volume
            confidence: OCR confidence

        Returns:
            List of GenealogyData entries
        """
        entries = []

        # Split by lines
        lines = raw_text.split('\n')

        # Group entries (separated by empty lines or generation markers)
        entry_groups = self._group_entries(lines)

        for group in entry_groups:
            entry = self._parse_entry(
                page_id=page_id,
                task_id=task_id,
                book_id=book_id,
                text_group=group,
                source_page_number=source_page_number,
                source_volume=source_volume,
                confidence=confidence
            )
            if entry:
                entries.append(entry)

        # Save to database
        for entry in entries:
            try:
                self.genealogy_repo.create(**entry)
            except Exception as e:
                logger.error(f"Failed to save genealogy entry: {e}")

        return entries

    def _group_entries(self, lines: List[str]) -> List[List[str]]:
        """Group lines into individual person entries"""
        groups = []
        current_group = []

        for line in lines:
            line = line.strip()
            if not line:
                if current_group:
                    groups.append(current_group)
                    current_group = []
            else:
                # Check if this line starts a new entry (contains generation info)
                if self._is_entry_start(line) and current_group:
                    groups.append(current_group)
                    current_group = []
                current_group.append(line)

        if current_group:
            groups.append(current_group)

        return groups

    def _is_entry_start(self, line: str) -> bool:
        """Check if line starts a new entry"""
        for pattern in self.GENERATION_PATTERNS:
            if re.search(pattern, line):
                return True
        return False

    def _parse_entry(
        self,
        page_id: str,
        task_id: str,
        book_id: str,
        text_group: List[str],
        source_page_number: Optional[int],
        source_volume: Optional[str],
        confidence: float
    ) -> Optional[Dict[str, Any]]:
        """Parse a single entry from text group"""

        full_text = '\n'.join(text_group)

        entry = {
            "entry_id": str(uuid.uuid4()),
            "page_id": page_id,
            "task_id": task_id,
            "book_id": book_id,
            "entry_type": "person",
            "source_text_snippet": full_text[:500],
            "source_page_number": source_page_number,
            "source_volume": source_volume,
            "confidence": confidence
        }

        # Extract generation number
        entry["generation_number"] = self._extract_generation(full_text)

        # Extract names
        names = self._extract_names(full_text)
        entry.update(names)

        # Extract dates
        dates = self._extract_dates(full_text)
        entry.update(dates)

        # Extract burial location
        entry["burial_location"] = self._extract_burial(full_text)

        # Extract biography
        entry["biography"] = full_text[:2000] if full_text else None

        # Extract relationships (simplified)
        relationships = self._extract_relationships(full_text)
        entry.update(relationships)

        # Extract location
        location = self._extract_location(full_text)
        entry.update(location)

        return entry if entry.get("surname") or entry.get("given_name") else None

    def _extract_generation(self, text: str) -> Optional[int]:
        """Extract generation number"""
        for pattern in self.GENERATION_PATTERNS:
            match = re.search(pattern, text)
            if match:
                try:
                    return int(match.group(1))
                except (ValueError, IndexError):
                    pass
        return None

    def _extract_names(self, text: str) -> Dict[str, Optional[str]]:
        """Extract names from text"""
        result = {
            "surname": None,
            "given_name": None,
            "courtesy_name": None,
            "art_name": None,
            "generation_name": None
        }

        # Try to extract surname + given name pattern
        for pattern in self.NAME_PATTERNS:
            match = re.search(pattern, text)
            if match:
                groups = match.groups()
                if len(groups) >= 2:
                    if "姓" in pattern or "名" in pattern:
                        result["surname"] = groups[0] if groups[0] else None
                        result["given_name"] = groups[1] if len(groups) > 1 else None
                    elif "号" in pattern:
                        result["art_name"] = groups[1] if len(groups) > 1 else groups[0]
                    elif "字" in pattern:
                        result["courtesy_name"] = groups[1] if len(groups) > 1 else groups[0]
                    elif "乳名" in pattern:
                        result["given_name"] = groups[1] if len(groups) > 1 else groups[0]

        # Try to find Chinese surname at beginning
        if not result["surname"]:
            # Common Chinese surnames
            surname_match = re.match(r'^([赵钱孙李周吴郑王冯陈褚卫蒋沈韩杨朱秦尤许何吕施张孔曹严华金魏陶姜戚谢邹喻柏水窦章云苏潘葛奚范彭郎鲁韦昌马苗凤花方俞任袁柳酆鲍史唐费廉岑薛雷贺倪汤滕殷罗毕郝邬安常乐于时傅皮卞齐康伍余元卜顾孟平黄和穆萧尹姚邵湛汪祁毛禹狄米贝明臧计伏成戴谈宋茅庞熊纪舒屈项祝董梁杜阮蓝闵席季麻强贾路娄危江童颜郭梅盛林刁钟徐邱骆高夏蔡田樊胡凌霍万柯卢莫房裘缪干解应宗丁宣邓郁单杭洪包诸左石崔吉钮龚])(.{1,3})(?:公|郎|君|)', text)
            if surname_match:
                result["surname"] = surname_match.group(1)
                result["given_name"] = surname_match.group(2)

        return result

    def _extract_dates(self, text: str) -> Dict[str, Optional[str]]:
        """Extract birth and death dates"""
        result = {"birth_date": None, "death_date": None}

        birth_match = re.search(r'生(?:于)?(.{5,20})(?:岁|时|日)', text)
        if birth_match:
            result["birth_date"] = birth_match.group(1).strip()

        death_match = re.search(r'卒(?:于)?(.{5,20})(?:岁|时|日)', text)
        if death_match:
            result["death_date"] = death_match.group(1).strip()

        return result

    def _extract_burial(self, text: str) -> Optional[str]:
        """Extract burial location"""
        match = re.search(r'葬(?:于)?(.{2,50})', text)
        if match:
            return match.group(1).strip()
        return None

    def _extract_relationships(self, text: str) -> Dict[str, Any]:
        """Extract relationships (simplified)"""
        return {
            "father_id": None,
            "mother_id": None,
            "spouse_ids": None,
            "children_ids": None
        }

    def _extract_location(self, text: str) -> Dict[str, Optional[str]]:
        """Extract location information"""
        result = {
            "village": None,
            "district": None,
            "province": None
        }

        # Try to extract village names (common patterns)
        village_match = re.search(r'([a-zA-Z\u4e00-\u9fff]{2,10})(?:村|镇|洞|山|岭)', text)
        if village_match:
            result["village"] = village_match.group(1)

        return result
