"""
APEX Housing — Async Smoke Test
Uses httpx.AsyncClient + ASGITransport so all tests share one event loop.
No TestClient, no subprocess, no event loop cascade.
"""
import os, sys, asyncio, time
os.environ.setdefault("RATE_LIMIT_ENABLED", "false")
os.environ.setdefault("OPENCODE_VENDOR", "pip")

if sys.platform == "win32":
    asyncio.set_event_loop_policy(asyncio.WindowsSelectorEventLoopPolicy())

import httpx
from app.main import app

API = "/api/v1"
passed = 0
failed = 0
errors = []
TOKEN = None
EMAIL = None
RESULTS = []


async def test(client, name, method, url, json=None, headers=None, expected_status=None):
    global passed, failed
    h = headers or {}
    try:
        r = await client.request(method, url, json=json, headers=h)
        ok = expected_status is None or r.status_code == expected_status
        body = r.text[:250].replace("\n", " ")
        if ok:
            passed += 1
            RESULTS.append(("PASS", name, r.status_code, body))
            print(f"  PASS  {name} [{r.status_code}] {body[:100]}")
        else:
            failed += 1
            msg = f"expected {expected_status}, got {r.status_code}"
            RESULTS.append(("FAIL", name, r.status_code, f"{msg} | {body}"))
            print(f"  FAIL  {name} -- {msg} | {body[:120]}")
        return r
    except Exception as e:
        failed += 1
        msg = f"{type(e).__name__}: {str(e)[:200]}"
        RESULTS.append(("FAIL", name, 0, msg))
        print(f"  FAIL  {name} -- {msg}")
        return None


async def main():
    global TOKEN, EMAIL

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:

        # ===== HEALTH =====
        print("=== HEALTH ===")
        await test(client, "GET /health", "GET", "/health", expected_status=200)

        # ===== AUTH =====
        print("\n=== AUTH ===")
        ts = int(time.time())
        EMAIL = f"smoke_{ts}@apexhousing.com"
        PASS = "TestPass123!"

        r = await test(client, "POST /auth/register", "POST", f"{API}/auth/register", json={
            "email": EMAIL, "password": PASS, "role": "TENANT", "first_name": "Smoke", "last_name": "Test"
        })
        if r and r.status_code in (200, 201):
            data = r.json()
            TOKEN = data.get("access_token") or (data.get("data", {}) or {}).get("access_token")
            if TOKEN:
                print(f"    Got register token: {TOKEN[:20]}...")

        r = await test(client, "POST /auth/login", "POST", f"{API}/auth/login", json={
            "email": EMAIL, "password": PASS
        })
        if r and r.status_code == 200:
            data = r.json()
            t2 = data.get("access_token") or (data.get("data", {}) or {}).get("access_token")
            if t2:
                TOKEN = t2
                print(f"    Got login token: {t2[:20]}...")

        auth_h = {"Authorization": f"Bearer {TOKEN}"} if TOKEN else {}

        # ===== USERS =====
        print("\n=== USERS ===")
        await test(client, "GET /users/me (no auth)", "GET", f"{API}/users/me", expected_status=401)
        if TOKEN:
            await test(client, "GET /users/me (auth)", "GET", f"{API}/users/me", headers=auth_h)

        # ===== PROPERTIES =====
        print("\n=== PROPERTIES ===")
        await test(client, "GET /properties/", "GET", f"{API}/properties/")
        await test(client, "GET /properties/?page=1&limit=5", "GET", f"{API}/properties/?page=1&limit=5")

        # ===== SEARCH =====
        print("\n=== SEARCH ===")
        await test(client, "GET /search/popular", "GET", f"{API}/search/popular")
        await test(client, "GET /search/price-ranges", "GET", f"{API}/search/price-ranges")
        await test(client, "GET /search/locations", "GET", f"{API}/search/locations")

        # ===== FAVORITES =====
        print("\n=== FAVORITES ===")
        if TOKEN:
            await test(client, "GET /favorites/", "GET", f"{API}/favorites/", headers=auth_h)
            await test(client, "GET /favorites/lists", "GET", f"{API}/favorites/lists", headers=auth_h)

        # ===== BOOKINGS =====
        print("\n=== BOOKINGS ===")
        if TOKEN:
            await test(client, "GET /bookings/", "GET", f"{API}/bookings/", headers=auth_h)

        # ===== NOTIFICATIONS =====
        print("\n=== NOTIFICATIONS ===")
        if TOKEN:
            await test(client, "GET /notifications/", "GET", f"{API}/notifications/", headers=auth_h)

        # ===== PAYMENTS =====
        print("\n=== PAYMENTS ===")
        if TOKEN:
            await test(client, "GET /payments/wallet", "GET", f"{API}/payments/wallet", headers=auth_h)
        await test(client, "GET /payments/business-days/check", "GET", f"{API}/payments/business-days/check")

        # ===== REVIEWS =====
        print("\n=== REVIEWS ===")
        await test(client, "GET /reviews/property/{id}", "GET",
                    f"{API}/reviews/property/00000000-0000-0000-0000-000000000000")

    # ===== RESULTS =====
    print(f"\n{'='*60}")
    print(f"RESULTS: {passed} passed, {failed} failed")
    if errors:
        print(f"\nFailed tests:")
        for e in errors:
            print(f"  {e}")
    print(f"{'='*60}")
    return passed, failed


if __name__ == "__main__":
    p, f = asyncio.run(main())
    sys.exit(0 if f == 0 else 1)
