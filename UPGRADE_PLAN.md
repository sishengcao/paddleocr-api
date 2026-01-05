# PaddleOCR API 系统升级方案

## 需求概述

1. **高并发支持** - 承载大量并发 OCR 请求
2. **任务队列管理** - 批量扫描任务队列化，检测重复任务
3. **MySQL 数据存储** - 存储原始数据、结构化数据、解析后数据
4. **族谱项目 API** - 提供查询接口供 Java Spring Boot 调用

---

## 技术选型

| 组件 | 选择 | 理由 |
|------|------|------|
| 数据库 | **MySQL 8.0** | 成熟稳定，事务支持好，适合关系型数据 |
| 队列系统 | **Redis + Celery** | 成熟的分布式任务队列，支持重试、优先级 |
| API 格式 | **JSON REST API** | 标准格式，与 Spring Boot 集成简单 |

---

## 数据库设计

### 核心表结构

```sql
-- 1. books - 书籍元数据表
-- 2. batch_tasks - 批量扫描任务表
-- 3. ocr_results - OCR 识别结果表（原始数据）
-- 4. genealogy_data - 结构化族谱数据表
-- 5. exports - 导出记录表
-- 6. task_locks - 任务锁表（防重复）
-- 7. processing_logs - 处理日志表
```

### 关键表字段

**batch_tasks (任务表)**
- `task_id`, `book_id`, `source_directory`
- `status`: pending/queued/processing/completed/failed/cancelled
- `task_hash`: 用于重复检测
- `celery_task_id`: Celery 任务追踪
- 统计字段: `total_files`, `processed_files`, `success_files`, `failed_files`, `progress`

**ocr_results (原始数据表)**
- `page_id`, `task_id`, `book_id`
- `file_path`, `file_name`, `page_number`, `volume`
- `raw_text`: 识别的原始文字
- `confidence`: 置信度
- `text_boxes`: 详细坐标信息（JSON）
- `success`, `processing_time`

**genealogy_data (结构化数据表)**
- `entry_id`, `page_id`, `task_id`, `book_id`
- `entry_type`: person/family/location/event/note
- 姓名: `surname`, `given_name`, `courtesy_name`, `art_name`
- 关系: `father_id`, `mother_id`, `spouse_ids`, `children_ids`
- 生卒: `birth_date`, `death_date`, `burial_location`
- 地点: `village`, `district`, `province`
- 其他: `biography`, `generation_number`, `verification_status`

---

## 新文件结构

```
paddleocr-api/
├── app/
│   ├── config.py                    # 配置管理（NEW）
│   ├── database/
│   │   ├── models.py                # SQLAlchemy ORM 模型（NEW）
│   │   ├── session.py               # 数据库会话（NEW）
│   │   └── repositories.py          # 数据访问层（NEW）
│   ├── api/
│   │   ├── genealogy.py             # 族谱查询 API（NEW）
│   │   ├── ocr.py                   # OCR 接口（重构）
│   │   └── batch.py                 # 批量扫描接口（重构）
│   ├── services/
│   │   ├── task_service.py          # 任务队列服务（NEW）
│   │   ├── genealogy_parser.py      # 族谱数据解析器（NEW）
│   │   └── duplicate_detector.py    # 重复检测服务（NEW）
│   └── workers/
│       └── celery_worker.py         # Celery 工作任务（NEW）
├── migrations/
│   └── 001_initial_schema.sql       # 数据库初始化脚本（NEW）
├── celeryconfig.py                  # Celery 配置（NEW）
├── docker-compose.yml               # 更新：添加 MySQL、Redis、Celery
└── requirements.txt                 # 更新依赖
```

---

## 重复检测机制

### 工作流程

