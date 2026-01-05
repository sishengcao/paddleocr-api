# PaddleOCR API 服务

基于 PaddleOCR 的图片文字识别 API 服务，提供单个识别和批量扫描两种功能，可独立部署或组合部署。

## 功能特性

### 单个识别功能（基础功能）
- ✅ 支持中英文识别
- ✅ 单张/批量图片同步识别
- ✅ 返回详细识别结果（文字框坐标、置信度）
- ✅ 完善的错误处理
- ✅ API 文档自动生成
- ✅ 无需额外依赖，开箱即用

### 批量扫描功能（扩展功能）
- ✅ 异步任务队列处理（Celery + Redis）
- ✅ 数据库存储识别结果（MySQL）
- ✅ 支持大目录批量扫描
- ✅ 任务状态追踪和进度查询
- ✅ 重复任务检测
- ✅ 结果导出（JSON/CSV）
- ✅ Web 可视化界面
- ✅ 完整的任务管理（取消/删除/重试）

## 部署模式

### 模式 1：仅单个识别（基础模式）
**适用场景**：单次识别、小批量同步识别
**依赖**：仅需 Python 环境
**无需**：MySQL、Redis、Celery Worker

### 模式 2：单个识别 + 批量扫描（完整模式）
**适用场景**：大量图片处理、目录扫描、任务队列
**依赖**：Python + MySQL + Redis + Celery Worker

---

## 快速开始

### Windows 部署

#### 仅单个识别功能

```batch
# 1. 克隆项目
cd D:\project\paddleocr-api

# 2. 创建虚拟环境
python -m venv venv
venv\Scripts\activate

# 3. 安装依赖
pip install -r requirements.txt

# 4. 启动服务
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

访问：http://localhost:8000/docs

---

### Linux/WSL 部署

#### 仅单个识别功能

```bash
# 1. 克隆项目
cd /opt/paddleocr-api

# 2. 创建虚拟环境
python3 -m venv venv
source venv/bin/activate

# 3. 安装依赖
pip install -r requirements.txt

# 4. 启动服务
python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000
```

#### 完整功能（单个识别 + 批量扫描）

##### 1. 安装依赖服务

**安装 MySQL**
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install mysql-server -y
sudo systemctl start mysql

# 创建数据库
sudo mysql -e "CREATE DATABASE paddleocr_api CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER 'paddleocr'@'localhost' IDENTIFIED BY 'your_password';"
sudo mysql -e "GRANT ALL PRIVILEGES ON paddleocr_api.* TO 'paddleocr'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# 导入数据库结构
mysql -u root -p paddleocr_api < migrations/001_initial_schema.sql
```

**安装 Redis**
```bash
# Ubuntu/Debian
sudo apt install redis-server -y
sudo systemctl start redis

# 或使用 Docker
docker run -d --name redis -p 6379:6379 redis:latest
```

##### 2. 配置环境变量

编辑 `.env` 文件：

```ini
# =====================================================
# 应用配置
# =====================================================
APP_NAME=PaddleOCR API
APP_VERSION=2.0.0
DEBUG=false
LOG_LEVEL=INFO

# =====================================================
# 服务器配置
# =====================================================
HOST=0.0.0.0
PORT=8000
WORKERS=4

# =====================================================
# 数据库配置（批量扫描功能需要）
# =====================================================
# MySQL 地址
DB_HOST=localhost        # 或远程地址如 172.27.243.32
DB_PORT=3306
DB_USER=paddleocr        # 或 root
DB_PASSWORD=your_password
DB_NAME=paddleocr_api

# 连接池配置
DB_POOL_SIZE=20
DB_MAX_OVERFLOW=40
DB_POOL_TIMEOUT=30
DB_POOL_RECYCLE=3600

# =====================================================
# Redis 配置（批量扫描功能需要）
# =====================================================
REDIS_HOST=localhost        # 或远程地址如 172.27.243.32
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=             # 如果设置了密码

# =====================================================
# Celery 配置（批量扫描功能需要）
# =====================================================
CELERY_WORKER_CONCURRENCY=4
CELERY_WORKER_MAX_TASKS_PER_CHILD=1000

# =====================================================
# OCR 配置
# =====================================================
OCR_LANG=ch
OCR_USE_GPU=false
OCR_USE_ANGLE_CLS=true

# =====================================================
# 任务配置
# =====================================================
TASK_DEFAULT_PRIORITY=5
TASK_MAX_RETRIES=3
TASK_RETRY_DELAY=60
TASK_LOCK_TTL=3600
TASK_DUPLICATE_DETECTION=true

# =====================================================
# 导出配置
# =====================================================
EXPORT_TTL_HOURS=24

# =====================================================
# API 配置
# =====================================================
API_PREFIX=/api/ocr
MAX_UPLOAD_SIZE=104857600
MAX_BATCH_FILES=10
```

