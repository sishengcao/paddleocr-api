# PaddleOCR API 服务

基于 PaddleOCR 的图片文字识别 API 服务，支持中英文识别、批量扫描、竖排文字识别等功能。

---

## 文档目录

| 文档 | 说明 |
|------|------|
| [快速开始](快速开始.md) | Windows、Linux/WSL、Docker Compose 部署详细步骤 |
| [配置说明](配置说明.md) | 环境变量完整配置参考 |
| [API 使用指南](API使用指南.md) | API 端点、请求响应格式、调用示例 |
| [数据库设计](数据库设计.md) | 表结构、ER 图、初始化脚本 |
| [常见问题](常见问题.md) | 部署和运行常见问题及解决方案 |
| [部署故障排查](部署故障排查.md) | 网络受限环境部署经验汇总 |
| [问题复盘记录](CHANGELOG.md) | 开发运维过程中的问题及解决方案 |

---

## 快速开始

### Docker Compose 部署（推荐）

```bash
# 1. 克隆项目
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api

# 2. 创建环境变量文件
cp .env.example .env

# 3. 启动服务
docker compose up -d

# 4. 查看日志
docker compose logs -f
```

### 访问服务

| 功能 | 地址 |
|------|------|
| API 文档 | http://localhost:8000/docs |
| 识别界面 | http://localhost:8000/ |
| 批量扫描 | http://localhost:8000/batch |
| 健康检查 | http://localhost:8000/api/ocr/health |

---

## 配置文件说明

### 环境变量

| 文件 | 说明 |
|------|------|
| `.env.example` | 环境变量模板 |
| `.env` | 实际环境变量（不提交到 Git） |
| `deploy/production/.env.example` | 生产环境配置模板 |

### Docker Compose

| 文件 | 说明 |
|------|------|
| `docker-compose.yml` | 本地开发环境配置 |
| `deploy/production/docker-compose.yml` | 生产环境配置 |

### 脚本工具

| 脚本 | 说明 |
|------|------|
| `docker-fix-script-pro.sh` | 一键安装 Docker 环境 |
| `system-purge-safe-script.sh` | 系统纯净还原脚本 |
| `deploy-server.sh` | 服务器部署脚本 |
| `deploy-linux.sh` | Linux 部署脚本 |

---

## API 使用示例

### 单图识别

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@test.jpg" \
  -F "use_angle_cls=true" \
  -F "return_details=true"
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

---

## 文件识别说明

### 宿主机文件识别（推荐）

**方法一：挂载目录（推荐）**

修改 `docker-compose.yml`，添加挂载配置：

```yaml
services:
  paddleocr-api:
    volumes:
      # 挂载宿主机目录到容器
      - /home/sishengcao/ocr:/app/uploads:ro
      - /path/to/your/images:/app/images:ro
```

重启后，容器内 `/app/uploads` 对应宿主机 `/home/sishengcao/ocr`。

```bash
# 重启容器
docker compose up -d

# 识别挂载目录中的文件
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@/app/uploads/test.jpg"
```

**方法二：复制文件到容器**

```bash
# 复制文件到容器
docker cp /path/to/image.png paddleocr-api:/app/temp/

# 在容器内识别
docker exec paddleocr-api curl -X POST http://localhost:8000/api/ocr/recognize \
  -F "file=@/app/temp/image.png"
```

### 目录结构说明

```
项目根目录/
├── app/                    # 应用代码
│   ├── api/               # API 路由
│   ├── database/          # 数据库模型
│   ├── static/            # 前端静态文件
│   └── workers/           # Celery 任务
├── deploy/                # 部署配置
│   └── production/        # 生产环境配置
├── uploads/               # 上传文件目录（宿主机挂载点）
├── temp/                  # 临时文件目录
├── logs/                  # 日志目录
├── docker-compose.yml     # Docker Compose 配置
├── .env                   # 环境变量
└── README.md              # 项目说明
```

### 容器内路径映射

| 容器内路径 | 宿主机路径（推荐挂载） | 说明 |
|-----------|---------------------|------|
| `/app/uploads` | `/home/sishengcao/ocr` | 待识别图片存放 |
| `/app/temp` | - | 临时文件（自动清理） |
| `/app/logs` | `/var/log/paddleocr` | 应用日志 |

**推荐挂载配置**：

```yaml
services:
  paddleocr-api:
    volumes:
      # 图片存储目录
      - /home/sishengcao/ocr:/app/uploads:ro
      # 日志目录
      - /var/log/paddleocr:/app/logs
      # 配置文件（可选）
      - ./config:/app/config:ro
```

---

