#!/bin/bash

# OpenVPN Docker 镜像构建脚本
# 自动化镜像构建过程，集成证书生成和验证

set -e

# 颜色输出定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
IMAGE_NAME="openvpn-frp/openvpn"
IMAGE_TAG="latest"
OPENVPN_VERSION="2.6.11"  # OpenVPN版本
BASE_IMAGE="alpine:3.18"
BUILD_CONTEXT="."
DOCKERFILE_PATH="docker/openvpn/Dockerfile"

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

# 显示帮助信息
show_help() {
    cat << EOF
OpenVPN Docker 镜像构建脚本

用法: $0 [选项]

选项:
    -n, --name NAME         Docker 镜像名称 (默认: openvpn-frp/openvpn)
    -t, --tag TAG          Docker 镜像标签 (默认: latest)
    -b, --base-image IMAGE  基础镜像 (默认: alpine:3.18)
    -f, --force            强制重新生成证书
    -c, --clean            构建前清理旧镜像
    --no-cache             Docker 构建时不使用缓存
    --ubuntu               使用 Ubuntu 22.04 作为基础镜像
    --alpine               使用 Alpine Linux 作为基础镜像 (默认)
    -h, --help             显示此帮助信息

镜像源配置:
    如需配置Docker镜像源，请先运行: scripts/docker-tools.sh configure
    或测试镜像源连通性: scripts/docker-tools.sh test

示例:
    scripts/docker-tools.sh configure    # 配置Docker镜像源（推荐先执行）
    $0                                    # 使用默认设置构建
    $0 --ubuntu --clean                  # 使用 Ubuntu 基础镜像并清理旧镜像
    $0 --force --no-cache                # 强制重新生成证书并不使用缓存构建

EOF
}


# 解析命令行参数
parse_args() {
    local force_certs=false
    local clean_images=false
    local no_cache=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -n|--name)
                IMAGE_NAME="$2"
                shift 2
                ;;
            -t|--tag)
                IMAGE_TAG="$2"
                shift 2
                ;;
            -b|--base-image)
                BASE_IMAGE="$2"
                shift 2
                ;;
            -f|--force)
                force_certs=true
                shift
                ;;
            -c|--clean)
                clean_images=true
                shift
                ;;
            --no-cache)
                no_cache=true
                shift
                ;;
            --ubuntu)
                BASE_IMAGE="ubuntu:22.04"
                shift
                ;;
            --alpine)
                BASE_IMAGE="alpine:3.18"
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
    
    # 设置全局变量
    FORCE_CERTS=$force_certs
    CLEAN_IMAGES=$clean_images
    NO_CACHE=$no_cache
}

