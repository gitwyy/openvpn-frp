#!/bin/bash

# =============================================================================
# OpenVPN-FRP 服务管理脚本
# =============================================================================
# 提供完整的服务管理功能，包括启动、停止、重启、状态查看等
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

# 获取Docker Compose命令
get_compose_cmd() {
    if docker compose version &> /dev/null; then
        echo "docker compose"
    else
        echo "docker-compose"
    fi
}

# 显示帮助信息
show_help() {
    cat << EOF
OpenVPN-FRP 服务管理脚本

用法: $0 <命令> [选项]

命令:
    start                   启动所有服务
    stop                    停止所有服务
    restart                 重启所有服务
    status                  查看服务状态
    logs                    查看服务日志
    ps                      查看容器列表
    config                  验证配置文件
    backup                  备份配置和证书
    restore                 恢复配置和证书
    clean                   清理未使用的资源
    update                  更新镜像
    reset                   重置所有数据
    client                  客户端管理
    cert                    证书管理
    
服务控制选项:
    --service SERVICE       指定特定服务 (openvpn|frps|frpc)
    --profile PROFILE       指定profile (frp-client|frp-full|monitoring)
    
日志选项:
    --follow                跟踪日志输出
    --tail NUM              显示最后N行日志
    --since TIME            显示指定时间后的日志
    
备份/恢复选项:
    --backup-dir DIR        指定备份目录
    --include-logs          包含日志文件
    
客户端管理选项:
    --list-clients          列出所有客户端
    --add-client NAME       添加新客户端
    --remove-client NAME    删除客户端
    --show-config NAME      显示客户端配置
    
证书管理选项:
    --list-certs            列出所有证书
    --verify-certs          验证证书有效性
    --renew-cert NAME       更新指定证书
    --revoke-cert NAME      撤销指定证书
    --generate-crl          生成证书撤销列表
    --auto-renew            自动续期即将过期的证书

示例:
    $0 start                启动所有服务
    $0 logs --follow        跟踪所有服务日志
    $0 logs openvpn --tail 100
    $0 backup --include-logs
    $0 client --add-client user1
    $0 cert --verify-certs

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

# 启动服务
start_services() {
    local service="$1"
    local profile="$2"
    local compose_cmd=$(get_compose_cmd)
    
    log_info "启动服务..."
    
    local cmd="$compose_cmd"
    
    if [[ -n "$profile" ]]; then
        cmd="$cmd --profile $profile"
    fi
    
    cmd="$cmd up -d"
    
    if [[ -n "$service" ]]; then
        cmd="$cmd $service"
    fi
    
    if eval "$cmd"; then
        log_success "服务启动完成"
        sleep 3
        show_status
    else
        log_error "服务启动失败"
        return 1
    fi
}

# 停止服务
stop_services() {
    local service="$1"
    local compose_cmd=$(get_compose_cmd)
    
    log_info "停止服务..."
    
    local cmd="$compose_cmd stop"
    
    if [[ -n "$service" ]]; then
        cmd="$cmd $service"
    fi
    
    if eval "$cmd"; then
        log_success "服务停止完成"
    else
        log_error "服务停止失败"
        return 1
    fi
}

# 重启服务
restart_services() {
    local service="$1"
    local profile="$2"
    
    log_info "重启服务..."
    
    stop_services "$service"
    sleep 2
    start_services "$service" "$profile"
}

# 查看服务状态
show_status() {
    local compose_cmd=$(get_compose_cmd)
    
    echo
    echo "=========================="
    echo "   服务状态"
    echo "=========================="
    
    # Docker Compose状态
    $compose_cmd ps
    
    echo
    echo "=========================="
    echo "   容器健康状态"
    echo "=========================="
    
    # 详细健康状态
    local containers=$(docker ps --filter "label=openvpn-frp.service" --format "{{.Names}}")
    
    if [[ -z "$containers" ]]; then
        log_warning "未找到运行中的服务容器"
        return
    fi
    
    for container in $containers; do
        local health=$(docker inspect --format='{{.State.Health.Status}}' "$container" 2>/dev/null || echo "unknown")
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null || echo "unknown")
        
        printf "%-20s %-10s %-10s\n" "$container" "$status" "$health"
    done
    
    echo
    echo "=========================="
    echo "   网络连通性"
    echo "=========================="
    
    # 检查端口监听
    check_port_listening
    
    echo
    echo "=========================="
    echo "   资源使用情况"
    echo "=========================="
    
    # 资源使用情况
    if [[ -n "$containers" ]]; then
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" $containers
    fi
}

