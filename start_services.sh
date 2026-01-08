#!/bin/bash
# 启动所有服务脚本（使用远程 Redis）

cd /mnt/d/project/github/paddleocr-api

# 激活虚拟环境
source venv/bin/activate

echo "=== 检查远程 Redis ==="
redis-cli -h 172.27.243.32 -p 6379 -a "!qwert" ping || { echo "无法连接到远程 Redis"; exit 1; }
echo "远程 Redis 连接成功"

echo ""
echo "=== 启动 Celery Worker ==="
pkill -9 -f "celery.*worker" 2>/dev/null
sleep 1
nohup python3 -m celery -A app.workers.celery_worker worker --loglevel=info --concurrency=4 --pool=solo > /tmp/celery.log 2>&1 &
sleep 4
ps aux | grep "celery.*worker" | grep -v grep || { echo "Celery Worker 启动失败"; cat /tmp/celery.log; exit 1; }
echo "Celery Worker 运行中"

echo ""
echo "=== 启动 API 服务 ==="
pkill -9 -f "uvicorn app.main:app" 2>/dev/null
sleep 1
nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/api.log 2>&1 &
sleep 4
curl -s http://localhost:8000/api/ocr/health || { echo "API 启动失败"; cat /tmp/api.log; exit 1; }
echo "API 服务运行中"

echo ""
echo "=== 服务状态 ==="
echo "API: http://localhost:8000"
echo "批量识别页面: http://localhost:8000/batch"
echo ""
echo "=== 日志位置 ==="
echo "API: tail -f /tmp/api.log"
echo "Celery: tail -f /tmp/celery.log"
echo "应用: tail -f /mnt/d/project/github/paddleocr-api/logs/api.log"
