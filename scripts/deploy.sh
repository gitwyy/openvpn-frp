#!/bin/bash

# =============================================================================
# OpenVPN-FRP 一键部署脚本
# =============================================================================
# 此脚本提供完整的一键部署解决方案，支持多种部署场景
# 
# 支持的部署模式：
# - standalone: 纯OpenVPN服务（有公网IP的服务器）
# - frp-client: OpenVPN + FRP客户端（内网服务器）
# - frp-full: 完整FRP架构（服务端+客户端）
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
DEFAULT_DEPLOY_MODE="standalone"
DEFAULT_OPENVPN_PORT="1194"
DEFAULT_FRP_SERVER_PORT="7000"
DEFAULT_FRP_DASHBOARD_PORT="7500"

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
    if [[ "${DEBUG_MODE:-false}" == "true" ]]; then
        echo -e "${PURPLE}[DEBUG]${NC} $1"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
OpenVPN-FRP 一键部署脚本

用法: $0 [选项]

选项:
    -m, --mode MODE         部署模式 (standalone|frp-client|frp-full)
    -h, --host HOST         FRP服务器地址 (frp-client和frp-full模式必需)
    -p, --port PORT         OpenVPN端口 (默认: 1194)
    -t, --token TOKEN       FRP认证令牌
    -c, --config FILE       自定义配置文件路径
    -f, --force             强制重新部署
    -d, --debug             启用调试模式
    --skip-deps             跳过依赖检查
    --skip-certs            跳过证书生成
    --skip-build            跳过镜像构建
    --dry-run               仅显示将要执行的操作
    --help                  显示此帮助信息

部署模式说明:
    standalone              纯OpenVPN服务，适用于有公网IP的服务器
    frp-client              OpenVPN + FRP客户端，适用于内网服务器
    frp-full                完整FRP架构，包含服务端和客户端

Docker镜像管理:
    使用专门的Docker工具进行镜像管理:
    scripts/docker-tools.sh test       # 测试镜像源连通性
    scripts/docker-tools.sh configure  # 配置镜像源
    scripts/docker-tools.sh fix        # 一键修复Docker问题

示例:
    $0 --mode standalone
    $0 --mode frp-client --host 192.168.1.100 --token my_token
    $0 --mode frp-full --port 1194 --token secure_token
    $0 --skip-build --mode standalone  # 跳过镜像构建

EOF
}

# 检查系统依赖
check_dependencies() {
    log_info "检查系统依赖..."
    
    local missing_deps=()
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # 检查Docker Compose
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    # 检查OpenSSL
    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi
    
    # 检查必要的网络工具
    if ! command -v nc &> /dev/null && ! command -v netcat &> /dev/null; then
        missing_deps+=("netcat")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "缺少以下依赖: ${missing_deps[*]}"
        log_info "请安装缺少的依赖后重试"
        
        # 提供安装建议
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "macOS安装建议:"
            log_info "  brew install docker docker-compose openssl netcat"
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            log_info "Ubuntu/Debian安装建议:"
            log_info "  sudo apt-get update && sudo apt-get install docker.io docker-compose openssl netcat"
            log_info "CentOS/RHEL安装建议:"
            log_info "  sudo yum install docker docker-compose openssl nc"
        fi
        
        exit 1
    fi
    
    # 检查Docker服务状态
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请启动Docker服务"
        exit 1
    fi
    
    # 检查Docker权限
    if ! docker ps &> /dev/null; then
        log_error "当前用户没有Docker权限，请将用户添加到docker组或使用sudo运行"
        exit 1
    fi
    
    log_success "所有依赖检查通过"
}

