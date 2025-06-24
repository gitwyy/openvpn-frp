#!/bin/bash

# =============================================================================
# macOS 环境 OpenVPN-FRP 修复脚本
# =============================================================================
# 此脚本专门处理 macOS 环境下的 TUN/TAP 设备问题
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
    echo -e "${PURPLE}[DEBUG]${NC} $1"
}

# 显示帮助信息
show_help() {
    cat << EOF
macOS OpenVPN-FRP 修复脚本

用法: $0 [选项]

选项:
    --check-only        仅检查环境，不执行修复
    --install-tuntap    安装 TunTap OSX 驱动
    --docker-mode       使用 Docker 模式（推荐）
    --help             显示此帮助信息

修复方案:
    1. Docker模式 - 在容器内创建TUN设备（推荐）
    2. TunTap驱动 - 安装第三方TUN/TAP驱动
    3. 网络模式 - 使用Docker Desktop网络功能

示例:
    $0 --docker-mode
    $0 --install-tuntap
    $0 --check-only

EOF
}

# 检查macOS环境
check_macos_environment() {
    log_info "检查macOS环境..."
    
    # 确认是macOS系统
    if [[ "$OSTYPE" != "darwin"* ]]; then
        log_error "此脚本仅适用于macOS系统"
        exit 1
    fi
    
    # 获取macOS版本
    local macos_version=$(sw_vers -productVersion)
    log_info "macOS版本: $macos_version"
    
    # 检查架构
    local arch=$(uname -m)
    log_info "系统架构: $arch"
    
    # 检查是否安装了Homebrew
    if command -v brew &> /dev/null; then
        log_success "Homebrew已安装"
    else
        log_warning "未检测到Homebrew，建议安装以便管理依赖"
    fi
    
    return 0
}

# 检查Docker环境
check_docker_environment() {
    log_info "检查Docker环境..."
    
    # 检查Docker是否安装
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装，请先安装Docker Desktop"
        log_info "下载地址: https://www.docker.com/products/docker-desktop"
        return 1
    fi
    
    # 检查Docker是否运行
    if ! docker info &> /dev/null; then
        log_error "Docker服务未运行，请启动Docker Desktop"
        return 1
    fi
    
    # 检查Docker版本
    local docker_version=$(docker --version)
    log_success "Docker状态正常: $docker_version"
    
    # 检查Docker Compose
    if command -v docker-compose &> /dev/null || docker compose version &> /dev/null; then
        log_success "Docker Compose可用"
    else
        log_warning "Docker Compose未安装"
        return 1
    fi
    
    return 0
}

# 检查TUN设备状态
check_tun_device() {
    log_info "检查TUN设备状态..."
    
    if [[ -e /dev/net/tun ]]; then
        log_success "主机TUN设备存在: /dev/net/tun"
        
        # 检查权限
        if [[ -r /dev/net/tun ]] && [[ -w /dev/net/tun ]]; then
            log_success "TUN设备权限正常"
            return 0
        else
            log_warning "TUN设备权限不足"
            return 1
        fi
    else
        log_warning "主机TUN设备不存在: /dev/net/tun"
        return 1
    fi
}

# 检查TunTap驱动安装状态
check_tuntap_driver() {
    log_info "检查TunTap驱动状态..."
    
    # 检查内核扩展
    if kextstat | grep -q "tun\|tap"; then
        log_success "TunTap内核扩展已加载"
        return 0
    fi
    
    # 检查驱动文件
    if [[ -d "/Library/Extensions/tun.kext" ]] || [[ -d "/System/Library/Extensions/tun.kext" ]]; then
        log_info "发现TunTap驱动文件，但未加载"
        return 1
    fi
    
    log_warning "未检测到TunTap驱动"
    return 1
}

# 安装TunTap OSX驱动
install_tuntap_driver() {
    log_info "安装TunTap OSX驱动..."
    
    # 检查是否已安装
    if check_tuntap_driver; then
        log_success "TunTap驱动已安装"
        return 0
    fi
    
    log_info "开始安装TunTap OSX驱动..."
    
    # 使用Homebrew安装（推荐）
    if command -v brew &> /dev/null; then
        log_info "使用Homebrew安装TunTap..."
        if brew install --cask tuntap; then
            log_success "TunTap安装完成"
        else
            log_error "Homebrew安装失败，尝试手动安装"
            install_tuntap_manual
        fi
    else
        log_warning "未安装Homebrew，使用手动安装"
        install_tuntap_manual
    fi
    
    # 提示重启
    log_warning "安装完成后需要重启系统以加载内核扩展"
    log_info "重启后运行: sudo kextload /Library/Extensions/tun.kext"
}

# 手动安装TunTap
install_tuntap_manual() {
    log_info "手动下载和安装TunTap..."
    
    local temp_dir="/tmp/tuntap-install"
    mkdir -p "$temp_dir"
    cd "$temp_dir"
    
    # 下载最新版本
    log_info "下载TunTap OSX..."
    if curl -L -o tuntap.pkg "https://sourceforge.net/projects/tuntaposx/files/latest/download"; then
        log_success "下载完成"
        
        # 安装
        log_info "安装TunTap（需要管理员权限）..."
        sudo installer -pkg tuntap.pkg -target /
        
        if [[ $? -eq 0 ]]; then
            log_success "TunTap安装完成"
        else
            log_error "TunTap安装失败"
            return 1
        fi
    else
        log_error "下载失败"
        return 1
    fi
    
    # 清理
    cd "$PROJECT_ROOT"
    rm -rf "$temp_dir"
}