## 系统配置

### SSH 免密登录

**生成密钥**：
```bash
ssh-keygen -t rsa -b 4096
```

**复制公钥到服务器**：
```bash
ssh-copy-id sishengcao@192.168.124.134
```

**或手动配置**：
```bash
# 本地查看公钥
cat ~/.ssh/id_rsa.pub

# 添加到服务器
ssh sishengcao@192.168.124.134
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "公钥内容" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 非 root 用户执行 Docker

**方法一：将用户添加到 docker 组（推荐）**

```bash
# 将用户添加到 docker 组
sudo usermod -aG docker sishengcao

# 用户重新登录或执行
newgrp docker

# 验证（不需要 sudo）
docker ps
```

**方法二：配置 sudoers**

```bash
# 编辑 sudoers
sudo visudo

# 添加以下行
sishengcao ALL=(ALL) NOPASSWD: /usr/bin/docker
```

---

## 环境准备

### 一键安装 Docker

```bash
chmod +x docker-fix-script-pro.sh
sudo bash docker-fix-script-pro.sh
```

**功能**：
- 自动安装 Docker CE、Docker Compose v2
- 配置多个国内镜像加速器
- 修复 DNS 污染问题
- 配置防火墙规则

### 系统纯净还原

```bash
chmod +x system-purge-safe-script.sh
sudo bash system-purge-safe-script.sh
sudo reboot
```

**⚠️ 警告**：会删除所有开发环境和数据，仅保留 root 和 sishengcao 用户！

**清理内容**：
- 所有开发环境 (Java, Python, Node.js, Go, Ruby, PHP, Rust)
- Docker 容器、镜像、数据卷
- IDE 和编辑器配置
- 数据库 (MySQL, PostgreSQL, MongoDB, Redis)
- Web 服务器 (Nginx, Apache, Tomcat)
- 所有非系统用户（保留 root 和 sishengcao）

**保留内容**：
- root 用户（密码: `!qwert`）
- sishengcao 用户（密码: `root`）
- 系统核心配置、网络、SSH

---

## 技术栈

| 组件 | 技术 |
|------|------|
| Web 框架 | FastAPI |
| OCR 引擎 | PaddleOCR |
| 任务队列 | Celery + Redis |
| 数据库 | MySQL |
| ORM | SQLAlchemy |
| 容器 | Docker + Docker Compose |

---

## 开发指南

### 修改代码后重启

| 修改类型 | 操作 |
|---------|------|
| Python 代码 | `docker compose restart paddleocr-api` |
| 静态文件 | `docker compose build && docker compose up -d` |
| Dockerfile | `docker compose build --no-cache && docker compose up -d` |
| 环境变量 | `docker compose up -d --force-recreate` |

### 查看日志

```bash
# 查看所有日志
docker compose logs -f

# 查看特定服务
docker compose logs -f paddleocr-api
docker compose logs -f paddleocr-celery-worker

# 进入容器
docker exec -it paddleocr-api bash
docker exec -it paddleocr-mysql mysql -uroot -p
```

---

## 常见问题

### Q: 如何识别服务器上的图片？

**A**: 推荐使用目录挂载方式：

```yaml
# docker-compose.yml
services:
  paddleocr-api:
    volumes:
      - /home/sishengcao/ocr:/app/uploads:ro
```

重启后即可识别 `/home/sishengcao/ocr` 目录下的图片。

### Q: 识别结果不准确怎么办？

**A**: 尝试以下参数调整：
- 启用文字方向检测：`use_angle_cls=true`
- 指定正确的语言：`lang=ch`（中文）或 `lang=en`（英文）
- 竖排文字设置：`text_layout=vertical_rl`

### Q: 批量扫描任务如何查看进度？

**A**: 使用任务状态查询接口：

```bash
curl "http://localhost:8000/api/ocr/batch/status/{task_id}"
```

### Q: 如何备份数据？

**A**:
```bash
# 备份 MySQL 数据库
docker exec paddleocr-mysql mysqldump -uroot -p paddleocr_api > backup.sql

# 备份上传的文件
cp -r /home/sishengcao/ocr /backup/
```

---

## 问题反馈

- 提交 Issue: [GitHub Issues](https://github.com/sishengcao/paddleocr-api/issues)
- 查看问题复盘: [CHANGELOG.md](CHANGELOG.md)

---

## 许可证

MIT License

---

## 相关链接

- [PaddleOCR](https://github.com/PaddlePaddle/PaddleOCR)
- [FastAPI](https://fastapi.tiangolo.com/)
- [Celery](https://docs.celeryq.dev/en/stable/)
