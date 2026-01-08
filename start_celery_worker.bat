@echo off
REM =====================================================
REM PaddleOCR API - Celery Worker 启动脚本
REM =====================================================

echo.
echo ========================================
echo PaddleOCR API - Celery Worker
echo ========================================
echo.

REM 设置项目根目录
set PROJECT_DIR=%~dp0
cd /d "%PROJECT_DIR%"

REM 激活虚拟环境（如果存在）
if exist "venv\Scripts\activate.bat" (
    echo 激活虚拟环境...
    call venv\Scripts\activate.bat
)

REM 检查 Redis 是否运行
echo.
echo 检查 Redis 连接...
redis-cli ping >nul 2>&1
if %errorlevel% neq 0 (
    echo [警告] Redis 似乎未运行！
    echo 请先启动 Redis 服务后再运行此脚本。
    echo.
    echo 启动 Redis 方法:
    echo   - Windows: redis-server.exe
    echo   - Docker: docker run -d -p 6379:6379 redis
    echo.
    pause
    exit /b 1
)
echo [OK] Redis 连接正常

REM 启动 Celery Worker
echo.
echo 启动 Celery Worker...
echo.
celery -A app.workers.celery_worker worker --loglevel=info --concurrency=4 --pool=solo

REM 如果出错则暂停
if %errorlevel% neq 0 (
    echo.
    echo [错误] Celery Worker 启动失败！
    echo.
    pause
    exit /b 1
)

echo.
echo Celery Worker 已停止
pause
