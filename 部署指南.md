# PaddleOCR API 项目启动指南

## 环境要求

### 远程服务
- **MySQL**: 172.27.243.32:3306
- **Redis**: 172.27.243.32:6379

### 本地/WSL 环境
- Python 3.8+
- 虚拟环境 (venv)

---

## 快速启动 (WSL)

### 1. 激活虚拟环境并安装依赖

```bash
cd /mnt/d/project/github/paddleocr-api
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt

# 如果缺少特定包，手动安装：
pip install celery[redis] redis sqlalchemy pymysql cryptography pydantic-settings
```

### 2. 启动 API 服务

```bash
cd /mnt/d/project/github/paddleocr-api
source venv/bin/activate

# 后台启动
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/api.log 2>&1 &

# 查看日志
tail -f /tmp/api.log
```

### 3. 启动 Celery Worker

```bash
cd /mnt/d/project/github/paddleocr-api
source venv/bin/activate

# 后台启动
nohup python -m celery -A app.workers.celery_worker worker --loglevel=info --concurrency=4 --pool=solo > /tmp/celery.log 2>&1 &

# 查看日志
tail -f /tmp/celery.log
```

---

## 验证服务状态

### 检查进程

```bash
ps aux | grep -E '(uvicorn|celery)' | grep -v grep
```

正常输出示例：
```
root  2308  python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
root  2866  python -m celery -A app.workers.celery_worker worker
```

### 检查 API 健康状态

```bash
curl http://localhost:8000/api/ocr/health
```

正常响应：
```json
{"status":"healthy","version":"1.0.0"}
```

### 访问 API 文档

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/redoc

---

## 停止服务

### 查找进程 ID
```bash
ps aux | grep -E '(uvicorn|celery)' | grep -v grep
```

### 停止服务
```bash
# 停止 API
pkill -f "uvicorn app.main:app"

# 停止 Celery Worker
pkill -f "celery.*worker"
```

---

## 配置说明

### 环境变量配置 (.env)

```ini
# 数据库配置
DB_HOST=172.27.243.32
DB_PORT=3306
DB_USER=root
DB_PASSWORD=!qwert
DB_NAME=paddleocr_api

# Redis 配置
REDIS_HOST=172.27.243.32
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=

# API 配置
HOST=0.0.0.0
PORT=8000
LOG_LEVEL=INFO
```

---

## 常见问题

### 1. ModuleNotFoundError: No module named 'xxx'

```bash
source venv/bin/activate
pip install xxx
```

### 2. 数据库连接失败

- 确认 MySQL 服务在 172.27.243.32:3306 运行
- 确认数据库 paddleocr_api 已创建
- 确认 .env 中的数据库配置正确

### 3. Celery Worker 无法连接 Redis

- 确认 Redis 服务在 172.27.243.32:6379 运行
- 测试连接: `redis-cli -h 172.27.243.32 ping`

### 4. 端口被占用

```bash
# 查看占用端口的进程
netstat -tulpn | grep 8000

# 杀死占用进程
kill -9 <PID>
```

---

## 日志位置

| 服务 | 日志文件 |
|------|---------|
| API 服务 | `/tmp/api.log` |
| Celery Worker | `/tmp/celery.log` |

---

## 数据库初始化

如需重新创建数据库：

```bash
mysql -h 172.27.243.32 -u root -p < migrations/001_initial_schema.sql
```