# 检查系统权限
check_permissions() {
    log_info "检查系统权限..."
    
    # 检测操作系统类型
    local os_type=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        os_type="macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        os_type="Linux"
    else
        os_type="Unknown"
    fi
    
    log_info "检测到操作系统: $os_type"
    
    # 检查TUN设备
    if [[ ! -e /dev/net/tun ]]; then
        log_warning "/dev/net/tun 设备不存在"
        
        if [[ "$os_type" == "macOS" ]]; then
            log_info "macOS环境检测到，将使用Docker容器内的TUN设备"
            log_info "如果容器启动失败，请考虑以下解决方案："
            log_info "  1. 安装 TunTap OSX: https://sourceforge.net/projects/tuntaposx/"
            log_info "  2. 使用 Docker Desktop 的网络功能"
            log_info "  3. 在容器中创建TUN设备（推荐）"
            log_warning "跳过主机TUN设备检查，容器将尝试自行创建设备"
        else
            log_error "Linux环境下 /dev/net/tun 设备不存在"
            log_info "请执行以下命令之一："
            log_info "  sudo modprobe tun"
            log_info "  sudo mkdir -p /dev/net && sudo mknod /dev/net/tun c 10 200"
            exit 1
        fi
    else
        log_info "TUN设备存在: /dev/net/tun"
        
        # 检查是否可以创建TUN设备
        if [[ ! -r /dev/net/tun ]] || [[ ! -w /dev/net/tun ]]; then
            log_warning "TUN设备权限不足，可能需要特权模式运行"
        fi
    fi
    
    log_success "权限检查完成"
}

# 加载环境配置
load_config() {
    log_info "加载配置文件..."
    
    # 如果.env文件不存在，从.env.example创建
    if [[ ! -f .env ]]; then
        if [[ -f .env.example ]]; then
            log_info "从 .env.example 创建 .env 文件"
            cp .env.example .env
        else
            log_error ".env.example 文件不存在"
            exit 1
        fi
    fi
    
    # 加载环境变量
    if [[ -f .env ]]; then
        set -a
        source .env
        set +a
        log_success "配置文件加载完成"
    else
        log_warning "未找到配置文件，使用默认配置"
    fi
}

# 验证配置
validate_config() {
    log_info "验证配置参数..."
    
    # 验证部署模式
    if [[ ! "$DEPLOY_MODE" =~ ^(standalone|frp-client|frp-full)$ ]]; then
        log_error "无效的部署模式: $DEPLOY_MODE"
        log_info "支持的模式: standalone, frp-client, frp-full"
        exit 1
    fi
    
    # 验证FRP配置（如果需要）
    if [[ "$DEPLOY_MODE" =~ ^(frp-client|frp-full)$ ]]; then
        if [[ -z "${FRP_SERVER_ADDR:-}" ]] || [[ "$FRP_SERVER_ADDR" == "YOUR_SERVER_IP" ]]; then
            log_error "FRP模式需要设置有效的FRP_SERVER_ADDR"
            exit 1
        fi
        
        if [[ -z "${FRP_TOKEN:-}" ]] || [[ "$FRP_TOKEN" == "frp_secure_token_2024" ]]; then
            log_warning "建议更改默认的FRP_TOKEN以提高安全性"
        fi
    fi
    
    # 验证端口配置
    if [[ ! "${OPENVPN_PORT:-1194}" =~ ^[0-9]+$ ]] || [[ "${OPENVPN_PORT:-1194}" -lt 1 ]] || [[ "${OPENVPN_PORT:-1194}" -gt 65535 ]]; then
        log_error "无效的OpenVPN端口: ${OPENVPN_PORT:-1194}"
        exit 1
    fi
    
    log_success "配置验证通过"
}

# 生成证书
generate_certificates() {
    if [[ "${SKIP_CERTS:-false}" == "true" ]]; then
        log_info "跳过证书生成"
        return
    fi
    
    log_info "生成OpenVPN证书..."
    
    if [[ -f scripts/generate-certs.sh ]]; then
        chmod +x scripts/generate-certs.sh
        
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] 将执行: scripts/generate-certs.sh"
        else
            if scripts/generate-certs.sh; then
                log_success "证书生成完成"
            else
                log_error "证书生成失败"
                exit 1
            fi
        fi
    else
        log_error "证书生成脚本不存在: scripts/generate-certs.sh"
        exit 1
    fi
}

