# 版本管理指南

## Git Tags 版本管理

### 版本命名规范

本项目使用语义化版本（Semantic Versioning）：`v主版本.次版本.修订版本`

| 版本 | 说明 | 示例 |
|------|------|------|
| **主版本** | 重大功能变更，可能不向后兼容 | v1.0 → v2.0 |
| **次版本** | 新增功能，向后兼容 | v2.0 → v2.1 |
| **修订版本** | Bug 修复，向后兼容 | v2.0 → v2.0.1 |

### 创建版本标签

```bash
# 创建带注释的标签
git tag -a v2.0.0 -m "Release v2.0.0: 描述信息"

# 查看所有标签
git tag -l

# 查看标签详情
git show v2.0.0

# 删除本地标签
git tag -d v2.0.0

# 删除远程标签
git push origin :refs/tags/v2.0.0
```

### 推送标签到远程

```bash
# 推送单个标签
git push origin v2.0.0

# 推送所有标签
git push origin --tags
```

### 当前项目标签

| 版本 | 日期 | 说明 |
|------|------|------|
| v2.0.0 | 2026-01-05 | 批量扫描与数据库存储 |

---

## GitHub Releases

### 方式一：通过 Web 界面创建（推荐）

1. 访问项目 Releases 页面：
   ```
   https://github.com/sishengcao/paddleocr-api/releases
   ```

2. 点击 **"Draft a new release"**

3. 填写发布信息：
   - **Tag version**: 选择 `v2.0.0`
   - **Release title**: `v2.0.0 - 批量扫描与数据库存储`
   - **Description**: 复制下面的发布说明

4. 点击 **"Publish release"**

### 方式二：通过 GitHub CLI

```bash
# 安装 GitHub CLI
# Windows: winget install GitHub.cli
# Linux: https://cli.github.com/

# 登录
gh auth login

# 创建 Release
gh release create v2.0.0 \
  --title "v2.0.0 - 批量扫描与数据库存储" \
  --notes "发布说明见下文"
```

### 方式三：通过 API

```bash
# 创建 Release（需要 Personal Access Token）
curl -X POST \
  -H "Authorization: token YOUR_GITHUB_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/sishengcao/paddleocr-api/releases \
  -d '{
    "tag_name": "v2.0.0",
    "target_commitish": "master",
    "name": "v2.0.0 - 批量扫描与数据库存储",
    "body": "发布说明",
    "draft": false,
    "prerelease": false
  }'
```

---

## GitHub Packages

### Python 包发布

本项目可以发布到 GitHub Packages：

#### 1. 创建 `.github/workflows/publish.yml`

```yaml
name: Publish to GitHub Packages

on:
  release:
    types: [created]

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Python
        uses: actions/setup-python@v4
        with:
          python-version: '3.10'

      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install build twine

      - name: Build package
        run: |
          python -m build

      - name: Publish to GitHub Packages
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          twine upload --repository-url https://pip.github.com/sishengcao/paddleocr-api --username __token__ --password $GITHUB_TOKEN dist/*
```

#### 2. 配置 `setup.py` 或 `pyproject.toml`

创建 `pyproject.toml`:

```toml
[build-system]
requires = ["setuptools>=61.0", "wheel"]
build-backend = "setuptools.build_meta"

[project]
name = "paddleocr-api"
version = "2.0.0"
description = "PaddleOCR API 服务 - 支持单个识别和批量扫描"
readme = "README.md"
requires-python = ">=3.8"
license = {text = "MIT"}
authors = [
    {name = "sishengcao", email = "your@email.com"}
]
keywords = ["ocr", "paddleocr", "api", "fastapi"]
classifiers = [
    "Development Status :: 4 - Beta",
    "Intended Audience :: Developers",
    "License :: OSI Approved :: MIT License",
    "Programming Language :: Python :: 3",
    "Programming Language :: Python :: 3.8",
    "Programming Language :: Python :: 3.9",
    "Programming Language :: Python :: 3.10",
    "Programming Language :: Python :: 3.11",
]
dependencies = [
    "fastapi>=0.104.0",
    "uvicorn>=0.24.0",
    "paddleocr>=2.7.0",
    "paddlepaddle>=2.6.0",
    "python-multipart>=0.0.6",
    "pydantic>=2.0.0",
    "sqlalchemy>=2.0.0",
    "pymysql>=1.1.0",
    "celery>=5.3.0",
    "redis>=5.0.0",
]

[project.urls]
Homepage = "https://github.com/sishengcao/paddleocr-api"
Documentation = "https://github.com/sishengcao/paddleocr-api/blob/master/README.md"
Repository = "https://github.com/sishengcao/paddleocr-api.git"
Issues = "https://github.com/sishengcao/paddleocr-api/issues"
```

