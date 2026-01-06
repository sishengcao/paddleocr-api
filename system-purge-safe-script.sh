#!/bin/bash
# system-purge-safe-script.sh
# 安全系统纯净还原脚本 - 保留root用户和必要配置

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
    if [[ $EUID -ne 0 ]]; then
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
    echo -e "${RED}2. 清理 /home 目录下除root外的所有用户数据${NC}"
    echo -e "${RED}3. 删除所有Docker容器、镜像、网络和数据卷${NC}"
    echo -e "${RED}4. 清理临时文件和缓存${NC}"
    echo -e "${RED}5. 重置root密码为: ${ROOT_PASS}${NC}"
    echo -e ""
    echo -e "${YELLOW}将保留以下内容：${NC}"
    echo -e "${GREEN}1. root用户账户和家目录${NC}"
    echo -e "${GREEN}2. 系统核心配置${NC}"
    echo -e "${GREEN}3. 网络配置${NC}"
    echo -e "${GREEN}4. SSH服务器配置${NC}"
    echo -e ""
    echo -e "${RED}══════════════════════════════════════════════════════════${NC}"
    echo -e ""
    
    read -p "请输入 'YES' 确认执行 (大小写敏感): " confirmation
    
    if [[ "$confirmation" != "YES" ]]; then
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
    if [[ -d /etc/netplan ]]; then
        cp -r /etc/netplan "$BACKUP_DIR/netplan_backup"
    fi
    
    # 备份SSH配置
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.backup"
    
    # 备份系统源列表
    if [[ -d /etc/apt/sources.list.d ]]; then
        cp -r /etc/apt/sources.list.d "$BACKUP_DIR/sources.list.d.backup"
    fi
    
    # 备份主机名和hosts
    cp /etc/hostname "$BACKUP_DIR/hostname.backup"
    cp /etc/hosts "$BACKUP_DIR/hosts.backup"
    
    # 备份磁盘挂载配置
    cp /etc/fstab "$BACKUP_DIR/fstab.backup"
    
    log_success "重要配置文件已备份"
}

# 重置root密码
reset_root_password() {
    log_info "重置root用户密码..."
    echo "root:${ROOT_PASS}" | chpasswd
    
    # 检查密码是否设置成功
    if su -c "true" "$ROOT_USER"; then
        log_success "root密码已重置为: ${ROOT_PASS}"
    else
        log_error "root密码重置失败"
    fi
}

