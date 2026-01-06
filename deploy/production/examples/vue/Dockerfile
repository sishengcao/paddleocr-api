# ===================================================================
# Vue 前端项目 Dockerfile 示例
# ===================================================================

# ==================== 构建阶段 ====================
FROM node:18-alpine AS build-stage

# 设置工作目录
WORKDIR /app

# 配置 npm 国内镜像源
RUN npm config set registry https://registry.npmmirror.com

# 复制 package.json 和 package-lock.json
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production

# 复制项目文件
COPY . .

# 设置构建时环境变量（如果需要）
ARG VITE_API_BASE_URL=https://api.sishengcao.fun
ENV VITE_API_BASE_URL=${VITE_API_BASE_URL}

# 构建项目
RUN npm run build

# ==================== 生产阶段 ====================
FROM nginx:alpine AS production-stage

# 复制构建产物
COPY --from=build-stage /app/dist /usr/share/nginx/html

# 复制 Nginx 配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost/ || exit 1

# 启动 Nginx
CMD ["nginx", "-g", "daemon off;"]
