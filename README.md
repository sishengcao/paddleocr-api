# PaddleOCR API 服务

基于 PaddleOCR 的图片文字识别 API 服务，提供单个识别和批量扫描两种功能。

---

## 功能特性

### 单个识别功能（基础功能）
- 支持中英文识别
- 单张/批量图片同步识别
- 返回详细识别结果（文字框坐标、置信度）
- 完善的错误处理
- API 文档自动生成
- 无需额外依赖，开箱即用

### 批量扫描功能（扩展功能）
- 异步任务队列处理（Celery + Redis）
- 数据库存储识别结果（MySQL）
- 支持大目录批量扫描
- 任务状态追踪和进度查询
- 重复任务检测
- 结果导出（JSON/CSV）
- Web 可视化界面
- 完整的任务管理（取消/删除/重试）

---

## 部署模式

> **推荐使用 Docker Compose 部署**：所有组件（API、MySQL、Redis、Celery Worker、Celery Beat）统一通过 Docker Compose 管理，部署简单，维护方便。

| 模式 | 适用场景 | 依赖 |
|------|----------|------|
| Docker Compose（推荐） | 生产环境、完整功能 | Docker + Docker Compose |
| 仅单个识别 | 开发测试、单次识别 | 仅需 Python 环境 |

---

## 快速开始（Docker Compose 部署）

### 1. 克隆项目

```bash
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
```

### 2. 创建环境变量文件

```bash
cp .env.example .env
# 如果 .env.example 不存在，参考配置说明.md手动创建 .env 文件
```

### 3. 启动所有服务

```bash
docker compose up -d
```

### 4. 查看运行状态

```bash
# 查看容器状态
docker compose ps

# 查看日志
docker compose logs -f
```

### 5. 访问服务

| 功能 | 地址 | 说明 |
|------|------|------|
| API 文档 | http://localhost:8000/docs | Swagger UI |
| API 文档（增强） | http://localhost:8000/docs-enhanced | ReDoc |
| 批量扫描界面 | http://localhost:8000/batch | 批量识别 Web UI |
| 健康检查 | http://localhost:8000/api/ocr/health | 服务健康状态 |

---

## 使用说明

### 扫描目录配置

**Docker Compose 部署时**，将待扫描的图片目录挂载到容器：

```yaml
# 在 docker-compose.yml 中添加 volumes
services:
  paddleocr-api:
    volumes:
      - /path/to/your/images:/app/scanner/images:ro  # 只读挂载扫描目录
```

**创建批量扫描任务时**，使用容器内的路径：

```bash
curl -X POST "http://localhost:8000/api/ocr/batch/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "book_id": "廖氏族谱",
    "directory": "/app/scanner/images",  # 使用容器内路径
    "lang": "ch",
    "recursive": true
  }'
```

### 单个图片识别

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@test.jpg" \
  -F "lang=ch" \
  -F "use_angle_cls=true"
