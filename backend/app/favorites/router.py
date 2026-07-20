from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession
from uuid import UUID

from app.database import get_db
from app.dependencies import get_current_user
from app.favorites.service import FavoriteService, WishListService
from app.favorites.schemas import (
    FavoriteCreate,
    WishListCreate,
    WishListItemCreate,
)
from app.users.models import User
from app.common.response import SuccessResponse

router = APIRouter(prefix="/favorites", tags=["Favorites"])


# --- Quick Favorites (toggle) ---

@router.post("/", response_model=SuccessResponse)
async def add_favorite(
    body: FavoriteCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = FavoriteService(db)
    fav = await service.add_favorite(user.id, body)
    return SuccessResponse(message="Added to favorites", data=fav)


@router.delete("/{property_id}", response_model=SuccessResponse)
async def remove_favorite(
    property_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = FavoriteService(db)
    await service.remove_favorite(user.id, property_id)
    return SuccessResponse(message="Removed from favorites")


@router.get("/", response_model=SuccessResponse)
async def get_favorites(
    page: int = 1,
    page_size: int = 20,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = FavoriteService(db)
    result = await service.get_favorites(user.id, page=page, page_size=page_size)
    return SuccessResponse(data=result)


@router.get("/check/{property_id}", response_model=SuccessResponse)
async def check_favorited(
    property_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = FavoriteService(db)
    is_fav = await service.is_favorited(user.id, property_id)
    return SuccessResponse(data={"is_favorited": is_fav})


# --- Wishlists ---

@router.post("/lists", response_model=SuccessResponse)
async def create_wishlist(
    body: WishListCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = WishListService(db)
    wl = await service.create_wishlist(user.id, body)
    return SuccessResponse(message="Wishlist created", data=wl)


@router.get("/lists", response_model=SuccessResponse)
async def get_wishlists(
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = WishListService(db)
    wishlists = await service.get_wishlists(user.id)
    return SuccessResponse(data=wishlists)


@router.get("/lists/{wishlist_id}", response_model=SuccessResponse)
async def get_wishlist(
    wishlist_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = WishListService(db)
    wl = await service.get_wishlist(wishlist_id, user.id)
    return SuccessResponse(data=wl)


@router.delete("/lists/{wishlist_id}", response_model=SuccessResponse)
async def delete_wishlist(
    wishlist_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = WishListService(db)
    await service.delete_wishlist(wishlist_id, user.id)
    return SuccessResponse(message="Wishlist deleted")


@router.post("/lists/{wishlist_id}/items", response_model=SuccessResponse)
async def add_wishlist_item(
    wishlist_id: UUID,
    body: WishListItemCreate,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = WishListService(db)
    item = await service.add_item(wishlist_id, user.id, body)
    return SuccessResponse(message="Added to wishlist", data=item)


@router.delete("/lists/{wishlist_id}/items/{item_id}", response_model=SuccessResponse)
async def remove_wishlist_item(
    wishlist_id: UUID,
    item_id: UUID,
    user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db),
):
    service = WishListService(db)
    await service.remove_item(wishlist_id, item_id, user.id)
    return SuccessResponse(message="Removed from wishlist")
