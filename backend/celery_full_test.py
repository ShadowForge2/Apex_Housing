"""Combined worker + test. Starts worker, sends task, checks result."""
import subprocess, sys, time, os, redis

backend = os.path.dirname(os.path.abspath(__file__))
celery_url = "redis://localhost:6380/0"

# Flush the celery queue first
r = redis.Redis(port=6380)
r.flushdb()
print("Flushed Redis DB", flush=True)

# Start worker
proc = subprocess.Popen(
    [sys.executable, '-m', 'celery', '-A', 'app.tasks.celery_app:celery_app', 'worker',
     '--loglevel=info', '--pool=solo', '--concurrency=1',
     '--without-heartbeat', '--without-mingle', '--without-gossip'],
    cwd=backend,
    stdout=subprocess.PIPE,
    stderr=subprocess.STDOUT,
)

print(f"Worker started (PID {proc.pid})", flush=True)
# Wait for worker to fully start
time.sleep(10)

# Send task
from app.tasks.otp_tasks import cleanup_expired_otps
print("Sending task...", flush=True)
result = cleanup_expired_otps.delay()
print(f"Task ID: {result.id}", flush=True)

# Wait for result
print("Waiting for result...", flush=True)
try:
    val = result.get(timeout=30)
    print(f"SUCCESS! Task completed. Result: {val}", flush=True)
except Exception as e:
    print(f"Task state: {result.state}", flush=True)
    print(f"Result: {e}", flush=True)

# Read worker output
proc.terminate()
try:
    proc.wait(timeout=5)
except subprocess.TimeoutExpired:
    proc.kill()
    proc.wait()

remaining = proc.stdout.read().decode()
if remaining.strip():
    print(f"\nWorker output (last 1000 chars):\n{remaining[-1000:]}", flush=True)

print("\nDone!", flush=True)