##### 3. 初始化数据库

```bash
# 执行数据库迁移脚本
mysql -h localhost -u paddleocr -p paddleocr_api < migrations/001_initial_schema.sql

# 如果已升级到新版本，执行第二个脚本
mysql -h localhost -u paddleocr -p paddleocr_api < migrations/002_add_json_data_column.sql
```

##### 4. 启动服务

**方式一：使用启动脚本**
```bash
chmod +x start_services.sh
./start_services.sh
```

**方式二：手动启动**
```bash
# 激活虚拟环境
source venv/bin/activate

# 启动 Celery Worker（批量扫描功能需要）
nohup python3 -m celery -A app.workers.celery_worker worker \
  --loglevel=info \
  --concurrency=4 \
  --pool=solo \
  > /tmp/celery.log 2>&1 &

# 启动 API 服务
nohup python3 -m uvicorn app.main:app --host 0.0.0.0 --port 8000 \
  > /tmp/api.log 2>&1 &
```

##### 5. 验证服务

```bash
# 检查 API 服务
curl http://localhost:8000/api/ocr/health

# 检查 Celery Worker
tail -f /tmp/celery.log

# 查看进程
ps aux | grep -E "uvicorn|celery"
```

---

### Docker Compose 部署（推荐）

> **要求**: Docker Compose v2（检查版本：`docker compose version`）
>
> **遇到问题？** 查看 [部署故障排查指南](DEPLOYMENT_TROUBLESHOOTING.md) 获取详细解决方案

使用 Docker Compose v2 可以一键启动所有服务（API + MySQL + Redis）：

```bash
# 前置要求：Docker Compose v2
# 检查版本：docker compose version

# 1. 克隆项目
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api

# 2. 创建环境变量文件
cp .env.example .env
# 如果 .env.example 不存在，手动创建 .env 文件，参考下方配置

# 3. (可选) 配置 Docker 镜像加速器
# 如果拉取镜像失败，执行以下命令：
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": [
    "https://docker.1panel.live",
    "https://docker.xuanyuan.me"
  ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker

# 4. 启动所有服务
docker compose up -d

# 5. 查看日志
docker compose logs -f

# 6. 查看服务状态
docker compose ps

# 7. 停止服务
docker compose down
```

**Docker Compose 服务架构**：
- `paddleocr-api`: API 服务（端口 8000）
- `mysql`: MySQL 数据库（端口 3306）
- `redis`: Redis 缓存（端口 6379）
- `celery-worker`: Celery 任务处理器

---

## 访问方式

### Web 界面

| 功能 | 地址 | 说明 |
|------|------|------|
| API 文档 | http://localhost:8000/docs | Swagger UI |
| API 文档（增强） | http://localhost:8000/docs-enhanced | ReDoc |
| 批量扫描界面 | http://localhost:8000/batch | 批量识别 Web UI |
| 健康检查 | http://localhost:8000/api/ocr/health | 服务健康状态 |

### API 端点

#### 单个识别功能

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/ocr/health` | GET | 健康检查 |
| `/api/ocr/status` | GET | 服务状态 |
| `/api/ocr/recognize` | POST | 识别单张图片 |
| `/api/ocr/recognize-batch` | POST | 批量识别图片（同步） |

#### 批量扫描功能

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/ocr/batch/scan` | POST | 创建批量扫描任务 |
| `/api/ocr/batch/start/{task_id}` | POST | 启动任务 |
| `/api/ocr/batch/status/{task_id}` | GET | 查询任务状态 |
| `/api/ocr/batch/cancel/{task_id}` | POST | 取消任务 |
| `/api/ocr/batch/delete/{task_id}` | POST | 删除任务 |
| `/api/ocr/batch/tasks` | GET | 列出所有任务 |
| `/api/ocr/batch/export` | POST | 导出任务结果 |
| `/api/ocr/batch/download/{task_id}` | GET | 下载导出文件 |

---

## 日志查看

### Linux/WSL

```bash
# API 服务日志
tail -f logs/api.log

# Celery Worker 日志
tail -f logs/celery_worker.log

# 或使用临时日志
tail -f /tmp/api.log
tail -f /tmp/celery.log
```

