#!/bin/bash

# =============================================================================
# OpenVPN-FRP 健康检查脚本 (增强版)
# =============================================================================
# 基于简化版本，增加完整功能，兼容macOS系统
# =============================================================================

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
DEFAULT_OUTPUT_FORMAT="text"
DEFAULT_CHECK_TIMEOUT=10
DEFAULT_CERT_WARNING_DAYS=30

# 健康检查结果 (使用简单数组避免关联数组兼容性问题)
health_results=()
health_messages=()
health_details=()
total_checks=0
passed_checks=0
warning_checks=0
failed_checks=0

# 环境变量
QUIET_MODE=${QUIET_MODE:-false}
VERBOSE_MODE=${VERBOSE_MODE:-false}
DEBUG_MODE=${DEBUG_MODE:-false}

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

log_debug() {
    if [[ "${DEBUG_MODE}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# 检测操作系统
detect_os() {
    local os_type=$(uname -s)
    local os_version=""
    
    case "$os_type" in
        "Darwin")
            os_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
            log_debug "检测到macOS系统，版本: $os_version"
            ;;
        "Linux")
            if [[ -f /etc/os-release ]]; then
                os_version=$(grep PRETTY_NAME /etc/os-release | cut -d'"' -f2)
            else
                os_version="Linux"
            fi
            log_debug "检测到Linux系统，版本: $os_version"
            ;;
        *)
            log_debug "检测到其他操作系统: $os_type"
            ;;
    esac
    
    export DETECTED_OS="$os_type"
    export DETECTED_OS_VERSION="$os_version"
}

# 显示帮助信息
show_help() {
    cat << EOF
OpenVPN-FRP 健康检查脚本 (增强版)

用法: $0 [选项]

选项:
    -f, --format FORMAT     输出格式 (text|json)
    -o, --output FILE       输出到文件
    -t, --timeout SECONDS   检查超时时间 (默认: 10秒)
    -w, --warning-days DAYS 证书警告天数 (默认: 30天)
    -c, --continuous        连续监控模式
    -i, --interval SECONDS  连续监控间隔 (默认: 60秒)
    -q, --quiet             静默模式，只输出错误
    -v, --verbose           详细模式
    -d, --debug             调试模式
    --check CATEGORY        只检查指定类别
    --help                  显示此帮助信息

检查类别:
    docker                  Docker服务和容器状态
    network                 网络连通性和端口监听
    certificates            证书有效期和完整性
    services                应用服务健康状态
    resources               系统资源使用情况
    configuration           配置文件完整性
    security                安全检查
    all                     所有检查 (默认)

输出格式:
    text                    人类可读的文本格式 (默认)
    json                    JSON格式

示例:
    $0                                      # 基本健康检查
    $0 --format json --output health.json  # JSON格式输出到文件
    $0 --continuous --interval 30          # 每30秒连续监控
    $0 --check docker                      # 只检查Docker
    $0 --quiet                             # 静默模式

EOF
}

# 加载环境配置
load_config() {
    if [[ -f .env ]]; then
        set -a
        source .env
        set +a
    fi
}

# 获取Docker Compose命令
get_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    else
        echo "docker-compose"
    fi
}

# 记录检查结果
record_result() {
    local check_name="$1"
    local status="$2"  # PASS, WARN, FAIL
    local message="$3"
    local details="${4:-}"
    
    health_results+=("$check_name:$status")
    health_messages+=("$check_name:$message")
    if [[ -n "$details" ]]; then
        health_details+=("$check_name:$details")
    fi
    
    ((total_checks++))
    
    case "$status" in
        "PASS")
            ((passed_checks++))
            if [[ "${QUIET_MODE}" != "true" ]]; then
                log_success "$check_name: $message"
            fi
            ;;
        "WARN")
            ((warning_checks++))
            log_warning "$check_name: $message"
            ;;
        "FAIL")
            ((failed_checks++))
            log_error "$check_name: $message"
            ;;
    esac
    
    if [[ "${VERBOSE_MODE}" == "true" ]] && [[ -n "$details" ]]; then
        echo "  详细信息: $details"
    fi
}

# 获取结果状态
get_result_status() {
    local check_name="$1"
    for result in "${health_results[@]}"; do
        if [[ "$result" =~ ^${check_name}: ]]; then
            echo "${result#*:}"
            return
        fi
    done
    echo "UNKNOWN"
}

# 获取结果消息
get_result_message() {
    local check_name="$1"
    for message in "${health_messages[@]}"; do
        if [[ "$message" =~ ^${check_name}: ]]; then
            echo "${message#*:}"
            return
        fi
    done
    echo ""
}

