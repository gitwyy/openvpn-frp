#!/bin/bash

# PKI 证书验证脚本
# 用于验证 OpenVPN 证书链的有效性和检查证书过期时间

set -e  # 遇到错误立即退出

# 配置变量
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
PKI_DIR="$PROJECT_ROOT/pki"

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
}

# 检查文件是否存在
check_file_exists() {
    local file_path="$1"
    local file_desc="$2"
    
    if [ ! -f "$file_path" ]; then
        log_error "$file_desc 不存在: $file_path"
        return 1
    fi
    return 0
}

# 验证 CA 证书
verify_ca_cert() {
    local ca_cert="$PKI_DIR/ca/ca.crt"
    local ca_key="$PKI_DIR/ca/private/ca.key"
    
    log_info "验证 CA 证书..."
    
    if ! check_file_exists "$ca_cert" "CA 证书"; then
        return 1
    fi
    
    if ! check_file_exists "$ca_key" "CA 私钥"; then
        return 1
    fi
    
    # 验证 CA 证书格式
    if openssl x509 -in "$ca_cert" -text -noout >/dev/null 2>&1; then
        log_success "CA 证书格式有效"
    else
        log_error "CA 证书格式无效"
        return 1
    fi
    
    # 验证 CA 私钥格式
    if openssl rsa -in "$ca_key" -check -noout >/dev/null 2>&1; then
        log_success "CA 私钥格式有效"
    else
        log_error "CA 私钥格式无效"
        return 1
    fi
    
    # 验证证书和私钥是否匹配
    local cert_modulus=$(openssl x509 -noout -modulus -in "$ca_cert" | openssl md5)
    local key_modulus=$(openssl rsa -noout -modulus -in "$ca_key" | openssl md5)
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        log_success "CA 证书和私钥匹配"
    else
        log_error "CA 证书和私钥不匹配"
        return 1
    fi
    
    # 检查证书是否为 CA 证书
    if openssl x509 -in "$ca_cert" -text -noout | grep -q "CA:TRUE"; then
        log_success "CA 证书具有正确的 CA 属性"
    else
        log_error "CA 证书缺少 CA 属性"
        return 1
    fi
    
    return 0
}

# 验证服务器证书
verify_server_cert() {
    local server_name="${1:-server}"
    local server_cert="$PKI_DIR/server/${server_name}.crt"
    local server_key="$PKI_DIR/server/private/${server_name}.key"
    local ca_cert="$PKI_DIR/ca/ca.crt"
    
    log_info "验证服务器证书 ($server_name)..."
    
    if ! check_file_exists "$server_cert" "服务器证书"; then
        return 1
    fi
    
    if ! check_file_exists "$server_key" "服务器私钥"; then
        return 1
    fi
    
    if ! check_file_exists "$ca_cert" "CA 证书"; then
        return 1
    fi
    
    # 验证服务器证书格式
    if openssl x509 -in "$server_cert" -text -noout >/dev/null 2>&1; then
        log_success "服务器证书格式有效"
    else
        log_error "服务器证书格式无效"
        return 1
    fi
    
    # 验证服务器私钥格式
    if openssl rsa -in "$server_key" -check -noout >/dev/null 2>&1; then
        log_success "服务器私钥格式有效"
    else
        log_error "服务器私钥格式无效"
        return 1
    fi
    
    # 验证证书和私钥是否匹配
    local cert_modulus=$(openssl x509 -noout -modulus -in "$server_cert" | openssl md5)
    local key_modulus=$(openssl rsa -noout -modulus -in "$server_key" | openssl md5)
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        log_success "服务器证书和私钥匹配"
    else
        log_error "服务器证书和私钥不匹配"
        return 1
    fi
    
    # 验证证书链
    if openssl verify -CAfile "$ca_cert" "$server_cert" >/dev/null 2>&1; then
        log_success "服务器证书链验证通过"
    else
        log_error "服务器证书链验证失败"
        return 1
    fi
    
    # 检查服务器证书的扩展密钥用法
    if openssl x509 -in "$server_cert" -text -noout | grep -q "TLS Web Server Authentication"; then
        log_success "服务器证书具有正确的扩展密钥用法"
    else
        log_warn "服务器证书可能缺少 TLS Web Server Authentication 扩展"
    fi
    
    return 0
}

