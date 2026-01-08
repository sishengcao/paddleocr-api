#!/bin/bash

# ===================================================================
# 更新部署脚本 - 更新现有服务
# ===================================================================

set -e

# 颜色定义
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# 项目目录
PROJECT_DIR="/opt/sishengcao"
cd $PROJECT_DIR

# 备份当前配置
log_info "备份当前配置..."
backup_dir="backups/pre-update-$(date +%Y%m%d_%H%M%S)"
mkdir -p $backup_dir
cp -r nginx $backup_dir/
cp .env $backup_dir/
cp docker-compose.yml $backup_dir/

# 拉取最新镜像
log_info "拉取最新 Docker 镜像..."
docker compose pull

# 停止服务
log_info "停止当前服务..."
docker compose down

# 启动服务
log_info "启动更新后的服务..."
docker compose up -d

# 等待服务就绪
log_info "等待服务启动..."
sleep 15

# 检查服务状态
docker compose ps

# 清理旧镜像
log_info "清理旧的 Docker 镜像..."
docker image prune -af --filter "until=72h"

log_info "更新完成！"