# 获取结果详情
get_result_details() {
    local check_name="$1"
    for detail in "${health_details[@]}"; do
        if [[ "$detail" =~ ^${check_name}: ]]; then
            echo "${detail#*:}"
            return
        fi
    done
    echo ""
}

# 检查Docker服务
check_docker() {
    log_info "检查Docker服务..."
    
    # 检查Docker daemon
    if docker info &> /dev/null; then
        record_result "docker_daemon" "PASS" "Docker daemon运行正常"
    else
        record_result "docker_daemon" "FAIL" "Docker daemon未运行或无权限访问"
        return
    fi
    
    # 检查Docker Compose
    local compose_cmd=$(get_compose_cmd)
    if $compose_cmd version &> /dev/null; then
        local compose_version=$($compose_cmd version --short 2>/dev/null || echo "unknown")
        record_result "docker_compose" "PASS" "Docker Compose可用 (版本: $compose_version)"
    else
        record_result "docker_compose" "FAIL" "Docker Compose不可用"
    fi
    
    # 检查项目容器状态
    local containers=$(docker ps --filter "label=openvpn-frp.service" --format "{{.Names}}")
    
    if [[ -z "$containers" ]]; then
        record_result "containers_running" "WARN" "未发现运行中的项目容器"
        return
    fi
    
    local running_count=0
    local unhealthy_containers=()
    
    for container in $containers; do
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "none")
        
        if [[ "$status" == "running" ]]; then
            ((running_count++))
            
            if [[ "$health" == "unhealthy" ]]; then
                unhealthy_containers+=("$container")
            fi
        fi
    done
    
    record_result "containers_running" "PASS" "发现 $running_count 个运行中的容器"
    
    if [[ ${#unhealthy_containers[@]} -gt 0 ]]; then
        record_result "containers_healthy" "WARN" "发现 ${#unhealthy_containers[@]} 个不健康的容器" "${unhealthy_containers[*]}"
    else
        record_result "containers_healthy" "PASS" "所有容器健康状态正常"
    fi
}

# 检查端口监听
check_port_listening() {
    local port="$1"
    local protocol="$2"
    
    log_debug "检查端口 $port/$protocol 是否监听"
    
    # 检测操作系统类型
    local os_type=$(uname -s)
    log_debug "操作系统类型: $os_type"
    
    if [[ "$os_type" == "Darwin" ]]; then
        # macOS环境优先使用lsof命令
        log_debug "macOS环境，使用lsof检查端口"
        if command -v lsof &> /dev/null; then
            if [[ "$protocol" == "tcp" ]]; then
                lsof -i TCP:$port -sTCP:LISTEN &> /dev/null
            else
                # macOS上UDP端口检查，包括Docker容器端口映射
                lsof -i UDP:$port &> /dev/null || \
                docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q ":$port->"
            fi
        else
            # 备用方案：使用netstat
            log_debug "lsof不可用，使用netstat备用方案"
            if [[ "$protocol" == "tcp" ]]; then
                netstat -an | grep -q "tcp.*\.$port.*LISTEN"
            else
                # macOS netstat UDP检查改进
                netstat -an | grep -q "udp.*\.$port" || \
                docker ps --format "table {{.Names}}\t{{.Ports}}" | grep -q ":$port->"
            fi
        fi
    else
        # Linux环境使用netstat或ss
        log_debug "Linux环境，使用netstat/ss检查端口"
        if command -v netstat &> /dev/null; then
            netstat -tuln 2>/dev/null | grep -q ":$port "
        elif command -v ss &> /dev/null; then
            ss -tuln 2>/dev/null | grep -q ":$port "
        else
            # 使用nc检查
            log_debug "netstat/ss不可用，使用nc备用方案"
            if [[ "$protocol" == "tcp" ]]; then
                nc -z localhost "$port" 2>/dev/null
            else
                # UDP检查比较复杂，这里简化处理
                nc -uz localhost "$port" 2>/dev/null
            fi
        fi
    fi
}

# 检查网络连通性
check_network() {
    log_info "检查网络连通性..."
    
    local openvpn_port="${OPENVPN_PORT:-1194}"
    local frp_port="${FRP_SERVER_PORT:-7000}"
    local dashboard_port="${FRP_DASHBOARD_PORT:-7500}"
    local timeout="${CHECK_TIMEOUT:-10}"
    
    # 检查OpenVPN端口
    if check_port_listening "$openvpn_port" "udp"; then
        record_result "openvpn_port" "PASS" "OpenVPN端口 $openvpn_port/udp 正在监听"
    else
        record_result "openvpn_port" "FAIL" "OpenVPN端口 $openvpn_port/udp 未监听"
    fi
    
    # 检查FRP相关端口（如果服务运行）
    if docker ps --filter "name=frps" --filter "status=running" | grep -q frps; then
        if check_port_listening "$frp_port" "tcp"; then
            record_result "frp_control_port" "PASS" "FRP控制端口 $frp_port/tcp 正在监听"
        else
            record_result "frp_control_port" "FAIL" "FRP控制端口 $frp_port/tcp 未监听"
        fi
        
        if check_port_listening "$dashboard_port" "tcp"; then
            record_result "frp_dashboard_port" "PASS" "FRP管理端口 $dashboard_port/tcp 正在监听"
        else
            record_result "frp_dashboard_port" "WARN" "FRP管理端口 $dashboard_port/tcp 未监听"
        fi
    fi
    
    # 检查DNS解析
    if nslookup google.com &> /dev/null; then
        record_result "dns_resolution" "PASS" "DNS解析正常"
    else
        record_result "dns_resolution" "WARN" "DNS解析可能存在问题"
    fi
    
    # 检查外网连通性
    if ping -c 1 -W $timeout 8.8.8.8 &> /dev/null; then
        record_result "internet_connectivity" "PASS" "外网连通性正常"
    else
        record_result "internet_connectivity" "WARN" "外网连通性检查失败"
    fi
}

# 检查证书
check_certificates() {
    log_info "检查证书..."
    
    local warning_days="${CERT_WARNING_DAYS:-30}"
    local current_time=$(date +%s)
    
    # 改进的日期解析函数
    parse_cert_date() {
        local cert_date="$1"
        log_debug "解析证书日期: $cert_date"
        
        # 检测操作系统类型
        local os_type=$(uname -s)
        
        if [[ "$os_type" == "Darwin" ]]; then
            # macOS环境的日期解析
            if command -v gdate &> /dev/null; then
                # 优先使用GNU date (brew install coreutils)
                log_debug "使用GNU date解析"
                gdate -d "$cert_date" +%s 2>/dev/null || echo "0"
            else
                # 使用macOS原生date命令，需要转换格式
                log_debug "使用macOS原生date解析"
                # 转换 "Nov 29 12:34:56 2025 GMT" 格式
                if [[ "$cert_date" =~ ^([A-Za-z]{3})\ +([0-9]{1,2})\ +([0-9]{2}):([0-9]{2}):([0-9]{2})\ +([0-9]{4})\ +(GMT|UTC)$ ]]; then
                    local month="${BASH_REMATCH[1]}"
                    local day="${BASH_REMATCH[2]}"
                    local hour="${BASH_REMATCH[3]}"
                    local min="${BASH_REMATCH[4]}"
                    local sec="${BASH_REMATCH[5]}"
                    local year="${BASH_REMATCH[6]}"
                    
                    # 使用macOS date格式: MMddHHmmyy
                    local month_num=""
                    case "$month" in
                        Jan) month_num="01" ;;
                        Feb) month_num="02" ;;
                        Mar) month_num="03" ;;
                        Apr) month_num="04" ;;
                        May) month_num="05" ;;
                        Jun) month_num="06" ;;
                        Jul) month_num="07" ;;
                        Aug) month_num="08" ;;
                        Sep) month_num="09" ;;
                        Oct) month_num="10" ;;
                        Nov) month_num="11" ;;
                        Dec) month_num="12" ;;
                        *) echo "0"; return ;;
                    esac
                    
                    # 补零
                    [[ ${#day} -eq 1 ]] && day="0$day"
                    
                    # 使用UTC时间
                    TZ=UTC date -j "${month_num}${day}${hour}${min}${year:2:2}" +%s 2>/dev/null || echo "0"
                else
                    log_debug "证书日期格式不匹配，使用备用解析"
                    # 备用方案：使用Python (如果可用)
                    if command -v python3 &> /dev/null; then
                        python3 -c "
import datetime
import sys
try:
    # 尝试多种日期格式
    formats = ['%b %d %H:%M:%S %Y %Z', '%b %d %H:%M:%S %Y GMT', '%b %d %H:%M:%S %Y UTC']
    for fmt in formats:
        try:
            dt = datetime.datetime.strptime('$cert_date', fmt)
            print(int(dt.timestamp()))
            sys.exit(0)
        except:
            continue
    print('0')
except:
    print('0')
" 2>/dev/null || echo "0"
                    else
                        echo "0"
                    fi
                fi
            fi
        else
            # Linux环境使用GNU date
            log_debug "Linux环境，使用GNU date解析"
            date -d "$cert_date" +%s 2>/dev/null || echo "0"
        fi
    }
    
    # 检查CA证书
    if [[ -f pki/ca/ca.crt ]]; then
        local ca_expiry=$(openssl x509 -in pki/ca/ca.crt -noout -enddate | cut -d= -f2)
        local ca_expiry_time=$(parse_cert_date "$ca_expiry")
        local ca_days_left=$(( (ca_expiry_time - current_time) / 86400 ))
        
        log_debug "CA证书过期时间: $ca_expiry (时间戳: $ca_expiry_time, 剩余天数: $ca_days_left)"
        
        if [[ $ca_expiry_time -eq 0 ]]; then
            record_result "ca_certificate" "WARN" "CA证书日期解析失败，无法验证过期时间"
        elif [[ $ca_expiry_time -gt $current_time ]]; then
            if [[ $ca_days_left -lt $warning_days ]]; then
                record_result "ca_certificate" "WARN" "CA证书将在 $ca_days_left 天后过期"
            else
                record_result "ca_certificate" "PASS" "CA证书有效，还有 $ca_days_left 天过期"
            fi
        else
            record_result "ca_certificate" "FAIL" "CA证书已过期"
        fi
    else
        record_result "ca_certificate" "FAIL" "CA证书文件不存在"
    fi
    
    # 检查服务器证书
    if [[ -f pki/server/server.crt ]]; then
        local server_expiry=$(openssl x509 -in pki/server/server.crt -noout -enddate | cut -d= -f2)
        local server_expiry_time=$(parse_cert_date "$server_expiry")
        local server_days_left=$(( (server_expiry_time - current_time) / 86400 ))
        
        log_debug "服务器证书过期时间: $server_expiry (时间戳: $server_expiry_time, 剩余天数: $server_days_left)"
        
        if [[ $server_expiry_time -eq 0 ]]; then
            record_result "server_certificate" "WARN" "服务器证书日期解析失败，无法验证过期时间"
        elif [[ $server_expiry_time -gt $current_time ]]; then
            if [[ $server_days_left -lt $warning_days ]]; then
                record_result "server_certificate" "WARN" "服务器证书将在 $server_days_left 天后过期"
            else
                record_result "server_certificate" "PASS" "服务器证书有效，还有 $server_days_left 天过期"
            fi
        else
            record_result "server_certificate" "FAIL" "服务器证书已过期"
        fi
        
        # 验证服务器证书是否由CA签名
        if openssl verify -CAfile pki/ca/ca.crt pki/server/server.crt &> /dev/null; then
            record_result "server_cert_validity" "PASS" "服务器证书验证通过"
        else
            record_result "server_cert_validity" "FAIL" "服务器证书验证失败"
        fi
    else
        record_result "server_certificate" "FAIL" "服务器证书文件不存在"
    fi
    
    # 检查DH参数
    if [[ -f pki/dh/dh2048.pem ]]; then
        if openssl dhparam -in pki/dh/dh2048.pem -check -noout &> /dev/null; then
            record_result "dh_parameters" "PASS" "DH参数文件有效"
        else
            record_result "dh_parameters" "FAIL" "DH参数文件无效"
        fi
    else
        record_result "dh_parameters" "FAIL" "DH参数文件不存在"
    fi
    
    # 检查TLS-Auth密钥
    if [[ -f pki/ta.key ]]; then
        record_result "tls_auth_key" "PASS" "TLS-Auth密钥文件存在"
    else
        record_result "tls_auth_key" "FAIL" "TLS-Auth密钥文件不存在"
    fi
}

# 检查服务健康状态
check_services() {
    log_info "检查服务健康状态..."
    
    # 检查OpenVPN服务
    if docker ps --filter "name=openvpn" --filter "status=running" | grep -q openvpn; then
        # 检查OpenVPN进程
        if docker exec openvpn pgrep openvpn &> /dev/null; then
            record_result "openvpn_process" "PASS" "OpenVPN进程运行正常"
        else
            record_result "openvpn_process" "FAIL" "OpenVPN进程未运行"
        fi
        
        # 检查OpenVPN日志是否有错误
        local error_count=$(docker logs openvpn --tail 100 2>&1 | grep -i "error\|fail\|fatal" | wc -l)
        if [[ $error_count -eq 0 ]]; then
            record_result "openvpn_logs" "PASS" "OpenVPN日志无错误"
        else
            record_result "openvpn_logs" "WARN" "OpenVPN日志中发现 $error_count 个错误条目"
        fi
    else
        record_result "openvpn_service" "FAIL" "OpenVPN容器未运行"
    fi
    
    # 检查FRP客户端服务（如果存在）
    if docker ps --filter "name=frpc" --filter "status=running" | grep -q frpc; then
        if docker exec frpc pgrep frpc &> /dev/null; then
            record_result "frpc_process" "PASS" "FRP客户端进程运行正常"
        else
            record_result "frpc_process" "FAIL" "FRP客户端进程未运行"
        fi
    fi
    
    # 检查FRP服务端服务（如果存在）
    if docker ps --filter "name=frps" --filter "status=running" | grep -q frps; then
        if docker exec frps pgrep frps &> /dev/null; then
            record_result "frps_process" "PASS" "FRP服务端进程运行正常"
        else
            record_result "frps_process" "FAIL" "FRP服务端进程未运行"
        fi
    fi
}

# 检查系统资源
check_resources() {
    log_info "检查系统资源..."
    
    # 检查磁盘空间
    local disk_usage=$(df "$PROJECT_ROOT" | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -lt 80 ]]; then
        record_result "disk_space" "PASS" "磁盘使用率: ${disk_usage}%"
    elif [[ $disk_usage -lt 90 ]]; then
        record_result "disk_space" "WARN" "磁盘使用率较高: ${disk_usage}%"
    else
        record_result "disk_space" "FAIL" "磁盘空间不足: ${disk_usage}%"
    fi
    
    # 检查内存使用 (macOS兼容)
    if command -v vm_stat &> /dev/null; then
        # macOS 使用 vm_stat
        log_debug "macOS环境，使用vm_stat检查内存"
        local vm_output=$(vm_stat)
        log_debug "vm_stat输出前几行: $(echo "$vm_output" | head -5)"
        
        # 获取页面大小
        local page_size=$(vm_stat | head -1 | sed 's/.*page size of \([0-9]*\) bytes.*/\1/')
        log_debug "页面大小: $page_size bytes"
        
        # 获取各种页面数量
        local free_pages=$(echo "$vm_output" | grep "Pages free" | awk '{print $3}' | sed 's/\.//')
        local active_pages=$(echo "$vm_output" | grep "Pages active" | awk '{print $3}' | sed 's/\.//')
        local inactive_pages=$(echo "$vm_output" | grep "Pages inactive" | awk '{print $3}' | sed 's/\.//')
        local wired_pages=$(echo "$vm_output" | grep "Pages wired down" | awk '{print $4}' | sed 's/\.//')
        local speculative_pages=$(echo "$vm_output" | grep "Pages speculative" | awk '{print $3}' | sed 's/\.//')
        local cached_pages=$(echo "$vm_output" | grep "File-backed pages" | awk '{print $3}' | sed 's/\.//')
        local compressed_pages=$(echo "$vm_output" | grep "Pages stored in compressor" | awk '{print $5}' | sed 's/\.//')
        
        # 处理空值和默认值
        [[ -z "$free_pages" ]] && free_pages=0
        [[ -z "$active_pages" ]] && active_pages=0
        [[ -z "$inactive_pages" ]] && inactive_pages=0
        [[ -z "$wired_pages" ]] && wired_pages=0
        [[ -z "$speculative_pages" ]] && speculative_pages=0
        [[ -z "$cached_pages" ]] && cached_pages=0
        [[ -z "$compressed_pages" ]] && compressed_pages=0
        
        log_debug "free: $free_pages, active: $active_pages, inactive: $inactive_pages, wired: $wired_pages"
        log_debug "speculative: $speculative_pages, cached: $cached_pages, compressed: $compressed_pages"
        
        # macOS内存管理特性：
        # - free: 完全空闲的内存
        # - active: 最近使用的内存
        # - inactive: 最近未使用但可能包含有用数据的内存
        # - wired: 不能被交换出去的内存
        # - speculative: 预读的内存，可以快速释放
        # - cached: 文件缓存，可以释放
        # - compressed: 压缩内存
        
        # 计算总内存页面数（包括压缩内存）
        local total_pages=$((free_pages + active_pages + inactive_pages + wired_pages + speculative_pages + compressed_pages))
        
        # 计算实际使用的内存（不包括可释放的缓存和speculative内存）
        # 真正"使用"的内存 = active + wired + compressed
        local truly_used_pages=$((active_pages + wired_pages + compressed_pages))
        
        # 可用内存 = free + inactive + speculative (这些都可以被释放)
        local available_pages=$((free_pages + inactive_pages + speculative_pages))
        
        # 计算内存使用率（基于真正使用的内存）
        local mem_usage=0
        if [[ $total_pages -gt 0 ]]; then
            mem_usage=$((truly_used_pages * 100 / total_pages))
        fi
        
        # 计算可用内存百分比
        local available_percentage=0
        if [[ $total_pages -gt 0 ]]; then
            available_percentage=$((available_pages * 100 / total_pages))
        fi
        
        # 转换为人类可读的大小
        local total_mb=$((total_pages * page_size / 1024 / 1024))
        local used_mb=$((truly_used_pages * page_size / 1024 / 1024))
        local available_mb=$((available_pages * page_size / 1024 / 1024))
        
        log_debug "总内存: ${total_mb}MB, 实际使用: ${used_mb}MB, 可用: ${available_mb}MB"
        log_debug "内存使用率: ${mem_usage}%, 可用率: ${available_percentage}%"
        
        # 基于实际使用率和可用内存进行判断
        if [[ $mem_usage -lt 70 ]] && [[ $available_percentage -gt 20 ]]; then
            record_result "memory_usage" "PASS" "内存使用率: ${mem_usage}% (${used_mb}MB/${total_mb}MB), 可用: ${available_percentage}%"
        elif [[ $mem_usage -lt 85 ]] && [[ $available_percentage -gt 10 ]]; then
            record_result "memory_usage" "WARN" "内存使用率较高: ${mem_usage}% (${used_mb}MB/${total_mb}MB), 可用: ${available_percentage}%"
        else
            record_result "memory_usage" "FAIL" "内存使用率过高: ${mem_usage}% (${used_mb}MB/${total_mb}MB), 可用: ${available_percentage}%"
        fi
    elif command -v free &> /dev/null; then
        # Linux 使用 free
        local mem_usage=$(free | awk 'NR==2 {printf "%.0f", $3/$2 * 100}')
        if [[ $mem_usage -lt 80 ]]; then
            record_result "memory_usage" "PASS" "内存使用率: ${mem_usage}%"
        elif [[ $mem_usage -lt 90 ]]; then
            record_result "memory_usage" "WARN" "内存使用率较高: ${mem_usage}%"
        else
            record_result "memory_usage" "FAIL" "内存使用率过高: ${mem_usage}%"
        fi
    fi
    
    # 检查Docker存储使用
    local docker_size=$(docker system df --format "table {{.Size}}" 2>/dev/null | tail -n +2 | head -1 || echo "unknown")
    record_result "docker_storage" "PASS" "Docker存储使用: $docker_size"
}

