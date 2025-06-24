#!/bin/bash

# PKI 证书生成脚本
# 用于为 OpenVPN 服务生成 CA、服务器和客户端证书

set -euo pipefail  # 更严格的错误处理：遇到错误立即退出，未定义变量报错，管道中任何命令失败都退出

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PKI_DIR="$PROJECT_ROOT/pki"
CONFIG_DIR="$PROJECT_ROOT/config"
OPENSSL_CNF="$CONFIG_DIR/openssl.cnf"

# 证书有效期（天）
CERT_VALIDITY=${CERT_VALIDITY_DAYS:-3650}  # 从环境变量读取，默认10年

# 证书主题信息（可通过环境变量配置）
CERT_COUNTRY="${CERT_COUNTRY:-CN}"
CERT_STATE="${CERT_STATE:-Beijing}"
CERT_CITY="${CERT_CITY:-Beijing}"
CERT_ORG="${CERT_ORG:-OpenVPN}"
CERT_OU="${CERT_OU:-IT Department}"
CERT_EMAIL="${CERT_EMAIL:-admin@openvpn.local}"

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# 检查 OpenSSL 是否安装
check_openssl() {
    if ! command -v openssl &> /dev/null; then
        log_error "OpenSSL 未安装，请先安装 OpenSSL"
        exit 1
    fi
    log_info "OpenSSL 版本: $(openssl version)"
}

# 创建目录结构
create_directories() {
    log_info "创建 PKI 目录结构..."
    mkdir -p "$PKI_DIR"/{ca,server,clients,dh}
    mkdir -p "$PKI_DIR/ca/private"
    mkdir -p "$PKI_DIR/server/private"
    mkdir -p "$PKI_DIR/clients/private"
    
    # 设置私钥目录权限
    chmod 700 "$PKI_DIR/ca/private"
    chmod 700 "$PKI_DIR/server/private"
    chmod 700 "$PKI_DIR/clients/private"
    
    log_success "PKI 目录结构创建完成"
}

# 生成 CA 根证书
generate_ca() {
    log_info "生成 CA 根证书..."
    
    # 生成 CA 私钥
    openssl genrsa -out "$PKI_DIR/ca/private/ca.key" 2048
    chmod 600 "$PKI_DIR/ca/private/ca.key"
    
    # 生成 CA 证书
    openssl req -new -x509 -days $CERT_VALIDITY \
        -key "$PKI_DIR/ca/private/ca.key" \
        -out "$PKI_DIR/ca/ca.crt" \
        -config "$OPENSSL_CNF" \
        -extensions v3_ca \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG} CA/OU=${CERT_OU}/CN=${CERT_ORG} CA/emailAddress=${CERT_EMAIL}"
    
    log_success "CA 根证书生成完成"
    log_info "CA 证书位置: $PKI_DIR/ca/ca.crt"
    log_info "CA 私钥位置: $PKI_DIR/ca/private/ca.key"
}

# 生成服务器证书
generate_server_cert() {
    local server_name="${1:-server}"
    log_info "生成服务器证书 ($server_name)..."
    
    # 生成服务器私钥
    openssl genrsa -out "$PKI_DIR/server/private/${server_name}.key" 2048
    chmod 600 "$PKI_DIR/server/private/${server_name}.key"
    
    # 生成服务器证书请求
    openssl req -new \
        -key "$PKI_DIR/server/private/${server_name}.key" \
        -out "$PKI_DIR/server/${server_name}.csr" \
        -config "$OPENSSL_CNF" \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG} Server/OU=${CERT_OU}/CN=${server_name}/emailAddress=server@${CERT_EMAIL#*@}"
    
    # 用 CA 签名生成服务器证书
    openssl x509 -req -days $CERT_VALIDITY \
        -in "$PKI_DIR/server/${server_name}.csr" \
        -CA "$PKI_DIR/ca/ca.crt" \
        -CAkey "$PKI_DIR/ca/private/ca.key" \
        -CAcreateserial \
        -out "$PKI_DIR/server/${server_name}.crt" \
        -extensions v3_server \
        -extfile "$OPENSSL_CNF"
    
    # 清理临时文件
    rm -f "$PKI_DIR/server/${server_name}.csr"
    
    log_success "服务器证书生成完成 ($server_name)"
    log_info "服务器证书位置: $PKI_DIR/server/${server_name}.crt"
    log_info "服务器私钥位置: $PKI_DIR/server/private/${server_name}.key"
}