```

更多使用示例和 API 说明请参考：[API 使用指南](API使用指南.md)

---

## 部署架构

### Docker Compose 部署架构（推荐）

```
┌─────────────────────────────────────────────────────────┐
│                    Docker Compose                       │
├─────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   MySQL      │  │    Redis     │  │  Celery Beat │  │
│  │  (Docker)    │  │   (Docker)   │  │   (Docker)   │  │
│  │  :3306       │  │   :6379      │  │              │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│         │                 │                 │           │
│         └─────────────────┼─────────────────┘           │
│                           │                             │
│         ┌─────────────────┼─────────────────┐           │
│         │                 │                 │           │
│  ┌──────▼──────┐  ┌──────▼──────┐  ┌──────▼──────┐    │
│  │ PaddleOCR   │  │  Celery     │  │             │    │
│  │    API      │  │   Worker    │  │             │    │
│  │  (Docker)   │  │  (Docker)   │  │             │    │
│  │   :8000     │  │             │  │             │    │
│  └─────────────┘  └─────────────┘  └─────────────┘    │
└─────────────────────────────────────────────────────────┘
```

**服务组件**：

| 容器 | 端口 | 说明 |
|------|------|------|
| paddleocr-api | 8000 | FastAPI 应用服务 |
| paddleocr-mysql | 3306 | MySQL 数据库 |
| paddleocr-redis | 6379 | Redis 消息队列 |
| paddleocr-celery-worker | - | Celery 异步任务处理器 |
| paddleocr-celery-beat | - | Celery 定时任务调度器 |

---

## 环境准备

本项目提供自动化脚本，用于快速准备运行环境：

### 1. 一键安装 Docker 运行环境

```bash
chmod +x docker-fix-script-pro.sh
sudo bash docker-fix-script-pro.sh
```

**脚本功能**：
- 自动检测并安装 Docker CE 和 Docker Compose v2
- 配置多个国内镜像加速器
- 配置 hosts 文件解决 DNS 污染问题
- 网络环境检测和故障诊断

### 2. 一键清理环境并重置

```bash
chmod +x system-purge-safe-script.sh
sudo bash system-purge-safe-script.sh
```

**⚠️ 警告**：此脚本会删除大量数据，请谨慎使用！

---

## 部署故障排查记录

### 2026-01-07 PaddleOCR API 适配更新

**更新概述**：本次更新修复了多个部署问题，并适配了最新版本的 PaddleOCR。

**修改内容**：

1. **Dockerfile 修复**
   - 将 `libgl1-mesa-glx` 改为 `libgl1`（Debian trixie 兼容性）
   - 移除清华 PyPI 镜像源（同步延迟问题）
   - 添加 `procps` 包（提供 `pgrep` 命令用于容器健康检查）

2. **docker-compose.yml 增强**
   - 为 `celery-worker` 添加健康检查配置（使用 `pgrep -f 'celery.*worker'`）
   - 为 `celery-beat` 添加健康检查配置（使用 `pgrep -f 'celery.*beat'`）

3. **PaddleOCR API 兼容性修复**
   - 移除不支持的 `use_gpu` 参数
   - 移除 `ocr.ocr()` 的 `cls` 参数
   - 添加对不同 PaddleOCR 返回格式的兼容处理

4. **代码质量改进**
   - 修复 `celery_worker.py` 中的硬编码路径
   - 添加更完善的异常处理和错误日志

5. **数据库迁移修复**
   - 修复 `books` 表列名（`metadata` → `metadata_json`）
   - 修复视图定义中的中文字符问题

**已知限制**：

> **当前版本仅支持 CPU 模式**
>
> 由于最新版 PaddleOCR 移除了 `use_gpu` 参数，当前版本使用 CPU 进行 OCR 识别。
> GPU 支持将在后续版本中通过其他方式实现。

**测试结果**：

- 单个扫描功能：✅ 正常
- 批量扫描功能：✅ 正常
- Docker Compose 部署：✅ 所有容器健康运行

### 容器健康检查问题（已解决）

**问题描述**：Celery worker 和 beat 容器显示为 unhealthy 状态。

**原因分析**：

1. **缺少 pgrep 命令**
   - 错误信息：`/bin/sh: 1: pgrep: not found`
   - 原因：健康检查脚本使用 `pgrep` 命令检查进程，但容器中未安装 `procps` 包

**解决方案**：

1. Dockerfile 添加 `procps` 包：在系统依赖列表中添加 `procps`
2. docker-compose.yml 添加健康检查配置：
   ```yaml
   celery-worker:
     healthcheck:
       test: ["CMD-SHELL", "pgrep -f 'celery.*worker' > /dev/null || exit 1"]
   celery-beat:
     healthcheck:
       test: ["CMD-SHELL", "pgrep -f 'celery.*beat' > /dev/null || exit 1"]
   ```
3. 重新构建镜像并启动容器

**修复后状态**：

```
paddleocr-api           healthy
paddleocr-mysql         healthy
paddleocr-redis         healthy
paddleocr-celery-worker healthy
paddleocr-celery-beat   healthy
```

### 容器启动失败问题（已解决）

**问题描述**：通过 Docker Compose 部署后，多个容器不停重启，服务无法使用。

**原因分析**：

1. **OpenCV 缺少系统依赖**
   - 错误信息：`ImportError: libGL.so.1: cannot open shared object file`
   - 原因：Dockerfile 中使用了 `libgl1-mesa-glx`，在 Debian trixie 中已弃用

2. **硬编码的日志路径**
   - 错误信息：`FileNotFoundError: /mnt/d/project/github/paddleocr-api/logs/celery_worker.log`
   - 原因：`celery_worker.py` 中日志路径被硬编码为开发机器路径

**解决方案**：

1. 修复 Dockerfile：将 `libgl1-mesa-glx` 改为 `libgl1`
2. 修复 celery_worker.py：将日志路径改为 `/app/logs`
3. 重新构建镜像并启动容器

**修复后状态**：

```
CONTAINER ID   IMAGE               STATUS
paddleocr-api      healthy (running)
paddleocr-mysql    healthy (running)
paddleocr-redis    healthy (running)
paddleocr-celery-worker   healthy
paddleocr-celery-beat     healthy
```

---

## 技术栈

| 组件 | 技术 |
|------|------|
| Web 框架 | FastAPI |
| OCR 引擎 | PaddleOCR |
| 服务器 | Uvicorn |
| 任务队列 | Celery + Redis |
| 数据库 | MySQL 8.0 |
| 数据验证 | Pydantic |
| ORM | SQLAlchemy |
| 容器化 | Docker + Docker Compose |

---

## 文档导航

### 快速上手
- [快速开始指南](快速开始.md) - Windows、Linux/WSL、Docker Compose 部署详细步骤
- [配置说明](配置说明.md) - 环境变量完整配置参考

### API 使用
- [API 使用指南](API使用指南.md) - API 端点、请求响应格式、调用示例

### 数据库
- [数据库设计](数据库设计.md) - 表结构、ER 图、初始化脚本

### 故障排查
- [常见问题](常见问题.md) - 部署和运行常见问题及解决方案
- [部署故障排查](部署故障排查.md) - 网络受限环境部署经验汇总

### 其他
- [升级计划](UPGRADE_PLAN.md) - PaddleOCR 升级指南
- [在线 API 文档](http://localhost:8000/docs) - Swagger UI 交互式文档

---

## 许可证

MIT License

---

## 相关链接

- GitHub: https://github.com/sishengcao/paddleocr-api
- PaddleOCR: https://github.com/PaddlePaddle/PaddleOCR
