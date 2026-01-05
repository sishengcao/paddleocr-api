# 生产环境部署指南 - Docker Compose + Portainer

完整部署方案：从零开始部署 Java、Python (PaddleOCR API)、Vue 项目到 Ubuntu 服务器

---

## 服务器信息

- **操作系统**: Ubuntu 22.04 / 24.04
- **域名**: sishengcao.fun
- **部署方式**: Docker Compose + Portainer
- **SSL证书**: Let's Encrypt (自动续期)

---

## 部署架构

```
┌─────────────────────────────────────────────────────────────┐
│                    Ubuntu 服务器                              │
│  IP: [您的服务器IP]                                          │
│  域名: sishengcao.fun                                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │              Nginx (80/443)                           │   │
│  │  - SSL 终结 (Let's Encrypt)                           │   │
│  │  - 反向代理                                            │   │
│  │  - 负载均衡                                            │   │
│  └──────────────────────────────────────────────────────┘   │
│                           │                                  │
│  ┌────────────────────────┼──────────────────────────────┐  │
│  │                        │                              │  │
│  ▼                        ▼                              ▼  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Java App     │  │ Python API   │  │ Vue Frontend │      │
│  │ :8080        │  │ :8000        │  │ :3000        │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           MySQL + Redis (数据层)                      │   │
│  │           MySQL:3306  Redis:6379                     │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌──────────────────────────────────────────────────────┐   │
│  │           Portainer (9000)                            │   │
│  │           Web管理界面                                  │   │
│  └──────────────────────────────────────────────────────┘   │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

---

## 第一步：服务器初始化

### 1.1 连接到服务器

```bash
# 使用 SSH 连接（替换为您的服务器IP）
ssh root@your-server-ip

# 或者使用密钥（如果有）
ssh -i /path/to/key.pem ubuntu@your-server-ip
```

### 1.2 更新系统

```bash
# 更新软件包列表
apt update && apt upgrade -y

# 安装基础工具
apt install -y curl wget git vim ufw fail2ban
```

### 1.3 配置防火墙

```bash
# 允许 SSH（确保不会锁死自己）
ufw allow 22/tcp

# 允许 HTTP 和 HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# 允许 Portainer（可选，建议通过 VPN 或内网访问）
ufw allow 9000/tcp

# 启用防火墙
ufw enable

# 查看状态
ufw status
```

---

## 第二步：安装 Docker 和 Docker Compose

### 2.1 安装 Docker

```bash
# 自动安装 Docker（推荐）
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh

# 启动 Docker 服务
systemctl start docker
systemctl enable docker

# 验证安装
docker --version
# 应该输出: Docker version 27.x.x 或类似版本
```

### 2.2 配置 Docker 用户（可选但推荐）

```bash
# 创建部署用户（如果还没有）
useradd -m -s /bin/bash deploy
usermod -aG docker deploy

# 切换到 deploy 用户
su - deploy
```

### 2.3 安装 Docker Compose

```bash
# Docker Compose 插件通常随 Docker 一起安装
# 验证安装
docker compose version
# 应该输出: Docker Compose version v2.x.x
```

---

## 第三步：域名和 DNS 配置

### 3.1 配置 DNS 记录

在您的域名注册商（阿里云/腾讯云/Cloudflare等）添加以下记录：

| 类型 | 主机记录 | 记录值 | TTL |
|------|----------|--------|-----|
| A | @ | [您的服务器IP] | 600 |
| A | www | [您的服务器IP] | 600 |
| A | api | [您的服务器IP] | 600 |
| A | app | [您的服务器IP] | 600 |

**访问地址规划**：
- `sishengcao.fun` 或 `www.sishengcao.fun` → Vue 前端
- `api.sishengcao.fun` → Python PaddleOCR API
- `app.sishengcao.fun` → Java 后端应用
- `portainer.sishengcao.fun` → Portainer 管理界面（可选）

### 3.2 验证 DNS 解析

```bash
# 等待 5-10 分钟后验证
ping sishengcao.fun
ping api.sishengcao.fun
```

---

## 第四步：创建项目目录结构

```bash
# 创建项目根目录
mkdir -p /opt/sishengcao
cd /opt/sishengcao

# 创建子目录
mkdir -p {nginx,ssl,java-app,python-api,vue-app,mysql,redis,portainer,logs}

