import subprocess, sys, time, httpx

proc = subprocess.Popen(
    [sys.executable, 'run_debug.py'],
    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
)
time.sleep(6)

PORT = 8055
ts = int(time.time())
EMAIL = "smoke_{}@apexhousing.com".format(ts)

print("=== Register ===")
try:
    r = httpx.post('http://127.0.0.1:{}/api/v1/auth/register'.format(PORT), json={
        'email': EMAIL, 'password': 'TestPass123!', 'role': 'TENANT', 'first_name': 'Smoke', 'last_name': 'Test'
    }, timeout=60)
    print("[{}] {}".format(r.status_code, r.text[:500]))
except Exception as e:
    print("TIMEOUT: {}".format(e))

print("\n=== Search Popular ===")
try:
    r2 = httpx.get('http://127.0.0.1:{}/api/v1/search/popular'.format(PORT), timeout=60)
    print("[{}] {}".format(r2.status_code, r2.text[:500]))
except Exception as e:
    print("TIMEOUT: {}".format(e))

print("\n=== Properties ===")
try:
    r3 = httpx.get('http://127.0.0.1:{}/api/v1/properties/'.format(PORT), timeout=60)
    print("[{}] {}".format(r3.status_code, r3.text[:300]))
except Exception as e:
    print("TIMEOUT: {}".format(e))

proc.terminate()
proc.wait()

try:
    with open('app_debug.log', 'r', encoding='utf-8', errors='replace') as f:
        log = f.read()
    print("\n=== SERVER LOG ===")
    for line in log.split("\n"):
        if "error" in line.lower() or "traceback" in line.lower() or "exception" in line.lower():
            print(line[:400])
    if not log.strip():
        print("(empty log)")
except Exception as e:
    print("Log read error:", e)
