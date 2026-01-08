@echo off
chcp 65001 >nul
echo ================================
echo   PaddleOCR API 服务
echo ================================
echo.

REM 检查 Python 是否安装
python --version >nul 2>&1
if errorlevel 1 (
    echo [错误] 未找到 Python，请先安装 Python 3.8+
    pause
    exit /b 1
)

REM 检查虚拟环境
if not exist "venv" (
    echo [信息] 创建虚拟环境...
    python -m venv venv
)

REM 激活虚拟环境
call venv\Scripts\activate.bat

REM 安装依赖
echo [信息] 检查并安装依赖...
pip install -r requirements.txt -i https://pypi.tuna.tsinghua.edu.cn/simple

REM 启动服务
echo.
echo [信息] 启动 PaddleOCR API 服务...
echo.
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload

pause
