# OpenVPN 服务器 Docker 镜像
# 基于 Alpine Linux 以减小镜像大小

FROM alpine:3.18

# 维护者信息
LABEL maintainer="OpenVPN-FRP Project"
LABEL description="OpenVPN Server with PKI Certificate Support"

# 安装必要的软件包
RUN apk update && \
    apk add --no-cache \
        openvpn \
        iptables \
        bash \
        curl \
        openssl \
        ca-certificates && \
    rm -rf /var/cache/apk/*
# 创建必要的目录
RUN mkdir -p /etc/openvpn/pki \
             /etc/openvpn/ccd \
             /var/log/openvpn \
             /dev/net && \
    # 创建 TUN 设备（容器启动时可能需要）
    mknod /dev/net/tun c 10 200 && \
    chmod 600 /dev/net/tun

# 复制 OpenVPN 服务器配置文件
COPY config/server.conf /etc/openvpn/server.conf

# 复制 PKI 证书文件（构建时复制）
COPY pki/ /etc/openvpn/pki/

# 复制启动脚本
COPY docker/openvpn/start-openvpn.sh /usr/local/bin/start-openvpn.sh
RUN chmod +x /usr/local/bin/start-openvpn.sh

# 设置正确的文件权限（存在性检查，安全方式）
RUN set -e; \
    for f in /etc/openvpn/pki/server/private/server.key \
             /etc/openvpn/pki/ca/private/ca.key \
             /etc/openvpn/pki/ta.key; do \
        if [ -f "$f" ]; then chmod 600 "$f"; fi; \
    done && \
    for f in /etc/openvpn/pki/clients/private/*.key; do \
        [ -f "$f" ] && chmod 600 "$f"; \
    done && \
    for f in /etc/openvpn/pki/ca/ca.crt \
             /etc/openvpn/pki/server/server.crt \
             /etc/openvpn/pki/dh/dh2048.pem; do \
        if [ -f "$f" ]; then chmod 644 "$f"; fi; \
    done && \
    for f in /etc/openvpn/pki/clients/*.crt; do \
        [ -f "$f" ] && chmod 644 "$f"; \
    done

# 创建运行用户（安全考虑）
RUN addgroup -g 1000 openvpn || true && \
    adduser -D -s /bin/false -u 1000 -G openvpn openvpn || true

# 暴露 OpenVPN 端口
EXPOSE 1194/udp

# 设置工作目录
WORKDIR /etc/openvpn

# 健康检查：检查 OpenVPN 进程是否运行
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
  CMD pgrep openvpn || exit 1

# 容器启动时执行的命令
ENTRYPOINT ["/usr/local/bin/start-openvpn.sh"]
CMD []

# 镜像元数据
LABEL version="1.0" \
      description="OpenVPN Server with PKI certificate support" \
      openvpn.version="latest" \
      network.ports.exposed="1194/udp"