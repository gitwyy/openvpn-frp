FROM python:3.11-alpine

# 设置工作目录
WORKDIR /app

# 安装系统依赖
RUN apk add --no-cache \
    bash \
    curl \
    docker-cli \
    openssl \
    openssl-dev \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# 复制依赖文件
COPY web/requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 复制应用代码
COPY web/ .

# 注意：为了访问Docker socket，这里使用root用户运行
# 在生产环境中，建议配置适当的用户权限

# 暴露端口
EXPOSE 5000

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/api/health || exit 1

# 启动应用
CMD ["python", "app.py"]
