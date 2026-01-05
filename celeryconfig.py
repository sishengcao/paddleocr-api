"""Celery Configuration"""
from app.config import settings

# Broker settings
broker_url = settings.CELERY_BROKER_URL
result_backend = settings.CELERY_RESULT_BACKEND

# Task settings
task_serializer = settings.CELERY_TASK_SERIALIZER
result_serializer = settings.CELERY_RESULT_SERIALIZER
accept_content = settings.CELERY_ACCEPT_CONTENT
timezone = settings.CELERY_TIMEZONE
enable_utc = settings.CELERY_ENABLE_UTC

# Task tracking
task_track_started = settings.CELERY_TASK_TRACK_STARTED
task_time_limit = settings.CELERY_TASK_TIME_LIMIT
task_soft_time_limit = settings.CELERY_TASK_SOFT_TIME_LIMIT

# Worker settings
worker_prefetch_multiplier = settings.CELERY_WORKER_PREFETCH_MULTIPLIER
worker_max_tasks_per_child = settings.CELERY_WORKER_MAX_TASKS_PER_CHILD

# Task result settings
result_expires = 3600  # 1 hour
result_extended = True

# Task routing
task_routes = {
    "app.process_batch_scan": {"queue": "ocr_tasks"},
    "app.cleanup_expired_exports": {"queue": "maintenance"},
}

# Beat schedule (scheduled tasks)
beat_schedule = {
    "cleanup-exports-every-hour": {
        "task": "app.cleanup_expired_exports",
        "schedule": 3600,  # Every hour
    },
}
