#!/bin/bash
# system-purge-safe-script.sh
# 安全系统纯净还原脚本 - 保留root和sishengcao用户，彻底清理开发环境

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# 配置
ROOT_USER="root"
ROOT_PASS="!qwert"
KEEP_USER="sishengcao"
KEEP_USER_PASS="root"
BACKUP_DIR="/tmp/system_backup_$(date +%Y%m%d_%H%M%S)"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查root权限
check_root() {
    if [ $(id -u) -ne 0 ]; then
        log_error "请使用 root 权限运行此脚本"
        echo "使用: sudo bash $0"
        exit 1
    fi
}

# 打印警告信息
print_warning() {
    clear
    echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}                    ⚠  ⚠  ⚠ 危险警告 ⚠  ⚠  ⚠                     ${NC}"
    echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
    echo -e ""
    echo -e "${YELLOW}这个脚本将执行以下操作：${NC}"
    echo -e "${RED}1. 删除所有非系统必要的软件包${NC}"
    echo -e "${RED}2. 清理所有开发环境 (Java, Python, Node.js, Go, Ruby等)${NC}"
    echo -e "${RED}3. 清理所有Docker容器、镜像、网络和数据卷${NC}"
    echo -e "${RED}4. 清理 /home 目录下除root和${KEEP_USER}外的所有用户${NC}"
    echo -e "${RED}5. 清理临时文件、缓存和日志${NC}"
    echo -e "${RED}6. 清理IDE和编辑器配置${NC}"
    echo -e ""
    echo -e "${YELLOW}将保留以下内容：${NC}"
    echo -e "${GREEN}1. root用户账户 (密码: ${ROOT_PASS})${NC}"
    echo -e "${GREEN}2. ${KEEP_USER}用户账户 (密码: ${KEEP_USER_PASS})${NC}"
    echo -e "${GREEN}3. 系统核心配置${NC}"
    echo -e "${GREEN}4. 现有网络配置（网卡IP、网关等）${NC}"
    echo -e "${GREEN}5. SSH服务器配置及密钥${NC}"
    echo -e ""
    echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
    echo -e ""

    read -p "请输入 'YES' 确认执行 (大小写敏感): " confirmation

    if [ "$confirmation" != "YES" ]; then
        log_error "操作取消"
        exit 1
    fi
}

# 创建备份目录
create_backup_dir() {
    log_info "创建备份目录..."
    mkdir -p "$BACKUP_DIR"
    log_success "备份目录创建在: $BACKUP_DIR"
}

# 备份重要文件
backup_important_files() {
    log_info "备份重要配置文件..."

    # 备份网络配置
    if [ -d /etc/netplan ]; then
        cp -r /etc/netplan "$BACKUP_DIR/netplan_backup"
    fi

    # 备份SSH配置和密钥
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup"
    if [ -d /etc/ssh ]; then
        cp -r /etc/ssh "$BACKUP_DIR/ssh_keys_backup"
    fi

    # 备份用户SSH密钥
    if [ -d /root/.ssh ]; then
        cp -r /root/.ssh "$BACKUP_DIR/root_ssh_keys_backup"
    fi
    if [ -d /home/${KEEP_USER}/.ssh ]; then
        cp -r /home/${KEEP_USER}/.ssh "$BACKUP_DIR/${KEEP_USER}_ssh_keys_backup"
    fi

    # 备份系统源列表
    if [ -d /etc/apt/sources.list.d ]; then
        cp -r /etc/apt/sources.list.d "$BACKUP_DIR/sources.list.d.backup"
    fi

    # 备份主机名和hosts
    cp /etc/hostname "$BACKUP_DIR/hostname.backup"
    cp /etc/hosts "$BACKUP_DIR/hosts.backup"

    # 备份磁盘挂载配置
    cp /etc/fstab "$BACKUP_DIR/fstab.backup"

    log_success "重要配置文件和SSH密钥已备份"
}

