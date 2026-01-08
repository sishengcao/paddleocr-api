#!/bin/bash
# 远程服务器更新脚本
# 在服务器上执行此脚本

echo "=== PaddleOCR API 服务器更新脚本 ==="
echo ""

# 检查 Docker 镜像配置
echo "检查 Docker 镜像加速配置..."
if ! sudo grep -q "registry-mirrors" /etc/docker/daemon.json 2>/dev/null; then
    echo "配置 Docker 镜像加速器..."
    sudo mkdir -p /etc/docker
    sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": [
    "https://docker.1panel.live",
    "https://docker.xuanyuan.me"
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
    sudo systemctl daemon-reload
    sudo systemctl restart docker
    echo "Docker 镜像加速器配置完成"
else
    echo "Docker 镜像加速器已配置"
fi

cd /opt/paddleocr-api

echo "1. 拉取最新代码..."
sudo git pull origin master

echo "2. 检查 docker-compose.yml 更新..."
head -5 docker-compose.yml

echo ""
echo "3. 检查 .env 文件..."
if [ ! -f .env ]; then
    echo "   .env 文件不存在，正在创建..."
    sudo cp .env.example .env 2>/dev/null || cat > .env << 'EOF'
# 应用配置
APP_NAME=PaddleOCR API
APP_VERSION=2.0.0
DEBUG=false
LOG_LEVEL=INFO

# 服务器配置
HOST=0.0.0.0
PORT=8000
WORKERS=4

# 数据库配置
DB_HOST=mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=!qwert
DB_NAME=paddleocr_api

# Redis 配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=

# OCR 配置
OCR_LANG=ch
OCR_USE_GPU=false
OCR_USE_ANGLE_CLS=true
EOF
    echo "   .env 文件已创建"
else
    echo "   .env 文件已存在"
fi

echo ""
echo "4. 停止现有服务..."
sudo docker compose down 2>/dev/null || sudo docker-compose down

echo ""
echo "5. 启动服务..."
sudo docker compose up -d

echo ""
echo "6. 查看服务状态..."
sudo docker compose ps

echo ""
echo "7. 查看日志..."
sudo docker compose logs --tail=20

echo ""
echo "=== 更新完成 ==="
