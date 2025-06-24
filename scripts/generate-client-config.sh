#!/bin/bash

# =============================================================================
# OpenVPN-FRP 客户端配置生成器
# =============================================================================
# 根据部署模式和FRP配置自动生成客户端配置文件
# 支持多种连接场景和客户端证书管理
# =============================================================================

set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# 默认配置
DEFAULT_CLIENT_NAME="client1"
DEFAULT_OUTPUT_DIR="."
DEFAULT_CONFIG_NAME="client.ovpn"

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
OpenVPN-FRP 客户端配置生成器

用法: $0 [选项] [客户端名称]

选项:
    -c, --client NAME       客户端名称 (默认: client1)
    -o, --output DIR        输出目录 (默认: 当前目录)
    -n, --name FILENAME     配置文件名 (默认: client.ovpn)
    -m, --mode MODE         连接模式 (auto|direct|frp)
    -h, --host HOST         连接主机地址
    -p, --port PORT         连接端口
    -t, --template FILE     自定义模板文件
    -f, --format FORMAT     输出格式 (ovpn|inline|separate)
    --include-keys          在配置中嵌入证书和密钥
    --android               生成Android兼容配置
    --ios                   生成iOS兼容配置
    --windows               生成Windows兼容配置
    --linux                 生成Linux兼容配置
    --macos                 生成macOS兼容配置
    --multiple              生成多客户端配置
    --list-clients          列出可用的客户端证书
    --verify                验证生成的配置
    --qr-code               生成配置的二维码
    --zip                   打包输出文件
    --help                  显示此帮助信息

连接模式:
    auto                    自动检测最佳连接方式 (默认)
    direct                  直接连接模式 (需要公网IP)
    frp                     通过FRP穿透连接

输出格式:
    ovpn                    标准.ovpn格式 (默认)
    inline                  内联证书的单文件配置
    separate                分离的配置和证书文件

示例:
    $0                                      # 生成默认客户端配置
    $0 --client user1 --android             # 生成user1的Android配置
    $0 --mode frp --host 1.2.3.4           # 指定FRP连接模式
    $0 --multiple --output ./clients       # 生成所有客户端配置
    $0 --list-clients                       # 列出所有客户端
    $0 --qr-code --client mobile1          # 生成配置和二维码

EOF
}

# 加载环境配置
load_config() {
    if [[ -f .env ]]; then
        set -a
        source .env
        set +a
        log_info "已加载环境配置"
    else
        log_warning "未找到.env文件，使用默认配置"
    fi
}

# 检测部署模式和连接参数
detect_connection_params() {
    local mode="${1:-auto}"
    local host="${2:-}"
    local port="${3:-}"
    
    # 获取部署模式
    local deploy_mode="${DEPLOY_MODE:-standalone}"
    
    # 自动检测模式
    if [[ "$mode" == "auto" ]]; then
        case "$deploy_mode" in
            "standalone")
                mode="direct"
                ;;
            "frp-client"|"frp-full")
                mode="frp"
                ;;
            *)
                mode="direct"
                ;;
        esac
        # 自动检测连接模式，不输出日志（由主函数统一输出）
    fi
    
    # 确定连接主机
    if [[ -z "$host" ]]; then
        case "$mode" in
            "direct")
                host="${OPENVPN_EXTERNAL_HOST:-YOUR_PUBLIC_IP}"
                ;;
            "frp")
                host="${FRP_SERVER_ADDR:-YOUR_SERVER_IP}"
                ;;
        esac
    fi
    
    # 确定连接端口
    if [[ -z "$port" ]]; then
        port="${OPENVPN_PORT:-1194}"
    fi
    
    # 验证参数
    if [[ "$host" == "YOUR_PUBLIC_IP" ]] || [[ "$host" == "YOUR_SERVER_IP" ]]; then
        log_error "请在.env文件中设置正确的服务器地址"
        exit 1
    fi
    
    echo "$mode|$host|$port"
}

