from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func

from app.reviews.models import Review, ReviewImage, ReviewResponse as ReviewResponseModel
from app.reviews.schemas import ReviewCreate, ReviewUpdate
from app.common.enums import ReviewTargetType
from app.common.exceptions import NotFound, BadRequest, Forbidden
from app.events.bus import event_bus
from app.events.types import ReviewCreatedEvent

class ReviewService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_review(self, reviewer_id: UUID, data: ReviewCreate) -> Review:
        existing = await self.db.execute(
            select(Review).where(
                Review.reviewer_id == reviewer_id,
                Review.target_type == data.target_type,
                Review.property_id == data.property_id,
            )
        )
        if existing.scalar_one_or_none():
            raise BadRequest("You have already reviewed this")

        review = Review(
            id=uuid4(), reviewer_id=reviewer_id,
            target_user_id=data.target_user_id,
            property_id=data.property_id,
            booking_id=data.booking_id,
            target_type=data.target_type,
            rating=data.rating, title=data.title,
            content=data.content, is_anonymous=data.is_anonymous,
            is_verified=data.booking_id is not None,
            helpful_count=0,
        )
        self.db.add(review)
        await self.db.flush()

        for url in data.image_urls:
            img = ReviewImage(id=uuid4(), review_id=review.id, url=url)
            self.db.add(img)

        await self.db.commit()
        await self.db.refresh(review)

        await event_bus.emit("review.created", ReviewCreatedEvent(
            review_id=review.id, reviewer_id=reviewer_id,
            target_type=data.target_type.value,
            target_id=data.target_user_id or data.property_id,
            rating=data.rating,
        ))
        return review

    async def get_reviews_for_property(self, property_id: UUID, page: int = 1, page_size: int = 20) -> dict:
        query = select(Review).where(Review.property_id == property_id, Review.is_flagged == False)
        count_result = await self.db.execute(select(func.count()).select_from(query.subquery()))
        total = count_result.scalar()

        avg_result = await self.db.execute(
            select(func.avg(Review.rating)).where(Review.property_id == property_id, Review.is_flagged == False)
        )
        average_rating = avg_result.scalar() or 0.0

        query = query.offset((page - 1) * page_size).limit(page_size).order_by(Review.created_at.desc())
        result = await self.db.execute(query)
        reviews = result.scalars().all()

        return {"total": total, "average_rating": round(float(average_rating), 1), "reviews": reviews}

    async def respond_to_review(self, review_id: UUID, responder_id: UUID, content: str) -> ReviewResponseModel:
        review_result = await self.db.execute(select(Review).where(Review.id == review_id))
        review = review_result.scalar_one_or_none()
        if not review:
            raise NotFound("Review not found")

        response = ReviewResponseModel(
            id=uuid4(), review_id=review_id,
            responder_id=responder_id, content=content,
        )
        self.db.add(response)
        await self.db.commit()
        await self.db.refresh(response)
        return response

    async def flag_review(self, review_id: UUID, reason: str) -> Review:
        result = await self.db.execute(select(Review).where(Review.id == review_id))
        review = result.scalar_one_or_none()
        if not review:
            raise NotFound("Review not found")
        review.is_flagged = True
        review.flag_reason = reason
        await self.db.commit()
        return review
