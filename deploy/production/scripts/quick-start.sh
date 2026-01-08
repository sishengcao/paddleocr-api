#!/bin/bash

# ===================================================================
# 快速部署脚本 - PaddleOCR API 生产环境
# 域名: sishengcao.fun
# ===================================================================

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为 root 用户
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "请使用 root 用户或 sudo 运行此脚本"
        exit 1
    fi
}

# 检查系统
check_system() {
    log_info "检查系统环境..."

    if [ ! -f /etc/os-release ]; then
        log_error "无法检测操作系统"
        exit 1
    fi

    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID

    log_info "检测到操作系统: $OS $VERSION"

    if [[ "$OS" != "ubuntu" ]]; then
        log_warn "此脚本专为 Ubuntu 设计，在其他系统上可能无法正常工作"
    fi

    log_info "系统检查完成"
}

# 更新系统
update_system() {
    log_info "更新系统软件包..."
    apt update
    apt upgrade -y
    apt install -y curl wget git vim ufw fail2ban ca-certificates gnupg lsb-release
    log_info "系统更新完成"
}

# 安装 Docker
install_docker() {
    if command -v docker &> /dev/null; then
        log_info "Docker 已安装，跳过"
        return
    fi

    log_info "安装 Docker..."

    # 使用 Docker 官方脚本安装
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh

    # 启动 Docker
    systemctl start docker
    systemctl enable docker

    # 验证安装
    docker --version

    log_info "Docker 安装完成"
}

# 安装 Docker Compose
install_docker_compose() {
    if docker compose version &> /dev/null; then
        log_info "Docker Compose 已安装，跳过"
        return
    fi

    log_info "Docker Compose 通常随 Docker 一起安装"
    log_info "验证 Docker Compose..."

    docker compose version

    log_info "Docker Compose 准备就绪"
}

# 配置防火墙
configure_firewall() {
    log_info "配置防火墙..."

    # 允许 SSH
    ufw allow 22/tcp

    # 允许 HTTP/HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp

    # 允许 Portainer（可选）
    read -p "是否允许 Portainer 外网访问 (9000端口)? (y/N): " allow_portainer
    if [[ "$allow_portainer" =~ ^[Yy]$ ]]; then
        ufw allow 9000/tcp
        log_info "已允许 Portainer 外网访问"
    fi

    # 启用防火墙
    ufw --force enable

    # 显示状态
    ufw status

    log_info "防火墙配置完成"
}

# 创建项目目录
create_project_dirs() {
    log_info "创建项目目录..."

    PROJECT_DIR="/opt/sishengcao"
    mkdir -p $PROJECT_DIR
    cd $PROJECT_DIR

    # 创建子目录
    mkdir -p {nginx,ssl,java-app,python-api,vue-app,mysql,redis,portainer,certbot,logs}
    mkdir -p nginx/conf.d
    mkdir -p mysql/init
    mkdir -p logs/{nginx,java-app,python-api,vue-app}
    mkdir -p certbot/{www,conf}
    mkdir -p backups

    log_info "项目目录创建完成: $PROJECT_DIR"
}