### Docker

```bash
# API 服务日志
docker compose logs -f paddleocr-api

# Celery Worker 日志
docker compose logs -f celery-worker

# MySQL 日志
docker compose logs -f mysql

# Redis 日志
docker compose logs -f redis
```

### Windows

```batch
# 查看 API 日志
type logs\api.log

# 实时监控（PowerShell）
Get-Content logs\api.log -Wait -Tail 50
```

---

## 数据库表结构

### books（书籍表）
存储书籍/项目的基本信息

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT | 主键 |
| book_id | VARCHAR(255) | 书籍唯一标识 |
| title | VARCHAR(500) | 书名 |
| author | VARCHAR(255) | 作者 |
| category | VARCHAR(100) | 分类 |
| description | TEXT | 描述 |
| source_directory | VARCHAR(1000) | 源目录 |
| total_pages | INT | 总页数 |
| total_volumes | INT | 总卷数 |
| metadata | JSON | 额外元数据 |
| created_at | TIMESTAMP | 创建时间 |
| updated_at | TIMESTAMP | 更新时间 |

### batch_tasks（批量任务表）
存储批量扫描任务信息

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT | 主键 |
| task_id | VARCHAR(36) | 任务 UUID |
| book_id | VARCHAR(255) | 关联书籍 |
| task_name | VARCHAR(500) | 任务名称 |
| source_directory | VARCHAR(1000) | 源目录 |
| lang | VARCHAR(10) | OCR 语言 |
| use_angle_cls | TINYINT | 使用角度分类 |
| text_layout | VARCHAR(20) | 文字排版方向 |
| output_format | VARCHAR(30) | 输出格式 |
| recursives | TINYINT | 递归扫描 |
| file_patterns | JSON | 文件匹配模式 |
| status | ENUM | 任务状态 |
| priority | INT | 优先级 |
| total_files | INT | 总文件数 |
| processed_files | INT | 已处理数 |
| success_files | INT | 成功数 |
| failed_files | INT | 失败数 |
| progress | DECIMAL(5,2) | 进度百分比 |
| celery_task_id | VARCHAR(255) | Celery 任务 ID |
| error_message | TEXT | 错误信息 |
| created_at | TIMESTAMP | 创建时间 |
| started_at | TIMESTAMP | 开始时间 |
| completed_at | TIMESTAMP | 完成时间 |

### ocr_results（OCR 结果表）
存储每张图片的识别结果

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT | 主键 |
| task_id | VARCHAR(36) | 关联任务 |
| book_id | VARCHAR(255) | 关联书籍 |
| page_id | VARCHAR(36) | 页面唯一标识 |
| file_name | VARCHAR(255) | 文件名 |
| page_number | INT | 页码 |
| raw_text | LONGTEXT | 识别文字 |
| json_data | JSON | 完整 JSON 数据（含 box 坐标） |
| volume | VARCHAR(100) | 卷号 |
| confidence | DECIMAL(5,4) | 置信度 |
| success | TINYINT | 识别成功状态 |
| processing_time | DECIMAL(10,3) | 处理时间（秒） |
| created_at | TIMESTAMP | 创建时间 |

### exports（导出记录表）
存储任务导出记录

| 字段 | 类型 | 说明 |
|------|------|------|
| id | BIGINT | 主键 |
| export_id | VARCHAR(36) | 导出 UUID |
| task_id | VARCHAR(36) | 关联任务 |
| book_id | VARCHAR(255) | 关联书籍 |
| export_format | ENUM | 导出格式 |
| include_images | TINYINT | 包含图片 |
| include_details | TINYINT | 包含详细信息 |
| status | ENUM | 导出状态 |
| file_path | VARCHAR(1000) | 文件路径 |
| expires_at | TIMESTAMP | 过期时间 |
| created_at | TIMESTAMP | 创建时间 |

---

## 使用示例

### 1. 单个图片识别

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@test.jpg" \
  -F "lang=ch" \
  -F "use_angle_cls=true"
```

### 2. 批量识别（同步）

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize-batch" \
  -F "files=@img1.jpg" \
  -F "files=@img2.jpg" \
  -F "lang=ch"
```

### 3. 创建批量扫描任务（异步）

