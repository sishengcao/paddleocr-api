#!/bin/bash
# docker-fix-script-pro.sh
# Docker 专业修复脚本
# 包含SSH检查、系统更新、Docker安装、网络防火墙检测等功能

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

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

log_debug() {
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

# 检查是否以root运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "请使用 root 权限运行此脚本"
        echo "使用: sudo bash $0"
        exit 1
    fi
}

# 打印横幅
print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║          Docker 专业修复与安装脚本                        ║"
    echo "║                 版本 2.0 - 高级版                        ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# 打印系统信息
print_system_info() {
    log_info "正在收集系统信息..."
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    
    if [[ -f /etc/os-release ]]; then
        OS_NAME=$(grep "^NAME=" /etc/os-release | cut -d'"' -f2)
        OS_VERSION=$(grep "^VERSION=" /etc/os-release | cut -d'"' -f2)
        echo -e "  OS: ${GREEN}$OS_NAME $OS_VERSION${NC}"
    fi
    
    echo -e "  内核版本: ${GREEN}$(uname -r)${NC}"
    echo -e "  系统架构: ${GREEN}$(uname -m)${NC}"
    echo -e "  主机名: ${GREEN}$(hostname)${NC}"
    
    # IP地址信息
    IP_ADDRS=$(hostname -I 2>/dev/null || echo "未知")
    echo -e "  IP地址: ${GREEN}$IP_ADDRS${NC}"
    
    # CPU信息
    CPU_CORES=$(nproc 2>/dev/null || echo "未知")
    echo -e "  CPU核心: ${GREEN}$CPU_CORES${NC}"
    
    # 内存信息
    MEM_TOTAL=$(free -h 2>/dev/null | grep Mem | awk '{print $2}' || echo "未知")
    echo -e "  总内存: ${GREEN}$MEM_TOTAL${NC}"
    
    # 磁盘空间
    DISK_SPACE=$(df -h / 2>/dev/null | tail -1 | awk '{print $4}')
    echo -e "  根分区可用: ${GREEN}$DISK_SPACE${NC}"
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
}

# 检查并配置SSH服务
check_and_config_ssh() {
    log_info "检查SSH服务状态..."
    
    # 检查是否安装了SSH
    if ! command -v sshd &> /dev/null && ! systemctl list-unit-files | grep -q ssh; then
        log_warning "SSH服务未安装，开始安装..."
        
        # 根据系统类型安装SSH
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y openssh-server
        elif command -v yum &> /dev/null; then
            yum install -y openssh-server
        elif command -v dnf &> /dev/null; then
            dnf install -y openssh-server
        else
            log_error "无法确定包管理器，请手动安装SSH"
            return 1
        fi
    fi
    
    # 检查SSH服务状态
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        log_success "SSH服务正在运行"
        SSH_SERVICE=$(systemctl list-units --type=service | grep -E "ssh|sshd" | head -1 | awk '{print $1}')
    else
        log_warning "SSH服务未运行，尝试启动..."
        
        # 尝试启动SSH服务
        if systemctl start ssh 2>/dev/null || systemctl start sshd 2>/dev/null; then
            sleep 2
            # 设置开机自启
            if systemctl enable ssh 2>/dev/null || systemctl enable sshd 2>/dev/null; then
                log_success "SSH服务已启动并设置为开机自启"
                SSH_SERVICE=$(systemctl list-units --type=service | grep -E "ssh|sshd" | head -1 | awk '{print $1}')
            else
                log_success "SSH服务已启动"
            fi
        else
            log_error "无法启动SSH服务"
            return 1
        fi
    fi
    
    # 检查SSH端口
    log_info "检查SSH端口(22)监听状态..."
    if ss -tlnp | grep -q ":22 "; then
        log_success "SSH端口(22)正在监听"
        
        # 检查防火墙规则
        if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
            if ufw status | grep -q "22/tcp"; then
                log_success "防火墙已放行SSH端口"
            else
                log_warning "防火墙未放行SSH端口，正在配置..."
                ufw allow 22/tcp
                log_success "已放行SSH端口"
            fi
        fi
    else
        log_error "SSH端口未监听，请检查配置"
    fi
    
    # 备份SSH配置文件（安全起见）
    if [[ -f /etc/ssh/sshd_config ]]; then
        cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d)
        log_info "已备份SSH配置文件"
    fi
    
    return 0
}

