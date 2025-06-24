#!/bin/bash

# =============================================================================
# OpenVPN-FRP Docker工具集
# =============================================================================
# 整合了镜像源测试、配置更新、验证等Docker相关功能
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

# 默认配置
NETWORK_TEST_TIMEOUT=5
VERBOSE=false

# 2024年可用的Docker镜像源列表
declare -a WORKING_MIRRORS=(
    "https://docker.1panel.live"
    "https://docker.m.daocloud.io"
    "https://docker.nju.edu.cn"
)

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
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# 显示帮助
show_help() {
    cat << EOF
OpenVPN-FRP Docker工具集

用法: $0 [命令] [选项]

命令:
    test            测试Docker镜像源连通性
    update          更新Docker镜像源配置
    configure       交互式配置Docker daemon
    verify          验证镜像源修复结果
    best            获取最佳镜像源
    fix             修复Docker镜像源问题
    help            显示帮助信息

选项:
    -v, --verbose   详细输出
    -q, --quiet     静默模式
    --timeout SEC   网络测试超时时间 (默认: 5秒)
    --format FMT    输出格式 (table|json|simple)

示例:
    $0 test                     # 测试所有镜像源
    $0 test --best              # 只显示最佳镜像源
    $0 update                   # 更新Docker配置
    $0 configure                # 交互式配置Docker daemon
    $0 verify                   # 验证修复结果
    $0 fix                      # 一键修复Docker问题
    
EOF
}

# 测试单个镜像源
test_single_mirror() {
    local mirror="$1"
    local timeout="${2:-$NETWORK_TEST_TIMEOUT}"
    
    log_debug "测试镜像源: $mirror"
    
    # 记录开始时间
    local start_time=$(date +%s.%N)
    
    # 测试方法1: 检查registry API
    if command -v curl &> /dev/null; then
        if curl -s --connect-timeout "$timeout" --max-time "$timeout" "https://$mirror/v2/" &> /dev/null; then
            local end_time=$(date +%s.%N)
            local response_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            log_debug "镜像源 $mirror 响应时间: ${response_time}s"
            echo "$response_time"
            return 0
        fi
    fi
    
    # 测试方法2: 使用wget
    if command -v wget &> /dev/null; then
        if wget --timeout="$timeout" --tries=1 -q -O /dev/null "https://$mirror/v2/" 2>/dev/null; then
            local end_time=$(date +%s.%N)
            local response_time=$(echo "$end_time - $start_time" | bc 2>/dev/null || echo "0")
            log_debug "镜像源 $mirror 响应时间: ${response_time}s"
            echo "$response_time"
            return 0
        fi
    fi
    
    log_debug "镜像源 $mirror 连接失败"
    echo "-1"
    return 1
}