```bash
curl -X POST "http://localhost:8000/api/ocr/batch/scan" \
  -H "Content-Type: application/json" \
  -d '{
    "book_id": "廖氏族谱",
    "directory": "/mnt/f/部分族谱",
    "lang": "ch",
    "recursive": true,
    "file_patterns": ["*.jpg", "*.jpeg", "*.JPG", "*.JPEG"]
  }'
```

### 4. 启动批量任务

```bash
curl -X POST "http://localhost:8000/api/ocr/batch/start/{task_id}"
```

### 5. 查询任务状态

```bash
curl "http://localhost:8000/api/ocr/batch/status/{task_id}"
```

### 6. 导出任务结果

```bash
curl -X POST "http://localhost:8000/api/ocr/batch/export" \
  -H "Content-Type: application/json" \
  -d '{
    "task_id": "task-uuid",
    "format": "json"
  }'
```

---

## Python 调用示例

### 单个识别

```python
import requests

# 识别单张图片
url = "http://localhost:8000/api/ocr/recognize"
with open("test.jpg", "rb") as f:
    files = {"file": f}
    data = {"lang": "ch", "use_angle_cls": True}
    response = requests.post(url, files=files, data=data)
    result = response.json()
    print("识别文本:", result["text"])
```

### 批量扫描

```python
import requests
import time

# 1. 创建任务
url = "http://localhost:8000/api/ocr/batch/scan"
data = {
    "book_id": "廖氏族谱",
    "directory": "/path/to/images",
    "lang": "ch",
    "recursive": True
}
response = requests.post(url, json=data)
task_id = response.json()["task_id"]

# 2. 启动任务
requests.post(f"http://localhost:8000/api/ocr/batch/start/{task_id}")

# 3. 轮询状态
while True:
    status = requests.get(f"http://localhost:8000/api/ocr/batch/status/{task_id}").json()
    print(f"进度: {status['progress']}%")
    if status["status"] in ["completed", "failed"]:
        break
    time.sleep(5)

# 4. 导出结果
export = requests.post("http://localhost:8000/api/ocr/batch/export", json={
    "task_id": task_id,
    "format": "json"
}).json()
print(f"导出文件: {export['file_path']}")
```

---

## Java 调用示例

### 单个识别

```java
import java.io.*;
import java.net.http.*;
import java.nio.file.Path;
import java.nio.file.Files;

public class OcrClient {

    private static final String API_URL = "http://localhost:8000";

    /**
     * 识别单张图片
     */
    public static String recognizeImage(String imagePath) throws Exception {
        HttpClient client = HttpClient.newHttpClient();

        // 读取图片文件
        byte[] fileContent = Files.readAllBytes(Path.of(imagePath));

        // 构建 multipart 请求
        String boundary = "----WebKitFormBoundary" + System.currentTimeMillis();
        StringBuilder requestBody = new StringBuilder();

        // 添加文件
        requestBody.append("--").append(boundary).append("\r\n");
        requestBody.append("Content-Disposition: form-data; name=\"file\"; filename=\"")
                  .append(new File(imagePath).getName()).append("\"\r\n");
        requestBody.append("Content-Type: image/jpeg\r\n\r\n");

        byte[] requestBodyBytes = getMultipartBytes(
            requestBody.toString(),
            fileContent,
            "\r\nlang=ch\r\nuse_angle_cls=true\r\n--" + boundary + "--\r\n"
        );

        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(API_URL + "/api/ocr/recognize"))
            .header("Content-Type", "multipart/form-data; boundary=" + boundary)
            .POST(HttpRequest.BodyPublishers.ofByteArray(requestBodyBytes))
            .build();

        HttpResponse<String> response = client.send(request,
            HttpResponse.BodyHandlers.ofString());

        return response.body();
    }

    private static byte[] getMultipartBytes(String header, byte[] fileContent, String footer)
            throws IOException {
        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        baos.write(header.getBytes());
        baos.write(fileContent);
        baos.write(footer.getBytes());
        return baos.toByteArray();
    }

    public static void main(String[] args) {
        try {
            String result = recognizeImage("test.jpg");
            System.out.println("识别结果: " + result);
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}
```

### 使用 OkHttp（推荐）