```
1. 用户提交批量扫描请求
   ↓
2. DuplicateDetector 生成 task_hash
   - 基于目录路径 + OCR 配置生成 SHA256
   ↓
3. 检查数据库是否存在相同 hash 的活跃任务
   - 存在 → 返回 "任务已在执行中，任务ID: xxx"
   - 不存在 → 创建新任务
   ↓
4. 创建 task_lock 锁记录，防止并发创建重复任务
   ↓
5. 任务提交到 Celery 队列，状态设为 "queued"
```

### API 响应示例

**重复任务检测响应：**
```json
{
  "success": false,
  "error": "DUPLICATE_TASK",
  "message": "相同目录的扫描任务已在执行中",
  "existing_task": {
    "task_id": "xxx",
    "status": "processing",
    "progress": 45.5
  }
}
```

---

## 族谱查询 API（供 Spring Boot 调用）

### 核心接口

| 接口 | 方法 | 说明 |
|------|------|------|
| `/api/genealogy/books` | GET | 获取所有书籍列表 |
| `/api/genealogy/books/{book_id}` | GET | 获取书籍详情 |
| `/api/genealogy/books/{book_id}/statistics` | GET | 获取书籍统计 |
| `/api/genealogy/persons/search` | POST | 按条件搜索人物 |
| `/api/genealogy/books/{book_id}/persons` | GET | 获取书籍中所有人物 |
| `/api/genealogy/persons/{entry_id}` | GET | 获取人物详情 |
| `/api/genealogy/persons/{entry_id}/family` | GET | 获取人物关系 |
| `/api/genealogy/books/{book_id}/family-tree/{entry_id}` | GET | 获取家族树 |
| `/api/genealogy/ocr/results` | GET | 全文搜索 OCR 结果 |
| `/api/genealogy/ocr/books/{book_id}/pages` | GET | 获取书籍 OCR 页面 |

### 搜索人物示例

```bash
POST /api/genealogy/persons/search
{
  "surname": "李",
  "generation_number": 20,
  "village": "珠岩"
}
```

响应：
```json
[
  {
    "entry_id": "uuid",
    "surname": "李",
    "given_name": "功勋",
    "courtesy_name": "作兴",
    "generation_number": 21,
    "birth_date": "1920年庚申岁十月十七日",
    "death_date": "1996年丙子岁四月初九日",
    "burial_location": "上洞",
    "village": "珠岩",
    "biography": "号国华，乳名作兴...",
    "confidence": 0.97
  }
]
```

---

## 配置管理

### 数据库配置（.env）

```env
# 数据库连接
DB_HOST=172.27.243.32
DB_PORT=3306
DB_USER=root
DB_PASSWORD=!qwert
DB_NAME=paddleocr_api

# 连接池配置
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=40
DB_POOL_TIMEOUT=30
DB_POOL_RECYCLE=3600
```

### Redis + Celery 配置

```env
# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=

# Celery
CELERY_BROKER_URL=redis://localhost:6379/0
CELERY_RESULT_BACKEND=redis://localhost:6379/1
CELERY_WORKER_CONCURRENCY=4
```

---

## 高并发配置

### Uvicorn 多 Worker

```bash
# 启动命令
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

### Docker Compose 部署

```yaml
services:
  api:
    deploy:
      replicas: 2  # 2 个 API 实例
      resources:
        limits:
          cpus: '4'
          memory: 4G

  celery-worker:
    deploy:
      replicas: 2  # 2 个 Worker 实例
```

---

## 依赖更新

### requirements.txt 新增

```txt
# 数据库
sqlalchemy>=2.0.0
pymysql>=1.1.0
alembic>=1.12.0

# 任务队列
celery[redis]>=5.3.0
redis>=5.0.0

# 配置管理
pydantic-settings>=2.0.0