# 测试所有镜像源
test_all_mirrors() {
    local format="${1:-table}"
    local show_best_only="${2:-false}"
    
    # 定义镜像源列表
    local mirror_names=("Docker Hub" "1Panel社区" "DaoCloud" "南京大学")
    local mirror_urls=("registry-1.docker.io" "docker.1panel.live" "docker.m.daocloud.io" "docker.nju.edu.cn")
    
    # 存储测试结果
    local available_mirrors=()
    
    log_info "开始测试镜像源连通性..."
    echo
    
    # 根据输出格式初始化
    if [[ "$format" == "table" ]] && [[ "$show_best_only" == "false" ]]; then
        printf "%-15s %-40s %-10s %-10s\n" "名称" "地址" "状态" "响应时间"
        printf "%-15s %-40s %-10s %-10s\n" "----" "----" "----" "--------"
    fi
    
    local total_mirrors=${#mirror_names[@]}
    
    for ((i=0; i<$total_mirrors; i++)); do
        local name="${mirror_names[$i]}"
        local mirror="${mirror_urls[$i]}"
        local response_time=$(test_single_mirror "$mirror")
        
        if [[ "$response_time" != "-1" ]]; then
            available_mirrors+=("$name:$mirror:$response_time")
            
            if [[ "$show_best_only" == "false" ]]; then
                case "$format" in
                    "table")
                        printf "%-15s %-40s ${GREEN}%-10s${NC} %-10s\n" "$name" "$mirror" "✓ 可用" "${response_time}s"
                        ;;
                    "json")
                        echo "{\"name\": \"$name\", \"url\": \"$mirror\", \"status\": \"available\", \"response_time\": $response_time}"
                        ;;
                    "simple")
                        echo "$name:$mirror:available:$response_time"
                        ;;
                esac
            fi
        elif [[ "$show_best_only" == "false" ]]; then
            case "$format" in
                "table")
                    printf "%-15s %-40s ${RED}%-10s${NC} %-10s\n" "$name" "$mirror" "✗ 不可用" "-"
                    ;;
                "json")
                    echo "{\"name\": \"$name\", \"url\": \"$mirror\", \"status\": \"unavailable\", \"response_time\": null}"
                    ;;
                "simple")
                    echo "$name:$mirror:unavailable:-"
                    ;;
            esac
        fi
    done
    
    echo
    log_info "测试完成，共测试 ${#mirror_names[@]} 个镜像源，${#available_mirrors[@]} 个可用"
    
    # 显示最佳镜像源
    if [[ ${#available_mirrors[@]} -gt 0 ]]; then
        # 按响应时间排序
        local best_mirror=""
        local best_time=999999
        local best_name=""
        
        for mirror_info in "${available_mirrors[@]}"; do
            local name="${mirror_info%%:*}"
            local url="${mirror_info#*:}"
            url="${url%:*}"
            local time="${mirror_info##*:}"
            
            if (( $(echo "$time < $best_time" | bc -l 2>/dev/null || echo "0") )); then
                best_time="$time"
                best_mirror="$url"
                best_name="$name"
            fi
        done
        
        echo
        log_success "推荐镜像源: ${best_name} (${best_mirror}) - 响应时间: ${best_time}s"
        
        if [[ "$show_best_only" == "false" ]]; then
            echo
            echo "使用建议:"
            echo "1. 更新Docker配置:"
            echo "   $0 update"
            echo "2. 构建OpenVPN镜像:"
            echo "   scripts/build-openvpn.sh"
            echo "3. 构建FRP镜像:"
            echo "   scripts/build-frp.sh"
        fi
        
        # 如果只显示最佳镜像源，返回镜像源URL
        if [[ "$show_best_only" == "true" ]]; then
            echo "$best_mirror"
        fi
    else
        log_warn "没有找到可用的镜像源"
        return 1
    fi
}

# 获取最佳镜像源（静默模式）
get_best_mirror() {
    local mirror_urls=("docker.1panel.live" "docker.m.daocloud.io" "docker.nju.edu.cn")
    
    local best_mirror=""
    local best_time=999999
    
    for mirror in "${mirror_urls[@]}"; do
        local response_time=$(test_single_mirror "$mirror" 2>/dev/null)
        
        if [[ "$response_time" != "-1" ]] && (( $(echo "$response_time < $best_time" | bc -l 2>/dev/null || echo "0") )); then
            best_time="$response_time"
            best_mirror="$mirror"
        fi
    done
    
    if [[ -n "$best_mirror" ]]; then
        echo "$best_mirror"
        return 0
    else
        return 1
    fi
}

# 检测操作系统
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    else
        echo "unknown"
    fi
}

# 获取Docker配置文件路径
get_docker_config_path() {
    local os_type=$(detect_os)
    case $os_type in
        "macos")
            echo "$HOME/.docker/daemon.json"
            ;;
        "linux")
            echo "/etc/docker/daemon.json"
            ;;
        *)
            log_error "不支持的操作系统: $OSTYPE"
            exit 1
            ;;
    esac
}

