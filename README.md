# PaddleOCR API 服务

基于 PaddleOCR 的图片文字识别 API 服务，提供 HTTP 接口进行 OCR 识别。

## 功能特性

- ✅ 支持中英文识别
- ✅ 单张/批量图片识别
- ✅ 返回详细识别结果（文字框坐标、置信度）
- ✅ 异步处理，支持高并发
- ✅ 完善的错误处理
- ✅ API 文档自动生成
- ✅ Docker 容器化部署
- ✅ 一键 Linux 自动部署脚本

## 快速开始

### 方式一：Windows 本地运行

### 1. 安装依赖

```bash
# 克隆项目
cd D:\project\paddleocr-api

# 创建虚拟环境（推荐）
python -m venv venv

# 激活虚拟环境
# Windows:
venv\Scripts\activate
# Linux/Mac:
source venv/bin/activate

# 安装依赖
pip install -r requirements.txt
```

### 2. 启动服务

**Windows:**
```bash
start.bat
```

**Linux/Mac:**
```bash
chmod +x start.sh
./start.sh
```

**或手动启动:**
```bash
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

### 3. 访问文档

服务启动后，访问：
- API 文档：http://localhost:8000/docs
- 健康检查：http://localhost:8000/api/ocr/health

### 方式二：Linux 一键自动部署

**适用于全新安装的 Linux 虚拟机（Ubuntu/Debian/CentOS/Fedora）**

```bash
# 1. 克隆项目
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api

# 2. 运行自动部署脚本
chmod +x deploy-linux.sh
./deploy-linux.sh
```

**脚本功能：**
- 自动检测 Linux 发行版
- 自动安装 Python3、pip 和虚拟环境工具
- 自动安装系统依赖（PaddleOCR 所需）
- 创建并配置 Python 虚拟环境
- 安装所有 Python 依赖包
- 可选：创建 systemd 系统服务（开机自启）

**手动启动服务：**
```bash
source venv/bin/activate
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

**使用 systemd 服务（如果安装时选择创建）：**
```bash
# 启动服务
sudo systemctl start paddleocr-api

# 停止服务
sudo systemctl stop paddleocr-api

# 重启服务
sudo systemctl restart paddleocr-api

# 查看服务状态
sudo systemctl status paddleocr-api

# 查看服务日志
sudo journalctl -u paddleocr-api -f
```

### 方式三：Docker 容器化部署

**最推荐的部署方式，环境隔离，跨平台运行**

#### 1. 使用 Docker 构建和运行

```bash
# 克隆项目
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api

# 构建 Docker 镜像
docker build -t paddleocr-api:latest .

# 运行容器
docker run -d \
  --name paddleocr-api \
  -p 8000:8000 \
  -v $(pwd)/logs:/app/logs \
  -v $(pwd)/uploads:/app/uploads \
  --restart unless-stopped \
  paddleocr-api:latest
```

#### 2. 使用 Docker Compose（推荐）

```bash
# 克隆项目
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api

# 一键启动
docker-compose up -d

# 查看日志
docker-compose logs -f

# 停止服务
docker-compose down

# 重启服务
docker-compose restart
```

**Docker Compose 配置说明：**
- 端口映射：`8000:8000`
- 日志目录：`./logs` → `/app/logs`
- 上传目录：`./uploads` → `/app/uploads`
- 资源限制：2 CPU，2GB 内存（可修改 `docker-compose.yml` 调整）
- 健康检查：每 30 秒检查一次服务状态

#### 3. Docker 常用命令

```bash
# 查看容器状态
docker ps

# 查看容器日志
docker logs -f paddleocr-api

# 进入容器
docker exec -it paddleocr-api bash

# 停止容器
docker stop paddleocr-api

# 启动容器
docker start paddleocr-api

# 删除容器
docker rm paddleocr-api

# 删除镜像
docker rmi paddleocr-api:latest

# 查看容器资源使用
docker stats paddleocr-api
```

#### 4. 自定义配置

修改 `docker-compose.yml` 中的环境变量：

```yaml
environment:
  - PORT=8000              # 服务端口
  - OCR_LANG=ch            # 语言：ch-中文, en-英文
  - OCR_USE_GPU=false      # 是否使用 GPU（需要 nvidia-docker）
  - LOG_LEVEL=info         # 日志级别
```

#### 5. 使用 GPU 加速

如果宿主机有 NVIDIA GPU 并安装了 nvidia-docker：

