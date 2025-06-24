#!/bin/sh

# FRP服务端启动脚本
# 作者: OpenVPN-FRP Project

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# 检查配置文件
if [ ! -f "./conf/frps.ini" ]; then
    log_error "配置文件 ./conf/frps.ini 不存在"
    exit 1
fi

log_info "FRP服务端启动中..."
log_info "配置文件: ./conf/frps.ini"

# 显示配置信息
log_info "读取配置信息..."
BIND_PORT=$(grep "bind_port" ./conf/frps.ini | cut -d'=' -f2 | tr -d ' ')
DASHBOARD_PORT=$(grep "dashboard_port" ./conf/frps.ini | cut -d'=' -f2 | tr -d ' ')

log_info "监听端口: ${BIND_PORT:-7000}"
log_info "管理后台端口: ${DASHBOARD_PORT:-7500}"

# 检查端口是否被占用
check_port() {
    local port=$1
    if netstat -ln 2>/dev/null | grep -q ":${port} "; then
        log_warn "端口 ${port} 已被占用"
        return 1
    fi
    return 0
}

# 创建日志目录
mkdir -p ./logs

# 信号处理函数
cleanup() {
    log_info "接收到终止信号，正在优雅关闭FRP服务端..."
    if [ ! -z "$FRP_PID" ]; then
        kill -TERM "$FRP_PID" 2>/dev/null || true
        wait "$FRP_PID" 2>/dev/null || true
    fi
    log_info "FRP服务端已停止"
    exit 0
}

# 注册信号处理
trap cleanup TERM INT

# 启动FRP服务端
log_info "启动FRP服务端..."
exec ./frps -c ./conf/frps.ini &
FRP_PID=$!

log_info "FRP服务端已启动 (PID: $FRP_PID)"
log_info "管理后台访问地址: http://YOUR_SERVER_IP:${DASHBOARD_PORT:-7500}"

# 等待进程
wait $FRP_PID