```java
import okhttp3.*;
import java.io.File;
import java.io.IOException;

public class OcrClientOkHttp {

    private static final String API_URL = "http://localhost:8000";
    private static final MediaType MEDIA_TYPE_JPEG = MediaType.parse("image/jpeg");

    private final OkHttpClient client = new OkHttpClient();

    /**
     * 识别单张图片
     */
    public String recognizeImage(File imageFile) throws IOException {
        RequestBody requestBody = new MultipartBody.Builder()
            .setType(MultipartBody.FORM)
            .addFormDataPart("file", imageFile.getName(),
                RequestBody.create(imageFile, MEDIA_TYPE_JPEG))
            .addFormDataPart("lang", "ch")
            .addFormDataPart("use_angle_cls", "true")
            .build();

        Request request = new Request.Builder()
            .url(API_URL + "/api/ocr/recognize")
            .post(requestBody)
            .build();

        try (Response response = client.newCall(request).execute()) {
            return response.body().string();
        }
    }

    /**
     * 批量扫描（异步任务）
     */
    public String createBatchTask(String bookId, String directory) throws IOException {
        String json = String.format("{\"book_id\":\"%s\",\"directory\":\"%s\",\"lang\":\"ch\",\"recursive\":true}",
            bookId, directory);

        RequestBody body = RequestBody.create(json, MediaType.parse("application/json"));
        Request request = new Request.Builder()
            .url(API_URL + "/api/ocr/batch/scan")
            .post(body)
            .build();

        try (Response response = client.newCall(request).execute()) {
            return response.body().string();
        }
    }

    /**
     * 查询任务状态
     */
    public String getTaskStatus(String taskId) throws IOException {
        Request request = new Request.Builder()
            .url(API_URL + "/api/ocr/batch/status/" + taskId)
            .get()
            .build();

        try (Response response = client.newCall(request).execute()) {
            return response.body().string();
        }
    }

    public static void main(String[] args) {
        OcrClientOkHttp client = new OcrClientOkHttp();
        try {
            // 单个识别
            String result = client.recognizeImage(new File("test.jpg"));
            System.out.println("识别结果: " + result);

            // 创建批量任务
            String taskResponse = client.createBatchTask("廖氏族谱", "/path/to/images");
            System.out.println("任务创建: " + taskResponse);

        } catch (IOException e) {
            e.printStackTrace();
        }
    }
}
```

### 使用 Spring Boot RestTemplate

```java
import org.springframework.core.io.FileSystemResource;
import org.springframework.http.*;
import org.springframework.util.LinkedMultiValueMap;
import org.springframework.util.MultiValueMap;
import org.springframework.web.client.RestTemplate;
import java.io.File;

@Service
public class OcrService {

    private final String API_URL = "http://localhost:8000";
    private final RestTemplate restTemplate = new RestTemplate();

    /**
     * 识别单张图片
     */
    public OcrResponse recognizeImage(File imageFile) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.MULTIPART_FORM_DATA);

        MultiValueMap<String, Object> body = new LinkedMultiValueMap<>();
        body.add("file", new FileSystemResource(imageFile));
        body.add("lang", "ch");
        body.add("use_angle_cls", "true");

        HttpEntity<MultiValueMap<String, Object>> requestEntity = new HttpEntity<>(body, headers);

        ResponseEntity<OcrResponse> response = restTemplate.postForEntity(
            API_URL + "/api/ocr/recognize",
            requestEntity,
            OcrResponse.class
        );

        return response.getBody();
    }

    /**
     * 批量扫描（创建任务）
     */
    public TaskResponse createBatchTask(BatchScanRequest request) {
        HttpHeaders headers = new HttpHeaders();
        headers.setContentType(MediaType.APPLICATION_JSON);

        HttpEntity<BatchScanRequest> requestEntity = new HttpEntity<>(request, headers);

        ResponseEntity<TaskResponse> response = restTemplate.postForEntity(
            API_URL + "/api/ocr/batch/scan",
            requestEntity,
            TaskResponse.class
        );

        return response.getBody();
    }

    /**
     * 启动任务
     */
    public void startTask(String taskId) {
        restTemplate.postForEntity(
            API_URL + "/api/ocr/batch/start/" + taskId,
            null,
            Void.class
        );
    }

    /**
     * 查询任务状态（支持轮询）
     */
    public TaskStatusResponse getTaskStatus(String taskId) {
        return restTemplate.getForObject(
            API_URL + "/api/ocr/batch/status/" + taskId,
            TaskStatusResponse.class
        );
    }

    /**
     * 完整的批量扫描流程
     */
    public void processBatchScan(String bookId, String directory) {
        // 1. 创建任务
        BatchScanRequest scanRequest = new BatchScanRequest();
        scanRequest.setBookId(bookId);
        scanRequest.setDirectory(directory);
        scanRequest.setLang("ch");
        scanRequest.setRecursive(true);

        TaskResponse taskResponse = createBatchTask(scanRequest);
        String taskId = taskResponse.getTaskId();
        System.out.println("任务已创建: " + taskId);

        // 2. 启动任务
        startTask(taskId);
        System.out.println("任务已启动");

        // 3. 轮询状态
        while (true) {
            TaskStatusResponse status = getTaskStatus(taskId);
            System.out.println("进度: " + status.getProgress() + "%");

            if ("completed".equals(status.getStatus())) {
                System.out.println("任务完成!");
                break;
            } else if ("failed".equals(status.getStatus())) {
                System.out.println("任务失败: " + status.getError());
                break;
            }

            try {
                Thread.sleep(5000); // 每5秒检查一次
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
    }
}

// 数据模型类
class OcrResponse {
    private boolean success;
    private String text;
    private double processingTime;
    // getters and setters
}

class TaskResponse {
    private String taskId;
    private boolean success;
    // getters and setters
}

class TaskStatusResponse {
    private String taskId;
    private String status;
    private double progress;
    private int processedFiles;
    private int successFiles;
    // getters and setters
}
```

