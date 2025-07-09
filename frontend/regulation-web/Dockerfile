# =============================================================================
# 监管合规智能系统 - 用户端前端 Dockerfile
# 基于Node.js 20 + Vue.js 3 + Vite
# =============================================================================

# -----------------------------------------------------------------------------
# 阶段1: 依赖安装阶段 (Dependencies Stage)
# -----------------------------------------------------------------------------
FROM node:20-alpine AS dependencies

# 设置工作目录
WORKDIR /app

# 安装pnpm（可选，如果使用pnpm的话）
# RUN npm install -g pnpm

# 复制package文件
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production && npm cache clean --force

# -----------------------------------------------------------------------------
# 阶段2: 开发运行阶段 (Development Stage)
# 用于开发环境，支持热重载
# -----------------------------------------------------------------------------
FROM node:20-alpine AS development

# 安装基础工具
RUN apk add --no-cache curl bash

# 设置工作目录
WORKDIR /app

# 复制package文件
COPY package*.json ./

# 安装所有依赖（包括开发依赖）
RUN npm ci && npm cache clean --force

# 复制源代码
COPY . .

# 创建node_modules卷的目录
RUN mkdir -p /app/node_modules

# 设置环境变量
ENV NODE_ENV=development
ENV VITE_DEV_SERVER_HOST=0.0.0.0
ENV VITE_DEV_SERVER_PORT=3000

# 暴露端口
EXPOSE 3000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:3000 || exit 1

# 启动开发服务器
CMD ["npm", "run", "dev", "--", "--host", "0.0.0.0", "--port", "3000"]

# -----------------------------------------------------------------------------
# 阶段3: 构建阶段 (Build Stage)
# 用于生产环境构建
# -----------------------------------------------------------------------------
FROM node:20-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制package文件
COPY package*.json ./

# 安装依赖
RUN npm ci && npm cache clean --force

# 复制源代码
COPY . .

# 构建应用
RUN npm run build

# 验证构建结果
RUN ls -la dist/

# -----------------------------------------------------------------------------
# 阶段4: 生产运行阶段 (Production Stage)
# 使用nginx提供静态文件服务
# -----------------------------------------------------------------------------
FROM nginx:alpine AS production

# 安装curl用于健康检查
RUN apk add --no-cache curl

# 复制构建结果到nginx目录
COPY --from=builder /app/dist /usr/share/nginx/html

# 复制nginx配置文件
COPY nginx.conf /etc/nginx/nginx.conf

# 创建nginx用户的目录
RUN mkdir -p /var/cache/nginx/client_temp && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /usr/share/nginx/html

# 暴露端口
EXPOSE 80

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
  CMD curl -f http://localhost/ || exit 1

# 启动nginx
CMD ["nginx", "-g", "daemon off;"]