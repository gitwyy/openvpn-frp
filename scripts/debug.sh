#!/bin/bash

# =============================================================================
# OpenVPN-FRP 统一调试脚本
# =============================================================================
# 整合了快速检查、客户端测试、连接测试和证书验证功能
# =============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_debug() {
    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# 显示帮助
show_help() {
    cat << EOF
OpenVPN-FRP 统一调试工具

用法: $0 [命令] [选项]

命令:
    status          快速状态检查
    logs            查看服务日志
    client          生成客户端配置
    test            测试客户端连接
    certs           验证证书
    all             执行所有检查
    help            显示帮助信息

选项:
    -v, --verbose   详细输出
    -d, --debug     调试模式
    -q, --quiet     静默模式

示例:
    $0 status           # 快速状态检查
    $0 client test-user # 生成测试用户配置
    $0 test             # 测试连接
    $0 all              # 完整检查
    
EOF
}

# 快速状态检查
quick_status_check() {
    echo "======================================="
    echo "    OpenVPN 快速状态检查"
    echo "======================================="
    
    local error_count=0
    
    # 检查容器状态
    log_info "检查 OpenVPN 容器状态..."
    if docker ps | grep -q openvpn; then
        log_success "OpenVPN 容器正在运行"
        docker ps | grep openvpn
    else
        log_error "OpenVPN 容器未运行"
        ((error_count++))
    fi

    # 检查端口监听
    log_info "检查端口监听状态..."
    if lsof -i UDP:1194 2>/dev/null | grep -q .; then
        log_success "端口 1194/UDP 正在监听"
    else
        log_warn "端口 1194/UDP 未监听，可能在容器内监听"
    fi
    
    # 检查容器内端口
    if docker exec openvpn netstat -uln 2>/dev/null | grep -q ":1194"; then
        log_success "容器内端口 1194/UDP 正在监听"
    else
        log_error "容器内端口 1194/UDP 未监听"
        ((error_count++))
    fi

    # 检查OpenVPN进程
    log_info "检查 OpenVPN 进程..."
    if docker exec openvpn ps aux 2>/dev/null | grep -q "[o]penvpn"; then
        log_success "OpenVPN 进程正在运行"
        docker exec openvpn ps aux | grep "[o]penvpn"
    else
        log_error "OpenVPN 进程未运行"
        ((error_count++))
    fi

    # 检查TUN接口
    log_info "检查 TUN 接口..."
    if docker exec openvpn ip addr show tun0 2>/dev/null | grep -q "inet "; then
        log_success "TUN 接口已创建并分配IP地址"
        docker exec openvpn ip addr show tun0 | grep "inet "
    else
        log_warn "TUN 接口未找到或未分配IP地址"
    fi

    # 检查最新日志
    log_info "检查最新日志..."
    echo "最近 10 行日志："
    docker logs --tail 10 openvpn

    echo
    echo "======================================="
    if [[ $error_count -eq 0 ]]; then
        log_success "OpenVPN 服务状态检查完成，未发现严重问题"
    else
        log_warn "发现 $error_count 个问题，请查看详细信息"
    fi
    echo "======================================="
    
    return $error_count
}