# 清理非系统用户
clean_non_system_users() {
    log_info "清理非系统用户..."

    # 定义要保留的用户（即使是普通用户）
    local keep_users=(
        "ubuntu"      # Ubuntu 默认用户
    )

    # 获取所有非系统用户（UID >= 1000），排除保留列表
    local users_to_remove=$(getent passwd | awk -F: -v keep="$(IFS='|'; echo "${keep_users[*]}")" '$3 >= 1000 && $1 != "nobody" && $1 != "root" && $1 !~ keep {print $1}')

    if [[ -z "$users_to_remove" ]]; then
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

    # 清理/home目录下除了root外的其他目录
    for dir in /home/*; do
        if [[ -d "$dir" ]]; then
            local dirname=$(basename "$dir")
            local skip=false

            # 跳过保留的目录
            for keep_user in "root" "${keep_users[@]}" "lost+found"; do
                if [[ "$dirname" == "$keep_user" ]]; then
                    skip=true
                    break
                fi
            done

            if ! $skip; then
                log_info "删除目录: $dir"
                rm -rf "$dir"
            fi
        fi
    done

    log_success "非系统用户清理完成"
}

# 清理root家目录
clean_root_home() {
    log_info "清理root家目录..."

    # 保留必要的隐藏文件
    cd /root || return 1

    # 创建需要保留的文件列表
    local keep_files=(
        ".bashrc"
        ".profile"
        ".bash_logout"
        ".ssh"
        ".vimrc"
        ".viminfo"
        ".gitconfig"
        ".gnupg"
    )

    # 备份这些文件
    mkdir -p "$BACKUP_DIR/root_home_backup"
    for file in "${keep_files[@]}"; do
        if [[ -e "$file" ]]; then
            cp -r "$file" "$BACKUP_DIR/root_home_backup/"
        fi
    done

    # 删除除需要保留外的所有文件和目录
    # 使用 find 来处理所有文件（包括隐藏文件）
    find . -maxdepth 1 ! -name "." ! -name ".." -print0 | while IFS= read -r -d '' item; do
        local basename=$(basename "$item")
        local skip=false

        # 检查是否在保留列表中
        for keep in "${keep_files[@]}"; do
            if [[ "$basename" == "$keep" ]]; then
                skip=true
                break
            fi
        done

        if ! $skip; then
            rm -rf "$item"
        fi
    done

    # 从备份恢复保留的文件
    for file in "${keep_files[@]}"; do
        if [[ -e "$BACKUP_DIR/root_home_backup/$file" ]]; then
            cp -r "$BACKUP_DIR/root_home_backup/$file" .
        fi
    done

    log_success "root家目录清理完成"
}

# 清理Docker
clean_docker() {
    log_info "清理Docker容器、镜像和数据..."
    
    # 检查Docker是否安装
    if command -v docker &> /dev/null; then
        # 停止所有容器
        docker stop $(docker ps -aq) 2>/dev/null || true
        
        # 删除所有容器
        docker rm $(docker ps -aq) 2>/dev/null || true
        
        # 删除所有镜像
        docker rmi $(docker images -q) 2>/dev/null || true
        
        # 删除所有数据卷
        docker volume rm $(docker volume ls -q) 2>/dev/null || true
        
        # 删除所有网络（除了默认网络）
        docker network ls --filter name=bridge -q | while read network; do
            if [[ "$network" != "$(docker network ls --filter name=bridge --format '{{.ID}}' | head -1)" ]]; then
                docker network rm "$network" 2>/dev/null || true
            fi
        done
        
        # 清理Docker缓存
        docker system prune -a -f --volumes 2>/dev/null || true
        
        log_success "Docker清理完成"
    else
        log_info "Docker未安装，跳过清理"
    fi
}

# 清理软件包
clean_packages() {
    log_info "清理非必要的软件包..."

    if command -v apt-get &> /dev/null; then
        # Ubuntu/Debian
        log_info "检测到APT系统，开始清理..."

        # 更新包列表
        apt-get update

        # 清理所有非必要的包，保留系统核心包
        apt-get autoremove --purge -y

        # 清理特定的大包（不删除Docker，因为可能需要后续使用）
        local packages_to_remove=(
            "mysql-server"
            "mysql-client"
            "postgresql-*"
            "mongodb-*"
            "redis-server"
            "nginx"
            "apache2"
            "tomcat*"
            "nodejs"
            "npm"
            "python3-pip"
            "openjdk-11-jdk"
            "openjdk-17-jdk"
            "ruby*"
            "php*"
            "golang"
        )

        for pkg_pattern in "${packages_to_remove[@]}"; do
            apt-get remove --purge -y "$pkg_pattern" 2>/dev/null || true
        done

        # 清理配置
        apt-get autoclean -y
        apt-get clean -y

    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        log_info "检测到YUM系统，开始清理..."

        yum clean all
        yum autoremove -y

    elif command -v dnf &> /dev/null; then
        # Fedora
        log_info "检测到DNF系统，开始清理..."

        dnf clean all
        dnf autoremove -y
    fi

    log_success "软件包清理完成"
}

# 清理临时文件
clean_temp_files() {
    log_info "清理临时文件和缓存..."

    # 清理临时目录
    rm -rf /tmp/*
    rm -rf /var/tmp/*

    # 清理日志（保留最近7天，不压缩旧日志）
    find /var/log -type f -name "*.log" -mtime +7 -delete 2>/dev/null || true

    # 清理轮转日志（压缩旧日志，但不删除关键的系统日志）
    find /var/log -type f \( -name "*.gz" -o -name "*.1" -o -name "*.2" \) -mtime +30 -delete 2>/dev/null || true

    # 清理包管理器缓存
    if command -v apt-get &> /dev/null; then
        rm -rf /var/cache/apt/archives/*.deb
    elif command -v yum &> /dev/null; then
        rm -rf /var/cache/yum/*
    fi

    # 清理DNS缓存
    systemd-resolve --flush-caches 2>/dev/null || true

    # 清理journal日志（保留7天）
    journalctl --vacuum-time=7d 2>/dev/null || true

    log_success "临时文件清理完成"
}

# 重置网络配置
reset_network_config() {
    log_info "重置网络配置..."

    # 备份当前网络配置
    cp /etc/network/interfaces "$BACKUP_DIR/interfaces.backup" 2>/dev/null || true

    # 检测当前使用的网络管理方式，保持一致
    if [[ -d /etc/netplan ]]; then
        # Ubuntu 18.04+ 使用 Netplan
        # 检测当前使用的 renderer
        local current_renderer=""
        if [[ -f /etc/netplan/*.yaml ]]; then
            current_renderer=$(grep -h "renderer:" /etc/netplan/*.yaml 2>/dev/null | head -1 | awk '{print $2}')
        fi

        # 如果检测不到 renderer，使用 NetworkManager 作为默认
        local renderer="${current_renderer:-NetworkManager}"

        log_info "使用 Netplan 配置，renderer: $renderer"

        # 创建基本配置（保持当前 renderer）
        cat > /etc/netplan/01-network-manager-all.yaml << EOF
network:
  version: 2
  renderer: $renderer
  ethernets:
    eth0:
      dhcp4: true
      optional: true
EOF

        # 应用配置
        netplan apply 2>/dev/null || log_warning "Netplan 配置应用失败"

    elif [[ -f /etc/network/interfaces ]]; then
        # 传统的 interfaces 配置
        log_info "使用传统 interfaces 配置"

        # 备份并创建基本配置
        cat > /etc/network/interfaces << 'EOF'
# interfaces(5) file used by ifup(8) and ifdown(8)
auto lo
iface lo inet loopback

allow-hotplug eth0
iface eth0 inet dhcp
EOF

        # 重启网络服务
        systemctl restart networking 2>/dev/null || true
    fi

    log_success "网络配置已重置"
}

# 重置SSH配置
reset_ssh_config() {
    log_info "重置SSH配置..."
    
    # 备份当前配置
    cp /etc/ssh/sshd_config "$BACKUP_DIR/sshd_config.original"
    
    # 生成安全的默认配置
    cat > /etc/ssh/sshd_config << 'EOF'
# SSH服务器配置
Port 22
Protocol 2

# 认证设置
PermitRootLogin yes
PasswordAuthentication yes
PubkeyAuthentication yes

# 安全设置
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10

# 日志设置
SyslogFacility AUTH
LogLevel INFO

# 其他设置
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
EOF
    
    # 重启SSH服务
    systemctl restart ssh 2>/dev/null || systemctl restart sshd 2>/dev/null || true
    
    log_success "SSH配置已重置"
}

# 清理历史记录
clean_history() {
    log_info "清理命令历史记录..."
    
    # 清理root的历史记录
    rm -f /root/.bash_history
    history -c
    
    # 清理所有用户的.bash_history
    find /home -name ".bash_history" -delete 2>/dev/null || true
    
    # 清理其他shell历史
    find /home -name ".zsh_history" -delete 2>/dev/null || true
    find /home -name ".history" -delete 2>/dev/null || true
    
    log_success "历史记录清理完成"
}

# 恢复基本服务
restore_basic_services() {
    log_info "恢复基本系统服务..."
    
    # 确保基本服务启动
    local basic_services=(
        "ssh"
        "sshd"
        "network-manager"
        "NetworkManager"
        "systemd-networkd"
        "systemd-resolved"
        "rsyslog"
        "cron"
        "systemd-journald"
    )
    
    for service in "${basic_services[@]}"; do
        if systemctl list-unit-files | grep -q "$service"; then
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
    
    # 检查root密码
    echo -n "root密码检查: "
    if su -c "true" "$ROOT_USER"; then
        echo -e "${GREEN}正常 ✓${NC}"
    else
        echo -e "${RED}失败 ✗${NC}"
    fi
    
    # 检查磁盘空间
    echo -n "磁盘空间检查: "
    local free_space=$(df -h / | tail -1 | awk '{print $4}')
    echo -e "${GREEN}$free_space 可用 ✓${NC}"
    
    # 检查网络
    echo -n "网络连接检查: "
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        echo -e "${GREEN}正常 ✓${NC}"
    else
        echo -e "${YELLOW}无网络连接 ⚠${NC}"
    fi
    
    # 检查SSH服务
    echo -n "SSH服务检查: "
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
    echo -e "  1. root密码已设置为: ${RED}${ROOT_PASS}${NC}"
    echo -e "  2. 备份文件保存在: ${GREEN}${BACKUP_DIR}${NC}"
    echo -e "  3. 所有非系统用户已被删除"
    echo -e "  4. Docker容器、镜像、数据已清理"
    echo -e ""
    echo -e "${YELLOW}建议操作：${NC}"
    echo -e "  1. 立即重启系统: ${GREEN}reboot${NC}"
    echo -e "  2. 检查备份文件是否需要恢复"
    echo -e "  3. 重新配置需要的软件和服务"
    echo -e ""
    echo -e "${RED}警告：${NC}"
    echo -e "  - 请在重启前验证重要数据已备份"
    echo -e "  - 某些软件配置可能需要手动恢复"
    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
}

# 主函数
main() {
    check_root
    print_warning
    
    # 执行清理步骤
    create_backup_dir
    backup_important_files
    reset_root_password
    clean_non_system_users
    clean_root_home
    clean_docker
    clean_packages
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
    if [[ "$reboot_choice" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        log_info "系统将在5秒后重启..."
        sleep 5
        reboot
    fi
}

# 异常处理
trap 'log_error "脚本执行被中断"; echo -e "\n${YELLOW}备份文件保存在: $BACKUP_DIR${NC}"; exit 1' INT TERM

# 执行主函数
main "$@"

exit 0