# 生成客户端证书
generate_client_cert() {
    local client_name="${1:-client1}"
    log_info "生成客户端证书 ($client_name)..."
    
    # 生成客户端私钥
    openssl genrsa -out "$PKI_DIR/clients/private/${client_name}.key" 2048
    chmod 600 "$PKI_DIR/clients/private/${client_name}.key"
    
    # 生成客户端证书请求
    openssl req -new \
        -key "$PKI_DIR/clients/private/${client_name}.key" \
        -out "$PKI_DIR/clients/${client_name}.csr" \
        -config "$OPENSSL_CNF" \
        -subj "/C=${CERT_COUNTRY}/ST=${CERT_STATE}/L=${CERT_CITY}/O=${CERT_ORG} Client/OU=${CERT_OU}/CN=${client_name}/emailAddress=${client_name}@${CERT_EMAIL#*@}"
    
    # 用 CA 签名生成客户端证书
    openssl x509 -req -days $CERT_VALIDITY \
        -in "$PKI_DIR/clients/${client_name}.csr" \
        -CA "$PKI_DIR/ca/ca.crt" \
        -CAkey "$PKI_DIR/ca/private/ca.key" \
        -CAcreateserial \
        -out "$PKI_DIR/clients/${client_name}.crt" \
        -extensions v3_client \
        -extfile "$OPENSSL_CNF"
    
    # 清理临时文件
    rm -f "$PKI_DIR/clients/${client_name}.csr"
    
    log_success "客户端证书生成完成 ($client_name)"
    log_info "客户端证书位置: $PKI_DIR/clients/${client_name}.crt"
    log_info "客户端私钥位置: $PKI_DIR/clients/private/${client_name}.key"
}

# 生成 DH 参数
generate_dh() {
    local dh_bits="${1:-2048}"
    log_info "生成 DH 参数 (${dh_bits} 位)..."
    log_warn "这可能需要几分钟时间，请耐心等待..."
    
    openssl dhparam -out "$PKI_DIR/dh/dh${dh_bits}.pem" $dh_bits
    
    log_success "DH 参数生成完成"
    log_info "DH 参数位置: $PKI_DIR/dh/dh${dh_bits}.pem"
}

# 生成 TLS-auth 密钥
generate_tls_auth() {
    log_info "生成 TLS-auth 密钥..."
    
    # 生成预共享密钥
    openvpn --genkey --secret "$PKI_DIR/ta.key" 2>/dev/null || {
        # 如果 openvpn 命令不可用，使用 openssl 生成随机密钥
        log_warn "openvpn 命令不可用，使用 openssl 生成 TLS-auth 密钥"
        openssl rand -hex 256 > "$PKI_DIR/ta.key"
    }
    
    chmod 600 "$PKI_DIR/ta.key"
    
    log_success "TLS-auth 密钥生成完成"
    log_info "TLS-auth 密钥位置: $PKI_DIR/ta.key"
}

# 检查证书有效期
check_certificate_validity() {
    local cert_file="$1"
    local cert_name="$2"
    
    if [[ ! -f "$cert_file" ]]; then
        log_warn "证书文件不存在: $cert_file"
        return 1
    fi
    
    local end_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local end_timestamp=$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null)
    local current_timestamp=$(date +%s)
    local days_left=$(( (end_timestamp - current_timestamp) / 86400 ))
    
    if [[ $days_left -lt 0 ]]; then
        log_error "$cert_name 证书已过期 ($days_left 天)"
        return 1
    elif [[ $days_left -lt 30 ]]; then
        log_warn "$cert_name 证书将在 $days_left 天内过期"
    else
        log_info "$cert_name 证书有效期剩余 $days_left 天"
    fi
    
    return 0
}