# 验证客户端证书
verify_client_cert() {
    local client_name="${1:-client1}"
    local client_cert="$PKI_DIR/clients/${client_name}.crt"
    local client_key="$PKI_DIR/clients/private/${client_name}.key"
    local ca_cert="$PKI_DIR/ca/ca.crt"
    
    log_info "验证客户端证书 ($client_name)..."
    
    if ! check_file_exists "$client_cert" "客户端证书"; then
        return 1
    fi
    
    if ! check_file_exists "$client_key" "客户端私钥"; then
        return 1
    fi
    
    if ! check_file_exists "$ca_cert" "CA 证书"; then
        return 1
    fi
    
    # 验证客户端证书格式
    if openssl x509 -in "$client_cert" -text -noout >/dev/null 2>&1; then
        log_success "客户端证书格式有效"
    else
        log_error "客户端证书格式无效"
        return 1
    fi
    
    # 验证客户端私钥格式
    if openssl rsa -in "$client_key" -check -noout >/dev/null 2>&1; then
        log_success "客户端私钥格式有效"
    else
        log_error "客户端私钥格式无效"
        return 1
    fi
    
    # 验证证书和私钥是否匹配
    local cert_modulus=$(openssl x509 -noout -modulus -in "$client_cert" | openssl md5)
    local key_modulus=$(openssl rsa -noout -modulus -in "$client_key" | openssl md5)
    
    if [ "$cert_modulus" = "$key_modulus" ]; then
        log_success "客户端证书和私钥匹配"
    else
        log_error "客户端证书和私钥不匹配"
        return 1
    fi
    
    # 验证证书链
    if openssl verify -CAfile "$ca_cert" "$client_cert" >/dev/null 2>&1; then
        log_success "客户端证书链验证通过"
    else
        log_error "客户端证书链验证失败"
        return 1
    fi
    
    # 检查客户端证书的扩展密钥用法
    if openssl x509 -in "$client_cert" -text -noout | grep -q "TLS Web Client Authentication"; then
        log_success "客户端证书具有正确的扩展密钥用法"
    else
        log_warn "客户端证书可能缺少 TLS Web Client Authentication 扩展"
    fi
    
    return 0
}

# 检查证书过期时间
check_cert_expiry() {
    local cert_file="$1"
    local cert_desc="$2"
    
    if [ ! -f "$cert_file" ]; then
        log_error "$cert_desc 不存在: $cert_file"
        return 1
    fi
    
    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    
    # 使用 openssl 的 checkend 功能检查证书是否过期
    # checkend 0 检查当前是否过期，checkend 2592000 检查30天内是否过期
    if openssl x509 -in "$cert_file" -checkend 0 >/dev/null 2>&1; then
        if openssl x509 -in "$cert_file" -checkend 2592000 >/dev/null 2>&1; then
            if openssl x509 -in "$cert_file" -checkend 7776000 >/dev/null 2>&1; then
                log_success "$cert_desc 有效期充足 (过期时间: $expiry_date)"
            else
                log_warn "$cert_desc 将在90天内过期 (过期时间: $expiry_date)"
            fi
        else
            log_warn "$cert_desc 将在30天内过期 (过期时间: $expiry_date)"
        fi
    else
        log_error "$cert_desc 已过期 (过期时间: $expiry_date)"
        return 1
    fi
    
    return 0
}

# 验证 DH 参数
verify_dh_params() {
    local dh_file="$PKI_DIR/dh/dh2048.pem"
    
    log_info "验证 DH 参数..."
    
    if ! check_file_exists "$dh_file" "DH 参数文件"; then
        return 1
    fi
    
    # 验证 DH 参数格式
    if openssl dhparam -in "$dh_file" -check -noout >/dev/null 2>&1; then
        log_success "DH 参数格式有效"
    else
        log_error "DH 参数格式无效"
        return 1
    fi
    
    # 获取 DH 参数位数
    local dh_bits=$(openssl dhparam -in "$dh_file" -text -noout | grep "DH Parameters" | grep -o '[0-9]\+')
    log_info "DH 参数位数: $dh_bits"
    
    return 0
}

# 验证 TLS-auth 密钥
verify_tls_auth() {
    local ta_file="$PKI_DIR/ta.key"
    
    log_info "验证 TLS-auth 密钥..."
    
    if ! check_file_exists "$ta_file" "TLS-auth 密钥文件"; then
        return 1
    fi
    
    # 检查文件大小和内容
    local file_size=$(wc -c < "$ta_file")
    if [ $file_size -gt 100 ]; then
        log_success "TLS-auth 密钥文件大小正常 ($file_size 字节)"
    else
        log_error "TLS-auth 密钥文件大小异常 ($file_size 字节)"
        return 1
    fi
    
    return 0
}

