"""
APEX Housing — Full API Smoke Test v3
"""
import sys
import time
import subprocess
import httpx

BASE = "http://127.0.0.1:8099"
API = f"{BASE}/api/v1"

passed = 0
failed = 0
errors = []


def test(name, method, url, json=None, headers=None, expected_status=None, auth=False, token=None, timeout=15):
    global passed, failed
    h = headers or {}
    if auth and token:
        h["Authorization"] = f"Bearer {token}"
    try:
        r = httpx.request(method, url, json=json, headers=h, timeout=timeout)
        ok = True
        if expected_status and r.status_code != expected_status:
            ok = False
        if ok:
            passed += 1
            body = r.text[:120].replace('\n', ' ')
            print(f"  PASS  {name} [{r.status_code}] {body}")
        else:
            failed += 1
            body = r.text[:200].replace('\n', ' ')
            msg = f"  FAIL  {name} -- expected {expected_status}, got {r.status_code} | {body}"
            print(msg)
            errors.append(msg)
        return r
    except Exception as e:
        failed += 1
        msg = f"  FAIL  {name} -- {type(e).__name__}: {e}"
        print(msg)
        errors.append(msg)
        return None


# --- Start app ---
print("Starting FastAPI app...", flush=True)
proc = subprocess.Popen(
    [sys.executable, "run_app.py"],
    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
)
time.sleep(6)

try:
    r = httpx.get(f"{BASE}/health", timeout=5)
    print(f"App is up! Health: {r.status_code}\n", flush=True)
except Exception as e:
    print(f"App failed to start: {e}")
    stderr = proc.stderr.read().decode()[-2000:]
    print(f"Stderr:\n{stderr}")
    proc.terminate()
    proc.wait()
    sys.exit(1)

# ========== ROUTES ==========
print("=== ROUTE LISTING ===", flush=True)
r = httpx.get(f"{API}/openapi.json", timeout=10)
if r.status_code == 200:
    spec = r.json()
    paths = sorted(spec.get("paths", {}).keys())
    print(f"Total routes: {len(paths)}")
else:
    print(f"  OpenAPI: {r.status_code}")

# ========== HEALTH ==========
print("\n=== HEALTH ===", flush=True)
test("GET /health", "GET", f"{BASE}/health", expected_status=200)

# ========== AUTH ==========
print("\n=== AUTH ===", flush=True)
ts = int(time.time())
EMAIL = f"smoke_{ts}@apexhousing.com"
PASS = "TestPass123!"

r = test("POST /auth/register", "POST", f"{API}/auth/register", json={
    "email": EMAIL, "password": PASS, "role": "TENANT", "full_name": "Smoke Test"
})

TOKEN = None
if r and r.status_code in (200, 201):
    data = r.json()
    TOKEN = data.get("access_token") or (data.get("data", {}) or {}).get("access_token")
    if TOKEN:
        print(f"    Got token: {TOKEN[:20]}...")

r = test("POST /auth/login", "POST", f"{API}/auth/login", json={
    "email": EMAIL, "password": PASS
})
if r and r.status_code == 200:
    data = r.json()
    t2 = data.get("access_token") or (data.get("data", {}) or {}).get("access_token")
    if t2:
        TOKEN = t2
        print(f"    Got login token: {t2[:20]}...")

# ========== USERS ==========
print("\n=== USERS ===", flush=True)
test("GET /users/me (no auth)", "GET", f"{API}/users/me", expected_status=401)
test("GET /users/me (auth)", "GET", f"{API}/users/me", auth=True, token=TOKEN)

# ========== PROPERTIES ==========
print("\n=== PROPERTIES ===", flush=True)
test("GET /properties/", "GET", f"{API}/properties/")
test("GET /properties/?page=1&limit=5", "GET", f"{API}/properties/?page=1&limit=5")

# ========== SEARCH ==========
print("\n=== SEARCH ===", flush=True)
test("GET /search/locations", "GET", f"{API}/search/locations")
test("GET /search/popular", "GET", f"{API}/search/popular")
test("GET /search/price-ranges", "GET", f"{API}/search/price-ranges")

# ========== FAVORITES ==========
print("\n=== FAVORITES ===", flush=True)
test("GET /favorites/", "GET", f"{API}/favorites/", auth=True, token=TOKEN)
test("GET /favorites/wishlists", "GET", f"{API}/favorites/lists", auth=True, token=TOKEN)

# ========== NOTIFICATIONS ==========
print("\n=== NOTIFICATIONS ===", flush=True)
test("GET /notifications/", "GET", f"{API}/notifications/", auth=True, token=TOKEN)

# ========== BOOKINGS ==========
print("\n=== BOOKINGS ===", flush=True)
test("GET /bookings/", "GET", f"{API}/bookings/", auth=True, token=TOKEN)

# ========== PAYMENTS ==========
print("\n=== PAYMENTS ===", flush=True)
test("GET /payments/wallet", "GET", f"{API}/payments/wallet", auth=True, token=TOKEN)
test("GET /payments/business-days/check", "GET", f"{API}/payments/business-days/check")

# ========== REVIEWS ==========
print("\n=== REVIEWS ===", flush=True)
test("GET /reviews/property/fake-id", "GET", f"{API}/reviews/property/00000000-0000-0000-0000-000000000000")

# ========== RESULTS ==========
print(f"\n{'='*50}")
print(f"RESULTS: {passed} passed, {failed} failed")
if errors:
    print(f"\nFailed tests:")
    for e in errors:
        print(f"  {e}")
print(f"{'='*50}")

proc.terminate()
proc.wait()
