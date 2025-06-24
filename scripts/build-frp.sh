#!/bin/bash

# FRP Docker镜像构建脚本
# 作者: OpenVPN-FRP Project
# 功能: 自动构建FRP服务端和客户端Docker镜像

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 默认配置
FRP_VERSION="0.62.1"
FRP_ARCH="linux_amd64"
TAG_PREFIX="openvpn-frp"
BUILD_SERVER=true
BUILD_CLIENT=true
PUSH_IMAGES=false
NO_CACHE=""

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

log_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# 显示帮助信息
show_help() {
    echo -e "${CYAN}FRP Docker镜像构建脚本${NC}"
    echo ""
    echo "用法: $0 [选项]"
    echo ""
    echo "选项:"
    echo "  -v, --version VERSION    指定FRP版本 (默认: 0.62.1)"
    echo "  -a, --arch ARCH         指定架构 (默认: linux_amd64)"
    echo "  -t, --tag TAG           指定Docker标签前缀 (默认: openvpn-frp)"
    echo "  -s, --server-only       仅构建服务端镜像"
    echo "  -c, --client-only       仅构建客户端镜像"
    echo "  -p, --push              构建后推送到仓库"
    echo "  -n, --no-cache          构建时不使用缓存"
    echo "  -h, --help              显示此帮助信息"
    echo ""
    echo "镜像源配置:"
    echo "  如需配置Docker镜像源，请先运行: scripts/docker-tools.sh configure"
    echo "  或测试镜像源连通性: scripts/docker-tools.sh test"
    echo ""
    echo "示例:"
    echo "  scripts/docker-tools.sh configure  # 配置Docker镜像源（推荐先执行）"
    echo "  $0                                  # 构建默认版本的服务端和客户端镜像"
    echo "  $0 -v 0.52.3                      # 构建指定版本"
    echo "  $0 -s                              # 仅构建服务端镜像"
    echo "  $0 -c                              # 仅构建客户端镜像"
    echo "  $0 -t myregistry/frp               # 使用自定义标签前缀"
}


# 解析命令行参数
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -v|--version)
                FRP_VERSION="$2"
                shift 2
                ;;
            -a|--arch)
                FRP_ARCH="$2"
                shift 2
                ;;
            -t|--tag)
                TAG_PREFIX="$2"
                shift 2
                ;;
            -s|--server-only)
                BUILD_SERVER=true
                BUILD_CLIENT=false
                shift
                ;;
            -c|--client-only)
                BUILD_SERVER=false
                BUILD_CLIENT=true
                shift
                ;;
            -p|--push)
                PUSH_IMAGES=true
                shift
                ;;
            -n|--no-cache)
                NO_CACHE="--no-cache"
                shift
                ;;
            -h|--help)
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
}

# 检查Docker是否安装
check_docker() {
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装或未在PATH中找到"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行或当前用户无权限访问Docker"
        exit 1
    fi
}

# 检查FRP版本是否存在
check_frp_version() {
    log_info "检查FRP版本 ${FRP_VERSION} 是否存在..."
    
    # 尝试检查GitHub Releases API
    local api_url="https://api.github.com/repos/fatedier/frp/releases/tags/v${FRP_VERSION}"
    if command -v curl &> /dev/null; then
        local response=$(curl -s -o /dev/null -w "%{http_code}" "$api_url")
        if [[ "$response" == "200" ]]; then
            log_info "FRP版本 ${FRP_VERSION} 验证成功"
            return 0
        else
            log_warn "GitHub API检查失败，尝试下载URL验证..."
            # 备用方案：检查实际下载URL
            local download_url="https://github.com/fatedier/frp/releases/download/v${FRP_VERSION}/frp_${FRP_VERSION}_${FRP_ARCH}.tar.gz"
            local download_response=$(curl -s -o /dev/null -w "%{http_code}" --head "$download_url")
            if [[ "$download_response" == "200" || "$download_response" == "302" ]]; then
                log_info "FRP版本 ${FRP_VERSION} 下载URL验证成功"
                return 0
            else
                log_warn "版本检查失败，但将继续构建尝试"
                return 0
            fi
        fi
    else
        log_warn "无法验证FRP版本，请确保版本 ${FRP_VERSION} 存在"
    fi
}

# 检查Docker daemon配置
check_docker_daemon_config() {
    log_info "检查Docker daemon镜像源配置..."
    
    local config_path
    if [[ "$OSTYPE" == "darwin"* ]]; then
        config_path="$HOME/.docker/daemon.json"
    else
        config_path="/etc/docker/daemon.json"
    fi
    
    if [[ -f "$config_path" ]]; then
        if command -v jq &> /dev/null; then
            local mirrors=$(jq -r '.["registry-mirrors"][]?' "$config_path" 2>/dev/null || echo "")
            if [[ -n "$mirrors" ]]; then
                log_info "已配置Docker daemon镜像源:"
                echo "$mirrors" | while read -r mirror; do
                    log_info "  - $mirror"
                done
            else
                log_warn "Docker daemon配置文件存在但未配置镜像源"
                suggest_daemon_config
            fi
        else
            log_info "Docker daemon配置文件存在: $config_path"
            log_warn "未安装jq，无法解析配置内容"
        fi
    else
        log_warn "未找到Docker daemon配置文件: $config_path"
        suggest_daemon_config
    fi
}

