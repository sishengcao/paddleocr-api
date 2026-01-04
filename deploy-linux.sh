#!/bin/bash

################################################################################
# PaddleOCR API - Linux 自动部署脚本
# 适用于：Ubuntu/Debian、CentOS/RHEL、Fedora
# 适用于全新安装的 Linux 虚拟机
################################################################################

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

# 检测 Linux 发行版
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
        log_info "检测到系统: $DISTRO $VERSION"
    else
        log_error "无法检测 Linux 发行版"
        exit 1
    fi
}

# 检查命令是否存在
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# 安装 Python3 和依赖 (Ubuntu/Debian)
install_ubuntu() {
    log_info "更新软件包列表..."
    sudo apt-get update -y

    log_info "安装 Python3、pip 和虚拟环境工具..."
    sudo apt-get install -y python3 python3-pip python3-venv build-essential

    log_info "安装系统依赖（PaddleOCR 需要）..."
    sudo apt-get install -y libgl1-mesa-glx libglib2.0-0 libsm6 libxext6 libxrender-dev libgomp1
}

# 安装 Python3 和依赖 (CentOS/RHEL/Fedora)
install_centos() {
    log_info "安装 Python3 和 pip..."
    sudo yum install -y python3 python3-pip

    log_info "安装系统依赖..."
    sudo yum install -y gcc-c++ mesa-libGL mesa-libGL-devel glib2 libSM libXext libXrender libgomp
}

# 创建虚拟环境
create_venv() {
    if [ -d "venv" ]; then
        log_warn "虚拟环境已存在，跳过创建"
    else
        log_info "创建 Python 虚拟环境..."
        python3 -m venv venv
    fi
}

# 激活虚拟环境并安装依赖
install_dependencies() {
    log_info "激活虚拟环境并安装依赖..."
    source venv/bin/activate

    # 升级 pip
    log_info "升级 pip 到最新版本..."
    pip install --upgrade pip -i https://pypi.tuna.tsinghua.edu.cn/simple

    # 安装项目依赖
    log_info "安装项目依赖（可能需要几分钟）..."
    pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

    log_info "依赖安装完成！"
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    mkdir -p logs temp uploads static
}

# 创建 .env 文件
create_env_file() {
    if [ ! -f ".env" ]; then
        log_info "创建 .env 配置文件..."
        cat > .env << 'EOF'
# 服务端口
PORT=8000

# OCR 配置
OCR_LANG=ch           # 语言：ch-中文, en-英文
OCR_USE_GPU=false     # 是否使用 GPU（需要安装 paddlepaddle-gpu）

# 日志级别
LOG_LEVEL=info
EOF
    else
        log_warn ".env 文件已存在，跳过创建"
    fi
}

# 创建 systemd 服务（可选）
create_systemd_service() {
    read -p "是否创建 systemd 服务（开机自启）？[y/N]: " create_service
    if [[ $create_service =~ ^[Yy]$ ]]; then
        SERVICE_NAME="paddleocr-api"
        SERVICE_PATH="/etc/systemd/system/${SERVICE_NAME}.service"

        log_info "创建 systemd 服务..."
        sudo tee $SERVICE_PATH > /dev/null << EOF
[Unit]
Description=PaddleOCR API Service
After=network.target

[Service]
Type=simple
User=$USER
WorkingDirectory=$(pwd)
Environment="PATH=$(pwd)/venv/bin:/usr/local/bin:/usr/bin:/bin"
ExecStart=$(pwd)/venv/bin/python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

        log_info "重载 systemd 配置..."
        sudo systemctl daemon-reload

        log_info "启用服务..."
        sudo systemctl enable $SERVICE_NAME

        log_info "服务已创建！使用以下命令管理："
        echo "  启动服务: sudo systemctl start $SERVICE_NAME"
        echo "  停止服务: sudo systemctl stop $SERVICE_NAME"
        echo "  重启服务: sudo systemctl restart $SERVICE_NAME"
        echo "  查看状态: sudo systemctl status $SERVICE_NAME"
        echo "  查看日志: sudo journalctl -u $SERVICE_NAME -f"
    fi
}

# 主函数
main() {
    echo "=============================================="
    echo "  PaddleOCR API - Linux 自动部署脚本"
    echo "=============================================="
    echo ""

    # 检测发行版
    detect_distro

    # 检查 Python3
    if command_exists python3; then
        log_info "Python3 已安装: $(python3 --version)"
    else
        log_info "Python3 未安装，开始安装..."
        case $DISTRO in
            ubuntu|debian)
                install_ubuntu
                ;;
            centos|rhel|fedora)
                install_centos
                ;;
            *)
                log_error "不支持的发行版: $DISTRO"
                exit 1
                ;;
        esac
    fi

    # 检查 pip
    if ! command_exists pip3 && ! python3 -m pip --version >/dev/null 2>&1; then
        log_error "pip 未安装，请先安装 pip"
        exit 1
    fi

    # 创建目录
    create_directories

    # 创建虚拟环境
    create_venv

    # 安装依赖
    install_dependencies

    # 创建 .env 文件
    create_env_file

    # 创建 systemd 服务（可选）
    create_systemd_service

    echo ""
    log_info "========================================"
    log_info "部署完成！"
    log_info "========================================"
    echo ""
    echo "启动服务："
    echo "  手动启动: source venv/bin/activate && python -m uvicorn app.main:app --host 0.0.0.0 --port 8000"
    echo "  或使用服务: sudo systemctl start paddleocr-api (如果已创建)"
    echo ""
    echo "访问地址："
    echo "  Web UI: http://localhost:8000/"
    echo "  API 文档: http://localhost:8000/docs"
    echo "  健康检查: http://localhost:8000/api/ocr/health"
    echo ""
}

# 运行主函数
main