# 配置环境变量
configure_env() {
    log_info "配置环境变量..."

    read -p "输入您的域名 [sishengcao.fun]: " domain
    domain=${domain:-sishengcao.fun}

    read -p "输入您的邮箱 (用于SSL证书): " email
    if [ -z "$email" ]; then
        log_error "邮箱不能为空"
        exit 1
    fi

    read -sp "输入 MySQL root 密码: " mysql_root_password
    echo
    if [ -z "$mysql_root_password" ]; then
        log_error "MySQL root 密码不能为空"
        exit 1
    fi

    read -sp "输入 MySQL 用户密码 (ocruser): " mysql_password
    echo
    if [ -z "$mysql_password" ]; then
        log_error "MySQL 用户密码不能为空"
        exit 1
    fi

    read -sp "输入 Redis 密码: " redis_password
    echo
    if [ -z "$redis_password" ]; then
        log_error "Redis 密码不能为空"
        exit 1
    fi

    # 创建 .env 文件
    cat > .env << EOF
# ============== 域名配置 ==============
DOMAIN_NAME=$domain
API_SUBDOMAIN=api
APP_SUBDOMAIN=app
PORTAINER_SUBDOMAIN=portainer

# ============== 时区配置 ==============
TZ=Asia/Shanghai

# ============== MySQL 配置 ==============
MYSQL_ROOT_PASSWORD=$mysql_root_password
MYSQL_DATABASE=paddleocr_api
MYSQL_USER=ocruser
MYSQL_PASSWORD=$mysql_password

# ============== Redis 配置 ==============
REDIS_PASSWORD=$redis_password

# ============== PaddleOCR API 配置 ==============
OCR_API_WORKERS=2

# ============== Java 应用配置 ==============
JAVA_APP_IMAGE=your-java-app:latest
JAVA_APP_JVM_OPTS=-Xms512m -Xmx1024m

# ============== Vue 前端配置 ==============
VUE_APP_IMAGE=your-vue-app:latest

# ============== Email 配置 ==============
LETSENCRYPT_EMAIL=$email
EOF

    chmod 600 .env
    log_info "环境变量配置完成"
}

# 等待 DNS 生效
wait_for_dns() {
    log_info "等待 DNS 生效..."

    domain=$(grep DOMAIN_NAME .env | cut -d '=' -f2)

    log_warn "请确保以下 DNS 记录已配置:"
    echo "  A    $domain         -> [服务器IP]"
    echo "  A    api.$domain     -> [服务器IP]"
    echo "  A    app.$domain     -> [服务器IP]"
    echo "  A    www.$domain     -> [服务器IP]"

    read -p "DNS 是否已配置? (y/N): " dns_ready
    if [[ ! "$dns_ready" =~ ^[Yy]$ ]]; then
        log_error "请先配置 DNS 记录后再继续"
        exit 1
    fi

    log_info "等待 DNS 解析生效..."
    for i in {1..30}; do
        if nslookup $domain &> /dev/null; then
            log_info "DNS 解析已生效"
            return
        fi
        echo -n "."
        sleep 2
    done

    log_warn "DNS 可能尚未完全生效，但将继续..."
}

# 申请 SSL 证书
obtain_ssl_certificates() {
    log_info "申请 SSL 证书..."

    # 创建临时 Nginx 配置
    cat > docker-compose.temp.yml << 'EOF'
version: '3.8'

services:
  nginx:
    image: nginx:alpine
    container_name: nginx-temp
    ports:
      - "80:80"
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./nginx/temp.conf:/etc/nginx/conf.d/default.conf:ro

  certbot:
    image: certbot/certbot:latest
    container_name: certbot-temp
    volumes:
      - ./certbot/www:/var/www/certbot
      - ./certbot/conf:/etc/letsencrypt
EOF

    # 创建临时 Nginx 配置
    domain=$(grep DOMAIN_NAME .env | cut -d '=' -f2)
    cat > nginx/temp.conf << EOF
server {
    listen 80;
    server_name $domain www.$domain api.$domain app.$domain portainer.$domain;

    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
}
EOF

    # 启动临时容器
    docker compose -f docker-compose.temp.yml up -d

    # 等待 Nginx 启动
    sleep 5

    # 申请证书
    email=$(grep LETSENCRYPT_EMAIL .env | cut -d '=' -f2)

    docker compose -f docker-compose.temp.yml run --rm certbot certonly --webroot \
        --webroot-path=/var/www/certbot \
        --email $email \
        --agree-tos \
        --no-eff-email \
        -d $domain \
        -d www.$domain \
        -d api.$domain \
        -d app.$domain \
        -d portainer.$domain

    # 创建符号链接
    mkdir -p nginx/ssl
    ln -sf ../certbot/conf/live/$domain nginx/ssl/live

    # 清理临时容器
    docker compose -f docker-compose.temp.yml down
    rm -f docker-compose.temp.yml nginx/temp.conf

    log_info "SSL 证书申请完成"
}