# 检查所有证书有效期
check_all_certificates() {
    log_info "检查证书有效期..."
    
    local cert_issues=0
    
    # 检查CA证书
    if ! check_certificate_validity "$PKI_DIR/ca/ca.crt" "CA"; then
        ((cert_issues++))
    fi
    
    # 检查服务器证书
    if ! check_certificate_validity "$PKI_DIR/server/server.crt" "服务器"; then
        ((cert_issues++))
    fi
    
    # 检查客户端证书
    if [[ -d "$PKI_DIR/clients" ]]; then
        for cert in "$PKI_DIR/clients"/*.crt; do
            if [[ -f "$cert" ]]; then
                local client_name=$(basename "$cert" .crt)
                if ! check_certificate_validity "$cert" "客户端 $client_name"; then
                    ((cert_issues++))
                fi
            fi
        done
    fi
    
    if [[ $cert_issues -eq 0 ]]; then
        log_success "所有证书检查通过"
    else
        log_error "发现 $cert_issues 个证书问题"
        return 1
    fi
}

# 批量生成客户端证书
generate_multiple_clients() {
    local num_clients="${1:-1}"
    log_info "批量生成 $num_clients 个客户端证书..."
    
    for i in $(seq 1 $num_clients); do
        generate_client_cert "client$i"
    done
    
    log_success "批量生成 $num_clients 个客户端证书完成"
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --ca                    仅生成 CA 根证书"
    echo "  --server [名称]         生成服务器证书 (默认名称: server)"
    echo "  --client [名称]         生成客户端证书 (默认名称: client1)"
    echo "  --clients [数量]        批量生成客户端证书 (默认: 1)"
    echo "  --dh [位数]             生成 DH 参数 (默认: 2048)"
    echo "  --tls-auth              生成 TLS-auth 密钥"
    echo "  --check-validity        检查所有证书有效期"
    echo "  --all                   生成所有证书和密钥"
    echo "  --help, -h              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --all                           # 生成所有证书"
    echo "  $0 --ca --server --client          # 生成 CA、服务器和一个客户端证书"
    echo "  $0 --clients 5                     # 批量生成 5 个客户端证书"
    echo "  $0 --client myclient               # 生成名为 myclient 的客户端证书"
}

# 主函数
main() {
    log_info "开始 PKI 证书生成..."
    
    # 检查依赖
    check_openssl
    
    # 检查配置文件
    if [ ! -f "$OPENSSL_CNF" ]; then
        log_error "配置文件不存在: $OPENSSL_CNF"
        exit 1
    fi
    
    # 创建目录结构
    create_directories
    
    # 解析命令行参数
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ca)
                generate_ca
                shift
                ;;
            --server)
                if [ -n "$2" ] && [[ $2 != --* ]]; then
                    generate_server_cert "$2"
                    shift 2
                else
                    generate_server_cert
                    shift
                fi
                ;;
            --client)
                if [ -n "$2" ] && [[ $2 != --* ]]; then
                    generate_client_cert "$2"
                    shift 2
                else
                    generate_client_cert
                    shift
                fi
                ;;
            --clients)
                if [ -n "$2" ] && [[ $2 != --* ]]; then
                    generate_multiple_clients "$2"
                    shift 2
                else
                    generate_multiple_clients
                    shift
                fi
                ;;
            --dh)
                if [ -n "$2" ] && [[ $2 != --* ]]; then
                    generate_dh "$2"
                    shift 2
                else
                    generate_dh
                    shift
                fi
                ;;
            --tls-auth)
                generate_tls_auth
                shift
                ;;
            --check-validity)
                check_all_certificates
                shift
                ;;
            --all)
                generate_ca
                generate_server_cert
                generate_client_cert
                generate_dh
                generate_tls_auth
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "未知选项: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    log_success "PKI 证书生成完成！"
    echo ""
    log_info "生成的文件结构:"
    if [ -d "$PKI_DIR" ]; then
        find "$PKI_DIR" -type f | sort
    fi
}

# 执行主函数
main "$@"