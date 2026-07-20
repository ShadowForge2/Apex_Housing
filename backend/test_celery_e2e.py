import subprocess, sys, time, os

backend = os.path.dirname(os.path.abspath(__file__))

# Start Celery worker in background
proc = subprocess.Popen(
    [sys.executable, '-m', 'celery', '-A', 'app.tasks.celery_app:celery_app', 'worker', '--loglevel=warning', '--pool=solo', '--concurrency=1'],
    cwd=backend,
    stdout=subprocess.PIPE,
    stderr=subprocess.PIPE,
    creationflags=subprocess.CREATE_NO_WINDOW,
)
print(f'Worker PID: {proc.pid}', flush=True)
time.sleep(3)

from app.tasks.otp_tasks import cleanup_expired_otps
result = cleanup_expired_otps.delay()
print(f'Task sent: {result.id}', flush=True)
time.sleep(5)

print(f'Task state: {result.state}', flush=True)
try:
    val = result.get(timeout=10)
    print(f'Task result: {val}', flush=True)
except Exception as e:
    print(f'Get result: {e}', flush=True)
    print(f'Task state after: {result.state}', flush=True)

proc.terminate()
proc.wait()
print('Worker stopped. Test complete!', flush=True)
