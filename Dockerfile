# PaddleOCR API - Docker 镜像
# 基础镜像：使用 Python 3.10 官方镜像
FROM python:3.10-slim

# 设置工作目录
WORKDIR /app

# 设置环境变量
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# 配置 DNS 和国内软件源
RUN echo "nameserver 8.8.8.8" > /etc/resolv.conf && \
    echo "nameserver 114.114.114.114" >> /etc/resolv.conf && \
    if [ -f /etc/os-release ]; then \
        CODENAME=$(grep "^VERSION_CODENAME=" /etc/os-release | cut -d'=' -f2); \
        echo "Debian 版本: $CODENAME"; \
        if [ -f /etc/apt/sources.list.d/debian.sources ]; then \
            echo "配置新版 debian.sources"; \
            cat > /etc/apt/sources.list.d/debian.sources <<EOF
Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/debian
Suites: $CODENAME $CODENAME-updates $CODENAME-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://mirrors.tuna.tsinghua.edu.cn/debian-security
Suites: $CODENAME-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
        else \
            echo "配置传统 sources.list"; \
            sed -i "s|deb.debian.org|mirrors.tuna.tsinghua.edu.cn|g" /etc/apt/sources.list || true; \
            sed -i "s|security.debian.org|mirrors.tuna.tsinghua.edu.cn|g" /etc/apt/sources.list || true; \
        fi \
    fi && \
    echo "测试网络连通性..." && \
    ping -c 2 -W 3 8.8.8.8 > /dev/null 2>&1 || echo "警告: 无法 ping 通 8.8.8.8" && \
    curl -s --connect-timeout 5 https://mirrors.tuna.tsinghua.edu.cn > /dev/null 2>&1 || echo "警告: 无法连接到清华镜像源"

# 安装系统依赖（添加重试机制）
RUN echo "开始安装系统依赖..." && \
    for i in 1 2 3; do \
        apt-get update && apt-get install -y \
            libgl1-mesa-glx \
            libglib2.0-0 \
            libsm6 \
            libxext6 \
            libxrender-dev \
            libgomp1 \
            build-essential \
            curl \
        && rm -rf /var/lib/apt/lists/* && break || \
        echo "第 $i 次尝试失败，等待 5 秒后重试..." && sleep 5; \
    done && \
    echo "系统依赖安装完成"

# 复制依赖文件
COPY requirements.txt .

# 安装 Python 依赖（使用清华镜像源加速）
RUN pip install --no-cache-dir -r requirements.txt \
    -i https://pypi.tuna.tsinghua.edu.cn/simple

# 复制应用代码
COPY app ./app
COPY static ./static

# 创建必要的目录
RUN mkdir -p logs temp uploads

# 暴露端口
EXPOSE 8000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD python -c "import requests; requests.get('http://localhost:8000/api/ocr/health', timeout=5)" || exit 1

# 启动命令
CMD ["python", "-m", "uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