# 查看目录结构
tree -L 1
# 或使用 ls
ls -la
```

目录结构：
```
/opt/sishengcao/
├── docker-compose.yml          # 主编排文件
├── .env                        # 环境变量
├── nginx/                      # Nginx 配置
│   ├── nginx.conf
│   ├── conf.d/
│   │   ├── api.conf
│   │   ├── app.conf
│   │   └── frontend.conf
│   └── ssl/                    # SSL 证书（自动生成）
├── java-app/                   # Java 应用配置
│   ├── Dockerfile
│   └── app.jar
├── python-api/                 # Python API 配置
│   └── (代码已打包在 Docker 镜像中)
├── vue-app/                    # Vue 前端配置
│   ├── Dockerfile
│   └── dist/                   # 构建产物
├── mysql/                      # MySQL 数据持久化
│   └── data/
├── redis/                      # Redis 数据持久化
│   └── data/
├── portainer/                  # Portainer 数据
│   └── data/
└── logs/                       # 日志目录
    ├── nginx/
    ├── java-app/
    ├── python-api/
    └── vue-app/
```

---

## 第五步：创建配置文件

### 5.1 创建环境变量文件

```bash
cd /opt/sishengcao

cat > .env << 'EOF'
# ============== 域名配置 ==============
DOMAIN_NAME=sishengcao.fun
API_SUBDOMAIN=api
APP_SUBDOMAIN=app
PORTAINER_SUBDOMAIN=portainer

# ============== 服务器配置 ==============
SERVER_IP=$(curl -s ifconfig.me)
TZ=Asia/Shanghai

# ============== MySQL 配置 ==============
MYSQL_ROOT_PASSWORD=your_strong_root_password_here
MYSQL_DATABASE=paddleocr_api
MYSQL_USER=ocruser
MYSQL_PASSWORD=your_strong_mysql_password_here

# ============== Redis 配置 ==============
REDIS_PASSWORD=your_strong_redis_password_here

# ============== PaddleOCR API 配置 ==============
OCR_API_PORT=8000
OCR_API_WORKERS=2

# ============== Java 应用配置 ==============
JAVA_APP_PORT=8080
JAVA_APP_JVM_OPTS=-Xms512m -Xmx1024m

# ============== Vue 前端配置 ==============
VUE_APP_PORT=3000

# ============== Email 配置 (用于 Let's Encrypt) ==============
LETSENCRYPT_EMAIL=your-email@example.com

EOF

# 修改权限
chmod 600 .env
```

**⚠️ 重要：请修改以下密码**：
- `MYSQL_ROOT_PASSWORD`: MySQL root 密码
- `MYSQL_PASSWORD`: MySQL 应用用户密码
- `REDIS_PASSWORD`: Redis 密码
- `LETSENCRYPT_EMAIL`: 您的邮箱（用于 SSL 证书）

---

## 第六步：创建 Nginx 配置

### 6.1 创建主 Nginx 配置

```bash
cd /opt/sishengcao

cat > nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log warn;
pid /var/run/nginx.pid;

