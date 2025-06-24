FROM alpine:3.18

# 维护者信息
LABEL maintainer="OpenVPN-FRP Project"
LABEL description="FRP Client for OpenVPN reverse proxy"

# 设置环境变量（通过构建参数传递）
ARG FRP_VERSION=0.62.1
ARG FRP_ARCH=linux_amd64
ENV FRP_VERSION=${FRP_VERSION}
ENV FRP_ARCH=${FRP_ARCH}

# 安装必要的包
RUN apk add --no-cache \
    wget \
    tar \
    ca-certificates \
    tzdata \
    netcat-openbsd

# 设置时区
RUN cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime && \
    echo "Asia/Shanghai" > /etc/timezone

# 创建frp用户和工作目录
RUN addgroup -g 1000 frp && \
    adduser -D -s /bin/sh -u 1000 -G frp frp && \
    mkdir -p /opt/frp/conf /opt/frp/logs && \
    chown -R frp:frp /opt/frp

# 工作目录
WORKDIR /opt/frp

# 下载并安装FRP
RUN wget --timeout=30 --tries=3 --retry-connrefused --no-check-certificate -O frp.tar.gz "https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz" && \
    tar -xzf frp.tar.gz --strip-components=1 && \
    rm frp.tar.gz && \
    chmod +x frpc && \
    rm -f frps

# 复制配置文件
COPY config/frpc.ini ./conf/frpc.ini
COPY docker/frp/frpc/start-frpc.sh ./start-frpc.sh

# 设置执行权限
RUN chmod +x start-frpc.sh && \
    chown -R frp:frp /opt/frp

# 切换到frp用户
USER frp

# 健康检查
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
    CMD pgrep frpc > /dev/null || exit 1

# 入口点
ENTRYPOINT ["./start-frpc.sh"]