```bash
# 安装 nvidia-docker（如果未安装）
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update && sudo apt-get install -y nvidia-docker2
sudo systemctl restart docker

# 修改 docker-compose.yml，添加 GPU 支持
services:
  paddleocr-api:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: 1
              capabilities: [gpu]
```

然后修改 Dockerfile，使用 GPU 版本的 PaddlePaddle：

```dockerfile
# 替换 requirements.txt 中的安装命令
RUN pip uninstall paddlepaddle -y && \
    pip install paddlepaddle-gpu==2.6.2 -i https://pypi.tuna.tsinghua.edu.cn/simple
```

## API 接口

### 1. 识别单张图片

**请求：**
```bash
POST /api/ocr/recognize
Content-Type: multipart/form-data
```

**参数：**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| file | File | 是 | 图片文件 |
| lang | string | 否 | 语言类型（默认：ch） |
| use_angle_cls | boolean | 否 | 是否使用文字方向分类（默认：true） |
| return_details | boolean | 否 | 是否返回详细信息（默认：true） |

**响应：**
```json
{
  "success": true,
  "text": "完整识别文本",
  "details": [
    {
      "text": "每行文字",
      "confidence": 0.99,
      "box": [[x1, y1], [x2, y2], [x3, y3], [x4, y4]]
    }
  ],
  "processing_time": 1.23,
  "error": null
}
```

### 2. 批量识别图片

**请求：**
```bash
POST /api/ocr/recognize-batch
Content-Type: multipart/form-data
```

**参数：**
| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| files | File[] | 是 | 图片文件列表（最多10张） |
| lang | string | 否 | 语言类型 |
| use_angle_cls | boolean | 否 | 是否使用文字方向分类 |
| return_details | boolean | 否 | 是否返回详细信息 |

## 使用示例

### Python 调用

```python
import requests

# 识别单张图片
url = "http://localhost:8000/api/ocr/recognize"
files = {"file": open("test.jpg", "rb")}
data = {
    "lang": "ch",
    "use_angle_cls": True,
    "return_details": True
}

response = requests.post(url, files=files, data=data)
result = response.json()

print("识别文本:", result["text"])
print("处理耗时:", result["processing_time"], "秒")
```

### curl 调用

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@test.jpg" \
  -F "lang=ch" \
  -F "use_angle_cls=true"
```

### JavaScript 调用

```javascript
const formData = new FormData();
formData.append('file', fileInput.files[0]);
formData.append('lang', 'ch');

fetch('http://localhost:8000/api/ocr/recognize', {
  method: 'POST',
  body: formData
})
.then(res => res.json())
.then(data => {
  console.log('识别结果:', data.text);
});
```

## 配置说明

编辑 `.env` 文件：

```env
# 服务端口
PORT=8000

# OCR 配置
OCR_LANG=ch           # 语言：ch-中文, en-英文
OCR_USE_GPU=false     # 是否使用 GPU（需要安装 paddlepaddle-gpu）

# 日志级别
LOG_LEVEL=info
```

## 目录结构

```
paddleocr-api/
├── app/
│   ├── __init__.py
│   ├── main.py           # FastAPI 主应用
│   ├── ocr_service.py    # OCR 服务封装
│   └── schemas.py        # 数据模型
├── static/               # 静态文件（Web UI）
├── temp/                 # 临时文件目录
├── uploads/              # 上传文件目录
├── logs/                 # 日志目录
├── requirements.txt      # Python 依赖列表
├── Dockerfile            # Docker 镜像构建文件
├── docker-compose.yml    # Docker Compose 配置
├── .dockerignore         # Docker 忽略文件
├── .env                  # 环境配置
├── start.bat             # Windows 启动脚本
├── start.sh              # Linux/Mac 启动脚本
├── deploy-linux.sh       # Linux 自动部署脚本
└── README.md             # 项目文档
```

## 常见问题

### 1. 首次启动慢
首次启动会下载 PaddleOCR 模型文件（约 10MB），请耐心等待。

### 2. GPU 加速
如需使用 GPU 加速：
```bash
pip uninstall paddlepaddle
pip install paddlepaddle-gpu
```
然后修改 `.env` 文件：`OCR_USE_GPU=true`

### 3. 端口被占用
修改 `.env` 文件中的 `PORT` 配置。

## 技术栈

- FastAPI - Web 框架
- PaddleOCR - OCR 引擎
- Uvicorn - ASGI 服务器
- Pydantic - 数据验证

## 许可证

MIT License