---

## PaddleOCR 升级计划

### 当前版本信息

| 组件 | 当前版本 | 说明 |
|------|----------|------|
| PaddleOCR | 2.7.0+ | OCR 引擎核心 |
| PaddlePaddle | 2.6.0 | 深度学习框架 |
| 模型版本 | PP-OCRv4 | 最新中文识别模型 |

### 升级检查清单

在升级 PaddleOCR 之前，请检查以下内容：

1. **查看 PaddleOCR 发布日志**
   ```bash
   # 查看最新版本
   pip index versions paddleocr

   # 访问发布页面
   https://github.com/PaddlePaddle/PaddleOCR/releases
   ```

2. **检查新版本特性**
   - 是否有新的识别模型
   - 是否有性能提升
   - 是否有 API 变更
   - 是否有依赖更新

3. **备份当前环境**
   ```bash
   # 导出当前依赖版本
   pip freeze > requirements_backup.txt

   # 备份模型文件
   cp -r ~/.paddleocr ~/.paddleocr_backup
   ```

### 升级步骤

#### 步骤 1: 停止服务

```bash
# 停止 API 服务
pkill -f "uvicorn app.main:app"

# 停止 Celery Worker
pkill -f "celery.*worker"

# 或使用 Docker
docker compose down
```

#### 步骤 2: 升级 PaddleOCR

```bash
# 激活虚拟环境
source venv/bin/activate  # Linux/Mac
# 或
venv\Scripts\activate  # Windows

# 卸载旧版本
pip uninstall paddleocr paddlepaddle -y

# 安装新版本
pip install paddleocr --upgrade

# 如果使用 GPU
pip install paddlepaddle-gpu --upgrade
```

#### 步骤 3: 更新模型文件

```bash
# 删除旧模型缓存（可选，推荐）
rm -rf ~/.paddleocr/whl/

# 首次运行会自动下载新模型
python3 -c "from paddleocr import PaddleOCR; ocr = PaddleOCR(use_angle_cls=True, lang='ch'); print('模型加载成功')"
```

#### 步骤 4: 更新依赖

```bash
# 更新所有依赖到兼容版本
pip install --upgrade -r requirements.txt
```

#### 步骤 5: 测试验证

```bash
# 运行测试
python3 -c "
from paddleocr import PaddleOCR
from app.ocr_service import ocr_service

# 测试模型加载
ocr = PaddleOCR(use_angle_cls=True, lang='ch')
print('✓ PaddleOCR 模型加载成功')

# 测试 OCR 服务
result = ocr_service.recognize('test.jpg')
print(f'✓ OCR 识别成功: {result[\"success\"]}')
"
```

#### 步骤 6: 启动服务

```bash
# 启动所有服务
./start_services.sh

# 或使用 Docker
docker compose up -d
```

#### 步骤 7: 验证升级

```bash
# 检查服务健康
curl http://localhost:8000/api/ocr/health

# 测试识别接口
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@test.jpg" \
  -F "lang=ch"
```

### 版本兼容性

| PaddleOCR 版本 | PaddlePaddle 版本 | Python 版本 | 状态 |
|----------------|-------------------|-------------|------|
| 2.7.0 | 2.6.0 | 3.8-3.11 | ✅ 推荐 |
| 2.8.0+ | 2.6.0+ | 3.8-3.11 | ⚠️ 测试中 |

