# 问题复盘记录

记录项目开发和运维过程中遇到的问题及解决方案。

---

## 目录

- [PaddleOCR 版本兼容性问题](#paddleocr-版本兼容性问题)
- [数据库列名不匹配问题](#数据库列名不匹配问题)
- [前端 API 请求失败问题](#前端-api-请求失败问题)

---

## PaddleOCR 版本兼容性问题

**日期**: 2026-01-07

**问题描述**:
OCR 识别返回空结果或错误字符，返回内容为单个字母且坐标全为 0。

**原因分析**:
新版 PaddleOCR 返回格式从列表改为字典：
- **旧版格式**: `[[box, (text, confidence)], ...]`
- **新版格式**: `{rec_texts: [...], rec_scores: [...], rec_polys: [...]}`

原代码只兼容旧版列表格式，导致解析失败。

**解决方案**:
修改 `app/ocr_service.py`，添加格式检测逻辑：

```python
if isinstance(result[0], dict):
    # 新版格式
    rec_texts = result[0].get('rec_texts', [])
    rec_scores = result[0].get('rec_scores', [])
    rec_polys = result[0].get('rec_polys', [])
    # 处理数据...
elif isinstance(result[0], list):
    # 旧版格式
    for line in result[0]:
        # 处理数据...
```

**影响范围**:
- 文件: `app/ocr_service.py`
- 新增: `import numpy as np`

**相关提交**: `23f5bfa`

---

## 数据库列名不匹配问题

**日期**: 2026-01-07

**问题描述**:
批量识别功能报错：
```
(pymysql.err.OperationalError) (1054, "Unknown column 'books.metadata_json' in 'field list'")
```

**原因分析**:
数据库表 `books` 的列名是 `metadata`，但 SQLAlchemy 模型中定义的属性名是 `metadata_json`，两者不匹配。

**解决方案**:
修改 `app/database/models.py`，显式指定数据库列名：

```python
# 修改前
metadata_json = Column(JSON, comment='Additional metadata')

# 修改后
metadata_json = Column("metadata", JSON, comment='Additional metadata')
```

使用 `Column("metadata", ...)` 指定数据库列名为 `metadata`，而 Python 属性保持为 `metadata_json`（因为 `metadata` 是 Python 保留字）。

**影响范围**:
- 文件: `app/database/models.py`

**相关提交**: `4b762ae`

---

## 前端 API 请求失败问题

**日期**: 2026-01-07

**问题描述**:
通过浏览器访问 http://192.168.124.134:8000/ 进行 OCR 识别时请求失败。

**原因分析**:
1. 前端硬编码 `localhost` 作为 API 地址
2. 静态文件在镜像构建时复制，修改后需重新构建镜像

**解决方案**:
1. 修改 `static/index.html` 使用动态 URL（`window.location.hostname`）
2. 重新构建镜像并重启容器

```bash
docker compose build paddleocr-api
docker compose up -d
```

**容器操作总结**:

| 操作类型 | 命令 |
|---------|------|
| 修改 Python 代码 | `docker compose restart` |
| 修改静态文件 | `docker compose build && docker compose up -d` |
| 修改 Dockerfile | `docker compose build --no-cache && docker compose up -d` |
| 查看日志 | `docker compose logs -f paddleocr-api` |
| 进入容器 | `docker exec -it paddleocr-api bash` |

**相关提交**: 前端修复提交

---

## 快速修复命令参考

### PaddleOCR 兼容性问题

```bash
# 本地修改后提交
git add app/ocr_service.py
git commit -m "Fix: 兼容新版 PaddleOCR 返回格式"
git push

# 远程服务器拉取更新
git pull
docker compose restart paddleocr-api
```

### 数据库列名问题

```bash
# 修复模型文件
# app/database/models.py
metadata_json = Column("metadata", JSON, comment='Additional metadata')

# 重启容器
docker compose restart paddleocr-api
```

### 前端请求问题

```bash
# 修改静态文件后重新构建
docker compose build paddleocr-api
docker compose up -d

# 浏览器强制刷新
# Ctrl + F5 (Windows/Linux)
# Cmd + Shift + R (Mac)
```
