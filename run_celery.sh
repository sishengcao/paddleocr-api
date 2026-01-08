#!/bin/bash
cd /mnt/d/project/github/paddleocr-api
source venv/bin/activate
python -m celery -A app.workers.celery_worker worker --loglevel=info --concurrency=4 --pool=solo
