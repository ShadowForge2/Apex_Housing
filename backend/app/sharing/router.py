from fastapi import APIRouter, Request
from fastapi.responses import HTMLResponse
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from fastapi import Depends

from app.database import get_db
from app.properties.models import Property

router = API(tags=["sharing"])

PLAY_STORE_URL = "https://play.google.com/store/apps/details?id=com.example.apex_housing"
APP_SCHEME = "apexhousing://property"
DOMAIN = "apex-housing.online"

LANDING_PAGE_HTML = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{title} - APEX Housing</title>

  <meta property="og:title" content="{title}">
  <meta property="og:description" content="{description}">
  <meta property="og:image" content="{image}">
  <meta property="og:url" content="{share_url}">
  <meta property="og:type" content="website">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{title}">
  <meta name="twitter:description" content="{description}">
  <meta name="twitter:image" content="{image}">

  <style>
    * {{ margin: 0; padding: 0; box-sizing: border-box; }}
    body {{
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #0a0a0a;
      color: #fff;
      min-height: 100vh;
      display: flex;
      align-items: center;
      justify-content: center;
    }}
    .card {{
      max-width: 420px;
      width: 90%;
      background: #1a1a1a;
      border-radius: 20px;
      overflow: hidden;
      box-shadow: 0 20px 60px rgba(0,0,0,0.5);
    }}
    .image {{
      width: 100%;
      height: 240px;
      object-fit: cover;
    }}
    .info {{
      padding: 24px;
    }}
    .title {{
      font-size: 20px;
      font-weight: 700;
      margin-bottom: 8px;
    }}
    .location {{
      color: #888;
      font-size: 14px;
      margin-bottom: 16px;
    }}
    .price {{
      font-size: 24px;
      font-weight: 700;
      color: #f59e0b;
      margin-bottom: 20px;
    }}
    .price span {{
      font-size: 14px;
      color: #888;
      font-weight: 400;
    }}
    .btn {{
      display: block;
      width: 100%;
      padding: 16px;
      border: none;
      border-radius: 12px;
      font-size: 16px;
      font-weight: 600;
      cursor: pointer;
      text-align: center;
      text-decoration: none;
      margin-bottom: 12px;
    }}
    .btn-primary {{
      background: #f59e0b;
      color: #000;
    }}
    .btn-secondary {{
      background: transparent;
      color: #fff;
      border: 1px solid #333;
    }}
    .brand {{
      text-align: center;
      padding: 16px;
      color: #555;
      font-size: 12px;
    }}
  </style>
</head>
<body>
  <div class="card">
    <img class="image" src="{image}" alt="{title}">
    <div class="info">
      <div class="title">{title}</div>
      <div class="location">{location}</div>
      <div class="price">{price} <span>/ month</span></div>
      <a class="btn btn-primary" href="{app_url}">Open in APEX Housing App</a>
      <a class="btn btn-secondary" href="{play_store_url}">Get it on Google Play</a>
    </div>
    <div class="brand">APEX Housing</div>
  </div>
</body>
</html>"""


@router.get("/p/{slug}", response_class=HTMLResponse)
async def property_share_page(slug: str, db: AsyncSession = Depends(get_db)):
    result = await db.execute(
        select(Property).where(Property.slug == slug)
    )
    prop = result.scalar_one_or_none()

    if not prop:
        return HTMLResponse(
            content="<html><body><h1>Property not found</h1></body></html>",
            status_code=404,
        )

    title = prop.title or "Property"
    description = (prop.description or "")[:200]
    image = ""
    if prop.images:
        primary = [i for i in prop.images if getattr(i, "is_primary", False)]
        image = primary[0].url if primary else prop.images[0].url

    location_parts = []
    if hasattr(prop, "location") and prop.location:
        if prop.location.address:
            location_parts.append(prop.location.address)
        if prop.location.city:
            location_parts.append(prop.location.city)
        if prop.location.state:
            location_parts.append(prop.location.state)
    location = ", ".join(location_parts) if location_parts else "Nigeria"

    price = "₦0"
    if hasattr(prop, "pricing") and prop.pricing and prop.pricing.rent_amount:
        amount = int(prop.pricing.rent_amount)
        price = f"₦{amount:,}"

    share_url = f"https://{DOMAIN}/p/{slug}"
    app_url = f"{APP_SCHEME}/{slug}"

    html = LANDING_PAGE_HTML.format(
        title=title,
        description=description,
        image=image or "https://via.placeholder.com/800x400?text=APEX+Housing",
        share_url=share_url,
        location=location,
        price=price,
        app_url=app_url,
        play_store_url=PLAY_STORE_URL,
    )

    return HTMLResponse(content=html)