# 检查配置文件
check_configuration() {
    log_info "检查配置文件..."
    
    # 检查必要的配置文件
    local config_files=(
        ".env:环境配置"
        "config/server.conf:OpenVPN服务器配置"
        "config/frps.ini:FRP服务端配置"
        "config/frpc.ini:FRP客户端配置"
        "docker-compose.yml:Docker Compose配置"
    )
    
    for config_entry in "${config_files[@]}"; do
        local file=$(echo "$config_entry" | cut -d: -f1)
        local desc=$(echo "$config_entry" | cut -d: -f2)
        
        if [[ -f "$file" ]]; then
            record_result "config_${file//\//_}" "PASS" "$desc 文件存在"
        else
            record_result "config_${file//\//_}" "FAIL" "$desc 文件不存在"
        fi
    done
    
    # 验证Docker Compose配置语法
    local compose_cmd=$(get_compose_cmd)
    if $compose_cmd config -q &> /dev/null; then
        record_result "docker_compose_syntax" "PASS" "Docker Compose配置语法正确"
    else
        record_result "docker_compose_syntax" "FAIL" "Docker Compose配置语法错误"
    fi
}

# 检查安全性
check_security() {
    log_info "检查安全配置..."
    
    # 检查文件权限 (macOS兼容)
    if [[ -f pki/ca/private/ca.key ]]; then
        local ca_key_perm=$(stat -f "%A" pki/ca/private/ca.key 2>/dev/null || stat -c "%a" pki/ca/private/ca.key 2>/dev/null || echo "unknown")
        if [[ "$ca_key_perm" == "600" ]] || [[ "$ca_key_perm" == "400" ]]; then
            record_result "ca_key_permissions" "PASS" "CA私钥权限安全: $ca_key_perm"
        else
            record_result "ca_key_permissions" "WARN" "CA私钥权限可能不安全: $ca_key_perm"
        fi
    fi
    
    if [[ -f pki/server/private/server.key ]]; then
        local server_key_perm=$(stat -f "%A" pki/server/private/server.key 2>/dev/null || stat -c "%a" pki/server/private/server.key 2>/dev/null || echo "unknown")
        if [[ "$server_key_perm" == "600" ]] || [[ "$server_key_perm" == "400" ]]; then
            record_result "server_key_permissions" "PASS" "服务器私钥权限安全: $server_key_perm"
        else
            record_result "server_key_permissions" "WARN" "服务器私钥权限可能不安全: $server_key_perm"
        fi
    fi
    
    # 检查默认密码
    if [[ -f .env ]]; then
        if grep -q "frp123456" .env; then
            record_result "default_passwords" "WARN" "检测到默认密码，建议修改"
        else
            record_result "default_passwords" "PASS" "未检测到默认密码"
        fi
    fi
}