### 模型升级

#### PP-OCRv3 → PP-OCRv4

PP-OCRv4 是最新版本，相比 PP-OCRv3 有以下改进：

| 特性 | PP-OCRv3 | PP-OCRv4 |
|------|----------|----------|
| 识别准确率 | 95.0% | 97.5% |
| 推理速度 | 基准 | +20% |
| 模型大小 | 基准 | 相同 |
| 支持语言 | 80+ | 80+ |

自动使用 PP-OCRv4：
```python
from paddleocr import PaddleOCR

# 默认使用 PP-OCRv4
ocr = PaddleOCR(use_angle_cls=True, lang='ch')
```

#### 使用自定义模型

如果需要使用特定版本的模型：

```python
from paddleocr import PaddleOCR

# 指定模型路径
ocr = PaddleOCR(
    det_model_dir='/path/to/det_model',
    rec_model_dir='/path/to/rec_model',
    cls_model_dir='/path/to/cls_model',
    use_angle_cls=True,
    lang='ch'
)
```

### 回滚方案

如果升级后出现问题，可以快速回滚：

```bash
# 1. 停止服务
pkill -f "uvicorn"
pkill -f "celery"

# 2. 恢复旧版本
pip uninstall paddleocr paddlepaddle -y
pip install paddleocr==2.7.0
pip install paddlepaddle==2.6.0

# 3. 恢复模型
rm -rf ~/.paddleocr/whl/
cp -r ~/.paddleocr_backup ~/.paddleocr/

# 4. 重启服务
./start_services.sh
```

### 性能对比

升级后建议进行性能测试：

```python
import time
from app.ocr_service import ocr_service, OcrOptions

# 测试图片
test_images = ['test1.jpg', 'test2.jpg', 'test3.jpg']

options = OcrOptions(
    lang='ch',
    use_angle_cls=True,
    return_details=True
)

for img in test_images:
    start = time.time()
    result = ocr_service.recognize(img, options)
    elapsed = time.time() - start

    print(f"{img}: {elapsed:.2f}秒, 成功: {result['success']}")
```

### 升级日志模板

建议记录每次升级的详细信息：

```markdown
## 升级记录 - YYYY-MM-DD

### 升级前版本
- PaddleOCR: 2.6.x
- PaddlePaddle: 2.5.x

### 升级后版本
- PaddleOCR: 2.7.0
- PaddlePaddle: 2.6.0

### 升级原因
- [ ] 新功能需求
- [ ] 性能提升
- [ ] Bug 修复
- [ ] 安全更新

### 升级过程
1. 备份完成
2. 停止服务
3. 更新依赖
4. 测试验证
5. 重启服务

### 遇到的问题
- 无

### 验证结果
- 单个识别: ✅ 通过
- 批量扫描: ✅ 通过
- 性能测试: ✅ 通过
- 准确率对比: ✅ 提升 2%

### 回滚计划
如需回滚，执行以下命令：
\`\`\`bash
pip install paddleocr==2.6.x
\`\`\`
```

---

## 配置文件说明

### 环境变量 (.env)

所有配置都通过 `.env` 文件管理，主要配置项：

| 配置项 | 说明 | 默认值 | 备注 |
|--------|------|--------|------|
| `HOST` | 服务监听地址 | 0.0.0.0 | - |
| `PORT` | 服务端口 | 8000 | - |
| `DB_HOST` | MySQL 地址 | localhost | 批量功能需要 |
| `DB_PORT` | MySQL 端口 | 3306 | - |
| `DB_USER` | MySQL 用户 | root | - |
| `DB_PASSWORD` | MySQL 密码 | - | - |
| `DB_NAME` | 数据库名 | paddleocr_api | - |
| `REDIS_HOST` | Redis 地址 | localhost | 批量功能需要 |
| `REDIS_PORT` | Redis 端口 | 6379 | - |
| `REDIS_PASSWORD` | Redis 密码 | - | 可选 |
| `OCR_LANG` | OCR 语言 | ch | ch/en |
| `OCR_USE_GPU` | 使用 GPU | false | 需安装 paddlepaddle-gpu |
| `TASK_MAX_RETRIES` | 任务最大重试次数 | 3 | - |

---

## 常见问题

### 1. .env 文件不存在
**错误**: `env file .env not found`

