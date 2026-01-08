"""Genealogy Query API - For Spring Boot Integration"""
from fastapi import APIRouter, Depends, HTTPException, Query
from typing import List, Optional
from pydantic import BaseModel, Field

from app.database.session import get_db
from app.database.repositories import GenealogyRepository, BookRepository, OcrResultRepository

router = APIRouter(prefix="/api/genealogy", tags=["Genealogy"])


# Request/Response Models
class PersonSearchRequest(BaseModel):
    """Person search request"""
    surname: Optional[str] = None
    given_name: Optional[str] = None
    generation_number: Optional[int] = None
    village: Optional[str] = None
    min_confidence: Optional[float] = 0.5


class PersonResponse(BaseModel):
    """Person entry response"""
    entry_id: str
    surname: Optional[str]
    given_name: Optional[str]
    courtesy_name: Optional[str]
    art_name: Optional[str]
    generation_name: Optional[str]
    generation_number: Optional[int]
    birth_date: Optional[str]
    death_date: Optional[str]
    burial_location: Optional[str]
    rank_title: Optional[str]
    village: Optional[str]
    district: Optional[str]
    province: Optional[str]
    biography: Optional[str]
    notes: Optional[str]
    verification_status: str
    confidence: Optional[float]
    source_page_number: Optional[int]
    source_volume: Optional[str]


class FamilyTreeResponse(BaseModel):
    """Family tree response"""
    entry_id: str
    name: str
    generation_number: Optional[int]
    children: List["FamilyTreeResponse"] = []


# Update forward references
FamilyTreeResponse.model_rebuild()


# Endpoints

@router.get("/books", response_model=List[dict])
async def list_books(
    category: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db=Depends(get_db)
):
    """List all books"""
    repo = BookRepository(db)
    books = repo.list_books(category=category, limit=limit, offset=offset)
    return books


@router.get("/books/{book_id}", response_model=dict)
async def get_book(book_id: str, db=Depends(get_db)):
    """Get book details"""
    repo = BookRepository(db)
    book = repo.get_by_id(book_id)
    if not book:
        raise HTTPException(status_code=404, detail="Book not found")
    return {
        "book_id": book.book_id,
        "title": book.title,
        "author": book.author,
        "category": book.category,
        "description": book.description,
        "source_directory": book.source_directory,
        "total_pages": book.total_pages,
        "total_volumes": book.total_volumes,
        "created_at": book.created_at.isoformat() if book.created_at else None
    }


@router.get("/books/{book_id}/statistics")
async def get_book_statistics(book_id: str, db=Depends(get_db)):
    """Get book processing statistics"""
    repo = BookRepository(db)
    stats = repo.get_statistics(book_id)
    if not stats:
        raise HTTPException(status_code=404, detail="Book not found")
    return stats


@router.post("/persons/search", response_model=List[PersonResponse])
async def search_persons(
    request: PersonSearchRequest,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db=Depends(get_db)
):
    """Search persons by criteria"""
    repo = GenealogyRepository(db)

    filters = {}
    if request.surname:
        filters["surname"] = request.surname
    if request.given_name:
        filters["given_name"] = request.given_name
    if request.generation_number is not None:
        filters["generation_number"] = request.generation_number
    if request.village:
        filters["village"] = request.village
    if request.min_confidence:
        filters["min_confidence"] = request.min_confidence

    persons = repo.search_persons(filters, limit=limit, offset=offset)
    return [PersonResponse(**p) for p in persons]


@router.get("/books/{book_id}/persons", response_model=List[PersonResponse])
async def get_book_persons(
    book_id: str,
    generation: Optional[int] = None,
    surname: Optional[str] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db=Depends(get_db)
):
    """Get all persons in a book"""
    repo = GenealogyRepository(db)
    persons = repo.get_book_persons(
        book_id=book_id,
        generation=generation,
        surname=surname,
        limit=limit,
        offset=offset
    )
    return [PersonResponse(**p) for p in persons]


