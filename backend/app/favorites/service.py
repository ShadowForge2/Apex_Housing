from uuid import UUID, uuid4
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, delete
from sqlalchemy.exc import IntegrityError

from app.favorites.models import Favorite, PropertyWishList, WishListItem
from app.favorites.schemas import FavoriteCreate, WishListCreate, WishListItemCreate
from app.common.exceptions import NotFound, BadRequest, Forbidden
from app.events.bus import event_bus
from app.events.types import BaseEvent


class FavoriteService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def add_favorite(self, user_id: UUID, data: FavoriteCreate) -> Favorite:
        # Optimistic insert — unique constraint handles race condition
        fav = Favorite(
            id=uuid4(),
            user_id=user_id,
            property_id=data.property_id,
            note=data.note,
        )
        self.db.add(fav)
        try:
            await self.db.flush()
        except IntegrityError:
            await self.db.rollback()
            raise BadRequest("Property already in favorites")
        await self.db.commit()
        await self.db.refresh(fav)
        return fav

    async def remove_favorite(self, user_id: UUID, property_id: UUID) -> None:
        result = await self.db.execute(
            select(Favorite).where(
                Favorite.user_id == user_id,
                Favorite.property_id == property_id,
            )
        )
        fav = result.scalar_one_or_none()
        if not fav:
            raise NotFound("Favorite not found")
        await self.db.delete(fav)
        await self.db.commit()

    async def get_favorites(self, user_id: UUID, page: int = 1, page_size: int = 20) -> dict:
        base = select(Favorite).where(Favorite.user_id == user_id)
        count_result = await self.db.execute(select(func.count()).select_from(base.subquery()))
        total = count_result.scalar()

        query = (
            base
            .offset((page - 1) * page_size)
            .limit(page_size)
            .order_by(Favorite.created_at.desc())
        )
        result = await self.db.execute(query)
        favorites = result.scalars().all()
        return {"total": total, "favorites": favorites}

    async def is_favorited(self, user_id: UUID, property_id: UUID) -> bool:
        result = await self.db.execute(
            select(Favorite).where(
                Favorite.user_id == user_id,
                Favorite.property_id == property_id,
            )
        )
        return result.scalar_one_or_none() is not None


class WishListService:
    def __init__(self, db: AsyncSession):
        self.db = db

    async def create_wishlist(self, user_id: UUID, data: WishListCreate) -> PropertyWishList:
        wl = PropertyWishList(
            id=uuid4(),
            user_id=user_id,
            name=data.name,
            description=data.description,
        )
        self.db.add(wl)
        await self.db.commit()
        await self.db.refresh(wl)
        return wl

    async def get_wishlists(self, user_id: UUID) -> list:
        result = await self.db.execute(
            select(PropertyWishList)
            .where(PropertyWishList.user_id == user_id)
            .order_by(PropertyWishList.created_at.desc())
        )
        return result.scalars().all()

    async def get_wishlist(self, wishlist_id: UUID, user_id: UUID) -> PropertyWishList:
        result = await self.db.execute(
            select(PropertyWishList).where(
                PropertyWishList.id == wishlist_id,
                PropertyWishList.user_id == user_id,
            )
        )
        wl = result.scalar_one_or_none()
        if not wl:
            raise NotFound("Wishlist not found")
        return wl

    async def delete_wishlist(self, wishlist_id: UUID, user_id: UUID) -> None:
        wl = await self.get_wishlist(wishlist_id, user_id)
        await self.db.delete(wl)
        await self.db.commit()

    async def add_item(self, wishlist_id: UUID, user_id: UUID, data: WishListItemCreate) -> WishListItem:
        wl = await self.get_wishlist(wishlist_id, user_id)

        # Optimistic insert — unique constraint handles race condition
        item = WishListItem(
            id=uuid4(),
            wishlist_id=wishlist_id,
            property_id=data.property_id,
            note=data.note,
        )
        self.db.add(item)
        try:
            await self.db.flush()
        except IntegrityError:
            await self.db.rollback()
            raise BadRequest("Property already in this wishlist")
        await self.db.commit()
        await self.db.refresh(item)
        return item

    async def remove_item(self, wishlist_id: UUID, item_id: UUID, user_id: UUID) -> None:
        await self.get_wishlist(wishlist_id, user_id)
        result = await self.db.execute(
            select(WishListItem).where(
                WishListItem.id == item_id,
                WishListItem.wishlist_id == wishlist_id,
            )
        )
        item = result.scalar_one_or_none()
        if not item:
            raise NotFound("Wishlist item not found")
        await self.db.delete(item)
        await self.db.commit()
