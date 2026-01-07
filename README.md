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

## 环境准备

本项目提供两个自动化脚本，用于快速准备运行环境：

### 1. 一键安装 Docker 运行环境

适用于全新安装的系统或需要配置 Docker 的环境。

```bash
# 赋予执行权限
chmod +x docker-fix-script-pro.sh

# 以 root 权限运行（自动安装 Docker Compose v2）
sudo bash docker-fix-script-pro.sh
```

**脚本功能**：
- ✓ 自动检测并安装 Docker CE 和 Docker Compose v2
- ✓ 配置多个国内镜像加速器（DaoCloud、南京大学、一面板等）
- ✓ 配置 hosts 文件解决 DNS 污染问题
- ✓ 配置 SSH 服务
- ✓ 配置防火墙规则
- ✓ 网络环境检测和故障诊断

**支持的系统**：Ubuntu/Debian (APT)、CentOS/RHEL (YUM)、Fedora (DNF)

### 2. 一键清理环境并重置

适用于需要将现有虚拟机重置为纯净环境的场景。

```bash
# 赋予执行权限
chmod +x system-purge-safe-script.sh

# 以 root 权限运行
sudo bash system-purge-safe-script.sh
```

**脚本功能**：
- ✓ 删除所有非系统用户和家目录
- ✓ 清理所有 Docker 容器、镜像、数据卷
- ✓ 清理非必要软件包（MySQL、Redis、Nginx 等，保留 Docker）
- ✓ 清理临时文件和日志
- ✓ 重置网络配置为 DHCP
- ✓ 重置 SSH 配置
- ✓ 重置 root 密码为 `!qwert`
- ✓ 清理命令历史记录

**⚠️ 警告**：此脚本会删除大量数据，请谨慎使用！执行前需要输入 `YES` 确认。

### 3. 推荐使用流程

**全新环境部署**：
```bash
# 步骤 1: 安装 Docker 环境
sudo bash docker-fix-script-pro.sh

# 步骤 2: 克隆项目并启动
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
docker compose up -d
```

**环境重置后重新部署**：
```bash
# 步骤 1: 清理现有环境
sudo bash system-purge-safe-script.sh

# 步骤 2: 重启系统
sudo reboot

# 步骤 3: 重新登录后安装 Docker 环境
sudo bash docker-fix-script-pro.sh

# 步骤 4: 克隆项目并启动
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
docker compose up -d
```

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
# 如果 .env.example 不存在，参考配置说明.md手动创建 .env 文件

# 3. (可选) 配置 Docker 镜像加速器
# 如果拉取镜像失败，参考部署故障排查.md配置镜像加速器

# 4. 启动所有服务
docker compose up -d

# 5. 查看日志
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

## 部署故障排查记录### 2026-01-07 前端 API 请求失败问题（已解决）**问题描述**：通过浏览器访问 http://192.168.124.134:8000/ 进行 OCR 识别时请求失败。**原因分析**：1. 前端硬编码 localhost（static/index.html 中 API_URL）2. 静态文件在镜像构建时复制，修改后需重新构建镜像**解决方案**：1. 修改 static/index.html 使用动态 URL2. 重新构建镜像：docker compose build paddleocr-api && docker compose up -d3. 浏览器强制刷新：Ctrl + F5**容器操作步骤总结**：| 操作类型 | 命令 ||---------|------|| 修改 Python 代码 | docker compose restart || 修改静态文件 | docker compose build && docker compose up -d || 修改 Dockerfile | docker compose build --no-cache && docker compose up -d || 查看日志 | docker compose logs -f paddleocr-api || 进入容器 | docker exec -it paddleocr-api bash |
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