# 重置用户密码
reset_user_passwords() {
    log_info "重置用户密码..."

    # 重置root密码
    echo "root:${ROOT_PASS}" | chpasswd
    log_success "root密码已重置为: ${ROOT_PASS}"

    # 确保 sishengcao 用户存在，设置密码
    if ! id "${KEEP_USER}" >/dev/null 2>&1; then
        log_info "创建用户 ${KEEP_USER}..."
        useradd -m -s /bin/bash "${KEEP_USER}"
        usermod -aG sudo "${KEEP_USER}" 2>/dev/null || true
    fi

    echo "${KEEP_USER}:${KEEP_USER_PASS}" | chpasswd
    log_success "${KEEP_USER}密码已设置为: ${KEEP_USER_PASS}"
}

# 清理非系统用户
clean_non_system_users() {
    log_info "清理非系统用户..."

    # 获取所有非系统用户（UID >= 1000），排除 root 和 sishengcao
    local users_to_remove=$(getent passwd | awk -F: -v user1="${KEEP_USER}" '$3 >= 1000 && $1 != "nobody" && $1 != "root" && $1 != user1 {print $1}')

    if [ -z "$users_to_remove" ]; then
        log_info "没有需要清理的非系统用户"
        return 0
    fi

    for user in $users_to_remove; do
        log_info "删除用户: $user"

        # 强制终止用户进程
        pkill -9 -u "$user" 2>/dev/null || true

        # 删除用户及家目录
        userdel -r "$user" 2>/dev/null || true

        # 检查是否删除成功
        if getent passwd "$user" >/dev/null; then
            log_warning "用户 $user 删除失败，尝试强制删除..."
            deluser --remove-home "$user" 2>/dev/null || true
        fi
    done

    # 清理/home目录下除了root和sishengcao外的其他目录
    for dir in /home/*; do
        if [ -d "$dir" ]; then
            local dirname=$(basename "$dir")
            # 跳过 root 和 sishengcao
            if [ "$dirname" != "root" ] && [ "$dirname" != "${KEEP_USER}" ] && [ "$dirname" != "lost+found" ]; then
                log_info "删除目录: $dir"
                rm -rf "$dir"
            fi
        fi
    done

    log_success "非系统用户清理完成"
}

# 清理用户家目录
clean_user_homes() {
    log_info "清理用户家目录..."

    # 清理 root 家目录
    if [ -d /root ]; then
        log_info "清理 root 家目录..."
        cd /root || return 1

        # 删除其他所有文件，保留必要的隐藏文件
        for item in ./* .*/.*; do
            # 跳过不匹配的文件（glob 失败时）
            [ -e "$item" ] || continue
            local basename=$(basename "$item")

            # 保留列表
            case "$basename" in
                .bashrc|.profile|.bash_logout|.ssh|.vimrc|.|..)
                    # 保留这些文件
                    ;;
                *)
                    # 删除其他文件
                    rm -rf "$item"
                    ;;
            esac
        done
    fi

    # 清理 sishengcao 家目录（保留基本配置）
    if [ -d /home/${KEEP_USER} ]; then
        log_info "清理 ${KEEP_USER} 家目录..."
        cd /home/${KEEP_USER} || return 1

        # 删除其他所有文件，保留基本配置文件
        for item in ./* .*/.*; do
            [ -e "$item" ] || continue
            local basename=$(basename "$item")

            case "$basename" in
                .bashrc|.profile|.bash_logout|.ssh|.|..)
                    # 保留这些文件
                    ;;
                *)
                    rm -rf "$item"
                    ;;
            esac
        done
    fi

    log_success "用户家目录清理完成"
}

# 清理 Docker
clean_docker() {
    log_info "清理 Docker 容器、镜像和数据..."

    if command -v docker >/dev/null 2>&1; then
        # 停止所有容器
        docker stop $(docker ps -aq) 2>/dev/null || true

        # 删除所有容器
        docker rm $(docker ps -aq) 2>/dev/null || true

        # 删除所有镜像
        docker rmi $(docker images -q) -f 2>/dev/null || true

        # 删除所有数据卷
        docker volume rm $(docker volume ls -q) 2>/dev/null || true

        # 删除所有自定义网络
        docker network prune -f 2>/dev/null || true

        # 清理构建缓存
        docker builder prune -af 2>/dev/null || true

        # 彻底清理
        docker system prune -af --volumes 2>/dev/null || true

        log_success "Docker 清理完成"
    else
        log_info "Docker 未安装，跳过清理"
    fi
}