# 检查客户端证书
check_client_certificate() {
    local client_name="$1"
    
    local cert_file="pki/clients/${client_name}.crt"
    local key_file="pki/clients/private/${client_name}.key"
    
    if [[ ! -f "$cert_file" ]]; then
        log_error "客户端证书不存在: $cert_file"
        log_info "请运行以下命令生成证书:"
        log_info "  scripts/generate-certs.sh"
        return 1
    fi
    
    if [[ ! -f "$key_file" ]]; then
        log_error "客户端私钥不存在: $key_file"
        return 1
    fi
    
    # 验证证书有效性
    if ! openssl x509 -in "$cert_file" -noout -checkend 0 &> /dev/null; then
        log_error "客户端证书已过期: $client_name"
        return 1
    fi
    
    log_info "客户端证书验证通过: $client_name"
    return 0
}

# 列出可用客户端
list_clients() {
    log_info "可用的客户端证书:"
    
    if [[ ! -d pki/clients ]]; then
        log_warning "客户端证书目录不存在"
        return 1
    fi
    
    local found_clients=false
    
    for cert in pki/clients/*.crt; do
        if [[ -f "$cert" ]]; then
            local client_name=$(basename "$cert" .crt)
            local expiry_date=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
            local days_left=$(( ($(date -d "$expiry_date" +%s) - $(date +%s)) / 86400 ))
            
            if [[ $days_left -gt 0 ]]; then
                echo "  ✓ $client_name (过期: $days_left 天后)"
            else
                echo "  ✗ $client_name (已过期)"
            fi
            found_clients=true
        fi
    done
    
    if [[ "$found_clients" == "false" ]]; then
        log_warning "未找到客户端证书"
        log_info "请运行 scripts/generate-certs.sh 生成客户端证书"
    fi
}

# 生成基础配置
generate_base_config() {
    local mode="$1"
    local host="$2"
    local port="$3"
    local protocol="${OPENVPN_PROTOCOL:-udp}"
    local platform="${4:-generic}"
    
    cat << EOF
# OpenVPN客户端配置
# 生成时间: $(date)
# 连接模式: $mode
# 目标平台: $platform

client
dev tun
proto $protocol
remote $host $port
resolv-retry infinite
nobind
persist-key
persist-tun

# 认证方式
auth SHA256
cipher AES-256-CBC
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC

# TLS设置
tls-client
tls-version-min 1.2

# 压缩设置
$(if [[ "${ENABLE_COMPRESSION:-true}" == "true" ]]; then echo "compress lz4-v2"; fi)

# 安全设置
remote-cert-tls server
verify-x509-name server name

# 网络设置
pull
route-metric 1

# 连接超时
connect-timeout ${CLIENT_TIMEOUT:-120}
server-poll-timeout 4
connect-retry 2 300

# 日志设置
verb 3
mute 20

EOF

    # 平台特定配置
    case "$platform" in
        "android")
            cat << EOF
# Android特定配置
block-outside-dns
dhcp-option DNS ${DNS_SERVER_1:-8.8.8.8}
dhcp-option DNS ${DNS_SERVER_2:-8.8.4.4}

EOF
            ;;
        "ios")
            cat << EOF
# iOS特定配置
block-outside-dns
dhcp-option DNS ${DNS_SERVER_1:-8.8.8.8}
dhcp-option DNS ${DNS_SERVER_2:-8.8.4.4}

EOF
            ;;
        "windows")
            cat << EOF
# Windows特定配置
route-method exe
dhcp-option DNS ${DNS_SERVER_1:-8.8.8.8}
dhcp-option DNS ${DNS_SERVER_2:-8.8.4.4}
block-outside-dns

EOF
            ;;
        "macos")
            cat << EOF
# macOS特定配置
route-method exe
dhcp-option DNS ${DNS_SERVER_1:-8.8.8.8}
dhcp-option DNS ${DNS_SERVER_2:-8.8.4.4}

EOF
            ;;
        "linux")
            cat << EOF
# Linux特定配置
script-security 2
up /etc/openvpn/update-resolv-conf
down /etc/openvpn/update-resolv-conf

EOF
            ;;
    esac
}

# 生成内联配置
generate_inline_config() {
    local client_name="$1"
    local mode="$2"
    local host="$3"
    local port="$4"
    local platform="${5:-generic}"
    
    # 生成基础配置
    generate_base_config "$mode" "$host" "$port" "$platform"
    
    # 嵌入CA证书
    echo "<ca>"
    cat pki/ca/ca.crt
    echo "</ca>"
    echo
    
    # 嵌入客户端证书
    echo "<cert>"
    cat "pki/clients/${client_name}.crt"
    echo "</cert>"
    echo
    
    # 嵌入客户端私钥
    echo "<key>"
    cat "pki/clients/private/${client_name}.key"
    echo "</key>"
    echo
    
    # 嵌入TLS-Auth密钥
    if [[ -f pki/ta.key ]]; then
        echo "<tls-auth>"
        cat pki/ta.key
        echo "</tls-auth>"
        echo "key-direction 1"
        echo
    fi
}

# 生成分离配置
generate_separate_config() {
    local client_name="$1"
    local mode="$2"
    local host="$3"
    local port="$4"
    local output_dir="$5"
    local platform="${6:-generic}"
    
    # 生成基础配置
    generate_base_config "$mode" "$host" "$port" "$platform"
    
    # 引用外部文件
    echo "ca ca.crt"
    echo "cert ${client_name}.crt"
    echo "key ${client_name}.key"
    
    if [[ -f pki/ta.key ]]; then
        echo "tls-auth ta.key 1"
    fi
    
    # 复制证书文件到输出目录
    cp pki/ca/ca.crt "$output_dir/"
    cp "pki/clients/${client_name}.crt" "$output_dir/"
    cp "pki/clients/private/${client_name}.key" "$output_dir/"
    
    if [[ -f pki/ta.key ]]; then
        cp pki/ta.key "$output_dir/"
    fi
    
    log_info "证书文件已复制到: $output_dir"
}

# 生成客户端配置
generate_client_config() {
    local client_name="$1"
    local output_dir="$2"
    local config_name="$3"
    local mode="$4"
    local host="$5"
    local port="$6"
    local format="${7:-ovpn}"
    local platform="${8:-generic}"
    local include_keys="${9:-true}"
    
    log_info "生成客户端配置: $client_name"
    
    # 检查客户端证书
    if ! check_client_certificate "$client_name"; then
        return 1
    fi
    
    # 确保输出目录存在
    mkdir -p "$output_dir"
    
    local output_file="$output_dir/$config_name"
    
    # 根据格式生成配置
    case "$format" in
        "inline")
            generate_inline_config "$client_name" "$mode" "$host" "$port" "$platform" > "$output_file"
            ;;
        "separate")
            generate_separate_config "$client_name" "$mode" "$host" "$port" "$output_dir" "$platform" > "$output_file"
            ;;
        *)
            if [[ "$include_keys" == "true" ]]; then
                generate_inline_config "$client_name" "$mode" "$host" "$port" "$platform" > "$output_file"
            else
                generate_separate_config "$client_name" "$mode" "$host" "$port" "$output_dir" "$platform" > "$output_file"
            fi
            ;;
    esac
    
    log_success "配置文件生成完成: $output_file"
    
    # 显示配置信息
    echo
    echo "=========================="
    echo "   配置信息"
    echo "=========================="
    echo "客户端名称: $client_name"
    echo "连接模式: $mode"
    echo "服务器地址: $host:$port"
    echo "配置文件: $output_file"
    echo "目标平台: $platform"
    echo "格式: $format"
    echo "=========================="
    
    return 0
}

# 生成多客户端配置
generate_multiple_configs() {
    local output_dir="$1"
    local mode="$2"
    local host="$3"
    local port="$4"
    local format="${5:-ovpn}"
    local platform="${6:-generic}"
    local include_keys="${7:-true}"
    
    log_info "生成所有客户端配置..."
    
    if [[ ! -d pki/clients ]]; then
        log_error "客户端证书目录不存在"
        return 1
    fi
    
    local generated_count=0
    
    for cert in pki/clients/*.crt; do
        if [[ -f "$cert" ]]; then
            local client_name=$(basename "$cert" .crt)
            local client_dir="$output_dir/$client_name"
            local config_name="${client_name}.ovpn"
            
            mkdir -p "$client_dir"
            
            if generate_client_config "$client_name" "$client_dir" "$config_name" "$mode" "$host" "$port" "$format" "$platform" "$include_keys"; then
                ((generated_count++))
            fi
        fi
    done
    
    log_success "生成了 $generated_count 个客户端配置"
}

# 验证配置文件
verify_config() {
    local config_file="$1"
    
    log_info "验证配置文件: $config_file"
    
    if [[ ! -f "$config_file" ]]; then
        log_error "配置文件不存在"
        return 1
    fi
    
    local errors=0
    
    # 检查必要的配置项
    local required_options=("client" "dev" "proto" "remote")
    
    for option in "${required_options[@]}"; do
        # 匹配以选项开头的行（允许后面有空格或没有）
        if ! grep -q -E "^$option( |$)" "$config_file"; then
            log_error "缺少必要配置项: $option"
            ((errors++))
        fi
    done
    
    # 检查证书配置
    if grep -q "^ca " "$config_file"; then
        # 分离模式，检查文件是否存在
        local ca_file=$(grep "^ca " "$config_file" | awk '{print $2}')
        local config_dir=$(dirname "$config_file")
        
        if [[ ! -f "$config_dir/$ca_file" ]]; then
            log_error "CA证书文件不存在: $ca_file"
            ((errors++))
        fi
    elif ! grep -q "<ca>" "$config_file"; then
        log_error "未找到CA证书配置"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "配置文件验证通过"
        return 0
    else
        log_error "配置文件验证失败，发现 $errors 个错误"
        return 1
    fi
}

# 生成二维码
generate_qr_code() {
    local config_file="$1"
    local output_file="${config_file%.ovpn}.png"
    
    log_info "生成配置二维码..."
    
    if ! command -v qrencode &> /dev/null; then
        log_warning "qrencode未安装，跳过二维码生成"
        log_info "安装方法: brew install qrencode (macOS) 或 apt-get install qrencode (Ubuntu)"
        return 1
    fi
    
    # 生成二维码
    if qrencode -t PNG -o "$output_file" -r "$config_file"; then
        log_success "二维码生成完成: $output_file"
    else
        log_error "二维码生成失败"
        return 1
    fi
}

# 打包输出文件
create_zip_package() {
    local output_dir="$1"
    local zip_name="${2:-openvpn-client-configs.zip}"
    
    log_info "打包配置文件..."
    
    if ! command -v zip &> /dev/null; then
        log_warning "zip命令未安装，跳过打包"
        return 1
    fi
    
    local zip_file="$output_dir/$zip_name"
    
    # 创建zip包
    if (cd "$output_dir" && zip -r "$zip_name" . -x "*.zip"); then
        log_success "配置包创建完成: $zip_file"
    else
        log_error "配置包创建失败"
        return 1
    fi
}

# 主函数
main() {
    local client_name="$DEFAULT_CLIENT_NAME"
    local output_dir="$DEFAULT_OUTPUT_DIR"
    local config_name="$DEFAULT_CONFIG_NAME"
    local mode="auto"
    local host=""
    local port=""
    local template_file=""
    local format="ovpn"
    local platform="generic"
    local include_keys=true
    local list_clients_only=false
    local multiple_clients=false
    local verify_config_only=false
    local generate_qr=false
    local create_zip=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--client)
                client_name="$2"
                shift 2
                ;;
            -o|--output)
                output_dir="$2"
                shift 2
                ;;
            -n|--name)
                config_name="$2"
                shift 2
                ;;
            -m|--mode)
                mode="$2"
                shift 2
                ;;
            -h|--host)
                host="$2"
                shift 2
                ;;
            -p|--port)
                port="$2"
                shift 2
                ;;
            -t|--template)
                template_file="$2"
                shift 2
                ;;
            -f|--format)
                format="$2"
                shift 2
                ;;
            --include-keys)
                include_keys=true
                shift
                ;;
            --android)
                platform="android"
                shift
                ;;
            --ios)
                platform="ios"
                shift
                ;;
            --windows)
                platform="windows"
                shift
                ;;
            --linux)
                platform="linux"
                shift
                ;;
            --macos)
                platform="macos"
                shift
                ;;
            --multiple)
                multiple_clients=true
                shift
                ;;
            --list-clients)
                list_clients_only=true
                shift
                ;;
            --verify)
                verify_config_only=true
                shift
                ;;
            --qr-code)
                generate_qr=true
                shift
                ;;
            --zip)
                create_zip=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "$client_name" ]] || [[ "$client_name" == "$DEFAULT_CLIENT_NAME" ]]; then
                    client_name="$1"
                else
                    log_error "未知参数: $1"
                    show_help
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # 加载配置
    load_config
    
    # 只列出客户端
    if [[ "$list_clients_only" == "true" ]]; then
        list_clients
        exit 0
    fi
    
    # 只验证配置
    if [[ "$verify_config_only" == "true" ]]; then
        if [[ -f "$config_name" ]]; then
            verify_config "$config_name"
        else
            log_error "配置文件不存在: $config_name"
            exit 1
        fi
        exit 0
    fi
    
    # 检测连接参数
    local connection_params=$(detect_connection_params "$mode" "$host" "$port")
    IFS='|' read -r mode host port <<< "$connection_params"
    
    # 确保变量存在
    if [[ -z "${mode}" ]]; then
        log_error "连接模式未定义"
        exit 1
    fi
    
    log_info "连接参数: ${mode}模式, ${host}:${port}"
    
    # 生成配置
    if [[ "$multiple_clients" == "true" ]]; then
        generate_multiple_configs "$output_dir" "$mode" "$host" "$port" "$format" "$platform" "$include_keys"
    else
        # 如果配置名没有指定客户端名，则使用客户端名作为配置文件名
        if [[ "$config_name" == "$DEFAULT_CONFIG_NAME" ]] && [[ "$client_name" != "$DEFAULT_CLIENT_NAME" ]]; then
            config_name="${client_name}.ovpn"
        fi
        
        if generate_client_config "$client_name" "$output_dir" "$config_name" "$mode" "$host" "$port" "$format" "$platform" "$include_keys"; then
            local config_file="$output_dir/$config_name"
            
            # 验证生成的配置
            verify_config "$config_file"
            
            # 生成二维码
            if [[ "$generate_qr" == "true" ]]; then
                generate_qr_code "$config_file"
            fi
        else
            exit 1
        fi
    fi
    
    # 创建压缩包
    if [[ "$create_zip" == "true" ]]; then
        create_zip_package "$output_dir"
    fi
    
    echo
    log_success "客户端配置生成完成！"
    
    # 显示使用说明
    echo
    echo "=========================="
    echo "   使用说明"
    echo "=========================="
    echo "1. 将配置文件导入OpenVPN客户端"
    echo "2. 如果是分离模式，请同时复制所有证书文件"
    echo "3. 连接前请确保服务器端OpenVPN服务正在运行"
    echo "4. 如有连接问题，请检查防火墙和网络设置"
    echo "=========================="
}

# 执行主函数
main "$@"