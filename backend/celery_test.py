"""Minimal Celery E2E test. Run from backend directory."""
import sys, time

from app.tasks.celery_app import celery_app
from app.tasks.otp_tasks import cleanup_expired_otps

print("1. Sending task...", flush=True)
result = cleanup_expired_otps.delay()
print(f"2. Task ID: {result.id}", flush=True)

print("3. Waiting for result (30s max)...", flush=True)
try:
    val = result.get(timeout=30)
    print(f"4. SUCCESS! Task returned: {val}", flush=True)
except Exception as e:
    print(f"4. Result: {e}", flush=True)
    print(f"   State: {result.state}", flush=True)

print("Done!", flush=True)