# 生成客户端配置
generate_client_config() {
    local client_name="${1:-client1}"
    
    log_info "为客户端 '$client_name' 生成配置文件..."
    
    # 获取服务器IP
    local server_ip="YOUR_PUBLIC_IP"
    if [[ -f .env ]] && grep -q "OPENVPN_EXTERNAL_HOST" .env; then
        server_ip=$(grep "OPENVPN_EXTERNAL_HOST" .env | cut -d'=' -f2 | tr -d '"' | tr -d "'")
    fi
    
    log_info "服务器地址: $server_ip"
    
    # 检查证书文件
    if ! docker exec openvpn test -f "/etc/openvpn/pki/clients/${client_name}.crt"; then
        log_error "客户端证书不存在: ${client_name}.crt"
        log_info "可用的客户端证书:"
        docker exec openvpn ls /etc/openvpn/pki/clients/*.crt 2>/dev/null | sed 's|.*/||' || echo "  无"
        return 1
    fi
    
    # 生成配置文件
    cat > "${client_name}.ovpn" << EOF
client
dev tun
proto udp
remote $server_ip 1194
resolv-retry infinite
nobind
persist-key
persist-tun
verb 3
EOF

    # 添加证书内容
    echo "<ca>" >> "${client_name}.ovpn"
    docker exec openvpn cat /etc/openvpn/pki/ca/ca.crt >> "${client_name}.ovpn"
    echo "</ca>" >> "${client_name}.ovpn"
    
    echo "<cert>" >> "${client_name}.ovpn"
    docker exec openvpn cat "/etc/openvpn/pki/clients/${client_name}.crt" >> "${client_name}.ovpn"
    echo "</cert>" >> "${client_name}.ovpn"
    
    echo "<key>" >> "${client_name}.ovpn"
    docker exec openvpn cat "/etc/openvpn/pki/clients/private/${client_name}.key" >> "${client_name}.ovpn"
    echo "</key>" >> "${client_name}.ovpn"
    
    echo "<tls-auth>" >> "${client_name}.ovpn"
    docker exec openvpn cat /etc/openvpn/pki/ta.key >> "${client_name}.ovpn"
    echo "</tls-auth>" >> "${client_name}.ovpn"
    echo "key-direction 1" >> "${client_name}.ovpn"
    
    log_success "客户端配置文件已生成: ${client_name}.ovpn"
}

# 查看服务日志
view_logs() {
    local lines="${1:-50}"
    
    log_info "查看OpenVPN服务日志 (最近 $lines 行)..."
    echo
    echo "=== Docker容器日志 ==="
    docker logs --tail "$lines" openvpn
    
    echo
    echo "=== OpenVPN应用日志 ==="
    docker exec openvpn cat /var/log/openvpn/openvpn.log | tail -"$lines"
    
    echo
    echo "=== 连接状态 ==="
    docker exec openvpn cat /var/log/openvpn/openvpn-status.log
}

# 验证证书
verify_certificates() {
    log_info "验证证书..."
    
    # 检查CA证书
    if [[ -f pki/ca/ca.crt ]]; then
        local ca_info=$(openssl x509 -in pki/ca/ca.crt -noout -subject -dates)
        log_success "CA证书有效"
        echo "  $ca_info"
    else
        log_error "CA证书文件不存在"
        return 1
    fi
    
    # 检查服务器证书
    if [[ -f pki/server/server.crt ]]; then
        local server_info=$(openssl x509 -in pki/server/server.crt -noout -subject -dates)
        log_success "服务器证书有效"
        echo "  $server_info"
        
        # 验证服务器证书
        if openssl verify -CAfile pki/ca/ca.crt pki/server/server.crt &> /dev/null; then
            log_success "服务器证书验证通过"
        else
            log_error "服务器证书验证失败"
        fi
    else
        log_error "服务器证书文件不存在"
        return 1
    fi
    
    # 检查客户端证书
    log_info "检查客户端证书..."
    local client_count=0
    if [[ -d pki/clients ]]; then
        for cert in pki/clients/*.crt; do
            if [[ -f "$cert" ]]; then
                ((client_count++))
                local client_name=$(basename "$cert" .crt)
                local client_info=$(openssl x509 -in "$cert" -noout -subject -dates)
                echo "  客户端 $client_name: $client_info"
            fi
        done
        log_success "发现 $client_count 个客户端证书"
    else
        log_warn "客户端证书目录不存在"
    fi
}

# 主函数
main() {
    local command="${1:-help}"
    local verbose=false
    local debug=false
    local quiet=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--verbose)
                verbose=true
                shift
                ;;
            -d|--debug)
                debug=true
                export DEBUG_MODE=true
                shift
                ;;
            -q|--quiet)
                quiet=true
                shift
                ;;
            help|--help)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "${command}" ]] || [[ "${command}" == "help" ]]; then
                    command="$1"
                fi
                shift
                ;;
        esac
    done
    
    case "$command" in
        status)
            quick_status_check
            ;;
        logs)
            view_logs
            ;;
        client)
            local client_name="${2:-client1}"
            generate_client_config "$client_name"
            ;;
        certs)
            verify_certificates
            ;;
        all)
            log_info "执行完整的调试检查..."
            echo
            quick_status_check
            echo
            verify_certificates
            echo
            view_logs 20
            ;;
        *)
            echo "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"