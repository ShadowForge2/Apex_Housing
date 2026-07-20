import httpx, time

API = "http://127.0.0.1:8099/api/v1"
ts = int(time.time())
EMAIL = f"smoke_{ts}@apexhousing.com"

# Test register
print("=== Register ===")
r = httpx.post(f"{API}/auth/register", json={
    "email": EMAIL, "password": "TestPass123!", "role": "TENANT", "first_name": "Smoke", "last_name": "Test"
}, timeout=30)
print(f"Status: {r.status_code}")
print(f"Body: {r.text[:500]}")

if r.status_code == 200:
    data = r.json()
    token = data.get("access_token") or (data.get("data", {}) or {}).get("access_token")
    if token:
        print(f"\nToken: {token[:30]}...")
        
        # Test authenticated routes
        h = {"Authorization": f"Bearer {token}"}
        
        print("\n=== /users/me ===")
        r2 = httpx.get(f"{API}/users/me", headers=h, timeout=15)
        print(f"Status: {r2.status_code}")
        print(f"Body: {r2.text[:300]}")
        
        print("\n=== /properties/ ===")
        r3 = httpx.get(f"{API}/properties/", timeout=15)
        print(f"Status: {r3.status_code}")
        print(f"Body: {r3.text[:300]}")

# Test search/popular error
print("\n=== /search/popular ===")
r4 = httpx.get(f"{API}/search/popular", timeout=15)
print(f"Status: {r4.status_code}")
print(f"Body: {r4.text[:500]}")
