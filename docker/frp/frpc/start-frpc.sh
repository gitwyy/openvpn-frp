#!/bin/sh

# FRP客户端启动脚本
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
if [ ! -f "./conf/frpc.ini" ]; then
    log_error "配置文件 ./conf/frpc.ini 不存在"
    exit 1
fi

log_info "FRP客户端启动中..."
log_info "配置文件: ./conf/frpc.ini"

# 显示配置信息
log_info "读取配置信息..."
SERVER_ADDR=$(grep "server_addr" ./conf/frpc.ini | cut -d'=' -f2 | tr -d ' ')
SERVER_PORT=$(grep "server_port" ./conf/frpc.ini | cut -d'=' -f2 | tr -d ' ')

log_info "FRP服务端地址: ${SERVER_ADDR:-未配置}"
log_info "FRP服务端端口: ${SERVER_PORT:-7000}"

# 检查服务端地址是否配置
if [ "$SERVER_ADDR" = "YOUR_SERVER_IP" ] || [ -z "$SERVER_ADDR" ]; then
    log_error "请在配置文件中设置正确的FRP服务端地址 (server_addr)"
    log_error "当前值: ${SERVER_ADDR}"
    exit 1
fi

# 等待OpenVPN服务可用
log_info "检查OpenVPN服务连通性..."
OPENVPN_HOST=${OPENVPN_HOST:-openvpn}
OPENVPN_PORT=${OPENVPN_PORT:-1194}

wait_for_service() {
    local host=$1
    local port=$2
    local timeout=${3:-30}
    local count=0
    
    log_info "等待 ${host}:${port} 服务可用..."
    
    while [ $count -lt $timeout ]; do
        if nc -zu "$host" "$port" 2>/dev/null; then
            log_info "服务 ${host}:${port} 已可用"
            return 0
        fi
        count=$((count + 1))
        sleep 1
    done
    
    log_warn "等待服务 ${host}:${port} 超时"
    return 1
}

# 等待OpenVPN服务
wait_for_service "$OPENVPN_HOST" "$OPENVPN_PORT" 60

# 创建日志目录
mkdir -p ./logs

# 信号处理函数
cleanup() {
    log_info "接收到终止信号，正在优雅关闭FRP客户端..."
    if [ ! -z "$FRP_PID" ]; then
        kill -TERM "$FRP_PID" 2>/dev/null || true
        wait "$FRP_PID" 2>/dev/null || true
    fi
    log_info "FRP客户端已停止"
    exit 0
}

# 注册信号处理
trap cleanup TERM INT

# 重连循环
while true; do
    log_info "启动FRP客户端..."
    
    # 启动FRP客户端
    ./frpc -c ./conf/frpc.ini &
    FRP_PID=$!
    
    log_info "FRP客户端已启动 (PID: $FRP_PID)"
    log_info "连接到FRP服务端: ${SERVER_ADDR}:${SERVER_PORT}"
    
    # 等待进程结束
    wait $FRP_PID
    exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        log_info "FRP客户端正常退出"
        break
    else
        log_warn "FRP客户端异常退出 (退出码: $exit_code)"
        log_info "5秒后尝试重新连接..."
        sleep 5
    fi
done