@router.get("/persons/{entry_id}", response_model=PersonResponse)
async def get_person(entry_id: str, db=Depends(get_db)):
    """Get person details"""
    repo = GenealogyRepository(db)
    person = repo.get_by_entry_id(entry_id)
    if not person:
        raise HTTPException(status_code=404, detail="Person not found")
    return PersonResponse(
        entry_id=person.entry_id,
        surname=person.surname,
        given_name=person.given_name,
        courtesy_name=person.courtesy_name,
        art_name=person.art_name,
        generation_name=person.generation_name,
        generation_number=person.generation_number,
        birth_date=person.birth_date,
        death_date=person.death_date,
        burial_location=person.burial_location,
        rank_title=person.rank_title,
        village=person.village,
        district=person.district,
        province=person.province,
        biography=person.biography,
        notes=person.notes,
        verification_status=person.verification_status or "pending",
        confidence=float(person.confidence) if person.confidence else None,
        source_page_number=person.source_page_number,
        source_volume=person.source_volume
    )


@router.get("/persons/{entry_id}/family")
async def get_person_family(entry_id: str, db=Depends(get_db)):
    """Get person's family relationships"""
    repo = GenealogyRepository(db)
    family = repo.get_person_family(entry_id)
    if not family:
        raise HTTPException(status_code=404, detail="Person not found")
    return family


@router.get("/books/{book_id}/family-tree/{entry_id}")
async def get_family_tree(
    book_id: str,
    entry_id: str,
    max_depth: int = Query(5, ge=1, le=10),
    db=Depends(get_db)
):
    """Get family tree for a person (descendants)"""
    repo = GenealogyRepository(db)
    tree = repo.build_family_tree(entry_id, max_depth=max_depth)
    if not tree:
        raise HTTPException(status_code=404, detail="Person not found")
    return tree


@router.get("/ocr/results")
async def search_ocr_results(
    book_id: str,
    query: str = Query(..., min_length=1),
    volume: Optional[str] = None,
    page_number: Optional[int] = None,
    limit: int = Query(50, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db=Depends(get_db)
):
    """Full-text search in OCR results"""
    repo = OcrResultRepository(db)

    results = repo.full_text_search(
        book_id=book_id,
        query=query,
        volume=volume,
        page_number=page_number,
        limit=limit,
        offset=offset
    )

    return {
        "total": len(results),
        "results": results
    }


@router.get("/ocr/books/{book_id}/pages")
async def get_book_pages(
    book_id: str,
    volume: Optional[str] = None,
    page_number: Optional[int] = None,
    min_confidence: Optional[float] = None,
    limit: int = Query(100, ge=1, le=1000),
    offset: int = Query(0, ge=0),
    db=Depends(get_db)
):
    """Get OCR pages for a book"""
    repo = OcrResultRepository(db)

    filters = {"book_id": book_id}
    if volume:
        filters["volume"] = volume
    if page_number is not None:
        filters["page_number"] = page_number
    if min_confidence:
        filters["min_confidence"] = min_confidence

    pages = repo.get_pages(filters, limit=limit, offset=offset)
    return {
        "total": len(pages),
        "pages": pages
    }


@router.get("/statistics/overview")
async def get_overview_statistics(db=Depends(get_db)):
    """Get system-wide statistics"""
    from sqlalchemy import func
    from app.database.models import Book, BatchTask, OcrResult, GenealogyData

    stats = {
        "total_books": db.query(func.count(Book.id)).scalar() or 0,
        "total_tasks": db.query(func.count(BatchTask.id)).scalar() or 0,
        "total_pages": db.query(func.count(OcrResult.id)).scalar() or 0,
        "total_persons": db.query(func.count(GenealogyData.id)).filter(
            GenealogyData.entry_type == 'person'
        ).scalar() or 0,
        "completed_tasks": db.query(func.count(BatchTask.id)).filter(
            BatchTask.status == 'completed'
        ).scalar() or 0,
        "processing_tasks": db.query(func.count(BatchTask.id)).filter(
            BatchTask.status.in_(['processing', 'queued'])
        ).scalar() or 0
    }
    return stats