# 文本格式输出
output_text() {
    local output_file="$1"
    
    local content=""
    
    content+="
==================================================
OpenVPN-FRP 健康检查报告
==================================================
检查时间: $(date)
总检查项: $total_checks
通过: $passed_checks
警告: $warning_checks
失败: $failed_checks

"
    
    # 添加详细结果
    local processed_checks=()
    for result in "${health_results[@]}"; do
        local check_name="${result%:*}"
        
        # 避免重复处理
        local already_processed=false
        for processed in "${processed_checks[@]}"; do
            if [[ "$processed" == "$check_name" ]]; then
                already_processed=true
                break
            fi
        done
        
        if [[ "$already_processed" == "true" ]]; then
            continue
        fi
        
        processed_checks+=("$check_name")
        
        local status=$(get_result_status "$check_name")
        local message=$(get_result_message "$check_name")
        
        case "$status" in
            "PASS")
                content+="✓ $check_name: $message"$'\n'
                ;;
            "WARN")
                content+="⚠ $check_name: $message"$'\n'
                ;;
            "FAIL")
                content+="✗ $check_name: $message"$'\n'
                ;;
        esac
    done
    
    content+="
==================================================
总体状态: "
    
    if [[ $failed_checks -gt 0 ]]; then
        content+="CRITICAL - 发现 $failed_checks 个严重问题"
    elif [[ $warning_checks -gt 0 ]]; then
        content+="WARNING - 发现 $warning_checks 个警告"
    else
        content+="OK - 所有检查通过"
    fi
    
    content+="
