# 生产环境部署 - Docker Compose + Portainer

完整的生产环境部署方案，支持从零开始部署到 Ubuntu 服务器。

---

## 快速开始

### 方式一：使用一键部署脚本（推荐）

```bash
# 1. 下载部署脚本
wget https://raw.githubusercontent.com/sishengcao/paddleocr-api/master/deploy/production/scripts/quick-start.sh

# 2. 添加执行权限
chmod +x quick-start.sh

# 3. 运行部署脚本
sudo ./quick-start.sh
```

脚本将自动完成：
- ✅ 安装 Docker 和 Docker Compose
- ✅ 配置防火墙
- ✅ 申请 SSL 证书
- ✅ 部署所有服务
- ✅ 配置自动备份

### 方式二：手动部署

参考 [PRODUCTION_DEPLOYMENT.md](../../PRODUCTION_DEPLOYMENT.md) 获取完整的手动部署步骤。

---

## 前置要求

- **操作系统**: Ubuntu 22.04 / 24.04
- **域名**: sishengcao.fun（需要配置 DNS）
- **内存**: 建议 4GB+
- **存储**: 建议 20GB+

---

## 项目结构

```
/opt/sishengcao/
├── docker-compose.yml          # Docker Compose 配置
├── .env                        # 环境变量
├── nginx/                      # Nginx 配置
│   ├── nginx.conf
│   └── conf.d/
│       ├── api.conf            # API 子域名
│       ├── app.conf            # Java 应用
│       ├── frontend.conf       # Vue 前端
│       └── portainer.conf      # Portainer
├── mysql/
│   └── init/
│       └── 001_init_database.sql
├── scripts/
│   ├── quick-start.sh         # 一键部署脚本
│   ├── update.sh              # 更新脚本
│   └── backup.sh              # 备份脚本（自动生成）
└── logs/                       # 日志目录
```

---

## 配置步骤

### 1. DNS 配置

在您的域名注册商添加以下 DNS 记录：

| 类型 | 主机记录 | 记录值 |
|------|----------|--------|
| A | @ | [服务器IP] |
| A | www | [服务器IP] |
| A | api | [服务器IP] |
| A | app | [服务器IP] |

### 2. 环境变量配置

复制并修改环境变量文件：

```bash
cp .env.example .env
vim .env
```

**必须修改的配置**：
```bash
MYSQL_ROOT_PASSWORD=your_strong_password_here
MYSQL_PASSWORD=your_strong_password_here
REDIS_PASSWORD=your_strong_password_here
LETSENCRYPT_EMAIL=your-email@example.com
```

### 3. 启动服务

```bash
# 拉取镜像
docker compose pull

# 启动所有服务
docker compose up -d

# 查看状态
docker compose ps
```

---

## 访问地址

部署完成后，可通过以下地址访问各服务：

| 服务 | 地址 | 说明 |
|------|------|------|
| Vue 前端 | https://sishengcao.fun | 用户界面 |
| API | https://api.sishengcao.fun | Python API |
| API 文档 | https://api.sishengcao.fun/docs | Swagger UI |
| API 文档 | https://api.sishengcao.fun/redoc | ReDoc |
| Java 应用 | https://app.sishengcao.fun | 后端应用 |
| Portainer | http://[服务器IP]:9000 | 容器管理 |

---

## 常用命令

### 服务管理

```bash
# 查看服务状态
docker compose ps

# 查看日志
docker compose logs -f

# 查看特定服务日志
docker compose logs -f python-api

# 重启服务
docker compose restart

# 重启特定服务
docker compose restart python-api

# 停止服务
docker compose down

# 停止并删除数据（危险操作）
docker compose down -v
```

### 日志查看

```bash
# 实时日志
tail -f logs/nginx/api_access.log

# Python API 日志
tail -f logs/python-api/app.log

# Celery Worker 日志
tail -f logs/python-api/celery.log

# MySQL 日志
docker compose logs mysql
```

### 数据库操作

```bash
# 进入 MySQL
docker compose exec mysql mysql -u root -p

# 备份数据库
docker compose exec mysql mysqldump -u root -p paddleocr_api > backup.sql

# 恢复数据库
docker compose exec -T mysql mysql -u root -p paddleocr_api < backup.sql
```

### 更新部署

```bash
# 使用更新脚本
./scripts/update.sh

# 或手动更新
docker compose pull
docker compose up -d
```

---

## 监控和维护

### Portainer

访问 http://[服务器IP]:9000 进行可视化容器管理。

### 备份

自动备份脚本每天凌晨 3 点运行，备份保留 7 天。

手动备份：
```bash
./backup.sh
```

### SSL 证书续期

证书自动续期由 Certbot 容器处理，每 12 小时检查一次。

手动续期：
```bash
docker compose run --rm certbot certbot renew
docker compose exec nginx nginx -s reload
```

---

## 故障排查

### 服务无法启动

```bash
# 查看详细错误
docker compose logs [service-name]

# 检查配置
docker compose config

# 检查端口占用
netstat -tulpn | grep :80
```

### SSL 证书问题

```bash
# 检查证书
docker compose exec certbot certbot certificates

# 重新申请证书
docker compose run --rm certbot certbot --force-renewal
```

### 数据库连接问题

```bash
# 测试 MySQL 连接
docker compose exec mysql mysql -u ocruser -p paddleocr_api

# 检查网络
docker network inspect sishengcao_app-network
```

---

## 安全建议

1. **定期更新**
   ```bash
   docker compose pull && docker compose up -d
   ```

2. **限制 Portainer 访问**
   - 建议仅通过 VPN 或内网访问
   - 不要暴露到公网

3. **使用强密码**
   - 定期更换数据库密码
   - 使用复杂的密码组合

4. **启用防火墙**
   - 只开放必要的端口
   - 使用 fail2ban 防止暴力破解

---

## 相关文档

- [完整部署指南](../../PRODUCTION_DEPLOYMENT.md)
- [项目 README](../../README.md)
- [版本管理](../../VERSION_MANAGEMENT.md)

---

## 支持

- 问题反馈: https://github.com/sishengcao/paddleocr-api/issues
- 讨论区: https://github.com/sishengcao/paddleocr-api/discussions