# 检查端口监听
check_port_listening() {
    local openvpn_port="${OPENVPN_PORT:-1194}"
    local frp_port="${FRP_SERVER_PORT:-7000}"
    local dashboard_port="${FRP_DASHBOARD_PORT:-7500}"
    
    # 检查OpenVPN端口
    if netstat -tuln 2>/dev/null | grep -q ":$openvpn_port " || ss -tuln 2>/dev/null | grep -q ":$openvpn_port "; then
        echo "✓ OpenVPN端口 $openvpn_port 正在监听"
    else
        echo "✗ OpenVPN端口 $openvpn_port 未监听"
    fi
    
    # 检查FRP端口（如果相关服务运行）
    if docker ps --filter "name=frps" --filter "status=running" | grep -q frps; then
        if netstat -tuln 2>/dev/null | grep -q ":$frp_port " || ss -tuln 2>/dev/null | grep -q ":$frp_port "; then
            echo "✓ FRP控制端口 $frp_port 正在监听"
        else
            echo "✗ FRP控制端口 $frp_port 未监听"
        fi
        
        if netstat -tuln 2>/dev/null | grep -q ":$dashboard_port " || ss -tuln 2>/dev/null | grep -q ":$dashboard_port "; then
            echo "✓ FRP管理端口 $dashboard_port 正在监听"
        else
            echo "✗ FRP管理端口 $dashboard_port 未监听"
        fi
    fi
}

# 查看日志
show_logs() {
    local service="$1"
    local follow="$2"
    local tail="$3"
    local since="$4"
    local compose_cmd=$(get_compose_cmd)
    
    local cmd="$compose_cmd logs"
    
    if [[ "$follow" == "true" ]]; then
        cmd="$cmd -f"
    fi
    
    if [[ -n "$tail" ]]; then
        cmd="$cmd --tail $tail"
    fi
    
    if [[ -n "$since" ]]; then
        cmd="$cmd --since $since"
    fi
    
    if [[ -n "$service" ]]; then
        cmd="$cmd $service"
    fi
    
    eval "$cmd"
}