=================================================="
    
    if [[ -n "$output_file" ]]; then
        echo "$content" > "$output_file"
        log_info "报告已保存到: $output_file"
    else
        echo "$content"
    fi
}

# JSON格式输出
output_json() {
    local output_file="$1"
    
    local json_content="{
  \"timestamp\": \"$(date -Iseconds 2>/dev/null || date)\",
  \"summary\": {
    \"total_checks\": $total_checks,
    \"passed\": $passed_checks,
    \"warnings\": $warning_checks,
    \"failed\": $failed_checks,
    \"overall_status\": \"$(
        if [[ $failed_checks -gt 0 ]]; then
            echo "CRITICAL"
        elif [[ $warning_checks -gt 0 ]]; then
            echo "WARNING"
        else
            echo "OK"
        fi
    )\"
  },
  \"checks\": {"
    
    local first=true
    local processed_checks=()
    
    for result in "${health_results[@]}"; do
        local check_name="${result%:*}"
        
        # 避免重复处理
        local already_processed=false
        for processed in "${processed_checks[@]}"; do
            if [[ "$processed" == "$check_name" ]]; then
                already_processed=true
                break
            fi
        done
        
        if [[ "$already_processed" == "true" ]]; then
            continue
        fi
        
        processed_checks+=("$check_name")
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            json_content+=","
        fi
        
        local status=$(get_result_status "$check_name")
        local message=$(get_result_message "$check_name")
        local details=$(get_result_details "$check_name")
        
        json_content+="
    \"$check_name\": {
      \"status\": \"$status\",
      \"message\": \"$message\""
      
        if [[ -n "$details" ]]; then
            json_content+=",
      \"details\": \"$details\""
        fi
        
        json_content+="
    }"
    done
    
    json_content+="
  }
}"
    
    if [[ -n "$output_file" ]]; then
        echo "$json_content" > "$output_file"
        log_info "JSON报告已保存到: $output_file"
    else
        echo "$json_content"
    fi
}