# 导出格式
openpyxl>=3.1.0
pandas>=2.1.0
```

---

## 实施步骤

### 阶段 1：基础设施（1周）
1. 创建数据库表结构
2. 实现配置管理 (config.py)
3. 创建数据库模型和会话管理
4. 设置 Redis 和 Celery
5. 更新 Docker 配置

### 阶段 2：核心服务（1周）
1. 实现重复检测服务
2. 创建 Celery 工作任务
3. 重构 batch_scan_service 使用队列
4. 实现数据库 repositories

### 阶段 3：族谱功能（1周）
1. 创建族谱数据解析器
2. 实现族谱 REST API
3. 添加全文搜索
4. 创建导出服务

### 阶段 4：测试优化（1周）
1. 编写测试用例
2. 性能优化
3. 文档完善

---

## 关键文件清单

需要修改/创建的文件：

| 文件 | 操作 | 说明 |
|------|------|------|
| `app/config.py` | 新建 | 统一配置管理 |
| `app/database/models.py` | 新建 | SQLAlchemy ORM 模型 |
| `app/database/session.py` | 新建 | 数据库会话管理 |
| `app/database/repositories.py` | 新建 | 数据访问层 |
| `app/api/genealogy.py` | 新建 | 族谱查询 API |
| `app/services/duplicate_detector.py` | 新建 | 重复检测服务 |
| `app/workers/celery_worker.py` | 新建 | Celery 工作任务 |
| `app/main.py` | 修改 | 集成新服务、路由 |
| `app/batch_scan_service.py` | 修改 | 改用队列 |
| `app/schemas.py` | 修改 | 扩展模型 |
| `requirements.txt` | 修改 | 添加依赖 |
| `docker-compose.yml` | 修改 | 添加服务 |
| `migrations/001_initial_schema.sql` | 新建 | 数据库初始化 |
| `celeryconfig.py` | 新建 | Celery 配置 |
| `.env` | 修改 | 添加数据库/Redis 配置 |

---

## 数据迁移

将现有的 JSON 文件任务迁移到数据库：

```python
# 迁移脚本：遍历 batch_tasks/*.json
# 读取每个任务文件，导入到 MySQL
# 归档旧文件到 batch_tasks/archive/
```

---

## 当前进度

### ✅ 已完成

#### 阶段 1：基础设施
- ✅ 数据库表结构设计 SQL
- ✅ 配置管理系统 (config.py)
- ✅ 数据库模型（SQLAlchemy ORM）
- ✅ 数据库会话管理
- ✅ 数据访问层

#### 阶段 2：核心服务
- ✅ 重复检测服务
- ✅ Celery 工作任务框架
- ✅ 族谱数据解析器

#### 阶段 3：API 接口
- ✅ 族谱查询 REST API（10个端点）

#### 配置文件
- ✅ requirements.txt - 添加新依赖
- ✅ .env - 添加数据库/Redis 配置
- ✅ docker-compose.yml - 添加 MySQL/Redis/Celery
- ✅ celeryconfig.py - Celery 配置
- ✅ app/main.py - 集成新路由

### 📋 待完成

#### 代码层面
1. **重构 batch_scan_service** - 集成数据库存储和 Celery 队列
2. **创建启动脚本** - start_worker.sh（Celery Worker 启动）
3. **添加数据库初始化代码** - 应用启动时自动创建表
4. **错误处理优化** - 完善异常处理和日志

#### 测试验证
1. **数据库连接测试** - 验证 MySQL 连接
2. **Celery 集成测试** - 验证任务队列
3. **API 接口测试** - 测试族谱查询接口
4. **端到端测试** - 完整流程测试

#### 部署相关
1. **数据库初始化** - 执行 SQL 脚本
2. **Redis 安装** - 如未安装需要安装
3. **服务启动** - API + Celery Worker

---

## 快速启动命令

```bash
# 1. 初始化数据库
mysql -h 172.27.243.32 -u root -p < migrations/001_initial_schema.sql

# 2. 安装依赖
pip install -r requirements.txt

# 3. 启动 API 服务
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4

# 4. 启动 Celery Worker（需要先启动 Redis）
celery -A app.workers.celery_worker worker --loglevel=info --concurrency=4

# 或使用 Docker Compose
docker compose up -d
```