# 批量验证客户端证书
verify_all_clients() {
    log_info "验证所有客户端证书..."
    
    local clients_dir="$PKI_DIR/clients"
    local failed_count=0
    local total_count=0
    
    if [ ! -d "$clients_dir" ]; then
        log_error "客户端证书目录不存在: $clients_dir"
        return 1
    fi
    
    for cert_file in "$clients_dir"/*.crt; do
        if [ -f "$cert_file" ]; then
            local client_name=$(basename "$cert_file" .crt)
            total_count=$((total_count + 1))
            
            if ! verify_client_cert "$client_name"; then
                failed_count=$((failed_count + 1))
            fi
            echo ""
        fi
    done
    
    if [ $total_count -eq 0 ]; then
        log_warn "未找到客户端证书"
        return 1
    fi
    
    if [ $failed_count -eq 0 ]; then
        log_success "所有 $total_count 个客户端证书验证通过"
    else
        log_error "$failed_count/$total_count 个客户端证书验证失败"
        return 1
    fi
    
    return 0
}

# 显示证书信息
show_cert_info() {
    local cert_file="$1"
    local cert_desc="$2"
    
    if [ ! -f "$cert_file" ]; then
        log_error "$cert_desc 不存在: $cert_file"
        return 1
    fi
    
    echo ""
    log_info "$cert_desc 详细信息:"
    echo "----------------------------------------"
    openssl x509 -in "$cert_file" -text -noout | grep -A1 "Subject:" | head -2
    openssl x509 -in "$cert_file" -text -noout | grep -A1 "Issuer:" | head -2
    openssl x509 -in "$cert_file" -text -noout | grep -A2 "Validity" | head -3
    openssl x509 -in "$cert_file" -text -noout | grep -A1 "Public Key Algorithm:" | head -2
    echo "----------------------------------------"
    
    return 0
}

# 显示帮助信息
show_help() {
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  --ca                    验证 CA 证书"
    echo "  --server [名称]         验证服务器证书 (默认名称: server)"
    echo "  --client [名称]         验证客户端证书 (默认名称: client1)"
    echo "  --clients               验证所有客户端证书"
    echo "  --dh                    验证 DH 参数"
    echo "  --tls-auth              验证 TLS-auth 密钥"
    echo "  --expiry                检查所有证书的过期时间"
    echo "  --info [证书文件]       显示证书详细信息"
    echo "  --all                   验证所有证书和密钥"
    echo "  --help, -h              显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $0 --all                           # 验证所有证书"
    echo "  $0 --ca --server --client          # 验证 CA、服务器和客户端证书"
    echo "  $0 --expiry                        # 检查所有证书过期时间"
    echo "  $0 --info pki/ca/ca.crt            # 显示 CA 证书信息"
}

# 主函数
main() {
    log_info "开始 PKI 证书验证..."
    
    # 检查依赖
    check_openssl
    
    # 检查 PKI 目录
    if [ ! -d "$PKI_DIR" ]; then
        log_error "PKI 目录不存在: $PKI_DIR"
        log_info "请先运行 generate-certs.sh 生成证书"
        exit 1
    fi
    
    # 解析命令行参数
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi
    
    local exit_code=0
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ca)
                verify_ca_cert || exit_code=1
                echo ""
                shift
                ;;
            --server)
                if [ -n "$2" ] && [[ $2 != --* ]]; then
                    verify_server_cert "$2" || exit_code=1
                    shift 2
                else
                    verify_server_cert || exit_code=1
                    shift
                fi
                echo ""
                ;;
            --client)
                if [ -n "$2" ] && [[ $2 != --* ]]; then
                    verify_client_cert "$2" || exit_code=1
                    shift 2
                else
                    verify_client_cert || exit_code=1
                    shift
                fi
                echo ""
                ;;
            --clients)
                verify_all_clients || exit_code=1
                echo ""
                shift
                ;;
            --dh)
                verify_dh_params || exit_code=1
                echo ""
                shift
                ;;
            --tls-auth)
                verify_tls_auth || exit_code=1
                echo ""
                shift
                ;;
            --expiry)
                log_info "检查证书过期时间..."
                [ -f "$PKI_DIR/ca/ca.crt" ] && check_cert_expiry "$PKI_DIR/ca/ca.crt" "CA 证书"
                [ -f "$PKI_DIR/server/server.crt" ] && check_cert_expiry "$PKI_DIR/server/server.crt" "服务器证书"
                for cert_file in "$PKI_DIR/clients"/*.crt; do
                    if [ -f "$cert_file" ]; then
                        local client_name=$(basename "$cert_file" .crt)
                        check_cert_expiry "$cert_file" "客户端证书 ($client_name)"
                    fi
                done
                echo ""
                shift
                ;;
            --info)
                if [ -n "$2" ] && [[ $2 != --* ]]; then
                    show_cert_info "$2" "证书文件"
                    shift 2
                else
                    log_error "--info 选项需要指定证书文件路径"
                    exit_code=1
                    shift
                fi
                ;;
            --all)
                verify_ca_cert || exit_code=1
                echo ""
                verify_server_cert || exit_code=1
                echo ""
                verify_all_clients || exit_code=1
                echo ""
                verify_dh_params || exit_code=1
                echo ""
                verify_tls_auth || exit_code=1
                echo ""
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
    
    if [ $exit_code -eq 0 ]; then
        log_success "所有验证通过！"
    else
        log_error "验证过程中发现问题，请检查上述错误信息"
    fi
    
    exit $exit_code
}

# 执行主函数
main "$@"