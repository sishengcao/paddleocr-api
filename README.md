# PaddleOCR API 服务

基于 PaddleOCR 的图片文字识别 API 服务，支持中英文识别、批量扫描、竖排文字识别。

---

**快速导航** | [部署](#部署) · [使用](#使用) · [系统管理](#系统管理) · [配置](#配置文件)

---

## 部署

### 方式一：Docker Compose（推荐）

```bash
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
cp .env.example .env
docker compose up -d
```

访问：http://localhost:8000/docs

### 部署后容器信息

| 服务 | 端口 | 访问地址 | 连接信息 |
|------|------|----------|----------|
| **API 服务** | 8000 | http://localhost:8000 | - |
| API 文档 | 8000 | http://localhost:8000/docs | - |
| 识别界面 | 8000 | http://localhost:8000/ | - |
| **MySQL** | 3306 | localhost:3306 | `mysql://root:!qwert@localhost:3306/paddleocr_api` |
| **Redis** | 6379 | localhost:6379 | `redis://localhost:6379/0` |

### 容器管理

```bash
# 查看运行状态
docker compose ps

# 查看日志
docker compose logs -f

# 重启服务
docker compose restart

# 停止服务
docker compose down

# 停止并删除数据
docker compose down -v
```

### 方式二：服务器部署

```bash
# 1. 安装 Docker（一键脚本）
chmod +x docker-fix-script-pro.sh
sudo bash docker-fix-script-pro.sh

# 2. 部署服务
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
cp .env.example .env
docker compose up -d
```

### 部署文档

- [快速开始.md](快速开始.md) - Windows、Linux/WSL 详细步骤
- [部署故障排查.md](部署故障排查.md) - 网络受限环境部署
- [生产环境部署.md](生产环境部署.md) - 生产环境配置

---

## 使用

### 单图识别

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@/path/to/image.jpg"
```

### 批量识别

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize-batch" \
  -F "files=@img1.jpg" \
  -F "files=@img2.jpg"
```

### 批量扫描

```bash
curl -X POST "http://localhost:8000/api/ocr/batch/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "book_id": "test_book",
    "directory": "/app/uploads",
    "lang": "ch",
    "recursive": true
  }'
```

### 使用文档

- [API 使用指南.md](API使用指南.md) - 完整 API 文档和调用示例

### 识别服务器上的文件

**推荐方式：挂载目录**

修改 `docker-compose.yml`：
```yaml
services:
  paddleocr-api:
    volumes:
      - /home/sishengcao/ocr:/app/uploads:ro
```

重启后，将图片放到 `/home/sishengcao/ocr` 目录即可识别。

---

## 配置文件

### 环境变量

```bash
# 复制模板
cp .env.example .env

# 编辑配置
vim .env
```

主要配置项：
- `MYSQL_ROOT_PASSWORD` - MySQL 密码
- `MYSQL_DATABASE` - 数据库名称
- `REDIS_PASSWORD` - Redis 密码

### 配置文档

- [配置说明.md](配置说明.md) - 完整环境变量说明

### 宿主机文件挂载

```yaml
# docker-compose.yml
volumes:
  # 图片目录（必需）
  - /home/sishengcao/ocr:/app/uploads:ro
  # 日志目录（可选）
  - /var/log/paddleocr:/app/logs
```

---

## 系统管理

### SSH 免密登录

```bash
# 生成密钥
ssh-keygen -t rsa -b 4096

# 复制到服务器
ssh-copy-id sishengcao@192.168.124.134
```

**SSH 配置生效操作**：

如果 SSH 无法登录或配置未生效，执行以下步骤：

```bash
# 1. 确保 SSH 服务运行
sudo systemctl restart ssh

# 2. 检查 SSH 配置
sudo grep -E "^PermitRootLogin|^PasswordAuthentication|^PubkeyAuthentication" /etc/ssh/sshd_config

# 3. 如果配置不正确，手动修改（可选）
sudo vim /etc/ssh/sshd_config
# 确保以下配置项：
# PermitRootLogin yes
# PasswordAuthentication yes
# PubkeyAuthentication yes

# 4. 重启 SSH 使配置生效
sudo systemctl restart ssh
```

### 非 root 用户执行 Docker

```bash
# 将用户添加到 docker 组
sudo usermod -aG docker sishengcao
newgrp docker

# 验证
docker ps
```

### 系统清理

**清理开发环境，重置为纯净状态**：

```bash
chmod +x system-purge-safe-script.sh
sudo bash system-purge-safe-script.sh
sudo reboot
```

⚠️ 警告：会删除所有开发环境、数据和非系统用户！

---

## 开发

### 修改代码后重启

| 修改类型 | 命令 |
|---------|------|
| Python 代码 | `docker compose restart paddleocr-api` |
| 静态文件 | `docker compose build && docker compose up -d` |
| Dockerfile | `docker compose build --no-cache && docker compose up -d` |

### 查看日志

```bash
# 所有日志
docker compose logs -f

# 特定服务
docker compose logs -f paddleocr-api
docker compose logs -f paddleocr-celery-worker

# 进入容器
docker exec -it paddleocr-api bash
docker exec -it paddleocr-mysql mysql -uroot -p
```

---

## 文档索引

### 核心文档

| 文档 | 说明 |
|------|------|
| [快速开始.md](快速开始.md) | Windows、Linux/WSL 部署步骤 |
| [配置说明.md](配置说明.md) | 环境变量配置 |
| [API使用指南.md](API使用指南.md) | API 文档和调用示例 |
| [CHANGELOG.md](CHANGELOG.md) | 问题复盘和变更记录 |
| [常见问题.md](常见问题.md) | 部署和运行常见问题 |

### 进阶文档

| 文档 | 说明 |
|------|------|
| [数据库设计.md](数据库设计.md) | 表结构和 ER 图 |
| [部署故障排查.md](部署故障排查.md) | 网络受限环境部署 |
| [生产环境部署.md](生产环境部署.md) | 生产环境配置 |
| [升级计划.md](升级计划.md) | PaddleOCR 升级指南 |

### 脚本工具

| 脚本 | 说明 |
|------|------|
| `docker-fix-script-pro.sh` | 一键安装 Docker |
| `system-purge-safe-script.sh` | 系统纯净还原 |
| `deploy-server.sh` | 服务器部署 |
| `deploy-linux.sh` | Linux 部署 |

---

## 技术栈

```
FastAPI + PaddleOCR + Celery + Redis + MySQL + Docker
```

---

## 许可证

MIT License

---

**相关链接** | [GitHub](https://github.com/sishengcao/paddleocr-api) · [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR) · [Issues](https://github.com/sishengcao/paddleocr-api/issues)
