# 创建 GitHub Release 指南

## 自动方式（推荐）：通过 GitHub Actions

代码已包含自动创建 Release 的工作流！

**如何触发：**
1. 在本地创建新的版本标签：
   ```bash
   git tag -a v2.1.0 -m "Release v2.1.0"
   git push origin v2.1.0
   ```
2. GitHub Actions 会自动创建 Release

**当前状态：**
- ✅ 工作流文件已创建：`.github/workflows/auto-release.yml`
- ✅ v2.0.0 标签已推送（会自动触发 Release）

---

## 手动方式：在 GitHub Web 界面创建

### 步骤 1：访问 Releases 页面

直接点击以下链接：
```
https://github.com/sishengcao/paddleocr-api/releases/new
```

### 步骤 2：填写 Release 信息

| 字段 | 填写内容 |
|------|----------|
| **Choose a tag** | 选择 `v2.0.0`（已存在） |
| **Release title** | `v2.0.0 - 批量扫描与数据库存储` |
| **Describe this release** | 复制下面的内容 |

### 步骤 3：Release 说明（复制以下内容）

```markdown
# 🎉 PaddleOCR API v2.0.0 发布

## 🚀 重大功能更新

### 新增功能

**批量扫描功能**
- ✅ 异步任务队列处理（基于 Celery + Redis）
- ✅ 支持大目录批量扫描（28+ 文件）
- ✅ 实时任务状态追踪和进度查询
- ✅ 智能重复任务检测
- ✅ 结果导出（JSON/CSV 格式）

**数据库存储**
- ✅ MySQL 数据持久化存储
- ✅ 书籍管理（books 表）
- ✅ 任务管理（batch_tasks 表）
- ✅ OCR 结果存储（ocr_results 表，含完整 JSON 数据）
- ✅ 导出记录管理（exports 表）

**Web 界面**
- ✅ 批量扫描可视化界面
- ✅ 实时进度监控
- ✅ 任务管理界面

### 功能增强

**文件扫描**
- ✅ 支持大写文件扩展名（.JPG, .JPEG, .PNG）
- ✅ 支持小写文件扩展名
- ✅ 自动文件名解析（卷号、页码）

**OCR 结果**
- ✅ 存储 JSON 数据（包含 box 坐标、置信度）
- ✅ 优化数据模型（简化存储结构）

### 文档完善

- ✅ **部署指南**：Windows/Linux/WSL 完整部署说明
- ✅ **配置说明**：数据库/Redis 完整配置说明
- ✅ **API 文档**：完整的 API 端点说明
- ✅ **调用示例**：Python/Java 完整示例代码
- ✅ **升级计划**：PaddleOCR 升级指南
- ✅ **表结构说明**：完整的数据库表结构

---

## 📦 安装方式

### 方式一：Docker（推荐）

```bash
# 使用版本标签
docker pull ghcr.io/sishengcao/paddleocr-api:v2.0.0
docker run -p 8000:8000 ghcr.io/sishengcao/paddleocr-api:v2.0.0

# 使用 latest 标签
docker pull ghcr.io/sishengcao/paddleocr-api:latest
docker run -p 8000:8000 ghcr.io/sishengcao/paddleocr-api:latest
```

### 方式二：从源码安装

```bash
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
git checkout v2.0.0
pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### 方式三：Python 包（从 GitHub Packages）

```bash
pip install paddleocr-api==2.0.0 --index-url https://pip.github.com/sishengcao/paddleocr-api
```

---

## 🏗️ GitHub Actions 自动构建

### Docker 镜像
推送标签后会自动构建 Docker 镜像到：
```
ghcr.io/sishengcao/paddleocr-api:v2.0.0
ghcr.io/sishengcao/paddleocr-api:latest
```

### Python 包
Release 创建后会自动发布到 GitHub Packages。

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
```bash
# 导入数据库结构
mysql -u root -p paddleocr_api < migrations/001_initial_schema.sql

# 执行增量迁移
mysql -u root -p paddleocr_api < migrations/002_add_json_data_column.sql
```

**配置更新**：
- 添加 MySQL 配置
- 添加 Redis 配置
- 更新 `.env` 文件

---

## 📚 相关文档

- [README](https://github.com/sishengcao/paddleocr-api/blob/master/README.md)
- [版本管理指南](https://github.com/sishengcao/paddleocr-api/blob/master/VERSION_MANAGEMENT.md)
- [部署指南](https://github.com/sishengcao/paddleocr-api/blob/master/DEPLOYMENT.md)
- [升级计划](https://github.com/sishengcao/paddleocr-api/blob/master/UPGRADE_PLAN.md)

---

## 🙏 致谢

感谢所有贡献者和用户的支持！

---

## 📞 获取帮助

- 📖 [完整文档](https://github.com/sishengcao/paddleocr-api/blob/master/README.md)
- 🐛 [问题反馈](https://github.com/sishengcao/paddleocr-api/issues)
- 💬 [讨论区](https://github.com/sishengcao/paddleocr-api/discussions)
```

### 步骤 4：发布 Release

1. 勾选 ✅ **Set as the latest release**（如果这是最新版本）
2. 点击 **"Publish release"** 绿色按钮

---

## 通过 GitHub CLI 创建（可选）

如果您安装了 `gh` CLI：

```bash
# 安装 GitHub CLI（如果未安装）
# Windows: winget install GitHub.cli
# Linux: https://cli.github.com/

# 登录
gh auth login

# 创建 Release
gh release create v2.0.0 \
  --title "v2.0.0 - 批量扫描与数据库存储" \
  --notes-file CREATE_RELEASE_GUIDE.md
```

---

## 当前项目状态

### ✅ 已完成

| 项目 | 状态 |
|------|------|
| v2.0.0 标签 | ✅ 已推送到 GitHub |
| GitHub Actions 工作流 | ✅ 已配置 |
| Python 包配置 | ✅ pyproject.toml 已创建 |
| Docker 自动构建 | ✅ 工作流已配置 |
| 自动创建 Release | ✅ 工作流已配置 |
| 分支清理 | ✅ 已删除 feature 分支 |

### 📌 需要手动操作

| 任务 | 说明 |
|------|------|
| **创建 GitHub Release** | 访问 https://github.com/sishengcao/paddleocr-api/releases/new |
| **安装 gh CLI**（可选） | 如果想用命令行创建 Release |

### 🔄 自动化已配置

推送新标签后将自动：
1. ✅ 构建 Docker 镜像并推送到 ghcr.io
2. ✅ 发布 Python 包到 GitHub Packages
3. ✅ 自动创建 GitHub Release

---

## 下次发布流程

```bash
# 1. 做代码更改
git add .
git commit -m "feat: 新功能"

# 2. 创建版本标签
git tag -a v2.1.0 -m "Release v2.1.0"

# 3. 推送标签
git push origin master
git push origin v2.1.0

# 4. 自动触发 GitHub Actions
# - 构建 Docker 镜像
# - 发布 Python 包
# - 创建 GitHub Release
```