# Docker模式修复
fix_docker_mode() {
    log_info "使用Docker模式修复..."
    
    # 创建Docker Compose覆盖文件
    local override_file="docker-compose.override.yml"
    
    log_info "创建Docker Compose覆盖配置..."
    cat > "$override_file" << EOF
version: '3.8'

services:
  openvpn:
    privileged: true
    cap_add:
      - NET_ADMIN
      - SYS_MODULE
      - MKNOD
    environment:
      - MACOS_MODE=true
    # 注释掉设备映射，让容器自行创建
    # devices:
    #   - "/dev/net/tun:/dev/net/tun"
EOF
    
    log_success "Docker覆盖配置创建完成: $override_file"
    log_info "容器将以特权模式运行并自行创建TUN设备"
}

# 修复防火墙配置
fix_macos_firewall() {
    log_info "检查和修复macOS防火墙配置..."
    
    # 检查防火墙状态
    local fw_status=$(sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate)
    log_info "防火墙状态: $fw_status"
    
    if echo "$fw_status" | grep -q "enabled"; then
        log_warning "防火墙已启用，需要配置Docker访问权限"
        
        # 添加Docker到防火墙白名单
        log_info "添加Docker到防火墙白名单..."
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Docker.app 2>/dev/null || true
        sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /Applications/Docker.app 2>/dev/null || true
        
        log_success "防火墙配置完成"
    else
        log_info "防火墙未启用，无需配置"
    fi
}

# 系统优化
optimize_macos_system() {
    log_info "优化macOS系统配置..."
    
    # 启用IP转发（临时）
    log_info "启用IP转发..."
    sudo sysctl -w net.inet.ip.forwarding=1
    
    # 创建永久配置
    if [[ ! -f /etc/sysctl.conf ]] || ! grep -q "net.inet.ip.forwarding=1" /etc/sysctl.conf; then
        log_info "创建永久IP转发配置..."
        echo "net.inet.ip.forwarding=1" | sudo tee -a /etc/sysctl.conf
    fi
    
    log_success "系统优化完成"
}

# 验证修复结果
verify_fix() {
    log_info "验证修复结果..."
    
    # 检查Docker
    if ! check_docker_environment; then
        log_error "Docker环境验证失败"
        return 1
    fi
    
    # 尝试构建测试容器
    log_info "测试容器TUN设备创建..."
    local test_result=$(docker run --rm --privileged alpine:latest sh -c "
        mkdir -p /dev/net
        if mknod /dev/net/tun c 10 200 2>/dev/null; then
            echo 'TUN_CREATE_SUCCESS'
        else
            echo 'TUN_CREATE_FAILED'
        fi
    ")
    
    if echo "$test_result" | grep -q "TUN_CREATE_SUCCESS"; then
        log_success "容器可以成功创建TUN设备"
        return 0
    else
        log_warning "容器无法创建TUN设备，但这在某些环境下是正常的"
        log_info "OpenVPN可能仍然可以正常工作"
        return 1
    fi
}

# 显示修复建议
show_recommendations() {
    echo
    echo "=================================="
    echo "   macOS 修复建议"
    echo "=================================="
    echo
    echo "推荐的修复方案按优先级排序："
    echo
    echo "1. 🐳 Docker模式（推荐）"
    echo "   ./scripts/macos-fix.sh --docker-mode"
    echo "   优点：无需安装第三方驱动，最兼容"
    echo
    echo "2. 🔧 安装TunTap驱动"
    echo "   ./scripts/macos-fix.sh --install-tuntap"
    echo "   优点：提供原生TUN支持"
    echo "   缺点：需要重启系统"
    echo
    echo "3. 📊 仅检查环境"
    echo "   ./scripts/macos-fix.sh --check-only"
    echo "   诊断当前环境状态"
    echo
    echo "=================================="
    echo "   部署步骤"
    echo "=================================="
    echo
    echo "1. 运行修复脚本"
    echo "2. 执行: ./scripts/deploy.sh --mode standalone"
    echo "3. 验证: docker-compose ps"
    echo
}

# 主函数
main() {
    local action=""
    local check_only=false
    local install_tuntap=false
    local docker_mode=false
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-only)
                check_only=true
                shift
                ;;
            --install-tuntap)
                install_tuntap=true
                shift
                ;;
            --docker-mode)
                docker_mode=true
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
    
    # 显示开始信息
    echo
    echo "=================================================="
    echo "    macOS OpenVPN-FRP 环境修复工具"
    echo "=================================================="
    echo
    
    # 执行环境检查
    check_macos_environment
    check_docker_environment || true
    check_tun_device || true
    check_tuntap_driver || true
    
    # 如果只是检查，则显示建议并退出
    if [[ "$check_only" == "true" ]]; then
        show_recommendations
        exit 0
    fi
    
    # 执行相应的修复操作
    if [[ "$docker_mode" == "true" ]]; then
        fix_docker_mode
        fix_macos_firewall
        optimize_macos_system
        verify_fix
        
        log_success "Docker模式修复完成！"
        log_info "现在可以运行: ./scripts/deploy.sh --mode standalone"
        
    elif [[ "$install_tuntap" == "true" ]]; then
        install_tuntap_driver
        fix_macos_firewall
        optimize_macos_system
        
        log_success "TunTap驱动安装完成！"
        log_warning "请重启系统后运行部署脚本"
        
    else
        # 默认显示建议
        show_recommendations
    fi
}

# 执行主函数
main "$@"