# 验证配置格式
validate_config() {
    local config_path="$1"
    if command -v jq &> /dev/null; then
        if jq empty "$config_path" 2>/dev/null; then
            log_success "配置文件格式验证通过"
            return 0
        else
            log_error "配置文件格式无效"
            return 1
        fi
    else
        log_warn "未安装jq，跳过配置格式验证"
        return 0
    fi
}

# 显示当前配置
show_current_config() {
    local config_path="$1"
    if [[ -f "$config_path" ]]; then
        log_info "当前Docker daemon配置:"
        if command -v jq &> /dev/null; then
            jq . "$config_path" 2>/dev/null || cat "$config_path"
        else
            cat "$config_path"
        fi
    else
        log_info "Docker daemon配置文件不存在: $config_path"
    fi
}

# 更新Docker daemon配置
update_docker_config() {
    local interactive="${1:-false}"
    
    log_info "更新Docker镜像源配置..."
    
    # 获取配置文件路径
    local daemon_config=$(get_docker_config_path)
    local config_dir=$(dirname "$daemon_config")
    
    log_debug "Docker daemon配置文件路径: $daemon_config"
    
    # 显示当前配置
    if [[ "$VERBOSE" == "true" ]]; then
        show_current_config "$daemon_config"
    fi
    
    # 交互式确认
    if [[ "$interactive" == "true" ]]; then
        echo
        read -p "是否要配置Docker daemon镜像源? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "操作已取消"
            return 0
        fi
    fi
    
    # 创建Docker配置目录
    if [[ ! -d "$config_dir" ]]; then
        log_info "创建配置目录: $config_dir"
        mkdir -p "$config_dir"
    fi
    
    # 备份现有配置
    if [[ -f "$daemon_config" ]]; then
        local backup_path="${daemon_config}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$daemon_config" "$backup_path"
        log_info "已备份现有Docker配置到: $backup_path"
    fi
    
    # 创建新的daemon.json配置
    cat > "$daemon_config" << EOF
{
  "registry-mirrors": [
$(printf '    "%s",\n' "${WORKING_MIRRORS[@]}" | sed '$ s/,$//')
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "experimental": false,
  "features": {
    "buildkit": true
  },
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  }
}
EOF
    
    log_success "已更新Docker daemon配置: $daemon_config"
    
    # 验证配置格式
    if ! validate_config "$daemon_config"; then
        log_error "配置验证失败，请检查配置文件"
        return 1
    fi
    
    # 重启Docker服务
    restart_docker_service
}

# 重启Docker服务
restart_docker_service() {
    local os_type=$(detect_os)
    
    log_info "重启Docker服务以应用新配置..."
    
    case $os_type in
        "macos")
            # 尝试自动重启Docker Desktop
            if osascript -e 'quit app "Docker Desktop"' 2>/dev/null; then
                log_info "正在关闭Docker Desktop..."
                sleep 3
                
                if open -a "Docker Desktop" 2>/dev/null; then
                    log_info "Docker Desktop已重启，等待服务启动..."
                    
                    # 等待Docker服务重新启动
                    local max_attempts=30
                    local attempt=0
                    while [[ $attempt -lt $max_attempts ]]; do
                        if docker version >/dev/null 2>&1; then
                            log_success "Docker服务已启动"
                            return 0
                        fi
                        sleep 2
                        ((attempt++))
                    done
                    
                    log_error "Docker服务启动超时"
                    return 1
                else
                    log_warn "无法自动启动Docker Desktop，请手动启动"
                    return 1
                fi
            else
                log_warn "在macOS上，请手动重启Docker Desktop应用"
                log_info "或使用以下命令:"
                log_info "  killall Docker && open /Applications/Docker.app"
                return 1
            fi
            ;;
        "linux")
            if command -v systemctl &> /dev/null; then
                log_info "使用systemctl重启Docker服务..."
                if sudo systemctl restart docker; then
                    log_success "Docker服务已重启"
                    
                    # 等待服务完全启动
                    sleep 3
                    if docker version >/dev/null 2>&1; then
                        log_success "Docker服务运行正常"
                        return 0
                    else
                        log_error "Docker服务重启后无法连接"
                        return 1
                    fi
                else
                    log_error "Docker服务重启失败"
                    return 1
                fi
            else
                log_warn "请手动重启Docker服务"
                log_info "可能的重启命令："
                log_info "  sudo service docker restart"
                log_info "  sudo /etc/init.d/docker restart"
                return 1
            fi
            ;;
        *)
            log_error "不支持的操作系统，请手动重启Docker服务"
            return 1
            ;;
    esac
}