# 验证配置
validate_config() {
    log_info "验证配置文件..."
    
    local errors=0
    
    # 检查必要的配置文件
    local required_files=(
        "config/server.conf"
        "config/frps.ini"
        "config/frpc.ini"
        ".env"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "缺少配置文件: $file"
            ((errors++))
        else
            echo "✓ $file"
        fi
    done
    
    # 检查证书文件
    local cert_files=(
        "pki/ca/ca.crt"
        "pki/server/server.crt"
        "pki/server/private/server.key"
        "pki/dh/dh2048.pem"
        "pki/ta.key"
    )
    
    for file in "${cert_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            log_error "缺少证书文件: $file"
            ((errors++))
        else
            echo "✓ $file"
        fi
    done
    
    # 验证Docker Compose文件
    local compose_cmd=$(get_compose_cmd)
    if $compose_cmd config -q; then
        echo "✓ docker-compose.yml 语法正确"
    else
        log_error "docker-compose.yml 语法错误"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "所有配置文件验证通过"
    else
        log_error "发现 $errors 个配置错误"
        return 1
    fi
}

# 备份配置和数据
backup_data() {
    local backup_dir="$1"
    local include_logs="$2"
    
    if [[ -z "$backup_dir" ]]; then
        backup_dir="./backups/backup-$(date +%Y%m%d-%H%M%S)"
    fi
    
    log_info "创建备份到: $backup_dir"
    
    # 创建备份目录
    mkdir -p "$backup_dir"
    
    # 备份配置文件
    log_info "备份配置文件..."
    cp -r config "$backup_dir/"
    
    # 备份证书
    log_info "备份证书文件..."
    cp -r pki "$backup_dir/"
    
    # 备份环境配置
    cp .env "$backup_dir/" 2>/dev/null || true
    
    # 备份Docker Compose文件
    cp docker-compose.yml "$backup_dir/"
    
    # 备份数据卷（如果需要）
    log_info "备份Docker卷数据..."
    local volumes=$(docker volume ls --filter "label=openvpn-frp.volume" --format "{{.Name}}")
    
    if [[ -n "$volumes" ]]; then
        mkdir -p "$backup_dir/volumes"
        for volume in $volumes; do
            log_info "备份卷: $volume"
            docker run --rm -v "$volume":/source -v "$backup_dir/volumes":/backup alpine tar czf "/backup/$volume.tar.gz" -C /source .
        done
    fi
    
    # 备份日志（如果指定）
    if [[ "$include_logs" == "true" ]]; then
        log_info "备份日志文件..."
        if [[ -d logs ]]; then
            cp -r logs "$backup_dir/"
        fi
    fi
    
    # 创建备份信息文件
    cat > "$backup_dir/backup-info.txt" << EOF
OpenVPN-FRP 备份信息
===================
备份时间: $(date)
备份版本: 1.0
部署模式: ${DEPLOY_MODE:-unknown}
包含日志: $include_logs

备份内容:
- 配置文件 (config/)
- 证书文件 (pki/)
- 环境配置 (.env)
- Docker Compose配置 (docker-compose.yml)
- Docker卷数据 (volumes/)
$(if [[ "$include_logs" == "true" ]]; then echo "- 日志文件 (logs/)"; fi)

恢复方法:
./scripts/manage.sh restore --backup-dir $backup_dir
EOF
    
    log_success "备份完成: $backup_dir"
}

# 恢复配置和数据
restore_data() {
    local backup_dir="$1"
    
    if [[ -z "$backup_dir" ]] || [[ ! -d "$backup_dir" ]]; then
        log_error "备份目录不存在: $backup_dir"
        return 1
    fi
    
    log_warning "即将恢复数据，这将覆盖现有配置！"
    read -p "确认继续？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "恢复操作已取消"
        return 0
    fi
    
    log_info "从备份恢复: $backup_dir"
    
    # 停止服务
    stop_services ""
    
    # 恢复配置文件
    if [[ -d "$backup_dir/config" ]]; then
        log_info "恢复配置文件..."
        rm -rf config
        cp -r "$backup_dir/config" .
    fi
    
    # 恢复证书
    if [[ -d "$backup_dir/pki" ]]; then
        log_info "恢复证书文件..."
        rm -rf pki
        cp -r "$backup_dir/pki" .
    fi
    
    # 恢复环境配置
    if [[ -f "$backup_dir/.env" ]]; then
        log_info "恢复环境配置..."
        cp "$backup_dir/.env" .
    fi
    
    # 恢复Docker Compose文件
    if [[ -f "$backup_dir/docker-compose.yml" ]]; then
        log_info "恢复Docker Compose配置..."
        cp "$backup_dir/docker-compose.yml" .
    fi
    
    # 恢复Docker卷数据
    if [[ -d "$backup_dir/volumes" ]]; then
        log_info "恢复Docker卷数据..."
        for backup_file in "$backup_dir/volumes"/*.tar.gz; do
            if [[ -f "$backup_file" ]]; then
                local volume_name=$(basename "$backup_file" .tar.gz)
                log_info "恢复卷: $volume_name"
                
                # 创建临时容器来恢复数据
                docker volume create "$volume_name" 2>/dev/null || true
                docker run --rm -v "$volume_name":/target -v "$backup_dir/volumes":/backup alpine tar xzf "/backup/$volume_name.tar.gz" -C /target
            fi
        done
    fi
    
    # 恢复日志文件
    if [[ -d "$backup_dir/logs" ]]; then
        log_info "恢复日志文件..."
        rm -rf logs
        cp -r "$backup_dir/logs" .
    fi
    
    log_success "数据恢复完成"
    log_info "请运行以下命令重新启动服务:"
    echo "  $0 start"
}

# 清理未使用的资源
clean_resources() {
    log_info "清理未使用的资源..."
    
    # 清理停止的容器
    log_info "清理停止的容器..."
    docker container prune -f
    
    # 清理未使用的镜像
    log_info "清理未使用的镜像..."
    docker image prune -f
    
    # 清理未使用的网络
    log_info "清理未使用的网络..."
    docker network prune -f
    
    # 清理未使用的卷（谨慎）
    read -p "是否清理未使用的Docker卷？这可能删除重要数据！(y/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_warning "清理未使用的卷..."
        docker volume prune -f
    fi
    
    log_success "资源清理完成"
}

# 更新镜像
update_images() {
    log_info "更新Docker镜像..."
    
    # 拉取最新的基础镜像
    docker pull alpine:latest
    docker pull ubuntu:20.04
    
    # 重新构建项目镜像
    log_info "重新构建OpenVPN镜像..."
    docker build --no-cache -f docker/openvpn/Dockerfile -t openvpn-frp/openvpn:latest .
    
    log_info "重新构建FRP镜像..."
    docker build --no-cache -f docker/frp/frpc/Dockerfile -t openvpn-frp/frpc:latest .
    docker build --no-cache -f docker/frp/frps/Dockerfile -t openvpn-frp/frps:latest .
    
    log_success "镜像更新完成"
}

# 重置所有数据
reset_all() {
    log_warning "即将重置所有数据，包括配置、证书和卷数据！"
    read -p "确认继续？(y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "重置操作已取消"
        return 0
    fi
    
    log_info "重置所有数据..."
    
    # 停止并删除容器
    local compose_cmd=$(get_compose_cmd)
    $compose_cmd down -v --remove-orphans
    
    # 删除项目相关的镜像
    docker images --filter "reference=openvpn-frp/*" -q | xargs -r docker rmi -f
    
    # 删除项目相关的卷
    docker volume ls --filter "label=openvpn-frp.volume" -q | xargs -r docker volume rm
    
    # 删除生成的文件
    rm -rf pki/
    rm -f client.ovpn
    rm -f .env
    
    log_success "重置完成"
    log_info "请运行以下命令重新部署:"
    echo "  scripts/deploy.sh"
}

# 客户端管理
manage_clients() {
    local action="$1"
    local client_name="$2"
    
    case "$action" in
        "list")
            log_info "客户端列表:"
            if [[ -d pki/clients ]]; then
                ls -1 pki/clients/*.crt 2>/dev/null | sed 's/.*\///;s/\.crt$//' | sort
            else
                log_warning "未找到客户端证书目录"
            fi
            ;;
        "add")
            if [[ -z "$client_name" ]]; then
                log_error "请指定客户端名称"
                return 1
            fi
            
            log_info "添加客户端: $client_name"
            
            # 使用现有的证书生成脚本添加客户端
            if [[ -f scripts/generate-certs.sh ]]; then
                log_info "生成客户端证书..."
                if scripts/generate-certs.sh --client "$client_name"; then
                    log_success "客户端证书生成成功: $client_name"
                    
                    # 生成客户端配置文件
                    if [[ -f scripts/generate-client-config.sh ]]; then
                        log_info "生成客户端配置文件..."
                        scripts/generate-client-config.sh "$client_name"
                    fi
                else
                    log_error "客户端证书生成失败"
                    return 1
                fi
            else
                log_error "证书生成脚本不存在"
                return 1
            fi
            ;;
        "remove")
            if [[ -z "$client_name" ]]; then
                log_error "请指定客户端名称"
                return 1
            fi
            
            log_warning "删除客户端: $client_name"
            read -p "确认删除？(y/N): " -n 1 -r
            echo
            
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                rm -f "pki/clients/${client_name}.crt"
                rm -f "pki/clients/private/${client_name}.key"
                log_success "客户端已删除: $client_name"
            fi
            ;;
        "show")
            if [[ -z "$client_name" ]]; then
                log_error "请指定客户端名称"
                return 1
            fi
            
            log_info "客户端配置: $client_name"
            
            if [[ -f scripts/generate-client-config.sh ]]; then
                scripts/generate-client-config.sh "$client_name"
            else
                log_error "客户端配置生成脚本不存在"
            fi
            ;;
        *)
            log_error "未知的客户端操作: $action"
            return 1
            ;;
    esac
}

# 证书管理
manage_certificates() {
    local action="$1"
    local cert_name="$2"
    
    case "$action" in
        "list")
            log_info "证书列表:"
            echo
            echo "CA证书:"
            if [[ -f pki/ca/ca.crt ]]; then
                openssl x509 -in pki/ca/ca.crt -noout -subject -dates
            fi
            
            echo
            echo "服务器证书:"
            if [[ -f pki/server/server.crt ]]; then
                openssl x509 -in pki/server/server.crt -noout -subject -dates
            fi
            
            echo
            echo "客户端证书:"
            if [[ -d pki/clients ]]; then
                for cert in pki/clients/*.crt; do
                    if [[ -f "$cert" ]]; then
                        echo "$(basename "$cert" .crt):"
                        openssl x509 -in "$cert" -noout -subject -dates
                        echo
                    fi
                done
            fi
            ;;
        "verify")
            log_info "验证证书..."
            
            if [[ -f scripts/verify-certs.sh ]]; then
                scripts/verify-certs.sh
            else
                log_error "证书验证脚本不存在"
            fi
            ;;
        "renew")
            if [[ -z "$cert_name" ]]; then
                log_error "请指定证书名称"
                return 1
            fi
# 撤销证书
revoke_certificate() {
    local cert_name="$1"
    
    # 检查证书是否存在
    local cert_file=""
    if [[ "$cert_name" == "server" ]]; then
        cert_file="pki/server/server.crt"
    elif [[ -f "pki/clients/${cert_name}.crt" ]]; then
        cert_file="pki/clients/${cert_name}.crt"
    else
        log_error "未找到证书: $cert_name"
        return 1
    fi
    
    # 准备撤销环境
    local crl_config="pki/ca/crl.conf"
    local index_file="pki/ca/index.txt"
    
    # 创建索引文件条目
    if [[ ! -f "$index_file" ]]; then
        touch "$index_file"
    fi
    
    # 获取证书序列号
    local serial=$(openssl x509 -in "$cert_file" -noout -serial | cut -d= -f2)
    local subject=$(openssl x509 -in "$cert_file" -noout -subject | sed 's/subject=//')
    
    # 添加到索引文件（如果还不存在）
    if ! grep -q "$serial" "$index_file"; then
        local expire_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
        local expire_formatted=$(date -d "$expire_date" +%y%m%d%H%M%SZ 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$expire_date" +%y%m%d%H%M%SZ 2>/dev/null)
        echo "V	$expire_formatted		$serial	unknown	$subject" >> "$index_file"
    fi
    
    # 撤销证书
    if openssl ca -config "$crl_config" -revoke "$cert_file" 2>/dev/null; then
        log_success "证书已撤销: $cert_name"
        
        # 重新生成CRL
        log_info "更新证书撤销列表..."
        openssl ca -config "$crl_config" -gencrl -out "pki/ca/crl.pem" 2>/dev/null
        
        # 移动撤销的证书到备份目录
        local revoked_dir="pki/revoked/$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$revoked_dir"
        
        if [[ "$cert_name" == "server" ]]; then
            mv "$cert_file" "$revoked_dir/"
            mv "pki/server/private/server.key" "$revoked_dir/" 2>/dev/null || true
        else
            mv "$cert_file" "$revoked_dir/"
            mv "pki/clients/private/${cert_name}.key" "$revoked_dir/" 2>/dev/null || true
        fi
        
        log_info "撤销的证书已移动到: $revoked_dir"
    else
        log_error "证书撤销失败"
        return 1
    fi
}

# 自动续期证书
auto_renew_certificates() {
    local renewed_count=0
    local warning_days=30
    
    log_info "检查证书有效期，自动续期即将在 $warning_days 天内过期的证书..."
    
    # 检查服务器证书
    if [[ -f "pki/server/server.crt" ]]; then
        local end_date=$(openssl x509 -in "pki/server/server.crt" -noout -enddate | cut -d= -f2)
        local end_timestamp=$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null)
        local current_timestamp=$(date +%s)
        local days_left=$(( (end_timestamp - current_timestamp) / 86400 ))
        
        if [[ $days_left -lt $warning_days ]]; then
            log_info "服务器证书将在 $days_left 天后过期，开始自动续期..."
            
            # 备份旧证书
            local backup_dir="pki/backup/auto-renew-$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            cp "pki/server/server.crt" "$backup_dir/"
            cp "pki/server/private/server.key" "$backup_dir/"
            
            # 重新生成服务器证书
            if scripts/generate-certs.sh --server; then
                log_success "服务器证书自动续期完成"
                ((renewed_count++))
            else
                log_error "服务器证书自动续期失败"
            fi
        fi
    fi
    
    # 检查客户端证书
    if [[ -d "pki/clients" ]]; then
        for cert in pki/clients/*.crt; do
            if [[ -f "$cert" ]]; then
                local client_name=$(basename "$cert" .crt)
                local end_date=$(openssl x509 -in "$cert" -noout -enddate | cut -d= -f2)
                local end_timestamp=$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null)
                local current_timestamp=$(date +%s)
                local days_left=$(( (end_timestamp - current_timestamp) / 86400 ))
                
                if [[ $days_left -lt $warning_days ]]; then
                    log_info "客户端证书 $client_name 将在 $days_left 天后过期，开始自动续期..."
                    
                    # 备份旧证书
                    local backup_dir="pki/backup/auto-renew-$(date +%Y%m%d-%H%M%S)"
                    mkdir -p "$backup_dir"
                    cp "$cert" "$backup_dir/"
                    cp "pki/clients/private/${client_name}.key" "$backup_dir/" 2>/dev/null || true
                    
                    # 重新生成客户端证书
                    if scripts/generate-certs.sh --client "$client_name"; then
                        log_success "客户端证书 $client_name 自动续期完成"
                        ((renewed_count++))
                    else
                        log_error "客户端证书 $client_name 自动续期失败"
                    fi
                fi
            fi
        done
    fi
    
    if [[ $renewed_count -eq 0 ]]; then
        log_info "没有需要续期的证书"
    else
        log_success "共续期了 $renewed_count 个证书"
        log_info "建议重启OpenVPN服务以加载新证书"
    fi
}
            
            log_info "更新证书: $cert_name"
            
            # 检查证书是否存在
            local cert_file=""
            if [[ "$cert_name" == "ca" ]]; then
                cert_file="pki/ca/ca.crt"
            elif [[ "$cert_name" == "server" ]]; then
                cert_file="pki/server/server.crt"
            elif [[ -f "pki/clients/${cert_name}.crt" ]]; then
                cert_file="pki/clients/${cert_name}.crt"
            else
                log_error "未找到证书: $cert_name"
                return 1
            fi
            
            # 检查证书有效期
            local end_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
            local end_timestamp=$(date -d "$end_date" +%s 2>/dev/null || date -j -f "%b %d %T %Y %Z" "$end_date" +%s 2>/dev/null)
            local current_timestamp=$(date +%s)
            local days_left=$(( (end_timestamp - current_timestamp) / 86400 ))
            
            if [[ $days_left -gt 30 ]]; then
                log_warning "证书 $cert_name 还有 $days_left 天有效期，是否确认更新？"
                read -p "确认更新？(y/N): " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                    log_info "证书更新已取消"
                    return 0
                fi
            fi
            
            # 备份旧证书
            local backup_dir="pki/backup/$(date +%Y%m%d-%H%M%S)"
            mkdir -p "$backup_dir"
            cp "$cert_file" "$backup_dir/"
            
            # 重新生成证书
            if [[ "$cert_name" == "ca" ]]; then
                log_error "CA证书更新需要重新生成整个PKI，请联系管理员"
                return 1
            elif [[ "$cert_name" == "server" ]]; then
                scripts/generate-certs.sh --server
            else
                scripts/generate-certs.sh --client "$cert_name"
            fi
            
            log_success "证书更新完成: $cert_name"
            log_info "旧证书已备份到: $backup_dir"
            ;;
        "crl")
            log_info "生成证书撤销列表..."
            
            # 检查是否存在撤销证书记录
            local crl_config="pki/ca/crl.conf"
            local crl_file="pki/ca/crl.pem"
            local revoked_certs_file="pki/ca/revoked_certs.txt"
            
            # 创建CRL配置文件
            if [[ ! -f "$crl_config" ]]; then
                cat > "$crl_config" << EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = ./pki/ca
database = \$dir/index.txt
serial = \$dir/serial
crlnumber = \$dir/crlnumber
crl = \$dir/crl.pem
private_key = \$dir/private/ca.key
certificate = \$dir/ca.crt
default_crl_days = 30
crl_extensions = crl_ext

[ crl_ext ]
authorityKeyIdentifier=keyid:always,issuer:always
EOF
            fi
            
            # 创建必要的文件
            touch "pki/ca/index.txt"
            if [[ ! -f "pki/ca/crlnumber" ]]; then
                echo "01" > "pki/ca/crlnumber"
            fi
            
            # 生成CRL
            if openssl ca -config "$crl_config" -gencrl -out "$crl_file" 2>/dev/null; then
                log_success "证书撤销列表生成完成: $crl_file"
                
                # 显示CRL信息
                log_info "CRL信息:"
                openssl crl -in "$crl_file" -noout -text | grep -E "(Next Update|Revoked Certificates)"
            else
                log_error "证书撤销列表生成失败"
                return 1
            fi
            ;;
        *)
            log_error "未知的证书操作: $action"
            return 1
            ;;
    esac
}

# 主函数
main() {
    local command=""
    local service=""
    local profile=""
    local follow=false
    local tail=""
    local since=""
    local backup_dir=""
    local include_logs=false
    local client_action=""
    local client_name=""
    local cert_action=""
    local cert_name=""
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            start|stop|restart|status|logs|ps|config|backup|restore|clean|update|reset)
                command="$1"
                shift
                ;;
            client)
                command="client"
                shift
                ;;
            cert)
                command="cert"
                shift
                ;;
            --service)
                service="$2"
                shift 2
                ;;
            --profile)
                profile="$2"
                shift 2
                ;;
            --follow)
                follow=true
                shift
                ;;
            --tail)
                tail="$2"
                shift 2
                ;;
            --since)
                since="$2"
                shift 2
                ;;
            --backup-dir)
                backup_dir="$2"
                shift 2
                ;;
            --include-logs)
                include_logs=true
                shift
                ;;
            --list-clients)
                client_action="list"
                shift
                ;;
            --add-client)
                client_action="add"
                client_name="$2"
                shift 2
                ;;
            --remove-client)
                client_action="remove"
                client_name="$2"
                shift 2
                ;;
            --show-config)
                client_action="show"
                client_name="$2"
                shift 2
                ;;
            --list-certs)
                cert_action="list"
                shift
                ;;
            --verify-certs)
                cert_action="verify"
                shift
                ;;
            --renew-cert)
                cert_action="renew"
                cert_name="$2"
                shift 2
                ;;
            --generate-crl)
                cert_action="crl"
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                if [[ -z "$command" ]]; then
                    command="$1"
                elif [[ -z "$service" ]] && [[ "$1" =~ ^(openvpn|frps|frpc)$ ]]; then
                    service="$1"
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
    
    # 执行命令
    case "$command" in
        "start")
            start_services "$service" "$profile"
            ;;
        "stop")
            stop_services "$service"
            ;;
        "restart")
            restart_services "$service" "$profile"
            ;;
        "status")
            show_status
            ;;
        "logs")
            show_logs "$service" "$follow" "$tail" "$since"
            ;;
        "ps")
            $(get_compose_cmd) ps
            ;;
        "config")
            validate_config
            ;;
        "backup")
            backup_data "$backup_dir" "$include_logs"
            ;;
        "restore")
            restore_data "$backup_dir"
            ;;
        "clean")
            clean_resources
            ;;
        "update")
            update_images
            ;;
        "reset")
            reset_all
            ;;
        "client")
            manage_clients "$client_action" "$client_name"
            ;;
        "cert")
            manage_certificates "$cert_action" "$cert_name"
            ;;
        "")
            log_error "请指定命令"
            show_help
            exit 1
            ;;
        *)
            log_error "未知命令: $command"
            show_help
            exit 1
            ;;
    esac
}

# 执行主函数
main "$@"