events {
    worker_connections 1024;
    use epoll;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # 日志格式
    log_format main '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

    access_log /var/log/nginx/access.log main;

    # 性能优化
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    client_max_body_size 100M;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml text/javascript
               application/json application/javascript application/xml+rss
               application/rss+xml font/truetype font/opentype
               application/vnd.ms-fontobject image/svg+xml;

    # SSL 配置
    ssl_session_timeout 1d;
    ssl_session_cache shared:SSL:50m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384';
    ssl_prefer_server_ciphers on;

    # 包含站点配置
    include /etc/nginx/conf.d/*.conf;
}
EOF
```

### 6.2 创建 API 子域名配置

```bash
mkdir -p nginx/conf.d

cat > nginx/conf.d/api.conf << 'EOF'
upstream python_api {
    server python-api:8000;
}

server {
    listen 80;
    listen [::]:80;
    server_name api.sishengcao.fun;

    # Let's Encrypt 验证路径
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name api.sishengcao.fun;

    # SSL 证书（certbot 会自动配置）
    ssl_certificate /etc/nginx/ssl/live/api.sishengcao.fun/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/api.sishengcao.fun/privkey.pem;

    # SSL 安全配置
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;

    # 日志
    access_log /var/log/nginx/api_access.log;
    error_log /var/log/nginx/api_error.log;

    # API 代理
    location / {
        proxy_pass http://python_api;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;

        # 批量扫描大文件上传
        client_max_body_size 100M;
    }

    # API 文档
    location /docs {
        proxy_pass http://python_api/docs;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location /redoc {
        proxy_pass http://python_api/redoc;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    # WebSocket 支持（如果需要）
    location /ws {
        proxy_pass http://python_api/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF
```

### 6.3 创建 Java 应用配置

```bash
cat > nginx/conf.d/app.conf << 'EOF'
upstream java_app {
    server java-app:8080;
}

server {
    listen 80;
    listen [::]:80;
    server_name app.sishengcao.fun;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name app.sishengcao.fun;

    ssl_certificate /etc/nginx/ssl/live/app.sishengcao.fun/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/app.sishengcao.fun/privkey.pem;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;

    access_log /var/log/nginx/app_access.log;
    error_log /var/log/nginx/app_error.log;

    location / {
        proxy_pass http://java_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 300s;
    }
}
EOF
```

### 6.4 创建 Vue 前端配置

```bash
cat > nginx/conf.d/frontend.conf << 'EOF'
server {
    listen 80;
    listen [::]:80;
    server_name sishengcao.fun www.sishengcao.fun;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name sishengcao.fun www.sishengcao.fun;

    ssl_certificate /etc/nginx/ssl/live/sishengcao.fun/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/sishengcao.fun/privkey.pem;

    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;

    access_log /var/log/nginx/frontend_access.log;
    error_log /var/log/nginx/frontend_error.log;

    root /usr/share/nginx/html;
    index index.html;

    # Vue Router history 模式支持
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存
    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # API 代理（如果前端需要直接调用）
    location /api/ {
        proxy_pass http://python-api:8000/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF
```

### 6.5 创建 Portainer 配置（可选）

```bash
cat > nginx/conf.d/portainer.conf << 'EOF'
upstream portainer {
    server portainer:9000;
}

server {
    listen 80;
    listen [::]:80;
    server_name portainer.sishengcao.fun;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }

    location / {
        return 301 https://$server_name$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name portainer.sishengcao.fun;

    ssl_certificate /etc/nginx/ssl/live/portainer.sishengcao.fun/fullchain.pem;
    ssl_certificate_key /etc/nginx/ssl/live/portainer.sishengcao.fun/privkey.pem;

    add_header Strict-Transport-Security "max-age=31536000" always;

    access_log /var/log/nginx/portainer_access.log;
    error_log /var/log/nginx/portainer_error.log;

    location / {
        proxy_pass http://portainer;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF
```

---

## 第七步：创建 Docker Compose 配置

```bash
cd /opt/sishengcao

cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  # ============== Nginx 反向代理 ==============
  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx/nginx.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/conf.d:/etc/nginx/conf.d:ro
      - ./nginx/ssl:/etc/nginx/ssl:ro
      - ./certbot/www:/var/www/certbot:ro
      - ./logs/nginx:/var/log/nginx
    depends_on:
      - python-api
      - java-app
      - vue-app
    networks:
      - app-network

  # ============== Certbot SSL 证书自动续期 ==============
  certbot:
    image: certbot/certbot:latest
    container_name: certbot
    restart: unless-stopped
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
    entrypoint: "/bin/sh -c 'trap exit TERM; while :; do certbot renew; sleep 12h & wait $${!}; done;'"
    networks:
      - app-network

  # ============== PaddleOCR Python API ==============
  python-api:
    image: ghcr.io/sishengcao/paddleocr-api:latest
    container_name: paddleocr-api
    restart: unless-stopped
    environment:
      - MYSQL_HOST=mysql
      - MYSQL_PORT=3306
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - OCR_API_WORKERS=${OCR_API_WORKERS:-2}
    volumes:
      - ./logs/python-api:/app/logs
      - ./python-api/data:/app/data
    depends_on:
      - mysql
      - redis
    networks:
      - app-network
    # 健康检查
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s

  # ============== Python API Celery Worker ==============
  celery-worker:
    image: ghcr.io/sishengcao/paddleocr-api:latest
    container_name: celery-worker
    restart: unless-stopped
    command: celery -A app.workers.celery_worker worker --loglevel=info --logfile=/app/logs/celery.log
    environment:
      - MYSQL_HOST=mysql
      - MYSQL_PORT=3306
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - REDIS_HOST=redis
      - REDIS_PORT=6379
      - REDIS_PASSWORD=${REDIS_PASSWORD}
    volumes:
      - ./logs/python-api:/app/logs
      - ./python-api/data:/app/data
    depends_on:
      - mysql
      - redis
    networks:
      - app-network

  # ============== Java 应用 ==============
  java-app:
    image: your-java-app:latest
    container_name: java-app
    restart: unless-stopped
    environment:
      - SPRING_PROFILES_ACTIVE=production
      - SPRING_DATASOURCE_URL=jdbc:mysql://mysql:3306/${MYSQL_DATABASE}
      - SPRING_DATASOURCE_USERNAME=${MYSQL_USER}
      - SPRING_DATASOURCE_PASSWORD=${MYSQL_PASSWORD}
      - JAVA_OPTS=${JAVA_APP_JVM_OPTS:--Xms512m -Xmx1024m}
    volumes:
      - ./logs/java-app:/app/logs
    depends_on:
      - mysql
      - redis
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health"]
      interval: 30s
      timeout: 10s
      retries: 3

  # ============== Vue 前端 ==============
  vue-app:
    image: your-vue-app:latest
    container_name: vue-app
    restart: unless-stopped
    volumes:
      - ./logs/vue-app:/var/log/nginx
    networks:
      - app-network

  # ============== MySQL 数据库 ==============
  mysql:
    image: mysql:8.0
    container_name: mysql-db
    restart: unless-stopped
    environment:
      - MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
      - MYSQL_DATABASE=${MYSQL_DATABASE}
      - MYSQL_USER=${MYSQL_USER}
      - MYSQL_PASSWORD=${MYSQL_PASSWORD}
      - TZ=${TZ:-Asia/Shanghai}
    volumes:
      - ./mysql/data:/var/lib/mysql
      - ./mysql/init:/docker-entrypoint-initdb.d:ro
    ports:
      - "127.0.0.1:3306:3306"
    networks:
      - app-network
    command:
      - --character-set-server=utf8mb4
      - --collation-server=utf8mb4_unicode_ci
      - --default-authentication-plugin=mysql_native_password

  # ============== Redis ==============
  redis:
    image: redis:7-alpine
    container_name: redis-cache
    restart: unless-stopped
    command: redis-server --requirepass ${REDIS_PASSWORD} --appendonly yes
    volumes:
      - ./redis/data:/data
    ports:
      - "127.0.0.1:6379:6379"
    networks:
      - app-network
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 10s
      timeout: 3s
      retries: 3

  # ============== Portainer 管理界面 ==============
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    command: -H unix:///var/run/docker.sock
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - ./portainer/data:/data
    ports:
      - "9000:9000"
    networks:
      - app-network

networks:
  app-network:
    driver: bridge

volumes:
  mysql-data:
  redis-data:
  portainer-data:
EOF
```

---

## 第八步：初始化数据库

```bash
# 创建数据库初始化脚本目录
mkdir -p mysql/init

# 从项目中复制数据库脚本
cd /opt/sishengcao

# 如果您有项目访问权限，执行：
# git clone https://github.com/sishengcao/paddleocr-api.git temp
# cp temp/migrations/*.sql mysql/init/
# rm -rf temp

# 或者手动创建初始化脚本
cat > mysql/init/001_init.sql << 'EOF'
-- 创建数据库
CREATE DATABASE IF NOT EXISTS paddleocr_api CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE paddleocr_api;

-- 导入表结构
-- 请将完整的 migrations/001_initial_schema.sql 内容粘贴到这里
EOF
```

**注意**：您需要从项目中复制 `migrations/001_initial_schema.sql` 的内容到初始化脚本中。

---

## 第九步：申请 SSL 证书

### 9.1 首次申请证书

```bash
cd /opt/sishengcao

# 创建临时 Nginx 配置（用于证书验证）
cat > docker-compose.temp.yml << 'EOF'
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./nginx/temp.conf:/etc/nginx/conf.d/default.conf:ro

  certbot:
    image: certbot/certbot:latest
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
EOF

# 创建临时 Nginx 配置
cat > nginx/temp.conf << 'EOF'
server {
    listen 80;
    server_name sishengcao.fun www.sishengcao.fun api.sishengcao.fun app.sishengcao.fun portainer.sishengcao.fun;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
}
EOF

# 启动临时容器
docker compose -f docker-compose.temp.yml up -d

# 等待 DNS 生效（5-10分钟）
# 然后申请证书
docker compose -f docker-compose.temp.yml run --rm certbot certonly --webroot \
  --webroot-path=/var/www/certbot \
  --email your-email@example.com \
  --agree-tos \
  --no-eff-email \
  -d sishengcao.fun \
  -d www.sishengcao.fun \
  -d api.sishengcao.fun \
  -d app.sishengcao.fun \
  -d portainer.sishengcao.fun

# 创建证书符号链接
mkdir -p nginx/ssl
ln -s ../certbot/conf/live/sishengcao.fun nginx/ssl/live

# 清理临时容器
docker compose -f docker-compose.temp.yml down
```

### 9.2 配置证书自动续期

```bash
# 测试证书续期
docker compose run --rm certbot certbot renew --dry-run

# 添加续期定时任务
crontab -e

# 添加以下行（每天凌晨2点检查并续期）
0 2 * * * cd /opt/sishengcao && docker compose run --rm certbot certbot renew --quiet && docker compose exec nginx nginx -s reload
```

---

## 第十步：构建和部署应用

### 10.1 准备 Java 应用 Dockerfile

```bash
# 在您的 Java 项目中创建 Dockerfile
cat > java-app/Dockerfile << 'EOF'
FROM openjdk:17-jdk-slim

WORKDIR /app

# 复制 JAR 文件
COPY target/*.jar app.jar

# 暴露端口
EXPOSE 8080

# 启动应用
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
EOF

# 构建镜像（在您的项目目录）
# docker build -t your-java-app:latest .
```

### 10.2 准备 Vue 应用 Dockerfile

```bash
# 在您的 Vue 项目中创建 Dockerfile
cat > vue-app/Dockerfile << 'EOF'
# 构建阶段
FROM node:18-alpine as build-stage

WORKDIR /app

COPY package*.json ./
RUN npm install

COPY . .
RUN npm run build

# 生产阶段
FROM nginx:alpine as production-stage

COPY --from=build-stage /app/dist /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
EOF

# 创建 Vue Nginx 配置
cat > vue-app/nginx.conf << 'EOF'
server {
    listen 80;
    server_name localhost;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
}
EOF
```

### 10.3 启动所有服务

```bash
cd /opt/sishengcao

# 拉取最新镜像
docker compose pull

# 构建自定义镜像（如果有）
# docker compose build java-app
# docker compose build vue-app

# 启动所有服务
docker compose up -d

# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f
```

---

## 第十一步：验证部署

### 11.1 检查服务状态

```bash
# 查看所有容器状态
docker compose ps

# 预期输出：
# NAME                IMAGE                              STATUS
# nginx-proxy         nginx:alpine                       Up
# paddleocr-api       ghcr.io/.../paddleocr-api:latest   Up
# celery-worker       ghcr.io/.../paddleocr-api:latest   Up
# java-app            your-java-app:latest               Up
# vue-app             your-vue-app:latest                Up
# mysql-db            mysql:8.0                          Up
# redis-cache         redis:7-alpine                     Up
# portainer           portainer/portainer-ce:latest      Up
```

### 11.2 测试各服务

```bash
# 测试 Nginx
curl -I https://sishengcao.fun

# 测试 API
curl https://api.sishengcao.fun/health

# 测试 Java 应用（如果有健康检查端点）
curl https://app.sishengcao.fun/actuator/health

# 查看 API 文档
# 浏览器访问: https://api.sishengcao.fun/docs
```

### 11.3 访问 Web 界面

| 服务 | URL | 用途 |
|------|-----|------|
| Vue 前端 | https://sishengcao.fun | 用户界面 |
| API 文档 | https://api.sishengcao.fun/docs | Swagger UI |
| API 备用文档 | https://api.sishengcao.fun/redoc | ReDoc |
| Java 应用 | https://app.sishengcao.fun | 后端应用 |
| Portainer | https://portainer.sishengcao.fun | 容器管理 |

---

## 第十二步：日常运维

### 12.1 日志查看

```bash
# 查看所有服务日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f python-api
docker compose logs -f nginx
docker compose logs -f mysql

# 查看最近100行日志
docker compose logs --tail=100 python-api

# 查看日志文件
tail -f logs/nginx/api_access.log
tail -f logs/python-api/app.log
```

### 12.2 服务管理

```bash
# 重启单个服务
docker compose restart python-api

# 重启所有服务
docker compose restart

# 停止所有服务
docker compose down

# 停止并删除数据卷（⚠️ 危险操作）
docker compose down -v

# 更新镜像并重启
docker compose pull && docker compose up -d
```

### 12.3 数据库备份

```bash
# 创建备份脚本
cat > /opt/sishengcao/backup.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/sishengcao/backups"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# 备份 MySQL
docker compose exec -T mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} \
  --all-databases > $BACKUP_DIR/mysql_$DATE.sql

# 备份 Redis
docker compose exec -T redis redis-cli -a ${REDIS_PASSWORD} --rdb \
  > $BACKUP_DIR/redis_$DATE.rdb

# 压缩备份
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz $BACKUP_DIR/*_$DATE.*

# 删除7天前的备份
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/backup_$DATE.tar.gz"
EOF

chmod +x /opt/sishengcao/backup.sh

# 添加定时备份（每天凌晨3点）
crontab -e
# 添加: 0 3 * * * /opt/sishengcao/backup.sh
```

### 12.4 监控和告警

```bash
# 安装监控工具（可选）
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v /opt/sishengcao/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

docker run -d \
  --name grafana \
  -p 3001:3000 \
  grafana/grafana
```

---

## 第十三步：Portainer 使用指南

### 13.1 初始化 Portainer

1. 访问 http://your-server-ip:9000
2. 创建管理员密码
3. 选择 "Get Started"（管理本地 Docker）

### 13.2 使用 Portainer 管理

**功能**：
- 📊 可视化容器状态
- 🚀 一键重启/停止服务
- 📈 查看资源使用情况
- 📝 查看容器日志
- 🔧 管理镜像和网络
- 📦 部署堆栈（Stacks）

**常用操作**：
1. 查看容器：点击 "Containers" → 选择容器 → 查看/重启/停止
2. 查看日志：点击容器 → "Logs" 标签
3. 更新镜像：点击 "Images" → 选择镜像 → "Pull" 最新版本

---

## 故障排查

### 问题 1：容器无法启动

```bash
# 查看详细错误
docker compose logs <service-name>

# 检查配置
docker compose config

# 检查端口占用
netstat -tulpn | grep :80
```

### 问题 2：SSL 证书申请失败

```bash
# 检查 DNS 解析
dig sishengcao.fun

# 检查 80 端口是否开放
curl http://sishengcao.fun/.well-known/acme-challenge/test

# 查看 certbot 日志
docker compose logs certbot
```

### 问题 3：数据库连接失败

```bash
# 进入 MySQL 容器
docker compose exec mysql bash

# 测试连接
mysql -u root -p

# 检查网络
docker network inspect sishengcao_app-network
```

### 问题 4：API 返回 502

```bash
# 检查 Python API 服务
docker compose logs python-api

# 检查 Nginx 配置
docker compose exec nginx nginx -t

# 重启 Nginx
docker compose restart nginx
```

---

## 安全建议

1. **定期更新**：
   ```bash
   # 定期更新镜像
   docker compose pull && docker compose up -d
   ```

2. **备份策略**：
   - 数据库：每日备份
   - 配置文件：版本控制（Git）
   - SSL 证书：自动续期

3. **访问控制**：
   - Portainer 仅限内网访问
   - 数据库不对外暴露
   - 使用强密码

4. **监控告警**：
   - 配置磁盘空间监控
   - 配置服务异常告警
   - 定期检查日志

---

## 总结

完成以上步骤后，您将拥有：

✅ 完整的 Docker Compose 部署方案
✅ 自动化的 SSL 证书管理
✅ 多项目（Java/Python/Vue）统一管理
✅ 可视化的 Portainer 管理界面
✅ 完整的日志和备份方案
✅ 生产级的安全配置

**下一步**：
1. 根据实际项目调整配置
2. 配置 CI/CD 自动化部署
3. 设置监控和告警系统

祝部署顺利！