#### 3. 安装包

```bash
# 从 GitHub Packages 安装
pip install paddleocr-api --index-url https://pip.github.com/sishengcao/paddleocr-api
```

### Docker 镜像发布

#### 1. 构建并推送到 GitHub Container Registry

```bash
# 登录到 GitHub Container Registry
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin

# 构建镜像
docker build -t ghcr.io/sishengcao/paddleocr-api:v2.0.0 .

# 推送镜像
docker push ghcr.io/sishengcao/paddleocr-api:v2.0.0

# 添加 latest 标签
docker tag ghcr.io/sishengcao/paddleocr-api:v2.0.0 ghcr.io/sishengcao/paddleocr-api:latest
docker push ghcr.io/sishengcao/paddleocr-api:latest
```

#### 2. 使用 GitHub Actions 自动构建

创建 `.github/workflows/docker.yml`:

```yaml
name: Docker Image CI

on:
  push:
    branches: [ master ]
    tags:
      - 'v*'

jobs:
  build_and_push:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v2

      - name: Login to GitHub Container Registry
        uses: docker/login-action@v2
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v4
        with:
          images: ghcr.io/sishengcao/paddleocr-api

      - name: Build and push
        uses: docker/build-push-action@v4
        with:
          context: .
          push: true
          tags: |
            ghcr.io/sishengcao/paddleocr-api:latest
            ghcr.io/sishengcao/paddleocr-api:${{ steps.meta.outputs.version }}
          labels: ${{ steps.meta.outputs.labels }}
```

---

## 发布说明模板

### v2.0.0 发布说明

```markdown
# 🎉 PaddleOCR API v2.0.0 发布

## 重要更新

### 🚀 新功能

**批量扫描功能**
- 异步任务队列处理（基于 Celery + Redis）
- 支持大目录批量扫描（支持 28+ 文件）
- 实时任务状态追踪和进度查询
- 智能重复任务检测
- 结果导出（JSON/CSV 格式）

**数据库存储**
- MySQL 数据持久化存储
- 书籍管理（books 表）
- 任务管理（batch_tasks 表）
- OCR 结果存储（ocr_results 表，含完整 JSON 数据）
- 导出记录管理（exports 表）

**Web 界面**
- 批量扫描可视化界面
- 实时进度监控
- 任务管理界面

### 📝 功能增强

**文件扫描**
- 支持大写文件扩展名（.JPG, .JPEG, .PNG）
- 支持小写文件扩展名（.jpg, .jpeg, .png）
- 自动文件名解析（卷号、页码）

**OCR 结果**
- 存储 JSON 数据（包含 box 坐标、置信度）
- 优化数据模型（简化存储结构）
- 提供详细的识别结果

### 📚 文档完善

- **部署指南**：Windows/Linux/WSL 完整部署说明
- **配置说明**：数据库/Redis 完整配置说明
- **API 文档**：完整的 API 端点说明
- **调用示例**：Python/Java 完整示例代码
- **升级计划**：PaddleOCR 升级指南
- **表结构说明**：完整的数据库表结构

### 🐛 Bug 修复

- 修复文件扫描仅识别小写扩展名问题
- 修复重复检测方法调用错误
- 修复数据库模型关系定义

---

## 📦 安装方式

### 方式一：从源码安装

\`\`\`bash
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
pip install -r requirements.txt
\`\`\`

### 方式二：Docker 部署

\`\`\`bash
docker pull ghcr.io/sishengcao/paddleocr-api:v2.0.0
docker run -p 8000:8000 ghcr.io/sishengcao/paddleocr-api:v2.0.0
\`\`\`

---

## 📋 版本对比

| 功能 | v1.0 | v2.0 |
|------|------|------|
| 单个识别 | ✅ | ✅ |
| 批量识别（同步） | ✅ | ✅ |
| 批量扫描（异步） | ❌ | ✅ |
| 数据库存储 | ❌ | ✅ |
| 任务队列 | ❌ | ✅ |
| Web 界面 | ❌ | ✅ |
| 结果导出 | ❌ | ✅ |
| Java 示例 | ❌ | ✅ |
| 完整文档 | ⚠️ | ✅ |

---

## ⚠️ 升级注意事项

### 从 v1.x 升级到 v2.0

**数据库迁移**（如使用批量功能）：
\`\`\`bash
# 导入数据库结构
mysql -u root -p paddleocr_api < migrations/001_initial_schema.sql

# 执行增量迁移
mysql -u root -p paddleocr_api < migrations/002_add_json_data_column.sql
\`\`\`

**配置更新**：
- 添加 MySQL 配置（`DB_HOST`, `DB_USER`, `DB_PASSWORD`）
- 添加 Redis 配置（`REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD`）
- 更新 `.env` 文件

**启动服务**：
\`\`\`bash
# 启动 Celery Worker（批量功能需要）
python3 -m celery -A app.workers.celery_worker worker

# 启动 API 服务
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
\`\`\`

---

## 🙏 致谢

感谢所有贡献者和用户的支持！

---

## 📞 获取帮助

- 📖 [完整文档](https://github.com/sishengcao/paddleocr-api/blob/master/README.md)
- 🐛 [问题反馈](https://github.com/sishengcao/paddleocr-api/issues)
- 💬 [讨论区](https://github.com/sishengcao/paddleocr-api/discussions)
```