# 建议配置Docker daemon
suggest_daemon_config() {
    log_info "建议配置Docker daemon镜像源以获得更好的构建体验:"
    log_info "  运行: scripts/docker-tools.sh configure"
    log_info "  或手动配置: ~/.docker/daemon.json"
    echo
}

# 构建镜像
build_image() {
    local component=$1
    local dockerfile_path=$2
    local tag_name="${TAG_PREFIX}/frp${component}:${FRP_VERSION}"
    local latest_tag="${TAG_PREFIX}/frp${component}:latest"
    
    log_step "构建 ${component} 镜像..."
    log_info "Dockerfile: ${dockerfile_path}"
    log_info "标签: ${tag_name}"
    log_info "镜像源: 使用Docker daemon配置"
    
    # 检查Docker daemon配置
    check_docker_daemon_config
    
    # 构建参数
    local build_args=(
        ${NO_CACHE}
        --build-arg FRP_VERSION="${FRP_VERSION}"
        --build-arg FRP_ARCH="${FRP_ARCH}"
    )
    
    # 构建镜像
    if docker build "${build_args[@]}" \
        -t "${tag_name}" \
        -t "${latest_tag}" \
        -f "${dockerfile_path}" \
        .; then
        log_info "${component} 镜像构建完成"
    else
        log_error "${component} 镜像构建失败"
        log_error "可能的解决方案："
        log_error "1. 检查网络连接"
        log_error "2. 配置Docker daemon镜像源: scripts/docker-tools.sh configure"
        log_error "3. 检查Docker daemon配置: ~/.docker/daemon.json"
        exit 1
    fi
    
    # 推送镜像
    if [ "$PUSH_IMAGES" = true ]; then
        log_info "推送镜像 ${tag_name}..."
        docker push "${tag_name}"
        docker push "${latest_tag}"
        log_info "镜像推送完成"
    fi
}

# 清理旧镜像
cleanup_old_images() {
    log_info "清理悬空镜像..."
    docker image prune -f || true
}

# 显示镜像信息
show_image_info() {
    echo ""
    log_step "构建完成的镜像:"
    
    if [ "$BUILD_SERVER" = true ]; then
        echo -e "${GREEN}FRP服务端:${NC}"
        docker images | grep "${TAG_PREFIX}/frps" | head -2
    fi
    
    if [ "$BUILD_CLIENT" = true ]; then
        echo -e "${GREEN}FRP客户端:${NC}"
        docker images | grep "${TAG_PREFIX}/frpc" | head -2
    fi
    
    echo ""
    log_info "使用说明:"
    if [ "$BUILD_SERVER" = true ]; then
        echo "  启动FRP服务端: docker run -d -p 7000:7000 -p 7500:7500 ${TAG_PREFIX}/frps:latest"
    fi
    if [ "$BUILD_CLIENT" = true ]; then
        echo "  启动FRP客户端: docker run -d ${TAG_PREFIX}/frpc:latest"
    fi
}

# 主函数
main() {
    echo -e "${CYAN}================================${NC}"
    echo -e "${CYAN}   FRP Docker镜像构建脚本${NC}"
    echo -e "${CYAN}================================${NC}"
    echo ""
    
    # 解析命令行参数
    parse_args "$@"
    
    log_info "构建配置:"
    log_info "  FRP版本: ${FRP_VERSION}"
    log_info "  架构: ${FRP_ARCH}"
    log_info "  标签前缀: ${TAG_PREFIX}"
    log_info "  构建服务端: ${BUILD_SERVER}"
    log_info "  构建客户端: ${BUILD_CLIENT}"
    log_info "  推送镜像: ${PUSH_IMAGES}"
    echo ""
    
    # 检查环境
    check_docker
    check_frp_version
    
    # 检查必要文件
    if [ "$BUILD_SERVER" = true ] && [ ! -f "docker/frp/frps/Dockerfile" ]; then
        log_error "FRP服务端Dockerfile不存在: docker/frp/frps/Dockerfile"
        exit 1
    fi
    
    if [ "$BUILD_CLIENT" = true ] && [ ! -f "docker/frp/frpc/Dockerfile" ]; then
        log_error "FRP客户端Dockerfile不存在: docker/frp/frpc/Dockerfile"
        exit 1
    fi
    
    # 构建镜像
    if [ "$BUILD_SERVER" = true ]; then
        build_image "s" "docker/frp/frps/Dockerfile"
        
        # 如果需要同时构建客户端，添加延迟避免网络请求冲突
        if [ "$BUILD_CLIENT" = true ]; then
            log_info "等待 3 秒以避免网络请求冲突..."
            sleep 3
        fi
    fi
    
    if [ "$BUILD_CLIENT" = true ]; then
        build_image "c" "docker/frp/frpc/Dockerfile"
    fi
    
    # 清理和显示信息
    cleanup_old_images
    show_image_info
    
    log_info "FRP镜像构建完成!"
}

# 执行主函数
main "$@"