# 部署故障排查指南

本文档汇总了 PaddleOCR API 在部署过程中常见的问题及解决方案，特别是在网络受限环境下的部署经验。

---

## 目录

1. [Docker Compose 版本问题](#1-docker-compose-版本问题)
2. [环境变量文件缺失](#2-环境变量文件缺失)
3. [Docker 镜像拉取失败](#3-docker-镜像拉取失败)
4. [国内镜像源配置](#4-国内镜像源配置)
5. [容器构建失败](#5-容器构建失败)
6. [网络环境诊断](#6-网络环境诊断)

---

## 1. Docker Compose 版本问题

### 问题描述

```
WARN[0000] the attribute `version` is obsolete
```

或命令不存在：

```
docker-compose: command not found
```

### 原因

项目已迁移到 Docker Compose v2，使用新语法 `docker compose` 而非 `docker-compose`。

### 解决方案

**检查版本**：
```bash
docker compose version
```

**更新命令语法**：
```bash
# 旧语法（v1）
docker-compose up -d
docker-compose ps
docker-compose logs
docker-compose down

# 新语法（v2）
docker compose up -d
docker compose ps
docker compose logs
docker compose down
```

**删除 version 字段**：
在 `docker-compose.yml` 中删除 `version: '3.8'` 行（v2 不再需要）。

---

## 2. 环境变量文件缺失

### 问题描述

```
env file .env not found: stat /path/.env: no such file or directory
```

### 原因

Docker Compose 启动时找不到 `.env` 文件。

### 解决方案

**方式1：复制示例文件**（推荐）：
```bash
cp .env.example .env
vim .env  # 修改必要的配置
```

**方式2：手动创建**：
```bash
cat > .env << 'EOF'
# 应用配置
APP_NAME=PaddleOCR API
DEBUG=false
HOST=0.0.0.0
PORT=8000

# 数据库配置（Docker 使用服务名）
DB_HOST=mysql
DB_PASSWORD=your_secure_password
DB_NAME=paddleocr_api

# Redis 配置
REDIS_HOST=redis
REDIS_PORT=6379

# OCR 配置
OCR_LANG=ch
OCR_USE_GPU=false
EOF
```

**注意**：`.env` 文件包含敏感信息，不应提交到 Git 仓库（已在 `.gitignore` 中）。

---

## 3. Docker 镜像拉取失败

### 问题描述

```
Error: failed to resolve reference "docker.io/library/xxx": connection reset by peer
Error: unable to fetch descriptor: content size of zero
```

### 原因

服务器无法访问 Docker Hub (registry-1.docker.io)，常见于：
- 中国大陆服务器
- 企业内网环境
- 防火墙限制

### 解决方案

#### 方案1：配置镜像加速器（推荐）

```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": [
    "https://docker.xuanyuan.me",
    "https://docker.1panel.live",
    "https://docker.chenby.cn",
    "https://registry.cn-hangzhou.aliyuncs.com"
  ]
}
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
docker compose up -d
```

#### 方案2：使用 VPN/代理

```bash
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null << 'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:7890"
Environment="HTTPS_PROXY=http://127.0.0.1:7890"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF

sudo systemctl daemon-reload
sudo systemctl restart docker
```

#### 方案3：手动下载并导入镜像

**在有网络的机器上**：
```bash
docker pull mysql:8.0
docker pull redis:7-alpine
docker pull python:3.10-slim
docker save mysql:8.0 redis:7-alpine python:3.10-slim -o paddleocr-images.tar
```

**传输到目标服务器**：
```bash
scp paddleocr-images.tar user@server:/tmp/
```

**在服务器上导入**：
```bash
docker load -i /tmp/paddleocr-images.tar
docker compose up -d
```

#### 方案4：预构建完整镜像

**在本地构建完整镜像**：
```bash
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
docker build -t paddleocr-api:latest .
docker save paddleocr-api:latest mysql:8.0 redis:7-alpine -o paddleocr-complete.tar
```

**传输并部署**：
```bash
scp paddleocr-complete.tar user@server:/tmp/
ssh user@server
docker load -i /tmp/paddleocr-complete.tar
cd /path/to/paddleocr-api
docker compose up -d
```

---

## 4. 国内镜像源配置

### 问题分析

经过实际测试，各镜像源在受限网络环境下的表现：

| 镜像源 | 状态 | 错误 |
|--------|------|------|
| docker.xuanyuan.me | ❌ | 401 Unauthorized（需认证） |
| docker.1panel.live | ❌ | 403 Forbidden |
| docker.chenby.cn | ❌ | 连接超时 |
| 阿里云 registry.cn-hangzhou.aliyuncs.com | ❌ | 404/403 |
| 腾讯云 ccr.ccs.tencentyun.com | ❌ | 401 Unauthorized |

### 结论

在**严重受限的网络环境**下，镜像加速器方案可能无效。

**最佳实践**：
1. 先测试镜像源可用性：`curl -I https://镜像源/v2/`
2. 优先使用**方案3（手动导入）**或**方案4（预构建）**

---

## 5. 容器构建失败

### 问题描述

```
failed to solve: process "/bin/sh -c apt-get update" did not complete successfully: exit code: 100
```

### 原因

Dockerfile 构建过程中，`apt-get update` 无法访问 Debian/Ubuntu 软件源。

### 解决方案

**修改 Dockerfile 使用国内软件源**（已配置）：

```dockerfile
# 配置阿里云 Debian 软件源
RUN sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list.d/debian.sources 2>/dev/null || \
    sed -i 's/deb.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list && \
    sed -i 's/security.debian.org/mirrors.aliyun.com/g' /etc/apt/sources.list
```

**其他可用软件源**：
```bash
# 清华大学
sed -i 's/deb.debian.org/mirrors.tuna.tsinghua.edu.cn/g' /etc/apt/sources.list

# 中科大
sed -i 's/deb.debian.org/mirrors.ustc.edu.cn/g' /etc/apt/sources.list

# 网易
sed -i 's/deb.debian.org/mirrors.163.com/g' /etc/apt/sources.list
```

**构建前先拉取基础镜像**：
```bash
docker pull python:3.10-slim
docker compose build
```

---

## 6. 网络环境诊断

### 诊断脚本

```bash
#!/bin/bash
echo "=== Docker 镜像源诊断 ==="

echo -e "\n1. Docker Hub 连通性:"
curl -I --connect-timeout 5 https://registry-1.docker.io/v2/ 2>&1 | grep -E "HTTP|timeout|refused"

echo -e "\n2. 镜像加速器测试:"
for mirror in "https://docker.xuanyuan.me" "https://docker.1panel.live" "https://docker.chenby.cn" "https://registry.cn-hangzhou.aliyuncs.com"; do
    echo -n "  $mirror: "
    curl -I --connect-timeout 5 "$mirror/v2/" 2>&1 | grep -E "HTTP|timeout|refused" | head -1
done

echo -e "\n3. Docker 配置:"
docker info | grep -A 5 "Registry Mirrors"

echo -e "\n4. 镜像拉取测试:"
docker pull hello-world:latest 2>&1 | grep -E "Error|Pulling|Downloaded"
```

### 根据诊断结果选择方案

| 诊断结果 | 推荐方案 |
|----------|----------|
| 所有镜像源均可访问 | 使用镜像加速器（方案1） |
| 部分镜像源可用 | 使用可用镜像源 + 手动导入 |
| 所有镜像源失败 | 使用方案3（手动导入）或方案4（预构建） |

---

## 7. 完整部署流程（网络受限环境）

### 步骤1：准备环境

```bash
# SSH 登录服务器
ssh user@server

# 安装 Docker 和 Docker Compose v2
curl -fsSL https://get.docker.com | sh
docker compose version
```

### 步骤2：克隆项目

```bash
cd /opt
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
```

### 步骤3：创建环境变量

```bash
cp .env.example .env
vim .env  # 修改数据库密码等配置
```

### 步骤4A：在线部署（镜像源可用）

```bash
# 配置镜像加速器
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": ["https://docker.xuanyuan.me"]
}
EOF

sudo systemctl daemon-reload && sudo systemctl restart docker

# 启动服务
docker compose up -d
```

### 步骤4B：离线部署（镜像源不可用）

**在有网络的机器上**：
```bash
# 拉取镜像
docker pull mysql:8.0
docker pull redis:7-alpine
docker pull python:3.10-slim

# 构建应用镜像
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api
docker build -t paddleocr-api:latest .

# 导出所有镜像
docker save mysql:8.0 redis:7-alpine paddleocr-api:latest -o paddleocr-images.tar

# 传输到服务器
scp paddleocr-images.tar user@server:/tmp/
```

**在目标服务器上**：
```bash
# 导入镜像
docker load -i /tmp/paddleocr-images.tar

# 部署
cd /opt/paddleocr-api
docker compose up -d
```

### 步骤5：验证部署

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 测试 API
curl http://localhost:8000/api/ocr/health
```

---

## 8. 常见错误代码对照表

| 错误代码 | 含义 | 解决方案 |
|----------|------|----------|
| `exit code: 100` | apt-get update 失败 | 配置国内软件源或预构建镜像 |
| `401 Unauthorized` | 需要认证 | 更换镜像源或使用代理 |
| `403 Forbidden` | 访问被拒绝 | 更换镜像源或手动导入 |
| `404 Not Found` | 镜像不存在 | 检查镜像名称或更换源 |
| `connection reset` | 连接被重置 | 使用代理或手动导入 |
| `content size of zero` | 无法获取元数据 | 使用代理或手动导入 |

---

## 9. 快速参考

### 检查清单

- [ ] Docker Compose v2 已安装
- [ ] `.env` 文件已创建
- [ ] 镜像加速器已配置（如需要）
- [ ] 防火墙已开放端口 8000, 3306, 6379
- [ ] Python 依赖可正常安装

### 关键命令

```bash
# 诊断网络
bash <(curl -s https://raw.githubusercontent.com/sishengcao/paddleocr-api/master/scripts/diagnose.sh)

# 完整重启
docker compose down && docker compose up -d

# 查看日志
docker compose logs -f paddleocr-api

# 进入容器调试
docker compose exec paddleocr-api bash
```

---

## 10. 获取帮助

如果以上方案都无法解决问题：

1. **查看详细日志**：`docker compose logs --tail=100`
2. **检查系统日志**：`journalctl -u docker -n 50`
3. **提交 Issue**：[https://github.com/sishengcao/paddleocr-api/issues](https://github.com/sishengcao/paddleocr-api/issues)
4. **查看讨论区**：[https://github.com/sishengcao/paddleocr-api/discussions](https://github.com/sishengcao/paddleocr-api/discussions)

**提交 Issue 时请包含**：
- 操作系统版本
- Docker 版本：`docker --version`
- Docker Compose 版本：`docker compose version`
- 完整的错误信息
- 网络诊断结果

---

## 11. 实战案例：网络受限环境部署（Ubuntu 24.04）

### 11.1 环境背景

**服务器信息**：
- 系统：Ubuntu 24.04.3 LTS
- IP：192.168.124.134
- 用户：ppocr
- 网络状态：严重受限，无法访问 Docker Hub 和大多数国内镜像源

### 11.2 遇到的问题

#### 问题 1：Docker 镜像拉取失败

```
Error: failed to resolve reference "docker.io/library/xxx": connection reset by peer
```

**尝试的解决方案**：
1. ✗ 配置镜像加速器（docker.xuanyuan.me → 401）
2. ✗ 配置镜像加速器（docker.1panel.live → 403）
3. ✗ 配置镜像加速器（阿里云 → 404）
4. ✗ 使用国内镜像仓库（全部失败）

**结论**：服务器网络严重受限，所有测试的镜像源均不可用。

#### 问题 2：Docker 构建失败

```
failed to solve: process "/bin/sh -c apt-get update" did not complete successfully: exit code: 100
```

**原因**：
- 即使配置了国内软件源（阿里云 mirrors.aliyun.com），apt-get update 仍然失败
- Docker 容器内的网络环境比宿主机更加受限

#### 问题 3：libGL.so.1 缺失

```
ImportError: libGL.so.1: cannot open shared object file: No such file or directory
```

**解决**：在宿主机安装系统依赖
```bash
sudo apt install -y libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libgomp1
```

#### 问题 4：MySQL 环境变量被清空

```
MYSQL_ROOT_PASSWORD=  # 密码为空
```

**原因**：`!qwert` 中的 `!` 被 shell 解释为历史命令扩展

**解决**：使用单引号包裹密码
```bash
docker run -e 'MYSQL_ROOT_PASSWORD=!qwert' ...
```

### 11.3 最终解决方案：混合部署

由于完全无法使用 Docker 构建，采用**混合部署方案**：

**架构**：
- MySQL 和 Redis 使用 Docker 容器（手动导入的镜像）
- PaddleOCR API 在宿主机运行（Python 虚拟环境）

#### 步骤 1：准备镜像（在有网络的机器）

```bash
# 拉取所需镜像
docker pull mysql:8.0
docker pull redis:7-alpine

# 导出镜像
docker save mysql:8.0 redis:7-alpine -o paddleocr-images.tar

# 传输到服务器
scp paddleocr-images.tar ppocr@192.168.124.134:/tmp/
```

#### 步骤 2：在服务器导入镜像

```bash
ssh ppocr@192.168.124.134
docker load -i /tmp/paddleocr-images.tar
```

#### 步骤 3：部署基础服务（Docker）

```bash
# 部署 MySQL（注意单引号）
docker run -d \
  --name paddleocr-mysql \
  -e 'MYSQL_ROOT_PASSWORD=!qwert' \
  -e 'MYSQL_DATABASE=paddleocr_api' \
  -p 3306:3306 \
  -v mysql_data:/var/lib/mysql \
  mysql:8.0

# 部署 Redis
docker run -d \
  --name paddleocr-redis \
  -p 6379:6379 \
  -v redis_data:/data \
  redis:7-alpine
```

#### 步骤 4：部署 API（宿主机）

```bash
cd /opt/paddleocr-api

# 安装系统依赖
sudo apt install -y python3.12-venv python3-pip libgl1 libglib2.0-0

# 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 安装 Python 依赖（使用清华源）
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 创建 .env 文件
cat > .env << 'EOF'
APP_NAME=PaddleOCR API
DEBUG=false
HOST=0.0.0.0
PORT=8000
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=!qwert
DB_NAME=paddleocr_api
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
OCR_LANG=ch
OCR_USE_GPU=false
EOF

# 启动 API（后台运行）
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/api.log 2>&1 &
```

#### 步骤 5：验证部署

```bash
# 检查服务状态
docker ps | grep -E "mysql|redis"
ps aux | grep uvicorn

# 测试 API
curl http://localhost:8000/api/ocr/health

# 查看日志
tail -f /tmp/api.log
```

### 11.4 服务管理命令

```bash
# 启动所有服务
docker start paddleocr-mysql paddleocr-redis
cd /opt/paddleocr-api
source venv/bin/activate
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/api.log 2>&1 &

# 停止所有服务
pkill -f uvicorn
docker stop paddleocr-mysql paddleocr-redis

# 重启 API
pkill -f uvicorn
cd /opt/paddleocr-api
source venv/bin/activate
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/api.log 2>&1 &

# 查看 API 日志
tail -f /tmp/api.log

# 查看 MySQL 日志
docker logs -f paddleocr-mysql

# 进入 MySQL 容器
docker exec -it paddleocr-mysql bash
```

### 11.5 关键经验总结

| 问题 | 解决方案 | 经验 |
|------|----------|------|
| 镜像拉取失败 | 手动导入 | 严重受限网络无法使用镜像加速器 |
| 构建失败 | 宿主机部署 | Docker 内网络比宿主机更受限 |
| libGL 缺失 | 安装系统依赖 | Ubuntu 24.04 使用 `libgl1` 而非 `libgl1-mesa-glx` |
| 密码变量清空 | 单引号包裹 | `!` 是 shell 特殊字符，必须转义或使用单引号 |
| pip 安装慢 | 使用国内源 | 清华源 `https://pypi.tuna.tsinghua.edu.cn/simple` |

### 11.6 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| API 服务 | http://192.168.124.134:8000 | 主要接口 |
| API 文档 | http://192.168.124.134:8000/docs | Swagger UI |
| ReDoc | http://192.168.124.134:8000/redoc | 备用文档 |
| MySQL | localhost:3306 | 仅内部访问 |
| Redis | localhost:6379 | 仅内部访问 |

### 11.7 故障排查

```bash
# 检查服务状态
docker ps
ps aux | grep uvicorn

# 检查端口占用
netstat -tlnp | grep -E "3306|6379|8000"

# 测试数据库连接
docker exec paddleocr-mysql mysql -u root -p'!qwert' -e "SHOW DATABASES;"

# 测试 Redis
docker exec paddleocr-redis redis-cli ping

# 测试 API
curl http://localhost:8000/api/ocr/health

# 查看详细错误
tail -50 /tmp/api.log
```

---

## 12. 快速部署脚本（混合部署）

基于以上经验，提供一键部署脚本：

```bash
#!/bin/bash
# hybrid-deploy.sh - 网络受限环境混合部署脚本

set -e

echo "=== PaddleOCR API 混合部署脚本 ==="

# 检查是否已导入镜像
echo "1. 检查 Docker 镜像..."
if ! docker images | grep -q "mysql.*8.0"; then
    echo "错误：未找到 MySQL 镜像，请先导入："
    echo "docker load -i /tmp/paddleocr-images.tar"
    exit 1
fi

if ! docker images | grep -q "redis.*7-alpine"; then
    echo "错误：未找到 Redis 镜像，请先导入："
    echo "docker load -i /tmp/paddleocr-images.tar"
    exit 1
fi
echo "✓ 镜像检查完成"

# 部署 MySQL
echo "2. 部署 MySQL..."
docker run -d \
  --name paddleocr-mysql \
  --restart unless-stopped \
  -e 'MYSQL_ROOT_PASSWORD=!qwert' \
  -e 'MYSQL_DATABASE=paddleocr_api' \
  -p 3306:3306 \
  -v mysql_data:/var/lib/mysql \
  mysql:8.0

# 等待 MySQL 启动
echo "等待 MySQL 启动..."
sleep 10

# 部署 Redis
echo "3. 部署 Redis..."
docker run -d \
  --name paddleocr-redis \
  --restart unless-stopped \
  -p 6379:6379 \
  -v redis_data:/data \
  redis:7-alpine

# 安装系统依赖
echo "4. 安装系统依赖..."
sudo apt install -y python3.12-venv python3-pip libgl1 libglib2.0-0 libsm6 libxext6 libxrender1 libgomp1

# 创建虚拟环境
echo "5. 创建虚拟环境..."
cd /opt/paddleocr-api
[ -d venv ] || python3 -m venv venv
source venv/bin/activate

# 安装 Python 依赖
echo "6. 安装 Python 依赖..."
pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

# 创建 .env 文件
echo "7. 配置环境变量..."
cat > .env << 'EOF'
APP_NAME=PaddleOCR API
DEBUG=false
LOG_LEVEL=INFO
HOST=0.0.0.0
PORT=8000
DB_HOST=127.0.0.1
DB_PORT=3306
DB_USER=root
DB_PASSWORD=!qwert
DB_NAME=paddleocr_api
REDIS_HOST=127.0.0.1
REDIS_PORT=6379
OCR_LANG=ch
OCR_USE_GPU=false
EOF

# 启动 API
echo "8. 启动 API 服务..."
pkill -f uvicorn || true
nohup python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 > /tmp/api.log 2>&1 &

# 等待 API 启动
sleep 5

# 验证部署
echo "9. 验证部署..."
echo "MySQL: $(docker ps | grep paddleocr-mysql | grep -q Up && echo '✓ Running' || echo '✗ Failed')"
echo "Redis: $(docker ps | grep paddleocr-redis | grep -q Up && echo '✓ Running' || echo '✗ Failed')"
echo "API: $(curl -s http://localhost:8000/api/ocr/health > /dev/null && echo '✓ Running' || echo '✗ Failed')"

echo ""
echo "=== 部署完成 ==="
echo "API: http://$(hostname -I | awk '{print $1}'):8000"
echo "文档: http://$(hostname -I | awk '{print $1}'):8000/docs"
echo ""
echo "日志位置："
echo "  API: tail -f /tmp/api.log"
echo "  MySQL: docker logs -f paddleocr-mysql"
echo "  Redis: docker logs -f paddleocr-redis"
```

使用方法：
```bash
# 1. 导入镜像
docker load -i /tmp/paddleocr-images.tar

# 2. 运行部署脚本
bash hybrid-deploy.sh
```

---

## 附录 A：完整部署流程对比

| 方案 | 适用场景 | 优点 | 缺点 |
|------|----------|------|------|
| **纯 Docker** | 网络正常 | 统一管理，易于维护 | 需要构建镜像 |
| **混合部署** | 网络受限 | 避免构建问题 | 管理分离 |
| **手动导入** | 完全离线 | 不依赖网络 | 需要提前准备镜像 |
| **本地构建** | 无法在线构建 | 在有网络环境构建 | 需要传输大文件 |

---

## 附录 B：常见问题快速索引

| 问题 | 章节 |
|------|------|
| Docker Compose 版本问题 | [第1节](#1-docker-compose-版本问题) |
| .env 文件缺失 | [第2节](#2-环境变量文件缺失) |
| 镜像拉取失败 | [第3节](#3-docker-镜像拉取失败) |
| 国内镜像源配置 | [第4节](#4-国内镜像源配置) |
| 容器构建失败 | [第5节](#5-容器构建失败) |
| 网络环境诊断 | [第6节](#6-网络环境诊断) |
| 网络受限实战案例 | [第11节](#11-实战案例网络受限环境部署-ubuntu-2404) |
- Docker Compose 版本：`docker compose version`
- 完整的错误信息
- 网络诊断结果
