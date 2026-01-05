# API 使用指南

本指南提供 PaddleOCR API 的详细使用说明和示例。

---

## 目录

- [API 端点](#api-端点)
- [请求示例](#请求示例)
- [Python 调用示例](#python-调用示例)
- [Java 调用示例](#java-调用示例)
- [响应格式](#响应格式)

---

## API 端点

### 单个识别功能

| 端点 | 方法 | 说明 |
|------|------|------|
| `/api/ocr/health` | GET | 健康检查 |
| `/api/ocr/status` | GET | 服务状态 |
| `/api/ocr/recognize` | POST | 识别单张图片 |
| `/api/ocr/recognize-batch` | POST | 批量识别图片（同步） |

### 批量扫描功能

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

## 请求示例

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

## 响应格式

### 健康检查响应

```json
{
  "status": "healthy",
  "version": "1.0.0"
}
```

### 识别成功响应

```json
{
  "success": true,
  "text": "识别的文字内容",
  "processingTime": 1.234
}
```

### 批量任务创建响应

```json
{
  "task_id": "uuid-string",
  "success": true
}
```

### 任务状态响应

```json
{
  "task_id": "uuid-string",
  "status": "processing",
  "progress": 50.5,
  "total_files": 100,
  "processed_files": 50,
  "success_files": 48,
  "failed_files": 2
}
```

---

## 在线文档

部署完成后，访问以下地址获取交互式 API 文档：

- **Swagger UI**: http://localhost:8000/docs
- **ReDoc**: http://localhost:8000/docs-enhanced

---

## 相关文档

- [快速开始](快速开始.md)
- [配置说明](配置说明.md)
- [数据库设计](数据库设计.md)
- [常见问题](常见问题.md)
