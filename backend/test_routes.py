import httpx, time

API = "http://127.0.0.1:8099/api/v1"
ts = int(time.time())
EMAIL = f"smoke_{ts}@apexhousing.com"

tests = [
    ("POST /auth/register", "POST", f"{API}/auth/register", {"email": EMAIL, "password": "TestPass123!", "role": "TENANT", "first_name": "Smoke", "last_name": "Test"}),
    ("GET /search/locations", "GET", f"{API}/search/locations", None),
    ("GET /search/popular", "GET", f"{API}/search/popular", None),
    ("GET /search/price-ranges", "GET", f"{API}/search/price-ranges", None),
]

for name, method, url, body in tests:
    print(f"Testing {name}...", flush=True)
    start = time.time()
    try:
        r = httpx.request(method, url, json=body, timeout=30)
        elapsed = time.time() - start
        print(f"  [{r.status_code}] {elapsed:.1f}s | {r.text[:200]}")
    except Exception as e:
        elapsed = time.time() - start
        print(f"  ERROR {elapsed:.1f}s | {type(e).__name__}: {e}")
