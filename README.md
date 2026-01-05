# PaddleOCR API 服务

基于 PaddleOCR 的图片文字识别 API 服务，提供单个识别和批量扫描两种功能，可独立部署或组合部署。

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

| 模式 | 适用场景 | 依赖 |
|------|----------|------|
| 仅单个识别 | 单次识别、小批量同步识别 | 仅需 Python 环境 |
| 完整功能 | 大量图片处理、目录扫描、任务队列 | Python + MySQL + Redis + Celery Worker |

---

## 快速开始

### Docker Compose 部署（推荐）

> **要求**: Docker Compose v2（检查版本：`docker compose version`）

```bash
# 1. 克隆项目
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api

# 2. 创建环境变量文件
cp .env.example .env
# 如果 .env.example 不存在，手动创建 .env 文件

# 3. 启动所有服务
docker compose up -d

# 4. 查看日志
docker compose logs -f
```

### Windows / Linux 部署

详细的部署步骤请参考：

- [快速开始指南](快速开始.md) - Windows、Linux/WSL、Docker Compose 部署详细步骤
- [部署故障排查](部署故障排查.md) - 网络受限环境部署经验汇总
- [配置说明](配置说明.md) - 环境变量完整配置参考

---

## 访问方式

| 功能 | 地址 | 说明 |
|------|------|------|
| API 文档 | http://localhost:8000/docs | Swagger UI |
| API 文档（增强） | http://localhost:8000/docs-enhanced | ReDoc |
| 批量扫描界面 | http://localhost:8000/batch | 批量识别 Web UI |
| 健康检查 | http://localhost:8000/api/ocr/health | 服务健康状态 |

---

## 使用示例

### 1. 单个图片识别

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@test.jpg" \
  -F "lang=ch" \
  -F "use_angle_cls=true"
```

### 2. 创建批量扫描任务

```bash
curl -X POST "http://localhost:8000/api/ocr/batch/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "book_id": "廖氏族谱",
    "directory": "/path/to/images",
    "lang": "ch",
    "recursive": true
  }'
```

更多使用示例和 API 说明请参考：
- [API 使用指南](API使用指南.md) - 完整的 API 端点、请求响应格式、Python/Java 调用示例

---

## 技术栈

| 组件 | 技术 |
|------|------|
| Web 框架 | FastAPI |
| OCR 引擎 | PaddleOCR |
| 服务器 | Uvicorn |
| 任务队列 | Celery + Redis |
| 数据库 | MySQL |
| 数据验证 | Pydantic |
| ORM | SQLAlchemy |

---

## 成功案例：网络受限环境部署

### 部署环境

| 项目 | 详情 |
|------|------|
| 服务器 | Ubuntu 24.04.3 LTS |
| IP 地址 | 192.168.124.134 |
| 网络状态 | 严重受限（无法访问 Docker Hub 和大多数国内镜像源） |

### 遇到的问题与解决方案

#### 问题 1：Docker 镜像拉取失败
**解决方案**：在有网络的机器上手动下载并导入镜像

#### 问题 2：Docker 构建失败
**解决方案**：采用混合部署 - MySQL/Redis 使用 Docker，API 在宿主机运行

#### 问题 3：libGL.so.1 缺失
**解决方案**：安装系统依赖 `libgl1 libglib2.0-0`

#### 问题 4：MySQL 环境变量被清空
**解决方案**：使用单引号包裹密码（`'MYSQL_ROOT_PASSWORD=!qwert'`）

### 最终部署架构

```
┌─────────────────────────────────────────┐
│          服务器 (Ubuntu 24.04)          │
├─────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐   │
│  │   MySQL      │  │    Redis     │   │
│  │  (Docker)    │  │   (Docker)   │   │
│  └──────────────┘  └──────────────┘   │
│         │                 │           │
│         └─────────────────┘           │
│                   │                   │
│          ┌────────────────┐          │
│          │  PaddleOCR API │          │
│          │  (宿主机 Python)│          │
│          └────────────────┘          │
└─────────────────────────────────────────┘
```

完整的部署过程和故障排查请参考：[部署故障排查指南](部署故障排查.md)

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
