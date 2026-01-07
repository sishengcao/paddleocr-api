# PaddleOCR API 服务

基于 PaddleOCR 的图片文字识别 API 服务，支持中英文识别、批量扫描、竖排文字识别等功能。

---

## 快速开始

### Docker Compose 部署

```bash
# 1. 克隆项目
git clone https://github.com/sishengcao/paddleocr-api.git
cd paddleocr-api

# 2. 创建环境变量文件
cp .env.example .env

# 3. 启动服务
docker compose up -d

# 4. 查看日志
docker compose logs -f
```

### 访问服务

| 功能 | 地址 |
|------|------|
| API 文档 | http://localhost:8000/docs |
| 识别界面 | http://localhost:8000/ |
| 健康检查 | http://localhost:8000/api/ocr/health |

---

## API 使用

### 单图识别

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@test.jpg" \
  -F "use_angle_cls=true" \
  -F "return_details=true"
```

### 批量识别

```bash
curl -X POST "http://localhost:8000/api/ocr/recognize-batch" \
  -F "files=@img1.jpg" \
  -F "files=@img2.jpg"
```

---

## 文件识别说明

### 识别服务器上的文件

**方法一：通过 curl 本地文件路径**

```bash
# 识别服务器上的图片
curl -X POST "http://localhost:8000/api/ocr/recognize" \
  -F "file=@/path/to/image.png"
```

**方法二：挂载目录到容器**

在 `docker-compose.yml` 中添加挂载：

```yaml
services:
  paddleocr-api:
    volumes:
      - /home/sishengcao/ocr:/app/uploads:ro
```

重启后可访问挂载目录中的文件。

### 文件放置位置

| 场景 | 路径 |
|------|------|
| 上传文件 | `/app/uploads/` (容器内) |
| 临时文件 | `/app/temp/` (容器内) |
| 挂载目录 | 自定义挂载点 |

---

## 问题复盘

### PaddleOCR 版本兼容性问题 (2026-01-07)

**问题**：OCR 识别返回空结果或错误字符

**原因**：新版 PaddleOCR 返回格式从列表改为字典：
- 旧版：`[[box, (text, confidence)], ...]`
- 新版：`{rec_texts: [...], rec_scores: [...], rec_polys: [...]}`

**解决**：修改 `app/ocr_service.py` 兼容两种格式

**修复命令**：
```bash
# 本地修改后提交
git add app/ocr_service.py
git commit -m "Fix: 兼容新版 PaddleOCR 返回格式"
git push

# 远程服务器拉取更新
git pull
docker compose restart paddleocr-api
```

---

## 系统配置

### SSH 免密登录

**本地生成密钥**：
```bash
ssh-keygen -t rsa -b 4096
```

**复制公钥到服务器**：
```bash
ssh-copy-id sishengcao@192.168.124.134
```

**或手动复制**：
```bash
# 本地查看公钥
cat ~/.ssh/id_rsa.pub

# 添加到服务器
ssh sishengcao@192.168.124.134
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "公钥内容" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

### 非 root 用户执行 Docker

**方法一：将用户添加到 docker 组（推荐）**

```bash
# 将用户添加到 docker 组
sudo usermod -aG docker sishengcao

# 用户重新登录或执行
newgrp docker

# 验证（不需要 sudo）
docker ps
```

**方法二：配置 sudoers**

```bash
# 编辑 sudoers
sudo visudo

# 添加以下行
sishengcao ALL=(ALL) NOPASSWD: /usr/bin/docker
```

---

## 环境准备

### 一键安装 Docker

```bash
chmod +x docker-fix-script-pro.sh
sudo bash docker-fix-script-pro.sh
```

**功能**：自动安装 Docker CE、Docker Compose v2、配置镜像加速器、修复 DNS 污染

### 系统重置

```bash
chmod +x system-purge-safe-script.sh
sudo bash system-purge-safe-script.sh
sudo reboot
```

**⚠️ 警告**：会删除所有非系统用户和数据！

---

## 技术栈

| 组件 | 技术 |
|------|------|
| Web 框架 | FastAPI |
| OCR 引擎 | PaddleOCR |
| 任务队列 | Celery + Redis |
| 数据库 | MySQL |

---

## 文档导航

- [API 使用指南](API使用指南.md) - 完整 API 文档和调用示例
- [配置说明](配置说明.md) - 环境变量配置参考
- [部署故障排查](部署故障排查.md) - 网络受限环境部署经验
- [常见问题](常见问题.md) - 部署和运行常见问题

---

## 许可证

MIT License
