from fastapi import APIRouter, Depends, UploadFile, File
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user
from app.reviews.service import ReviewService
from app.reviews.schemas import ReviewCreate, ReviewUpdate
from app.reviews.models import Review, ReviewImage, ReviewVote
from app.users.models import User
from app.common.response import SuccessResponse
from app.common.exceptions import NotFound, BadRequest
from app.services.storage import supabase_storage

router = APIRouter(prefix="/reviews", tags=["Reviews"])

@router.post("/", response_model=SuccessResponse)
async def create_review(body: ReviewCreate, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = ReviewService(db)
    review = await service.create_review(user.id, body)
    return SuccessResponse(message="Review created", data=review)

@router.get("/property/{property_id}", response_model=SuccessResponse)
async def get_property_reviews(property_id: UUID, page: int = 1, page_size: int = 20, db: AsyncSession = Depends(get_db)):
    service = ReviewService(db)
    reviews = await service.get_reviews_for_property(property_id, page=page, page_size=page_size)
    return SuccessResponse(data=reviews)

@router.post("/{review_id}/respond", response_model=SuccessResponse)
async def respond_to_review(review_id: UUID, content: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = ReviewService(db)
    response = await service.respond_to_review(review_id, user.id, content)
    return SuccessResponse(message="Response added", data=response)

@router.post("/{review_id}/flag")
async def flag_review(review_id: UUID, reason: str, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    service = ReviewService(db)
    await service.flag_review(review_id, reason)
    return SuccessResponse(message="Review flagged for moderation")

@router.post("/{review_id}/vote", response_model=SuccessResponse)
async def vote_review(review_id: UUID, is_helpful: bool, user: User = Depends(get_current_user), db: AsyncSession = Depends(get_db)):
    review_result = await db.execute(select(Review).where(Review.id == review_id))
    review = review_result.scalar_one_or_none()
    if not review:
        raise NotFound("Review not found")
    if review.reviewer_id == user.id:
        raise BadRequest("Cannot vote on your own review")

    existing = await db.execute(
        select(ReviewVote).where(ReviewVote.review_id == review_id, ReviewVote.user_id == user.id)
    )
    vote = existing.scalar_one_or_none()

    if vote:
        if vote.is_helpful == is_helpful:
            db.delete(vote)
            review.helpful_count = max(0, review.helpful_count + (-1 if is_helpful else 1))
            await db.commit()
            return SuccessResponse(message="Vote removed")
        old_helpful = vote.is_helpful
        vote.is_helpful = is_helpful
        if old_helpful and not is_helpful:
            review.helpful_count = max(0, review.helpful_count - 1)
        elif not old_helpful and is_helpful:
            review.helpful_count += 1
    else:
        vote = ReviewVote(id=UUID.__new__(UUID), review_id=review_id, user_id=user.id, is_helpful=is_helpful)
        db.add(vote)
        if is_helpful:
            review.helpful_count += 1

    await db.commit()
    return SuccessResponse(message="Vote recorded", data={"helpful_count": review.helpful_count})

@router.get("/{review_id}/votes", response_model=SuccessResponse)
async def get_review_votes(review_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(ReviewVote).where(ReviewVote.review_id == review_id)
    )
    votes = result.scalars().all()
    helpful = sum(1 for v in votes if v.is_helpful)
    not_helpful = len(votes) - helpful
    return SuccessResponse(data={"total": len(votes), "helpful": helpful, "not_helpful": not_helpful})

@router.post("/{review_id}/images", response_model=SuccessResponse)
async def upload_review_image(
    review_id: UUID,
    file: UploadFile = File(...),
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    review_result = await db.execute(select(Review).where(Review.id == review_id))
    review = review_result.scalar_one_or_none()
    if not review:
        raise NotFound("Review not found")
    if review.reviewer_id != user.id:
        raise BadRequest("Only the review author can add images")

    content = await file.read()
    if len(content) > 10 * 1024 * 1024:
        raise BadRequest("Image too large. Max 10MB.")
    if not file.content_type or not file.content_type.startswith("image/"):
        raise BadRequest("File must be an image")

    try:
        result = await supabase_storage.upload_file(
            file_bytes=content,
            file_name=file.filename or "review_image",
            content_type=file.content_type,
            folder=f"reviews/{review_id}/images",
        )
    except Exception as e:
        raise BadRequest(f"Upload failed: {str(e)}")

    image = ReviewImage(
        id=UUID.__new__(UUID), review_id=review_id,
        url=result["url"],
        alt_text=file.filename,
    )
    db.add(image)
    await db.commit()

    return SuccessResponse(message="Image uploaded", data={
        "id": str(image.id),
        "url": result["url"],
    })

@router.get("/{review_id}/images", response_model=SuccessResponse)
async def get_review_images(review_id: UUID, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(ReviewImage).where(ReviewImage.review_id == review_id)
    )
    images = result.scalars().all()
    return SuccessResponse(data={"total": len(images), "images": images})
