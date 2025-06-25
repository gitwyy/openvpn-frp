#!/bin/bash

# =============================================================================
# OpenVPN-FRP Web管理界面部署脚本
# =============================================================================

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# 显示帮助信息
show_help() {
    cat << EOF
OpenVPN-FRP Web管理界面部署脚本

用法: $0 [选项]

选项:
    --deploy            部署Web管理界面
    --start             启动Web管理界面
    --stop              停止Web管理界面
    --restart           重启Web管理界面
    --status            查看Web管理界面状态
    --logs              查看Web管理界面日志
    --build             重新构建Web管理界面镜像
    --remove            移除Web管理界面
    --help              显示此帮助信息

示例:
    $0 --deploy         # 部署Web管理界面
    $0 --start          # 启动Web管理界面
    $0 --logs           # 查看日志

EOF
}

# 获取Docker Compose命令
get_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    else
        echo "docker-compose"
    fi
}

# 检查环境配置
check_environment() {
    log_info "检查环境配置..."
    
    # 检查.env文件
    if [[ ! -f .env ]]; then
        log_warning ".env文件不存在，从模板创建..."
        cp .env.example .env
        log_warning "请编辑.env文件，设置WEB_ADMIN_PASSWORD等配置"
    fi
    
    # 检查Docker
    if ! command -v docker &> /dev/null; then
        log_error "Docker未安装或不在PATH中"
        exit 1
    fi
    
    # 检查Docker Compose
    local compose_cmd=$(get_compose_cmd)
    if ! $compose_cmd version &> /dev/null; then
        log_error "Docker Compose未安装或不在PATH中"
        exit 1
    fi
    
    log_success "环境检查通过"
}

# 构建Web管理界面镜像
build_web_image() {
    log_info "构建Web管理界面镜像..."
    
    local compose_cmd=$(get_compose_cmd)
    
    if $compose_cmd build web; then
        log_success "Web管理界面镜像构建完成"
    else
        log_error "Web管理界面镜像构建失败"
        exit 1
    fi
}

# 部署Web管理界面
deploy_web() {
    log_info "开始部署Web管理界面..."
    
    check_environment
    build_web_image
    
    local compose_cmd=$(get_compose_cmd)
    
    # 启动Web管理界面
    if $compose_cmd --profile web up -d web; then
        log_success "Web管理界面部署完成"
        
        # 等待服务启动
        log_info "等待服务启动..."
        sleep 5
        
        show_web_info
    else
        log_error "Web管理界面部署失败"
        exit 1
    fi
}

# 启动Web管理界面
start_web() {
    log_info "启动Web管理界面..."
    
    local compose_cmd=$(get_compose_cmd)
    
    if $compose_cmd --profile web up -d web; then
        log_success "Web管理界面启动完成"
        show_web_info
    else
        log_error "Web管理界面启动失败"
        exit 1
    fi
}

# 停止Web管理界面
stop_web() {
    log_info "停止Web管理界面..."
    
    local compose_cmd=$(get_compose_cmd)
    
    if $compose_cmd stop web; then
        log_success "Web管理界面已停止"
    else
        log_error "停止Web管理界面失败"
        exit 1
    fi
}

# 重启Web管理界面
restart_web() {
    log_info "重启Web管理界面..."
    
    local compose_cmd=$(get_compose_cmd)
    
    if $compose_cmd restart web; then
        log_success "Web管理界面重启完成"
        show_web_info
    else
        log_error "重启Web管理界面失败"
        exit 1
    fi
}

# 查看Web管理界面状态
show_web_status() {
    log_info "Web管理界面状态:"
    
    local compose_cmd=$(get_compose_cmd)
    $compose_cmd ps web
    
    # 检查健康状态
    if docker ps --filter "name=openvpn-web" --filter "status=running" | grep -q openvpn-web; then
        log_success "Web管理界面运行正常"
        show_web_info
    else
        log_warning "Web管理界面未运行"
    fi
}

# 查看Web管理界面日志
show_web_logs() {
    log_info "Web管理界面日志:"
    
    local compose_cmd=$(get_compose_cmd)
    $compose_cmd logs -f web
}

# 移除Web管理界面
remove_web() {
    log_warning "这将完全移除Web管理界面容器和数据卷"
    read -p "确定要继续吗? (y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "移除Web管理界面..."
        
        local compose_cmd=$(get_compose_cmd)
        
        # 停止并移除容器
        $compose_cmd down web
        
        # 移除数据卷
        docker volume rm openvpn-frp_web-data 2>/dev/null || true
        
        # 移除镜像
        docker rmi openvpn-frp/web:latest 2>/dev/null || true
        
        log_success "Web管理界面已移除"
    else
        log_info "操作已取消"
    fi
}

# 显示Web管理界面信息
show_web_info() {
    # 从.env文件读取配置
    local web_port=$(grep "^WEB_PORT=" .env 2>/dev/null | cut -d'=' -f2 || echo "8080")
    local admin_user=$(grep "^WEB_ADMIN_USER=" .env 2>/dev/null | cut -d'=' -f2 || echo "admin")
    
    echo
    log_success "=== Web管理界面信息 ==="
    echo -e "${GREEN}访问地址:${NC} http://localhost:${web_port}"
    echo -e "${GREEN}管理员账户:${NC} ${admin_user}"
    echo -e "${GREEN}默认密码:${NC} admin123 (请及时修改)"
    echo
    log_info "功能特性:"
    echo "  • 服务状态监控和控制"
    echo "  • 实时日志查看"
    echo "  • 客户端管理"
    echo "  • 在线客户端列表"
    echo
}

# 主函数
main() {
    case "${1:-}" in
        "--deploy")
            deploy_web
            ;;
        "--start")
            start_web
            ;;
        "--stop")
            stop_web
            ;;
        "--restart")
            restart_web
            ;;
        "--status")
            show_web_status
            ;;
        "--logs")
            show_web_logs
            ;;
        "--build")
            check_environment
            build_web_image
            ;;
        "--remove")
            remove_web
            ;;
        "--help"|"-h"|"")
            show_help
            ;;
        *)
            log_error "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"