# 部署服务
deploy_services() {
    log_info "部署服务..."

    # 检查 docker-compose.yml 是否存在
    if [ ! -f docker-compose.yml ]; then
        log_error "docker-compose.yml 不存在，请先创建"
        log_info "您可以从 GitHub 获取配置文件"
        exit 1
    fi

    # 拉取镜像
    log_info "拉取 Docker 镜像..."
    docker compose pull

    # 启动服务
    log_info "启动服务..."
    docker compose up -d

    # 等待服务启动
    log_info "等待服务启动..."
    sleep 10

    # 显示状态
    docker compose ps

    log_info "服务部署完成"
}

# 配置自动备份
setup_backup() {
    log_info "配置自动备份..."

    # 创建备份脚本
    cat > backup.sh << 'EOF'
#!/bin/bash

PROJECT_DIR="/opt/sishengcao"
BACKUP_DIR="$PROJECT_DIR/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# 加载环境变量
source $PROJECT_DIR/.env

mkdir -p $BACKUP_DIR

# 备份 MySQL
docker compose exec -T mysql mysqldump -u root -p${MYSQL_ROOT_PASSWORD} \
    --all-databases --single-transaction --quick --lock-tables=false \
    > $BACKUP_DIR/mysql_$DATE.sql

# 备份 Redis
docker compose exec -T redis redis-cli -a ${REDIS_PASSWORD} --rdb - > $BACKUP_DIR/redis_$DATE.rdb

# 压缩备份
tar -czf $BACKUP_DIR/backup_$DATE.tar.gz -C $BACKUP_DIR mysql_$DATE.sql redis_$DATE.rdb
rm -f $BACKUP_DIR/mysql_$DATE.sql $BACKUP_DIR/redis_$DATE.rdb

# 删除7天前的备份
find $BACKUP_DIR -name "backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/backup_$DATE.tar.gz"
EOF

    chmod +x backup.sh

    # 添加定时任务
    (crontab -l 2>/dev/null | grep -v "backup.sh"; echo "0 3 * * * $PROJECT_DIR/backup.sh >> $PROJECT_DIR/logs/backup.log 2>&1") | crontab -

    log_info "自动备份配置完成"
}

# 显示部署信息
show_deployment_info() {
    log_info "=========================================="
    log_info "部署完成！"
    log_info "=========================================="
    echo
    echo "服务访问地址:"
    echo "  前端:     https://$(grep DOMAIN_NAME .env | cut -d '=' -f2)"
    echo "  API:      https://api.$(grep DOMAIN_NAME .env | cut -d '=' -f2)"
    echo "  API 文档: https://api.$(grep DOMAIN_NAME .env | cut -d '=' -f2)/docs"
    echo "  Java应用: https://app.$(grep DOMAIN_NAME .env | cut -d '=' -f2)"
    echo "  Portainer: http://$(curl -s ifconfig.me):9000"
    echo
    echo "常用命令:"
    echo "  查看日志:   docker compose logs -f"
    echo "  重启服务:   docker compose restart"
    echo "  停止服务:   docker compose down"
    echo "  启动服务:   docker compose up -d"
    echo "  查看状态:   docker compose ps"
    echo
    log_info "=========================================="
}

# 主函数
main() {
    log_info "开始部署 PaddleOCR API 生产环境..."

    check_root
    check_system
    update_system
    install_docker
    install_docker_compose
    configure_firewall
    create_project_dirs
    configure_env
    wait_for_dns
    obtain_ssl_certificates
    deploy_services
    setup_backup
    show_deployment_info

    log_info "部署脚本执行完成！"
}

# 执行主函数
main "$@"