# 输出结果
output_results() {
    local format="$1"
    local output_file="$2"
    
    case "$format" in
        "json")
            output_json "$output_file"
            ;;
        *)
            output_text "$output_file"
            ;;
    esac
}

# 连续监控模式
continuous_monitoring() {
    local interval="$1"
    
    log_info "启动连续监控模式，间隔: ${interval}秒"
    log_info "按 Ctrl+C 停止监控"
    
    while true; do
        echo
        echo "=========================================="
        echo "监控检查 - $(date)"
        echo "=========================================="
        
        # 重置计数器和结果
        health_results=()
        health_messages=()
        health_details=()
        total_checks=0
        passed_checks=0
        warning_checks=0
        failed_checks=0
        
        # 执行检查
        run_health_checks
        
        # 显示简短总结
        echo
        if [[ $failed_checks -gt 0 ]]; then
            log_error "状态: CRITICAL ($failed_checks failures, $warning_checks warnings)"
        elif [[ $warning_checks -gt 0 ]]; then
            log_warning "状态: WARNING ($warning_checks warnings)"
        else
            log_success "状态: OK (所有检查通过)"
        fi
        
        sleep "$interval"
    done
}

# 执行健康检查
run_health_checks() {
    local check_categories=("$@")
    
    # 如果没有指定类别，检查所有
    if [[ ${#check_categories[@]} -eq 0 ]]; then
        check_categories=("docker" "network" "certificates" "services" "resources" "configuration" "security")
    fi
    
    for category in "${check_categories[@]}"; do
        case "$category" in
            "docker")
                check_docker
                ;;
            "network")
                check_network
                ;;
            "certificates")
                check_certificates
                ;;
            "services")
                check_services
                ;;
            "resources")
                check_resources
                ;;
            "configuration")
                check_configuration
                ;;
            "security")
                check_security
                ;;
            "all")
                check_docker
                check_network
                check_certificates
                check_services
                check_resources
                check_configuration
                check_security
                ;;
            *)
                log_warning "未知的检查类别: $category"
                ;;
        esac
    done
}