# 更新系统包
update_system_packages() {
    log_info "开始更新系统包..."
    
    # 根据系统类型更新
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        log_info "检测到APT包管理器，更新中..."
        
        # 更新包列表
        if ! apt-get update; then
            log_warning "APT更新失败，尝试修复..."
            # 修复可能的apt问题
            rm -f /var/lib/apt/lists/lock
            rm -f /var/cache/apt/archives/lock
            rm -f /var/lib/dpkg/lock
            dpkg --configure -a
            apt-get update
        fi
        
        # 升级已安装的包
        apt-get upgrade -y
        apt-get dist-upgrade -y
        
        # 清理不需要的包
        apt-get autoremove -y
        apt-get autoclean -y
        
        log_success "APT系统更新完成"
        
    elif command -v yum &> /dev/null; then
        # RHEL/CentOS 7
        log_info "检测到YUM包管理器，更新中..."
        
        yum update -y
        yum upgrade -y
        yum autoremove -y
        
        log_success "YUM系统更新完成"
        
    elif command -v dnf &> /dev/null; then
        # RHEL/CentOS 8+, Fedora
        log_info "检测到DNF包管理器，更新中..."
        
        dnf update -y
        dnf upgrade -y
        dnf autoremove -y
        
        log_success "DNF系统更新完成"
        
    else
        log_error "无法识别的包管理器"
        return 1
    fi
    
    # 安装常用工具
    log_info "安装常用工具..."
    if command -v apt-get &> /dev/null; then
        apt-get install -y curl wget net-tools lsof htop telnet dnsutils
    elif command -v yum &> /dev/null; then
        yum install -y curl wget net-tools lsof htop telnet bind-utils
    elif command -v dnf &> /dev/null; then
        dnf install -y curl wget net-tools lsof htop telnet bind-utils
    fi
    
    return 0
}

# 安装Docker和Docker Compose插件(v2)
install_docker_and_compose() {
    log_info "检查Docker安装状态..."
    
    # 检查Docker是否已安装
    if command -v docker &> /dev/null; then
        DOCKER_VERSION=$(docker --version | cut -d' ' -f3)
        log_success "Docker已安装 (版本: $DOCKER_VERSION)"
    else
        log_warning "Docker未安装，开始安装..."
        
        # 卸载旧版本
        log_info "清理旧版本Docker..."
        if command -v apt-get &> /dev/null; then
            apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
        elif command -v yum &> /dev/null; then
            yum remove -y docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-engine 2>/dev/null || true
        fi
        
        # 安装依赖
        log_info "安装依赖包..."
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y \
                apt-transport-https \
                ca-certificates \
                curl \
                gnupg \
                lsb-release \
                software-properties-common
        elif command -v yum &> /dev/null; then
            yum install -y yum-utils device-mapper-persistent-data lvm2
        elif command -v dnf &> /dev/null; then
            dnf install -y dnf-plugins-core device-mapper-persistent-data lvm2
        fi
        
        # 添加Docker官方GPG密钥
        log_info "添加Docker官方GPG密钥..."
        mkdir -p /etc/apt/keyrings 2>/dev/null || true
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || \
        curl -fsSL https://download.docker.com/linux/centos/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null || \
        curl -fsSL https://download.docker.com/linux/fedora/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg 2>/dev/null
        
        # 添加Docker仓库
        log_info "添加Docker仓库..."
        if command -v apt-get &> /dev/null; then
            # 区分 Debian 和 Ubuntu
            if grep -q "Debian" /etc/os-release 2>/dev/null; then
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
                  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                log_info "已添加 Docker Debian 仓库"
            else
                echo \
                  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
                  $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
                log_info "已添加 Docker Ubuntu 仓库"
            fi
        elif command -v yum &> /dev/null; then
            yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
        elif command -v dnf &> /dev/null; then
            dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        fi
        
        # 安装Docker引擎（包含docker-compose插件）
        log_info "安装Docker引擎..."
        if command -v apt-get &> /dev/null; then
            apt-get update
            apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        elif command -v yum &> /dev/null; then
            yum install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        elif command -v dnf &> /dev/null; then
            dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        fi
        
        # 验证安装
        if docker --version; then
            log_success "Docker安装成功"
        else
            log_error "Docker安装失败"
            return 1
        fi
    fi
    
    # 检查Docker Compose插件(v2)
    log_info "检查Docker Compose插件(v2)..."
    if docker compose version &> /dev/null; then
        COMPOSE_VERSION=$(docker compose version | head -1 | cut -d' ' -f4)
        log_success "Docker Compose插件已安装 (版本: $COMPOSE_VERSION)"
    else
        # 尝试安装Docker Compose插件
        log_warning "Docker Compose插件未找到，尝试安装..."
        
        # 安装docker-compose-plugin
        if command -v apt-get &> /dev/null; then
            apt-get install -y docker-compose-plugin
        elif command -v yum &> /dev/null; then
            yum install -y docker-compose-plugin
        elif command -v dnf &> /dev/null; then
            dnf install -y docker-compose-plugin
        fi
        
        if docker compose version &> /dev/null; then
            log_success "Docker Compose插件安装成功"
        else
            log_error "Docker Compose插件安装失败"
            return 1
        fi
    fi
    
    # 启动并启用Docker服务
    log_info "配置Docker服务..."
    systemctl start docker
    systemctl enable docker
    
    # 添加当前用户到docker组（避免sudo）
    log_info "配置用户组权限..."
    if ! getent group docker | grep -q "\b$(whoami)\b"; then
        usermod -aG docker $(whoami) || usermod -aG docker $SUDO_USER 2>/dev/null || true
        log_success "已将用户添加到docker组，需要重新登录生效"
    fi
    
    return 0
}