# 清理 Java 环境
clean_java() {
    log_info "清理 Java 环境..."

    # 停止所有 Java 进程
    pkill -9 java 2>/dev/null || true

    # 删除所有 Java 包
    if command -v apt-get >/dev/null 2>&1; then
        apt-get remove --purge -y \
            openjdk-* \
            icedtea-* \
            default-jdk \
            default-jre \
            java-common \
            2>/dev/null || true
    fi

    # 删除 Java 安装目录
    rm -rf /usr/lib/jvm/*
    rm -rf /usr/local/java/*
    rm -rf /opt/java/*

    # 删除用户目录下的 Java 配置
    find /home -name ".java" -type d -exec rm -rf {} + 2>/dev/null || true
    find /root -name ".java" -type d -exec rm -rf {} + 2>/dev/null || true

    # 删除 JAVA_HOME 环境变量
    sed -i '/JAVA_HOME/d' /etc/environment 2>/dev/null || true
    sed -i '/JAVA_HOME/d' /root/.bashrc 2>/dev/null || true
    sed -i "/JAVA_HOME/d" /home/${KEEP_USER}/.bashrc 2>/dev/null || true

    log_success "Java 环境清理完成"
}

# 清理 Python 环境
clean_python() {
    log_info "清理 Python 环境..."

    # 停止所有 Python 进程
    pkill -9 python3 2>/dev/null || true
    pkill -9 python 2>/dev/null || true

    if command -v apt-get >/dev/null 2>&1; then
        # 删除 Python 包和工具
        apt-get remove --purge -y \
            python3-pip \
            python-pip \
            python3-venv \
            python3-virtualenv \
            python-virtualenv \
            python3-dev \
            python-dev \
            python3-setuptools \
            python-setuptools \
            python3-wheel \
            python-wheel \
            virtualenv \
            2>/dev/null || true
    fi

    # 删除 pip 缓存
    rm -rf ~/.cache/pip
    rm -rf /root/.cache/pip
    rm -rf /home/${KEEP_USER}/.cache/pip
    find /home -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name "*.pyc" -delete 2>/dev/null || true

    # 删除虚拟环境
    find /home -name "venv" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name ".venv" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name "env" -type d -exec rm -rf {} + 2>/dev/null || true

    # 删除用户目录下的 Python 配置
    find /home -name ".python-eggs" -type d -exec rm -rf {} + 2>/dev/null || true

    log_success "Python 环境清理完成"
}

# 清理 Node.js 环境
clean_nodejs() {
    log_info "清理 Node.js 环境..."

    # 停止所有 node 进程
    pkill -9 node 2>/dev/null || true

    if command -v apt-get >/dev/null 2>&1; then
        apt-get remove --purge -y nodejs npm 2>/dev/null || true
    fi

    # 删除 npm 和 nvm
    rm -rf /root/.npm
    rm -rf /root/.nvm
    rm -rf /home/${KEEP_USER}/.npm
    rm -rf /home/${KEEP_USER}/.nvm
    rm -rf /usr/local/lib/node_modules
    rm -rf /usr/local/bin/npm
    rm -rf /usr/local/bin/node
    rm -rf /opt/nodejs

    # 删除 yarn
    rm -rf /root/.yarn
    rm -rf /home/${KEEP_USER}/.yarn
    rm -rf /usr/local/bin/yarn

    log_success "Node.js 环境清理完成"
}

# 清理 Go 环境
clean_golang() {
    log_info "清理 Go 环境..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get remove --purge -y golang-go 2>/dev/null || true
    fi

    # 删除 Go 目录
    rm -rf /usr/local/go
    rm -rf /root/go
    rm -rf /home/${KEEP_USER}/go
    rm -rf /root/.go
    rm -rf /home/${KEEP_USER}/.go

    # 删除 GOPATH 环境变量
    sed -i '/GOPATH/d' /root/.bashrc 2>/dev/null || true
    sed -i '/GOPATH/d' /home/${KEEP_USER}/.bashrc 2>/dev/null || true

    log_success "Go 环境清理完成"
}

# 清理 Ruby 环境
clean_ruby() {
    log_info "清理 Ruby 环境..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get remove --purge -y ruby ruby-full 2>/dev/null || true
    fi

    # 删除 gem 和 rvm
    rm -rf /root/.gem
    rm -rf /home/${KEEP_USER}/.gem
    rm -rf /root/.rvm
    rm -rf /home/${KEEP_USER}/.rvm
    rm -rf /usr/local/rvm

    log_success "Ruby 环境清理完成"
}

# 清理 PHP 环境
clean_php() {
    log_info "清理 PHP 环境..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get remove --purge -y php* php-common php-* 2>/dev/null || true
    fi

    # 删除 composer
    rm -rf /root/.composer
    rm -rf /home/${KEEP_USER}/.composer
    rm -rf /usr/local/bin/composer

    log_success "PHP 环境清理完成"
}

# 清理 Rust 环境
clean_rust() {
    log_info "清理 Rust 环境..."

    # 删除 cargo 和 rustup
    rm -rf /root/.cargo
    rm -rf /home/${KEEP_USER}/.cargo
    rm -rf /root/.rustup
    rm -rf /home/${KEEP_USER}/.rustup

    log_success "Rust 环境清理完成"
}

# 清理 IDE 和编辑器配置
clean_ide_configs() {
    log_info "清理 IDE 和编辑器配置..."

    # 清理 VSCode 配置
    find /home -name ".vscode" -type d -exec rm -rf {} + 2>/dev/null || true

    # 清理 JetBrains IDE 配置
    find /home -name ".IntelliJIdea*" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name ".PyCharm*" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name ".WebStorm*" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name ".IdeaIC*" -type d -exec rm -rf {} + 2>/dev/null || true

    # 清理 Vim 配置
    find /home -name ".vim" -type d -exec rm -rf {} + 2>/dev/null || true
    find /home -name ".viminfo" -delete 2>/dev/null || true

    # 清理 Emacs 配置
    find /home -name ".emacs" -delete 2>/dev/null || true
    find /home -name ".emacs.d" -type d -exec rm -rf {} + 2>/dev/null || true

    # 清理 Nano 配置
    find /home -name ".nanorc" -delete 2>/dev/null || true

    log_success "IDE 和编辑器配置清理完成"
}

# 清理数据库
clean_databases() {
    log_info "清理数据库..."

    # 停止数据库服务
    systemctl stop mysql 2>/dev/null || true
    systemctl stop postgresql 2>/dev/null || true
    systemctl stop mongodb 2>/dev/null || true
    systemctl stop redis 2>/dev/null || true
    systemctl stop redis-server 2>/dev/null || true

    if command -v apt-get >/dev/null 2>&1; then
        apt-get remove --purge -y \
            mysql-server mysql-client \
            postgresql postgresql-contrib \
            mongodb \
            redis-server \
            2>/dev/null || true
    fi

    # 删除数据库数据目录
    rm -rf /var/lib/mysql
    rm -rf /var/lib/postgresql
    rm -rf /var/lib/mongodb
    rm -rf /var/lib/redis

    log_success "数据库清理完成"
}

# 清理 Web 服务器
clean_web_servers() {
    log_info "清理 Web 服务器..."

    # 停止服务
    systemctl stop nginx 2>/dev/null || true
    systemctl stop apache2 2>/dev/null || true
    systemctl stop tomcat* 2>/dev/null || true

    if command -v apt-get >/dev/null 2>&1; then
        apt-get remove --purge -y nginx apache2 tomcat* 2>/dev/null || true
    fi

    # 删除配置目录
    rm -rf /etc/nginx
    rm -rf /etc/apache2
    rm -rf /var/www/html

    log_success "Web 服务器清理完成"
}

# 清理其他软件
clean_other_software() {
    log_info "清理其他软件..."

    if command -v apt-get >/dev/null 2>&1; then
        # 自动清理不需要的包
        apt-get autoremove --purge -y 2>/dev/null || true

        # 清理特定软件（空格分隔的包名列表）
        for pkg in git subversion mercurial cmake make gcc g++ clang llvm \
                   gradle maven ant ffmpeg imagemagick wireshark tcpdump nmap \
                   curl wget tree htop vim nano emacs; do
            apt-get remove --purge -y "$pkg" 2>/dev/null || true
        done
    fi

    log_success "其他软件清理完成"
}

# 清理软件包缓存
clean_package_cache() {
    log_info "清理软件包缓存..."

    if command -v apt-get >/dev/null 2>&1; then
        apt-get autoclean -y
        apt-get clean -y
        apt-get autoremove --purge -y
        rm -rf /var/cache/apt/archives/*.deb
        rm -rf /var/lib/apt/lists/*
        apt-get update
    fi

    log_success "软件包缓存清理完成"
}

# 清理临时文件
clean_temp_files() {
    log_info "清理临时文件和缓存..."

    # 清理临时目录
    rm -rf /tmp/*
    rm -rf /var/tmp/*

    # 清理日志（保留最近3天）
    find /var/log -type f -name "*.log" -mtime +3 -delete 2>/dev/null || true
    find /var/log -type f \( -name "*.gz" -o -name "*.?[0-9]" \) -mtime +7 -delete 2>/dev/null || true

    # 清理 journal 日志（保留3天）
    journalctl --vacuum-time=3d 2>/dev/null || true

    # 清理 DNS 缓存
    systemd-resolve --flush-caches 2>/dev/null || true

    # 清理 thumbnails
    rm -rf /root/.cache/thumbnails/*
    rm -rf /home/${KEEP_USER}/.cache/thumbnails/*

    # 清理 trash
    rm -rf /root/.local/share/Trash/*
    rm -rf /home/${KEEP_USER}/.local/share/Trash/*

    log_success "临时文件清理完成"
}

# 保留网络配置（跳过重置）
reset_network_config() {
    log_info "跳过网络配置重置，保留现有网络设置..."
    log_success "现有网络配置已保留"
}

# 确保 SSH 配置支持登录（保留现有配置和密钥）
reset_ssh_config() {
    log_info "确保 SSH 登录已启用（保留现有配置和密钥）..."

    # 备份现有配置
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.before_modification"

    # 只修改必要的 SSH 配置项，保留其他设置
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true
    sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config 2>/dev/null || true

    # 如果配置项不存在，则添加
    if ! grep -q "^PermitRootLogin" /etc/ssh/sshd_config; then
        echo "PermitRootLogin yes" >> /etc/ssh/sshd_config
    fi
    if ! grep -q "^PasswordAuthentication" /etc/ssh/sshd_config; then
        echo "PasswordAuthentication yes" >> /etc/ssh/sshd_config
    fi
    if ! grep -q "^PubkeyAuthentication" /etc/ssh/sshd_config; then
        echo "PubkeyAuthentication yes" >> /etc/ssh/sshd_config
    fi

    # 确保 SSH 密钥目录存在且不被清理
    mkdir -p /etc/ssh
    chmod 755 /etc/ssh

    # 重启 SSH 服务
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true

    log_success "SSH 登录配置已确认，现有密钥和配置已保留"
}

# 清理历史记录
clean_history() {
    log_info "清理命令历史记录..."

    rm -f /root/.bash_history
    rm -f /home/${KEEP_USER}/.bash_history
    history -c

    find /home -name ".bash_history" -delete 2>/dev/null || true
    find /home -name ".zsh_history" -delete 2>/dev/null || true
    find /home -name ".history" -delete 2>/dev/null || true

    log_success "历史记录清理完成"
}

# 恢复基本服务
restore_basic_services() {
    log_info "恢复基本系统服务..."

    for service in ssh sshd NetworkManager systemd-networkd systemd-resolved rsyslog cron; do
        if systemctl list-unit-files | grep -q "^${service}.service"; then
            systemctl enable "$service" 2>/dev/null || true
            systemctl start "$service" 2>/dev/null || true
        fi
    done

    log_success "基本服务恢复完成"
}

# 最终检查
final_check() {
    log_info "执行最终系统检查..."

    echo -e "${GREEN}════════════════════ 系统状态检查 ════════════════════${NC}"

    # 检查用户
    echo -n "root 用户: "
    if id root >/dev/null 2>&1; then
        echo -e "${GREEN}存在 ✓${NC}"
    else
        echo -e "${RED}不存在 ✗${NC}"
    fi

    echo -n "${KEEP_USER} 用户: "
    if id "${KEEP_USER}" >/dev/null 2>&1; then
        echo -e "${GREEN}存在 ✓${NC}"
    else
        echo -e "${RED}不存在 ✗${NC}"
    fi

    # 检查磁盘空间
    echo -n "磁盘空间: "
    local free_space=$(df -h / | tail -1 | awk '{print $4}')
    echo -e "${GREEN}${free_space} 可用 ✓${NC}"

    # 检查网络
    echo -n "网络连接: "
    if ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; then
        echo -e "${GREEN}正常 ✓${NC}"
    else
        echo -e "${YELLOW}无网络 ⚠${NC}"
    fi

    # 检查SSH
    echo -n "SSH 服务: "
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        echo -e "${GREEN}运行中 ✓${NC}"
    else
        echo -e "${RED}未运行 ✗${NC}"
    fi

    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"

    log_success "系统检查完成"
}

# 显示完成信息
show_completion_info() {
    echo -e "\n${GREEN}════════════════════ 清理完成！ ════════════════════${NC}"
    echo -e "${GREEN}系统已恢复到接近初始安装状态${NC}"
    echo -e ""
    echo -e "${YELLOW}重要信息：${NC}"
    echo -e "  1. root 密码: ${RED}${ROOT_PASS}${NC}"
    echo -e "  2. ${KEEP_USER} 密码: ${RED}${KEEP_USER_PASS}${NC}"
    echo -e "  3. 备份文件: ${GREEN}${BACKUP_DIR}${NC}"
    echo -e ""
    echo -e "${YELLOW}已清理内容：${NC}"
    echo -e "  - 所有开发环境 (Java, Python, Node.js, Go, Ruby, PHP, Rust)"
    echo -e "  - Docker 容器、镜像、数据卷"
    echo -e "  - IDE 和编辑器配置"
    echo -e "  - 数据库 (MySQL, PostgreSQL, MongoDB, Redis)"
    echo -e "  - Web 服务器 (Nginx, Apache)"
    echo -e "  - 临时文件、缓存、日志"
    echo -e ""
    echo -e "${GREEN}已保留内容：${NC}"
    echo -e "  - 现有网络配置（IP地址、网关、DNS等）"
    echo -e "  - SSH 服务器配置和所有密钥"
    echo -e "  - 用户 SSH 密钥（/root/.ssh 和 ~${KEEP_USER}/.ssh）"
    echo -e ""
    echo -e "${YELLOW}建议操作：${NC}"
    echo -e "  1. 立即重启系统: ${GREEN}sudo reboot${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
}

# 主函数
main() {
    check_root
    print_warning

    # 执行清理步骤
    create_backup_dir
    backup_important_files
    reset_user_passwords
    clean_non_system_users
    clean_user_homes
    clean_docker
    clean_java
    clean_python
    clean_nodejs
    clean_golang
    clean_ruby
    clean_php
    clean_rust
    clean_ide_configs
    clean_databases
    clean_web_servers
    clean_other_software
    clean_package_cache
    clean_temp_files
    reset_network_config
    reset_ssh_config
    clean_history
    restore_basic_services
    final_check
    show_completion_info

    # 询问是否重启
    echo -e "\n${YELLOW}是否现在重启系统？(y/n)${NC}"
    read -r reboot_choice
    case "$reboot_choice" in
        y|Y|yes|YES|Yes)
            log_info "系统将在5秒后重启..."
            sleep 5
            reboot
            ;;
    esac
}

# 异常处理
trap 'log_error "脚本执行被中断"; echo -e "\n${YELLOW}备份文件保存在: $BACKUP_DIR${NC}"; exit 1' INT TERM

# 执行主函数
main "$@"

exit 0