# 主函数
main() {
    local output_format="$DEFAULT_OUTPUT_FORMAT"
    local output_file=""
    local check_timeout="$DEFAULT_CHECK_TIMEOUT"
    local cert_warning_days="$DEFAULT_CERT_WARNING_DAYS"
    local continuous_mode=false
    local monitor_interval=60
    local check_categories=()
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -f|--format)
                output_format="$2"
                shift 2
                ;;
            -o|--output)
                output_file="$2"
                shift 2
                ;;
            -t|--timeout)
                check_timeout="$2"
                shift 2
                ;;
            -w|--warning-days)
                cert_warning_days="$2"
                shift 2
                ;;
            -c|--continuous)
                continuous_mode=true
                shift
                ;;
            -i|--interval)
                monitor_interval="$2"
                shift 2
                ;;
            -q|--quiet)
                QUIET_MODE=true
                shift
                ;;
            -v|--verbose)
                VERBOSE_MODE=true
                shift
                ;;
            -d|--debug)
                DEBUG_MODE=true
                shift
                ;;
            --check)
                check_categories+=("$2")
                shift 2
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                log_error "未知参数: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # 设置环境变量
    export CHECK_TIMEOUT="$check_timeout"
    export CERT_WARNING_DAYS="$cert_warning_days"
    
    # 加载配置
    load_config
    
    # 检测操作系统
    detect_os
    
    # 连续监控模式
    if [[ "$continuous_mode" == "true" ]]; then
        continuous_monitoring "$monitor_interval"
        return
    fi
    
    # 执行健康检查
    if [[ "${QUIET_MODE}" != "true" ]]; then
        echo "OpenVPN-FRP 健康检查开始..."
        echo "操作系统: ${DETECTED_OS} ${DETECTED_OS_VERSION}"
        echo "调试模式: ${DEBUG_MODE}"
        echo "检查超时: ${check_timeout}秒"
        echo "证书警告天数: ${cert_warning_days}天"
        if [[ "${DEBUG_MODE}" == "true" ]]; then
            echo "详细调试信息将在检查过程中显示"
        fi
        echo
    fi
    
    run_health_checks "${check_categories[@]}"
    
    # 输出结果
    output_results "$output_format" "$output_file"
    
    # 设置退出码
    if [[ $failed_checks -gt 0 ]]; then
        exit 2
    elif [[ $warning_checks -gt 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

# 执行主函数
main "$@"