---

## 版本发布流程

### 标准发布流程

```bash
# 1. 更新版本号
# 编辑相关文件中的版本号

# 2. 创建标签
git tag -a v2.0.0 -m "Release v2.0.0: 发布说明"

# 3. 推送标签
git push origin v2.0.0

# 4. 在 GitHub 创建 Release
# 访问 https://github.com/sishengcao/paddleocr-api/releases/new
# 选择标签 v2.0.0，填写发布说明，点击 Publish

# 5. 构建 Docker 镜像（如需要）
docker build -t paddleocr-api:v2.0.0 .
docker tag paddleocr-api:v2.0.0 ghcr.io/sishengcao/paddleocr-api:v2.0.0
docker push ghcr.io/sishengcao/paddleocr-api:v2.0.0
```

### 紧急修复流程

```bash
# 主版本出错，创建修订版本
git tag -a v2.0.1 -m "Hotfix: 修复紧急问题"
git push origin v2.0.1

# 创建 Release
# 在 GitHub 创建 Release，选择 v2.0.1 标签
```

---

## 分支策略

| 分支 | 用途 | 稳定性 |
|------|------|--------|
| `master` | 主分支，稳定版本 | ✅ 生产就绪 |
| `develop` | 开发分支，最新功能 | ⚠️ 可能不稳定 |
| `feature-*` | 功能分支 | ⚠️ 开发中 |

---

## 变更日志

### [v2.0.0] - 2026-01-05

### Added
- 批量扫描功能（异步任务队列）
- 数据库存储（MySQL）
- Web 可视化界面
- 任务状态追踪和进度查询
- 重复任务检测
- 结果导出功能
- Java 调用示例
- PaddleOCR 升级计划
- 完善的部署文档

### Changed
- 支持大写文件扩展名
- 优化 OCR 结果数据结构
- 更新 README 文档结构

### Fixed
- 文件扫描扩展名问题
- 重复检测方法调用错误
- 数据库模型关系定义

---

## 相关链接

- [GitHub Releases](https://github.com/sishengcao/paddleocr-api/releases)
- [GitHub Packages](https://github.com/sishengcao/paddleocr-api/packages)
- [Container Registry](https://github.com/sishengcao/paddleocr-api/pkgs/container/paddleocr-api)
- [项目首页](https://github.com/sishengcao/paddleocr-api)