# 构建Docker镜像
build_images() {
    if [[ "${SKIP_BUILD:-false}" == "true" ]]; then
        log_info "跳过镜像构建"
        return
    fi
    
    log_info "构建Docker镜像..."
    
    # 检查Docker服务状态
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请先启动Docker"
        exit 1
    fi
    
    # 构建OpenVPN镜像
    log_info "构建OpenVPN镜像..."
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] 将执行: scripts/build-openvpn.sh"
    else
        if scripts/build-openvpn.sh; then
            log_success "OpenVPN镜像构建完成"
        else
            log_error "OpenVPN镜像构建失败"
            log_error "请尝试以下解决方案："
            log_error "1. 检查网络连接"
            log_error "2. 使用Docker工具修复: scripts/docker-tools.sh fix"
            log_error "3. 手动配置镜像源: scripts/docker-tools.sh configure"
            exit 1
        fi
    fi
    
    # 根据部署模式构建FRP镜像
    if [[ "$DEPLOY_MODE" =~ ^(frp-client|frp-full)$ ]]; then
        log_info "构建FRP镜像..."
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] 将执行: scripts/build-frp.sh"
        else
            local frp_build_args=""
            
            # 根据部署模式选择构建选项
            if [[ "$DEPLOY_MODE" == "frp-client" ]]; then
                frp_build_args="--client-only"
            elif [[ "$DEPLOY_MODE" == "frp-full" ]]; then
                # 构建服务端和客户端
                frp_build_args=""
            fi
            
            if scripts/build-frp.sh $frp_build_args; then
                log_success "FRP镜像构建完成"
            else
                log_error "FRP镜像构建失败"
                log_error "请尝试以下解决方案："
                log_error "1. 检查网络连接"
                log_error "2. 使用Docker工具修复: scripts/docker-tools.sh fix"
                log_error "3. 手动配置镜像源: scripts/docker-tools.sh configure"
                exit 1
            fi
        fi
    fi
}

# 更新配置文件
update_configs() {
    log_info "更新配置文件..."
    
    # 更新FRP客户端配置
    if [[ "$DEPLOY_MODE" =~ ^(frp-client|frp-full)$ ]] && [[ -f config/frpc.ini ]]; then
        log_info "更新FRP客户端配置..."
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] 将更新 config/frpc.ini 中的服务器地址和令牌"
        else
            # 备份原配置
            cp config/frpc.ini config/frpc.ini.backup
            
            # 更新配置
            sed -i.tmp "s/server_addr = .*/server_addr = ${FRP_SERVER_ADDR}/" config/frpc.ini
            sed -i.tmp "s/server_port = .*/server_port = ${FRP_SERVER_PORT:-7000}/" config/frpc.ini
            sed -i.tmp "s/token = .*/token = ${FRP_TOKEN}/" config/frpc.ini
            rm -f config/frpc.ini.tmp
            
            log_success "FRP客户端配置更新完成"
        fi
    fi
    
    # 更新FRP服务端配置
    if [[ "$DEPLOY_MODE" == "frp-full" ]] && [[ -f config/frps.ini ]]; then
        log_info "更新FRP服务端配置..."
        if [[ "${DRY_RUN:-false}" == "true" ]]; then
            log_info "[DRY RUN] 将更新 config/frps.ini 中的令牌和管理配置"
        else
            # 备份原配置
            cp config/frps.ini config/frps.ini.backup
            
            # 更新配置
            sed -i.tmp "s/bind_port = .*/bind_port = ${FRP_SERVER_PORT:-7000}/" config/frps.ini
            sed -i.tmp "s/dashboard_port = .*/dashboard_port = ${FRP_DASHBOARD_PORT:-7500}/" config/frps.ini
            sed -i.tmp "s/token = .*/token = ${FRP_TOKEN}/" config/frps.ini
            
            if [[ -n "${FRP_DASHBOARD_USER:-}" ]]; then
                sed -i.tmp "s/dashboard_user = .*/dashboard_user = ${FRP_DASHBOARD_USER}/" config/frps.ini
            fi
            
            if [[ -n "${FRP_DASHBOARD_PWD:-}" ]]; then
                sed -i.tmp "s/dashboard_pwd = .*/dashboard_pwd = ${FRP_DASHBOARD_PWD}/" config/frps.ini
            fi
            
            rm -f config/frps.ini.tmp
            log_success "FRP服务端配置更新完成"
        fi
    fi
}

