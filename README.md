# PaddleOCR API 服务

基于 PaddleOCR 的图片文字识别 API 服务，提供 HTTP 接口进行 OCR 识别。

## 功能特性

- ✅ 支持中英文识别
- ✅ 单张/批量图片识别
- ✅ 返回详细识别结果（文字框坐标、置信度）
- ✅ 异步处理，支持高并发
- ✅ 完善的错误处理
- ✅ API 文档自动生成

## 快速开始

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
├── temp/                 # 临时文件目录
├── uploads/              # 上传文件目录
├── requirements.txt      # 依赖列表
├── .env                 # 环境配置
├── start.bat            # Windows 启动脚本
├── start.sh             # Linux 启动脚本
└── README.md            # 项目文档
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