# 检查依赖工具
check_dependencies() {
    log_info "检查依赖工具..."
    
    local tools=("docker" "openssl")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            log_error "未找到必需工具: $tool"
            exit 1
        fi
        log_debug "工具检查通过: $tool"
    done
    
    # 检查 Docker 是否运行
    if ! docker info &> /dev/null; then
        log_error "Docker 未运行或无权限访问"
        exit 1
    fi
    
    log_info "依赖工具检查完成"
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

# 检查项目结构
check_project_structure() {
    log_info "检查项目结构..."
    
    local required_files=(
        "config/server.conf"
        "docker/openvpn/Dockerfile"
        "docker/openvpn/start-openvpn.sh"
        "scripts/generate-certs.sh"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "缺少必需文件: $file"
            exit 1
        fi
        log_debug "文件存在: $file"
    done
    
    log_info "项目结构检查通过"
}

# 生成或验证证书
handle_certificates() {
    log_info "处理 PKI 证书..."
    
    if [[ "$FORCE_CERTS" == true ]] || [[ ! -d "pki" ]]; then
        log_info "生成新的 PKI 证书..."
        if [[ -f "scripts/generate-certs.sh" ]]; then
            chmod +x scripts/generate-certs.sh
            ./scripts/generate-certs.sh
        else
            log_error "证书生成脚本不存在: scripts/generate-certs.sh"
            exit 1
        fi
    else
        log_info "验证现有证书..."
        if [[ -f "scripts/verify-certs.sh" ]]; then
            chmod +x scripts/verify-certs.sh
            if ! ./scripts/verify-certs.sh; then
                log_warn "证书验证失败，建议重新生成证书"
                log_info "使用 --force 参数强制重新生成证书"
            fi
        else
            log_warn "证书验证脚本不存在，跳过验证"
        fi
    fi
    
    # 检查关键证书文件
    local key_files=(
        "pki/ca/ca.crt"
        "pki/server/server.crt"
        "pki/server/private/server.key"
        "pki/dh/dh2048.pem"
        "pki/ta.key"
    )
    
    for file in "${key_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "缺少关键证书文件: $file"
            log_error "请运行证书生成脚本或使用 --force 参数"
            exit 1
        fi
    done
    
    log_info "证书处理完成"
}

# 清理旧镜像
clean_old_images() {
    if [[ "$CLEAN_IMAGES" == true ]]; then
        log_info "清理旧的 Docker 镜像..."

        # 删除旧的镜像（包括版本标签和latest标签）
        if docker images | grep -q "$IMAGE_NAME"; then
            docker rmi "${IMAGE_NAME}:${OPENVPN_VERSION}" 2>/dev/null || log_warn "无法删除版本标签镜像，可能不存在"
            docker rmi "${IMAGE_NAME}:latest" 2>/dev/null || log_warn "无法删除latest标签镜像，可能不存在"
        fi

        # 删除旧的命名约定镜像
        if docker images | grep -q "openvpn-server"; then
            docker rmi "openvpn-server:latest" 2>/dev/null || log_warn "无法删除旧命名镜像，可能不存在"
        fi

        # 清理悬空镜像
        local dangling_images=$(docker images -f "dangling=true" -q)
        if [[ -n "$dangling_images" ]]; then
            log_info "清理悬空镜像..."
            docker rmi $dangling_images 2>/dev/null || log_warn "清理悬空镜像时出现警告"
        fi

        log_info "镜像清理完成"
    fi
}

# 构建 Docker 镜像
build_image() {
    log_info "开始构建 Docker 镜像..."
    
    # 检查Docker daemon配置
    check_docker_daemon_config
    
    # 构建参数
    local build_args=()
    if [[ "$NO_CACHE" == true ]]; then
        build_args+=("--no-cache")
    fi

    # 创建版本标签和latest标签
    local version_tag="${IMAGE_NAME}:${OPENVPN_VERSION}"
    local latest_tag="${IMAGE_NAME}:latest"

    log_info "构建参数:"
    log_info "  镜像名称: $IMAGE_NAME"
    log_info "  版本标签: $version_tag"
    log_info "  最新标签: $latest_tag"
    log_info "  基础镜像: $BASE_IMAGE"
    log_info "  Dockerfile: $DOCKERFILE_PATH"
    log_info "  构建上下文: $BUILD_CONTEXT"
    log_info "  镜像源: 使用Docker daemon配置"

    # 调试：显示完整的构建命令
    log_debug "Docker构建命令: docker build ${build_args[*]} -t $version_tag -t $latest_tag -f $DOCKERFILE_PATH $BUILD_CONTEXT"

    # 执行构建
    log_info "执行Docker构建命令..."
    if docker build "${build_args[@]}" \
                   -t "$version_tag" \
                   -t "$latest_tag" \
                   -f "$DOCKERFILE_PATH" \
                   "$BUILD_CONTEXT"; then
        log_info "Docker 镜像构建成功:"
        log_info "  版本标签: $version_tag"
        log_info "  最新标签: $latest_tag"
    else
        log_error "Docker 镜像构建失败"
        log_error "可能的解决方案："
        log_error "1. 检查网络连接"
        log_error "2. 配置Docker daemon镜像源: scripts/docker-tools.sh configure"
        log_error "3. 检查Docker daemon配置: ~/.docker/daemon.json"
        exit 1
    fi
    
    # 显示镜像信息
    log_info "镜像信息:"
    docker images | grep "$IMAGE_NAME"
}

# 验证构建结果
verify_build() {
    log_info "验证构建结果..."

    local version_tag="${IMAGE_NAME}:${OPENVPN_VERSION}"
    local latest_tag="${IMAGE_NAME}:latest"

    # 检查版本标签镜像是否存在
    if ! docker images | grep -q "$IMAGE_NAME.*$OPENVPN_VERSION"; then
        log_error "镜像构建验证失败: 版本标签镜像不存在"
        exit 1
    fi

    # 检查latest标签镜像是否存在
    if ! docker images | grep -q "$IMAGE_NAME.*latest"; then
        log_error "镜像构建验证失败: latest标签镜像不存在"
        exit 1
    fi

    # 尝试创建容器但不启动（测试镜像完整性）
    local test_container="openvpn-test-$$"
    if docker create --name "$test_container" "$latest_tag" &>/dev/null; then
        docker rm "$test_container" &>/dev/null
        log_info "镜像完整性验证通过"
    else
        log_warn "镜像完整性验证失败，但构建已完成"
    fi
}

# 显示使用说明
show_usage_instructions() {
    log_info "构建完成！使用说明："
    
    cat << EOF

=== OpenVPN 服务器 Docker 镜像使用说明 ===

1. 运行 OpenVPN 服务器容器:

   docker run -d \\
     --name openvpn-server \\
     --privileged \\
     --restart unless-stopped \\
     -p 1194:1194/udp \\
     --device /dev/net/tun \\
     $IMAGE_NAME:latest

2. 查看容器日志:

   docker logs -f openvpn-server

3. 停止服务器:

   docker stop openvpn-server

4. 移除容器:

   docker rm openvpn-server

5. 客户端连接:
   - 使用现有的 client.ovpn 配置文件
   - 确保服务器IP地址正确配置
   - 客户端将获得 10.8.0.x 网段的IP地址

注意事项:
- 容器必须以特权模式运行 (--privileged)
- 需要映射 TUN 设备 (--device /dev/net/tun)
- 防火墙需要开放 1194/UDP 端口
- 确保主机启用了IP转发功能

EOF
}

# 主函数
main() {
    log_info "OpenVPN Docker 镜像构建脚本启动"
    
    # 解析命令行参数
    parse_args "$@"
    
    # 显示构建配置
    log_info "构建配置:"
    log_info "  镜像名称: $IMAGE_NAME:$IMAGE_TAG"
    log_info "  基础镜像: $BASE_IMAGE"
    log_info "  强制重新生成证书: $FORCE_CERTS"
    log_info "  清理旧镜像: $CLEAN_IMAGES"
    log_info "  不使用缓存: $NO_CACHE"
    
    # 执行构建步骤
    check_dependencies
    check_project_structure
    
    handle_certificates
    clean_old_images
    build_image
    verify_build
    show_usage_instructions
    
    log_info "OpenVPN 服务器 Docker 镜像构建完成！"
}

# 如果直接执行此脚本，则运行主函数
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi