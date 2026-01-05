#!/bin/bash
cd /mnt/d/project/github/paddleocr-api
source venv/bin/activate
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