# 启动服务
start_services() {
    log_info "启动服务..."
    
    local compose_profiles=""
    local compose_cmd="docker-compose"
    
    # 检查是否使用docker compose命令
    if docker compose version &> /dev/null; then
        compose_cmd="docker compose"
    fi
    
    # 根据部署模式设置profiles
    case "$DEPLOY_MODE" in
        "standalone")
            compose_profiles=""
            ;;
        "frp-client")
            compose_profiles="--profile frp-client"
            ;;
        "frp-full")
            compose_profiles="--profile frp-full"
            ;;
    esac
    
    # 停止可能存在的服务
    log_info "停止现有服务..."
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] 将执行: $compose_cmd down"
    else
        $compose_cmd down 2>/dev/null || true
    fi
    
    # 启动服务
    log_info "启动新服务..."
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] 将执行: $compose_cmd $compose_profiles up -d"
    else
        if $compose_cmd $compose_profiles up -d; then
            log_success "服务启动完成"
        else
            log_error "服务启动失败"
            exit 1
        fi
    fi
}

# 验证服务状态
verify_services() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] 将验证服务状态"
        return
    fi
    
    log_info "验证服务状态..."
    
    local max_wait=60
    local wait_time=0
    
    while [[ $wait_time -lt $max_wait ]]; do
        local all_healthy=true
        
        # 检查OpenVPN服务
        if ! docker ps --filter "name=openvpn" --filter "status=running" | grep -q openvpn; then
            all_healthy=false
        fi
        
        # 根据部署模式检查FRP服务
        if [[ "$DEPLOY_MODE" =~ ^(frp-client|frp-full)$ ]]; then
            if ! docker ps --filter "name=frpc" --filter "status=running" | grep -q frpc; then
                all_healthy=false
            fi
        fi
        
        if [[ "$DEPLOY_MODE" == "frp-full" ]]; then
            if ! docker ps --filter "name=frps" --filter "status=running" | grep -q frps; then
                all_healthy=false
            fi
        fi
        
        if [[ "$all_healthy" == "true" ]]; then
            log_success "所有服务运行正常"
            break
        fi
        
        log_info "等待服务启动... (${wait_time}s/${max_wait}s)"
        sleep 5
        wait_time=$((wait_time + 5))
    done
    
    if [[ $wait_time -ge $max_wait ]]; then
        log_error "服务启动超时"
        log_info "请检查服务日志:"
        docker-compose logs
        exit 1
    fi
}

# 生成客户端配置
generate_client_config() {
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "[DRY RUN] 将生成客户端配置"
        return
    fi
    
    log_info "生成客户端配置..."
    
    if [[ -f scripts/generate-client-config.sh ]]; then
        chmod +x scripts/generate-client-config.sh
        
        if scripts/generate-client-config.sh; then
            log_success "客户端配置生成完成"
        else
            log_warning "客户端配置生成失败，请手动运行 scripts/generate-client-config.sh"
        fi
    else
        log_warning "客户端配置生成脚本不存在: scripts/generate-client-config.sh"
    fi
}

# 显示部署信息
show_deployment_info() {
    log_info "部署完成！"
    
    echo
    echo "=========================="
    echo "   部署信息总结"
    echo "=========================="
    echo "部署模式: $DEPLOY_MODE"
    echo "OpenVPN端口: ${OPENVPN_PORT:-1194}"
    
    if [[ "$DEPLOY_MODE" =~ ^(frp-client|frp-full)$ ]]; then
        echo "FRP服务器: ${FRP_SERVER_ADDR}:${FRP_SERVER_PORT:-7000}"
    fi
    
    if [[ "$DEPLOY_MODE" == "frp-full" ]]; then
        echo "FRP管理后台: http://localhost:${FRP_DASHBOARD_PORT:-7500}"
        echo "管理后台用户: ${FRP_DASHBOARD_USER:-admin}"
    fi
    
    echo
    echo "=========================="
    echo "   连接信息"
    echo "=========================="
    
    case "$DEPLOY_MODE" in
        "standalone")
            echo "客户端连接地址: ${OPENVPN_EXTERNAL_HOST:-YOUR_PUBLIC_IP}:${OPENVPN_PORT:-1194}"
            ;;
        "frp-client"|"frp-full")
            echo "客户端连接地址: ${FRP_SERVER_ADDR}:${OPENVPN_PORT:-1194}"
            ;;
    esac
    
    echo "客户端配置文件: client.ovpn"
    
    echo
    echo "=========================="
    echo "   管理命令"
    echo "=========================="
    echo "查看服务状态: docker-compose ps"
    echo "查看服务日志: docker-compose logs"
    echo "停止服务: docker-compose down"
    echo "重启服务: docker-compose restart"
    echo "管理脚本: scripts/manage.sh"
    echo "健康检查: scripts/health-check.sh"
    
    echo
    echo "=========================="
    echo "   注意事项"
    echo "=========================="
    echo "1. 请确保防火墙已开放相应端口"
    echo "2. 建议定期备份证书和配置文件"
    echo "3. 使用 scripts/manage.sh 进行日常管理"
    echo "4. 客户端配置文件位于项目根目录"
    
    if [[ "$DEPLOY_MODE" == "frp-full" ]]; then
        echo "5. FRP管理后台: http://localhost:${FRP_DASHBOARD_PORT:-7500}"
    fi
}