**解决方法**:
```bash
# 方式1：复制示例文件
cp .env.example .env

# 方式2：手动创建
cat > .env << 'EOF'
# 应用配置
APP_NAME=PaddleOCR API
APP_VERSION=2.0.0
DEBUG=false
LOG_LEVEL=INFO

# 服务器配置
HOST=0.0.0.0
PORT=8000
WORKERS=4

# 数据库配置（Docker 部署使用服务名）
DB_HOST=mysql
DB_PORT=3306
DB_USER=root
DB_PASSWORD=!qwert
DB_NAME=paddleocr_api

# Redis 配置
REDIS_HOST=redis
REDIS_PORT=6379
REDIS_DB=0
REDIS_PASSWORD=

# OCR 配置
OCR_LANG=ch
OCR_USE_GPU=false
OCR_USE_ANGLE_CLS=true
EOF
```

### 2. 首次启动慢
首次启动会下载 PaddleOCR 模型文件（约 10MB），请耐心等待。

### 3. GPU 加速
```bash
pip uninstall paddlepaddle
pip install paddlepaddle-gpu
```
然后修改 `.env`：`OCR_USE_GPU=true`

### 4. 端口被占用
修改 `.env` 文件中的 `PORT` 配置。

### 5. 数据库连接失败
检查：
- MySQL 服务是否启动
- 数据库用户名密码是否正确
- 数据库是否已创建
- 防火墙是否开放端口

### 6. Celery Worker 不处理任务
检查：
- Redis 服务是否启动
- Celery Worker 是否正常运行
- 查看日志：`tail -f logs/celery_worker.log`

### 7. 文件扩展名不匹配
确保 `.env` 中的 `file_patterns` 包含实际文件的扩展名，包括大小写：
```json
["*.jpg", "*.jpeg", "*.png", "*.JPG", "*.JPEG", "*.PNG"]
```

### 8. Docker 镜像拉取失败
**错误**: `failed to resolve reference "docker.io/library/xxx": connection reset by peer`

**原因**: 无法访问 Docker Hub (registry-1.docker.io)

**解决方法**：

**方法1: 配置镜像加速器**
```bash
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "registry-mirrors": [
    "https://docker.1panel.live",
    "https://docker.xuanyuan.me",
    "https://registry.cn-hangzhou.aliyuncs.com"
  ]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
docker compose up -d
```

**方法2: 使用 VPN/代理**
```bash
# 为 Docker 配置代理
sudo mkdir -p /etc/systemd/system/docker.service.d
sudo tee /etc/systemd/system/docker.service.d/http-proxy.conf > /dev/null << 'EOF'
[Service]
Environment="HTTP_PROXY=http://127.0.0.1:代理端口"
Environment="HTTPS_PROXY=http://127.0.0.1:代理端口"
Environment="NO_PROXY=localhost,127.0.0.1"
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```

**方法3: 手动下载并导入镜像**
```bash
# 在有网络的机器上下载
docker pull redis:7-alpine
docker pull mysql:8.0
docker pull python:3.10-slim

# 导出镜像
docker save redis:7-alpine mysql:8.0 python:3.10-slim -o paddleocr-images.tar

# 传输到目标服务器
scp paddleocr-images.tar user@server:/tmp/

# 在目标服务器上导入
docker load -i /tmp/paddleocr-images.tar
docker compose up -d
```

**方法4: 使用国内镜像仓库**
修改 `docker-compose.yml`，替换镜像源：
```yaml
services:
  mysql:
    image: registry.cn-hangzhou.aliyuncs.com/library/mysql:8.0
  redis:
    image: registry.cn-hangzhou.aliyuncs.com/library/redis:7-alpine
  paddleocr-api:
    build:
      context: .
      dockerfile: Dockerfile
    # 或使用预构建镜像
    image: registry.cn-hangzhou.aliyuncs.com/你的命名空间/paddleocr-api:latest
```

---

## 技术栈

- **Web 框架**: FastAPI
- **OCR 引擎**: PaddleOCR
- **服务器**: Uvicorn
- **任务队列**: Celery + Redis
- **数据库**: MySQL
- **数据验证**: Pydantic
- **ORM**: SQLAlchemy

---

## 开发计划

详见 [UPGRADE_PLAN.md](UPGRADE_PLAN.md)

---

## 许可证

MIT License

---

## 相关文档

- [部署指南](DEPLOYMENT.md)
- [部署故障排查指南](DEPLOYMENT_TROUBLESHOOTING.md) - 🔧 网络受限环境部署经验汇总
- [升级计划](UPGRADE_PLAN.md)
- [API 文档](http://localhost:8000/docs)