# 配置 hosts 文件解决 DNS 污染
configure_hosts_for_docker() {
    log_info "配置 hosts 文件解决 DNS 污染..."

    # 备份 hosts 文件
    if [[ -f /etc/hosts ]]; then
        cp /etc/hosts /etc/hosts.backup.$(date +%Y%m%d%H%M%S)
        log_info "已备份 hosts 文件"
    fi

    # Docker Hub 相关域名的 IP 地址（需要定期更新）
    # 这些 IP 可以通过以下方式获取：
    # 1. nslookup registry-1.docker.io 8.8.8.8
    # 2. https://www.ipaddress.com/
    # 3. ping 或 curl 测试连通性

    # 检查是否已存在 Docker hosts 配置
    if grep -q "# Docker hosts配置" /etc/hosts 2>/dev/null; then
        log_info "检测到已存在的 Docker hosts 配置，先移除旧配置..."
        # 移除旧的 Docker hosts 配置
        sed -i '/# Docker hosts配置/,/# End Docker hosts配置/d' /etc/hosts
    fi

    # 获取 Docker Hub 的真实 IP（通过 Google DNS 8.8.8.8）
    log_info "获取 Docker Hub 域名的真实 IP..."

    # 尝试解析 registry-1.docker.io
    DOCKER_REGISTRY_IP=$(nslookup registry-1.docker.io 8.8.8.8 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    # 尝试解析 index.docker.io
    DOCKER_INDEX_IP=$(nslookup index.docker.io 8.8.8.8 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    # 尝试解析 auth.docker.io
    DOCKER_AUTH_IP=$(nslookup auth.docker.io 8.8.8.8 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')

    # 如果解析失败，使用已知的可用 IP（这些需要定期更新）
    if [[ -z "$DOCKER_REGISTRY_IP" ]] || [[ "$DOCKER_REGISTRY_IP" == *"servfail"* ]]; then
        log_warning "无法自动解析 Docker Hub IP，使用备用 IP"
        DOCKER_REGISTRY_IP="54.198.65.55"  # 需要定期更新
        DOCKER_INDEX_IP="54.198.65.55"
        DOCKER_AUTH_IP="54.198.65.55"
    fi

    log_info "解析到的 IP 地址:"
    log_info "  registry-1.docker.io -> $DOCKER_REGISTRY_IP"
    log_info "  index.docker.io -> $DOCKER_INDEX_IP"
    log_info "  auth.docker.io -> $DOCKER_AUTH_IP"

    # 添加 hosts 配置
    cat >> /etc/hosts << EOF

# Docker hosts配置 - 自动生成于 $(date)
# 用于解决 DNS 污染导致的镜像拉取问题
$DOCKER_REGISTRY_IP registry-1.docker.io
$DOCKER_INDEX_IP index.docker.io
$DOCKER_AUTH_IP auth.docker.io
# End Docker hosts配置
EOF

    log_success "hosts 文件配置完成"

    # 验证配置
    log_info "验证域名解析..."
    if ping -c 1 -W 2 registry-1.docker.io > /dev/null 2>&1; then
        log_success "registry-1.docker.io 解析成功"
    else
        log_warning "registry-1.docker.io 解析测试失败（可能需要等待生效）"
    fi

    return 0
}

# 检测网络环境并提供解决方案
detect_network_environment() {
    log_info "检测网络环境..."

    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}网络环境检测:${NC}"

    # 测试 DNS 解析
    echo -e "\n${GREEN}1. DNS 解析测试:${NC}"

    if command -v nslookup &> /dev/null || command -v dig &> /dev/null; then
        # 测试当前 DNS
        if command -v nslookup &> /dev/null; then
            CURRENT_DNS_RESULT=$(nslookup registry-1.docker.io 2>/dev/null | grep "Address:" | tail -1)
            echo -e "  当前DNS解析: $CURRENT_DNS_RESULT"
        fi

        # 测试 Google DNS
        echo -e "  测试 Google DNS (8.8.8.8)..."
        if command -v nslookup &> /dev/null; then
            GOOGLE_DNS_RESULT=$(timeout 3 nslookup registry-1.docker.io 8.8.8.8 2>/dev/null | grep "Address:" | tail -1)
            if [[ -n "$GOOGLE_DNS_RESULT" ]]; then
                echo -e "    ${GREEN}✓${NC} $GOOGLE_DNS_RESULT"
            else
                echo -e "    ${RED}✗${NC} 无法连接到 Google DNS"
            fi
        fi
    else
        echo -e "  ${YELLOW}未安装 nslookup/dig 工具，跳过 DNS 测试${NC}"
    fi

    # 测试网络连接
    echo -e "\n${GREEN}2. 网络连接测试:${NC}"

    # 测试 Docker Hub 直连
    echo -e "  测试 Docker Hub 连接..."
    if timeout 5 curl -s -I https://registry-1.docker.io/v2/ > /dev/null 2>&1; then
        echo -e "    ${GREEN}✓${NC} 可以直接连接 Docker Hub"
    else
        echo -e "    ${YELLOW}△${NC} 无法直接连接 Docker Hub（可能需要代理）"
    fi

    # 测试国内镜像源
    echo -e "\n${GREEN}3. 国内镜像源测试:${NC}"
    local test_mirrors=(
        "https://docker.m.daocloud.io"
        "https://dockerproxy.com"
        "https://docker.nju.edu.cn"
        "https://hub-mirror.c.163.com"
    )

    for mirror in "${test_mirrors[@]}"; do
        if timeout 3 curl -s -I "$mirror/v2/" > /dev/null 2>&1; then
            echo -e "    ${GREEN}✓${NC} $mirror"
        else
            echo -e "    ${RED}✗${NC} $mirror"
        fi
    done

    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"

    # 提供建议
    echo -e "\n${YELLOW}网络优化建议:${NC}"
    echo -e "  1. 如果 DNS 解析异常，建议配置 hosts 文件"
    echo -e "  2. 如果直连 Docker Hub 失败，建议使用镜像加速器"
    echo -e "  3. 可以考虑配置代理服务器"

    return 0
}

# 配置Docker镜像加速器（多源 fallback）
configure_docker_mirror() {
    log_info "配置Docker镜像加速器（多源模式）..."

    # 测试镜像源是否可用
    test_mirror() {
        local url=$1
        if curl -s --connect-timeout 3 -I "$url/v2/" > /dev/null 2>&1; then
            return 0
        fi
        return 1
    }

    # 构建可用的镜像源列表
    local available_mirrors=()

    # 2024-2025 可用的镜像源
    local all_mirrors=(
        "https://docker.m.daocloud.io"
        "https://dockerproxy.com"
        "https://docker.nju.edu.cn"
        "https://docker.1panel.live"
        "https://hub-mirror.c.163.com"
        "https://mirror.baidubce.com"
        "https://docker.mirrors.ustc.edu.cn"
        "https://mirror.ccs.tencentyun.com"
    )

    # 测试每个镜像源
    for mirror in "${all_mirrors[@]}"; do
        log_info "测试镜像源: $mirror"
        if test_mirror "$mirror"; then
            log_success "镜像源可用: $mirror"
            available_mirrors+=("$mirror")
        else
            log_warning "镜像源不可用: $mirror"
        fi
    done

    # 检查是否有可用的镜像源
    if [[ ${#available_mirrors[@]} -eq 0 ]]; then
        log_warning "所有镜像源测试失败，但仍配置所有镜像源（Docker会自动fallback）"
        available_mirrors=("${all_mirrors[@]}")
    else
        log_success "共有 ${#available_mirrors[@]} 个镜像源可用"
    fi

    # 配置daemon.json
    log_info "配置Docker守护进程..."
    mkdir -p /etc/docker

    # 备份原配置
    if [[ -f /etc/docker/daemon.json ]]; then
        cp /etc/docker/daemon.json /etc/docker/daemon.json.backup.$(date +%Y%m%d%H%M%S)
    fi

    # 构建 registry-mirrors JSON 数组
    local mirrors_json="["
    local first=true
    for mirror in "${available_mirrors[@]}"; do
        if [[ "$first" == true ]]; then
            mirrors_json+="    \"$mirror\""
            first=false
        else
            mirrors_json+=","
            mirrors_json+="    \"$mirror\""
        fi
    done
    mirrors_json+="  ]"

    # 创建 daemon.json 配置文件
    cat > /etc/docker/daemon.json << EOF
{
  "registry-mirrors": $mirrors_json,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "dns": ["8.8.8.8", "114.114.114.114", "223.5.5.5"],
  "default-address-pools": [
    {
      "base": "172.17.0.0/16",
      "size": 24
    }
  ]
}
EOF

    log_success "已配置 ${#available_mirrors[@]} 个镜像加速器"
    echo -e "${CYAN}  已配置的镜像源:${NC}"
    for mirror in "${available_mirrors[@]}"; do
        echo -e "    - $mirror"
    done
    echo -e "${CYAN}  Docker会自动尝试这些镜像源，直到成功拉取镜像${NC}"

    # 验证 daemon.json 格式
    log_info "验证配置文件格式..."
    if command -v python3 &> /dev/null; then
        if ! python3 -m json.tool /etc/docker/daemon.json > /dev/null 2>&1; then
            log_error "daemon.json 格式错误！"
            cat /etc/docker/daemon.json
            log_error "请检查配置文件格式"
            return 1
        fi
        log_success "配置文件格式验证通过"
    fi

    # 停止 Docker（如果正在运行）
    log_info "停止 Docker 服务..."
    systemctl stop docker 2>/dev/null || true

    # 重启Docker服务
    log_info "启动 Docker 服务..."
    systemctl daemon-reload

    # 尝试启动 Docker 并捕获错误
    if ! systemctl start docker; then
        log_error "Docker 启动失败！"
        log_info "查看详细错误日志..."
        journalctl -xeu docker.service --no-pager -n 50 | tail -30
        log_info "daemon.json 内容："
        cat /etc/docker/daemon.json
        return 1
    fi

    # 设置开机自启
    systemctl enable docker 2>/dev/null || true

    # 等待 Docker 完全启动
    sleep 3

    # 验证 Docker 是否正常运行
    if ! systemctl is-active --quiet docker; then
        log_error "Docker 服务启动后未处于运行状态！"
        systemctl status docker --no-pager
        return 1
    fi

    log_success "Docker 服务启动成功"

    # 验证配置
    if docker info | grep -q "Registry Mirrors"; then
        log_success "Docker镜像加速器配置生效"
    else
        log_info "Docker配置完成"
    fi

    return 0
}

# 检查防火墙配置
check_and_config_firewall() {
    log_info "检查防火墙配置..."
    
    local firewall_type=""
    
    # 检测防火墙类型
    if systemctl is-active --quiet firewalld 2>/dev/null; then
        firewall_type="firewalld"
        log_info "检测到 firewalld"
    elif command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        firewall_type="ufw"
        log_info "检测到 ufw"
    elif iptables -L -n 2>/dev/null | wc -l > 8; then
        firewall_type="iptables"
        log_info "检测到 iptables"
    else
        log_info "未检测到活动防火墙"
        return 0
    fi
    
    # 配置防火墙规则
    log_info "配置防火墙规则..."
    case $firewall_type in
        "firewalld")
            # 添加Docker服务
            firewall-cmd --permanent --new-service=docker 2>/dev/null || true
            firewall-cmd --permanent --service=docker --set-description="Docker Service Ports" 2>/dev/null || true
            firewall-cmd --permanent --service=docker --add-port=2375/tcp 2>/dev/null || true
            firewall-cmd --permanent --service=docker --add-port=2376/tcp 2>/dev/null || true
            
            # 添加Docker Swarm端口
            firewall-cmd --permanent --add-port=2377/tcp 2>/dev/null || true
            firewall-cmd --permanent --add-port=7946/tcp 2>/dev/null || true
            firewall-cmd --permanent --add-port=7946/udp 2>/dev/null || true
            firewall-cmd --permanent --add-port=4789/udp 2>/dev/null || true
            
            # 添加Docker服务到默认区域
            firewall-cmd --permanent --add-service=docker 2>/dev/null || true
            
            # 重新加载
            firewall-cmd --reload 2>/dev/null || true
            log_success "firewalld配置完成"
            ;;
            
        "ufw")
            # 允许Docker端口
            ufw allow 2375/tcp 2>/dev/null || true
            ufw allow 2376/tcp 2>/dev/null || true
            ufw allow 2377/tcp 2>/dev/null || true
            ufw allow 7946/tcp 2>/dev/null || true
            ufw allow 7946/udp 2>/dev/null || true
            ufw allow 4789/udp 2>/dev/null || true
            
            # 重新加载
            ufw reload 2>/dev/null || true
            log_success "ufw配置完成"
            ;;
            
        "iptables")
            # 添加Docker规则
            iptables -A INPUT -p tcp --dport 2375 -j ACCEPT 2>/dev/null || true
            iptables -A INPUT -p tcp --dport 2376 -j ACCEPT 2>/dev/null || true
            iptables -A INPUT -p tcp --dport 2377 -j ACCEPT 2>/dev/null || true
            iptables -A INPUT -p tcp --dport 7946 -j ACCEPT 2>/dev/null || true
            iptables -A INPUT -p udp --dport 7946 -j ACCEPT 2>/dev/null || true
            iptables -A INPUT -p udp --dport 4789 -j ACCEPT 2>/dev/null || true
            
            log_success "iptables规则已添加"
            ;;
    esac
    
    return 0
}

# 最终验证和测试
final_validation() {
    log_info "进行最终验证..."
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    
    # 验证SSH服务
    log_info "1. 验证SSH服务..."
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        log_success "  SSH服务: 运行正常 ✓"
    else
        log_error "  SSH服务: 未运行 ✗"
    fi
    
    # 验证Docker服务
    log_info "2. 验证Docker服务..."
    if systemctl is-active --quiet docker; then
        log_success "  Docker服务: 运行正常 ✓"
        echo -e "    版本: $(docker --version | cut -d' ' -f3)"
    else
        log_error "  Docker服务: 未运行 ✗"
    fi
    
    # 验证Docker Compose插件
    log_info "3. 验证Docker Compose插件(v2)..."
    if docker compose version &> /dev/null; then
        COMPOSE_FULL_VERSION=$(docker compose version)
        log_success "  Docker Compose v2: 可用 ✓"
        echo -e "    命令: docker compose (v2语法)"
        echo -e "    版本: $COMPOSE_FULL_VERSION"
    else
        log_error "  Docker Compose v2: 不可用 ✗"
    fi
    
    # 测试镜像拉取
    log_info "4. 测试镜像拉取..."
    if timeout 30 docker pull hello-world:latest > /dev/null 2>&1; then
        log_success "  镜像拉取: 成功 ✓"
        # 清理测试镜像
        docker rmi hello-world:latest > /dev/null 2>&1 || true
    else
        log_error "  镜像拉取: 失败 ✗"
    fi
    
    # 检查网络连接
    log_info "5. 检查网络连接..."
    if ping -c 2 -W 2 8.8.8.8 > /dev/null 2>&1; then
        log_success "  网络连接: 正常 ✓"
    else
        log_warning "  网络连接: 不稳定 ⚠"
    fi
    
    echo -e "${CYAN}══════════════════════════════════════════════════════════${NC}"
    
    log_success "所有检查完成！"
    
    # 显示使用说明
    echo -e "\n${YELLOW}════════════════════ 使用说明 ════════════════════${NC}"
    echo -e "${GREEN}1. SSH连接:${NC}"
    echo -e "   ssh $(whoami)@$(hostname -I | awk '{print $1}')"
    echo -e ""
    echo -e "${GREEN}2. Docker基本命令:${NC}"
    echo -e "   docker ps                    # 查看运行中的容器"
    echo -e "   docker images                # 查看本地镜像"
    echo -e "   docker compose up -d         # 启动docker-compose服务 (v2语法)"
    echo -e "   docker compose down          # 停止docker-compose服务 (v2语法)"
    echo -e ""
    echo -e "${GREEN}3. 服务管理:${NC}"
    echo -e "   systemctl status docker      # 查看Docker状态"
    echo -e "   systemctl restart docker     # 重启Docker"
    echo -e "   journalctl -u docker -f      # 查看Docker日志"
    echo -e ""
    echo -e "${GREEN}4. 配置文件位置:${NC}"
    echo -e "   /etc/docker/daemon.json      # Docker主配置"
    echo -e "   /etc/ssh/sshd_config         # SSH配置"
    echo -e "   /etc/hosts                   # DNS配置（已配置Docker Hub）"
    echo -e ""
    echo -e "${GREEN}5. 故障排查:${NC}"
    echo -e "   docker info                  # 查看Docker详细信息"
    echo -e "   systemctl status docker      # 查看Docker服务状态"
    echo -e "   cat /etc/docker/daemon.json  # 查看配置文件"
    echo -e ""
    echo -e "${YELLOW}注意: 如果当前用户已添加到docker组，需要重新登录才能免sudo使用docker${NC}"
    echo -e "${YELLOW}注意: Docker Compose v2 使用 'docker compose' 命令（无横线）${NC}"
    echo -e "${YELLOW}══════════════════════════════════════════════════════════${NC}"
}

# 主函数
main() {
    print_banner
    check_root
    print_system_info
    
    # 步骤执行
    local steps=(
        "检查并配置SSH服务" check_and_config_ssh
        "更新系统包" update_system_packages
        "安装Docker和Compose" install_docker_and_compose
        "检测网络环境" detect_network_environment
        "配置hosts解决DNS污染" configure_hosts_for_docker
        "配置Docker镜像加速器" configure_docker_mirror
        "配置防火墙规则" check_and_config_firewall
        "最终验证" final_validation
    )
    
    local total_steps=$((${#steps[@]} / 2))
    local current_step=1
    
    for ((i=0; i<${#steps[@]}; i+=2)); do
        local step_name="${steps[i]}"
        local step_func="${steps[i+1]}"
        
        echo -e "\n${CYAN}[步骤 $current_step/$total_steps] $step_name${NC}"
        echo -e "${CYAN}──────────────────────────────────────────────────────${NC}"
        
        if $step_func; then
            log_success "$step_name 完成"
        else
            log_error "$step_name 失败"
            echo -e "${YELLOW}是否继续? (y/n)${NC}"
            read -r response
            if [[ ! "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
                log_error "脚本中止"
                exit 1
            fi
        fi
        
        ((current_step++))
    done
    
    echo -e "\n${GREEN}══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                 所有任务已完成！                          ${NC}"
    echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
    
    # 建议重启系统
    echo -e "\n${YELLOW}建议:${NC}"
    echo -e "  建议重启系统以使所有更改生效: ${GREEN}reboot${NC}"
    echo -e "  或重新登录以使docker组权限生效"
}

# 异常处理
trap 'log_error "脚本执行被中断"; exit 1' INT TERM

# 执行主函数
main "$@"

exit 0