# 验证配置是否生效
verify_docker_config() {
    log_info "验证镜像源配置..."
    
    # 检查Docker是否运行
    if ! docker version >/dev/null 2>&1; then
        log_error "Docker服务未运行"
        return 1
    fi
    
    # 尝试拉取测试镜像
    local test_images=("hello-world:latest" "alpine:3.18")
    local success_count=0
    
    for image in "${test_images[@]}"; do
        log_debug "测试拉取镜像: $image"
        if docker pull "docker.1panel.live/library/$image" >/dev/null 2>&1; then
            log_success "成功拉取: docker.1panel.live/library/$image"
            ((success_count++))
        else
            log_warn "拉取失败: docker.1panel.live/library/$image"
        fi
    done
    
    if [[ $success_count -gt 0 ]]; then
        log_success "镜像源配置验证成功！"
        return 0
    else
        log_error "镜像源配置验证失败"
        return 1
    fi
}

# 一键修复Docker问题
fix_docker_issues() {
    log_info "开始一键修复Docker镜像源问题..."
    echo
    
    # 步骤1: 测试镜像源
    log_info "步骤1: 测试镜像源连通性"
    if ! test_all_mirrors "simple" >/dev/null 2>&1; then
        log_error "所有镜像源都不可用，请检查网络连接"
        return 1
    fi
    
    # 步骤2: 更新配置
    log_info "步骤2: 更新Docker配置"
    if ! update_docker_config; then
        log_error "配置更新失败"
        return 1
    fi
    
    # 步骤3: 验证配置
    log_info "步骤3: 验证配置生效"
    sleep 5  # 等待Docker重启
    if verify_docker_config; then
        echo
        log_success "Docker镜像源问题修复完成！"
        echo
        echo "现在可以正常使用："
        echo "  scripts/build-openvpn.sh"
        echo "  scripts/build-frp.sh"
        echo "  docker-compose build"
        return 0
    else
        log_error "配置验证失败"
        return 1
    fi
}

# 主函数
main() {
    local command="${1:-help}"
    local format="table"
    local show_best_only=false
    local quiet=false
    
    # 解析参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            test)
                command="test"
                shift
                ;;
            update)
                command="update"
                shift
                ;;
            configure)
                command="configure"
                shift
                ;;
            verify)
                command="verify"
                shift
                ;;
            best)
                command="best"
                shift
                ;;
            fix)
                command="fix"
                shift
                ;;
            --best)
                show_best_only=true
                shift
                ;;
            --format)
                format="$2"
                shift 2
                ;;
            --timeout)
                NETWORK_TEST_TIMEOUT="$2"
                shift 2
                ;;
            -v|--verbose)
                VERBOSE=true
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
    
    # 检查依赖
    if [[ "$command" != "help" ]]; then
        if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
            log_error "需要安装 curl 或 wget"
            exit 1
        fi
    fi
    
    # 执行命令
    case "$command" in
        test)
            if [[ "$quiet" == "true" ]]; then
                test_all_mirrors "$format" "$show_best_only" >/dev/null 2>&1
            else
                test_all_mirrors "$format" "$show_best_only"
            fi
            ;;
        best)
            if best_mirror=$(get_best_mirror); then
                echo "$best_mirror"
            else
                log_error "没有找到可用的镜像源"
                exit 1
            fi
            ;;
        update)
            update_docker_config
            ;;
        configure)
            update_docker_config "true"
            ;;
        verify)
            verify_docker_config
            ;;
        fix)
            fix_docker_issues
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