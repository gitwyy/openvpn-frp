#!/bin/bash

# OpenVPN 服务器启动脚本
# 检查环境、配置网络并启动 OpenVPN 服务

set -e

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# 检查是否以特权模式运行
check_privileges() {
    log_info "检查容器权限..."
    
    # 检查是否可以创建 TUN 设备
    if [[ ! -c /dev/net/tun ]]; then
        log_warn "/dev/net/tun 设备不存在，尝试创建..."
        mkdir -p /dev/net
        
        # 尝试创建TUN设备
        if mknod /dev/net/tun c 10 200 2>/dev/null; then
            chmod 600 /dev/net/tun
            log_info "成功创建 TUN 设备"
        else
            log_error "无法创建 TUN 设备"
            log_info "这通常发生在以下情况："
            log_info "  1. 容器未以特权模式运行 (需要 --privileged)"
            log_info "  2. 主机系统不支持TUN设备 (如某些macOS配置)"
            log_info "  3. Docker配置限制了设备访问"
            log_info ""
            log_info "解决方案："
            log_info "  • 使用 docker run --privileged 运行容器"
            log_info "  • 或者映射主机设备: --device /dev/net/tun:/dev/net/tun"
            log_info "  • macOS用户请参考 docs/MACOS-DEPLOYMENT.md"
            log_info ""
            log_info "尝试继续启动，OpenVPN将尝试自行处理设备创建..."
        fi
    else
        log_info "TUN 设备已存在: /dev/net/tun"
    fi
    
    # 检查设备权限
    if [[ -c /dev/net/tun ]]; then
        if [[ ! -r /dev/net/tun ]] || [[ ! -w /dev/net/tun ]]; then
            log_warn "TUN设备权限不足，尝试修复..."
            chmod 600 /dev/net/tun 2>/dev/null || log_warn "无法修改TUN设备权限"
        fi
    fi
    
    log_info "权限检查完成"
}

# 检查证书文件
check_certificates() {
    log_info "检查证书文件..."
    
    local cert_files=(
        "/etc/openvpn/pki/ca/ca.crt"
        "/etc/openvpn/pki/server/server.crt"
        "/etc/openvpn/pki/server/private/server.key"
        "/etc/openvpn/pki/dh/dh2048.pem"
        "/etc/openvpn/pki/ta.key"
    )
    
    for cert_file in "${cert_files[@]}"; do
        if [[ ! -f "$cert_file" ]]; then
            log_error "证书文件不存在: $cert_file"
            log_error "请确保已正确生成证书并构建 Docker 镜像"
            exit 1
        fi
        log_debug "证书文件存在: $cert_file"
    done
    
    log_info "所有证书文件检查通过"
}

# 设置网络转发和 iptables 规则
setup_networking() {
    log_info "配置网络转发和防火墙规则..."
    
    # 启用 IP 转发
    echo 1 > /proc/sys/net/ipv4/ip_forward
    log_debug "已启用 IPv4 转发"
    
    # 获取默认网络接口
    DEFAULT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    log_debug "默认网络接口: $DEFAULT_INTERFACE"
    
    # 配置 iptables NAT 规则
    if [[ -n "$DEFAULT_INTERFACE" ]]; then
        # 添加 MASQUERADE 规则以支持 NAT
        iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o "$DEFAULT_INTERFACE" -j MASQUERADE
        
        # 允许 OpenVPN 流量转发
        iptables -A FORWARD -i tun+ -j ACCEPT
        iptables -A FORWARD -i tun+ -o "$DEFAULT_INTERFACE" -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables -A FORWARD -i "$DEFAULT_INTERFACE" -o tun+ -m state --state RELATED,ESTABLISHED -j ACCEPT
        
        log_info "iptables 规则配置完成"
    else
        log_warn "无法确定默认网络接口，可能需要手动配置 iptables 规则"
    fi
}

# 创建必要的目录
create_directories() {
    log_info "创建必要的目录..."
    
    local directories=(
        "/var/log/openvpn"
        "/etc/openvpn/ccd"
        "/run/openvpn"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            mkdir -p "$dir"
            log_debug "创建目录: $dir"
        fi
    done
    
    # 设置日志目录权限
    chown -R openvpn:openvpn /var/log/openvpn 2>/dev/null || true
    
    log_info "目录创建完成"
}

# 验证配置文件
validate_config() {
    log_info "验证 OpenVPN 配置文件..."
    
    if [[ ! -f "/etc/openvpn/server.conf" ]]; then
        log_error "OpenVPN 配置文件不存在: /etc/openvpn/server.conf"
        exit 1
    fi
    
    # 使用 OpenVPN 验证配置文件语法
    if ! openvpn --config /etc/openvpn/server.conf --test-crypto 2>/dev/null; then
        log_warn "配置文件验证警告，但继续启动..."
    else
        log_info "配置文件验证通过"
    fi
}

# 设置时区
setup_timezone() {
    log_info "配置容器时区..."
    
    # 默认时区
    local default_tz="Asia/Shanghai"
    
    # 如果设置了 TZ 环境变量则使用，否则使用默认值
    local target_tz="${TZ:-$default_tz}"
    
    # 检查目标时区文件是否存在
    if [[ ! -f "/usr/share/zoneinfo/${target_tz}" ]]; then
        log_warn "时区文件不存在: /usr/share/zoneinfo/${target_tz}"
        log_info "使用默认时区: $default_tz"
        target_tz="$default_tz"
    fi
    
    # 设置时区
    if [[ -f "/usr/share/zoneinfo/${target_tz}" ]]; then
        # 安装 tzdata 包（如果尚未安装）
        if ! apk info --installed tzdata >/dev/null 2>&1; then
            log_info "安装 tzdata 包..."
            apk add --no-cache tzdata >/dev/null
        fi
        
        # 创建时区链接
        ln -sf "/usr/share/zoneinfo/${target_tz}" /etc/localtime
        echo "$target_tz" > /etc/timezone
        
        log_info "时区设置为: $target_tz"
    else
        log_error "无法设置时区: $target_tz"
    fi
    
    # 同步硬件时间（在容器中可能失败，忽略错误）
    log_info "同步容器时间..."
    hwclock -s 2>/dev/null || log_debug "硬件时钟同步失败（容器环境正常）"
}

# 启动 OpenVPN 服务
start_openvpn() {
    log_info "启动 OpenVPN 服务器..."
    
    # 显示启动信息
    echo "=================================="
    echo "OpenVPN 服务器启动信息:"
    echo "配置文件: /etc/openvpn/server.conf"
    echo "监听端口: 1194/UDP"
    echo "虚拟网段: 10.8.0.0/24"
    echo "服务器虚拟IP: 10.8.0.1"
    echo "日志文件: /var/log/openvpn/openvpn.log"
    echo "状态文件: /var/log/openvpn/openvpn-status.log"
    echo "=================================="
    
    # 启动 OpenVPN（前台运行，便于容器管理）
    exec openvpn --config /etc/openvpn/server.conf --verb 3
}

# 信号处理函数
cleanup() {
    log_info "收到停止信号，正在关闭 OpenVPN 服务器..."
    pkill -TERM openvpn 2>/dev/null || true
    exit 0
}

# 注册信号处理
trap cleanup SIGTERM SIGINT

# 主函数
main() {
    log_info "OpenVPN 服务器容器启动中..."
    
    # 执行各项检查和设置
    check_privileges
    check_certificates
    setup_networking
    create_directories
    validate_config
    
    # 启动服务
    start_openvpn
}

# 如果直接执行此脚本，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi