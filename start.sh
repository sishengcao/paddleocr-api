#!/bin/bash

echo "================================"
echo "  PaddleOCR API 服务"
echo "================================"
echo ""

# 检查 Python
if ! command -v python3 &> /dev/null; then
    echo "[错误] 未找到 Python3，请先安装 Python 3.8+"
    exit 1
fi

# 检查虚拟环境
if [ ! -d "venv" ]; then
    echo "[信息] 创建虚拟环境..."
    python3 -m venv venv
fi

# 激活虚拟环境
source venv/bin/activate

# 安装依赖
echo "[信息] 检查并安装依赖..."
pip install -r requirements.txt

# 启动服务
echo ""
echo "[信息] 启动 PaddleOCR API 服务..."
echo ""
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