# 清理函数
cleanup() {
    if [[ $? -ne 0 ]]; then
        log_error "部署过程中出现错误"
        log_info "正在清理..."
        
        # 停止可能启动的容器
        docker-compose down 2>/dev/null || true
        
        log_info "如需查看详细错误信息，请使用 --debug 选项重新运行"
    fi
}

# 主函数
main() {
    local deploy_mode="${DEFAULT_DEPLOY_MODE}"
    local frp_server_addr=""
    local openvpn_port="${DEFAULT_OPENVPN_PORT}"
    local frp_token=""
    local config_file=""
    local force_deploy=false
    local skip_deps=false
    local skip_certs=false
    local skip_build=false
    local dry_run=false
    local debug_mode=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -m|--mode)
                deploy_mode="$2"
                shift 2
                ;;
            -h|--host)
                frp_server_addr="$2"
                shift 2
                ;;
            -p|--port)
                openvpn_port="$2"
                shift 2
                ;;
            -t|--token)
                frp_token="$2"
                shift 2
                ;;
            -c|--config)
                config_file="$2"
                shift 2
                ;;
            -f|--force)
                force_deploy=true
                shift
                ;;
            -d|--debug)
                debug_mode=true
                shift
                ;;
            --skip-deps)
                skip_deps=true
                shift
                ;;
            --skip-certs)
                skip_certs=true
                shift
                ;;
            --skip-build)
                skip_build=true
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
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
    export DEPLOY_MODE="$deploy_mode"
    export DEBUG_MODE="$debug_mode"
    export DRY_RUN="$dry_run"
    export SKIP_CERTS="$skip_certs"
    export SKIP_BUILD="$skip_build"
    
    if [[ -n "$frp_server_addr" ]]; then
        export FRP_SERVER_ADDR="$frp_server_addr"
    fi
    
    if [[ -n "$openvpn_port" ]]; then
        export OPENVPN_PORT="$openvpn_port"
    fi
    
    if [[ -n "$frp_token" ]]; then
        export FRP_TOKEN="$frp_token"
    fi
    
    # 设置错误处理
    trap cleanup EXIT
    
    # 显示开始信息
    echo
    echo "=================================================="
    echo "    OpenVPN-FRP 一键部署系统"
    echo "=================================================="
    echo "部署模式: $deploy_mode"
    echo "调试模式: $debug_mode"
    echo "演练模式: $dry_run"
    echo "=================================================="
    echo
    
    # 如果是调试模式，显示配置信息
    if [[ "$debug_mode" == "true" ]]; then
        log_debug "Docker镜像管理由专门工具处理: scripts/docker-tools.sh"
        log_debug "如果遇到网络问题，请运行: scripts/docker-tools.sh fix"
    fi
    
    # 执行部署步骤
    if [[ "$skip_deps" != "true" ]]; then
        check_dependencies
        check_permissions
    fi
    
    load_config
    validate_config
    generate_certificates
    build_images
    update_configs
    start_services
    verify_services
    generate_client_config
    show_deployment_info
    
    log_success "部署完成！"
}

# 执行主函数
main "$@"