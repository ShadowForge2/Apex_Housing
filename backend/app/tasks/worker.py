# Celery worker entry point
# Used by docker-compose: celery -A app.tasks.worker worker
from app.tasks.celery_app import celery_app as app

__all__ = ["app"]
