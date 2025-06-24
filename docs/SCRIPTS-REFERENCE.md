# OpenVPN-FRP 脚本参考手册

## 概述

本文档提供OpenVPN-FRP项目中所有脚本的详细参数说明、使用示例和高级配置指南。

## 📁 脚本总览

| 脚本名称 | 主要功能 | 文件路径 |
|---------|----------|----------|
| [`deploy.sh`](#deploysh) | 一键部署脚本 | `scripts/deploy.sh` |
| [`manage.sh`](#managesh) | 服务管理脚本 | `scripts/manage.sh` |
| [`debug.sh`](#debugsh) | 统一调试工具 | `scripts/debug.sh` |
| [`docker-tools.sh`](#docker-toolssh) | Docker工具集 | `scripts/docker-tools.sh` |
| [`health-check.sh`](#health-checksh) | 健康检查脚本 | `scripts/health-check.sh` |
| [`generate-client-config.sh`](#generate-client-configsh) | 客户端配置生成 | `scripts/generate-client-config.sh` |
| [`generate-certs.sh`](#generate-certssh) | 证书生成脚本 | `scripts/generate-certs.sh` |
| [`verify-certs.sh`](#verify-certssh) | 证书验证脚本 | `scripts/verify-certs.sh` |
| [`build-openvpn.sh`](#build-openvpnsh) | OpenVPN构建脚本 | `scripts/build-openvpn.sh` |
| [`build-frp.sh`](#build-frpsh) | FRP构建脚本 | `scripts/build-frp.sh` |

## 🚀 deploy.sh

一键部署脚本，提供完整的自动化部署解决方案。

### 语法
```bash
./scripts/deploy.sh [选项]
```

### 选项参数

| 参数 | 长选项 | 描述 | 默认值 | 示例 |
|------|--------|------|--------|------|
| `-m` | `--mode` | 部署模式 | `standalone` | `--mode frp_client` |
| `-h` | `--host` | FRP服务器地址 | - | `--host 192.168.1.100` |
| `-p` | `--port` | OpenVPN端口 | `1194` | `--port 1194` |
| `-t` | `--token` | FRP认证令牌 | - | `--token secure_token` |
| `-c` | `--config` | 自定义配置文件 | `.env` | `--config custom.env` |
| `-f` | `--force` | 强制重新部署 | `false` | `--force` |
| `-d` | `--debug` | 启用调试模式 | `false` | `--debug` |
| - | `--skip-deps` | 跳过依赖检查 | `false` | `--skip-deps` |
| - | `--skip-certs` | 跳过证书生成 | `false` | `--skip-certs` |
| - | `--skip-build` | 跳过镜像构建 | `false` | `--skip-build` |
| - | `--dry-run` | 演练模式 | `false` | `--dry-run` |
| - | `--help` | 显示帮助信息 | - | `--help` |

### 部署模式说明

#### 1. Standalone 模式
适用于有公网IP的服务器，直接部署OpenVPN服务。

```bash
# 基本部署
./scripts/deploy.sh --mode standalone

# 自定义端口部署
./scripts/deploy.sh --mode standalone --port 1194

# 调试模式部署
./scripts/deploy.sh --mode standalone --debug
```

#### 2. FRP-Client 模式
适用于内网服务器，通过FRP进行端口穿透。

```bash
# 基本FRP客户端部署
./scripts/deploy.sh --mode frp_client --host 1.2.3.4 --token my_token

# 自定义配置部署
./scripts/deploy.sh --mode frp_client --host frp.example.com --token secure_token_2024 --port 1194

# 跳过证书生成（使用现有证书）
./scripts/deploy.sh --mode frp_client --host 1.2.3.4 --token my_token --skip-certs
```

#### 3. FRP-Full 模式
包含完整的FRP架构，适用于完全控制的环境。

```bash
# 完整FRP架构部署
./scripts/deploy.sh --mode frp_full --token secure_token

# 强制重新部署
./scripts/deploy.sh --mode frp_full --token secure_token --force

# 演练模式（查看将执行的操作）
./scripts/deploy.sh --mode frp_full --token secure_token --dry-run
```

### 高级用法

#### 1. 批量部署脚本
```bash
#!/bin/bash
# 批量部署多个环境

environments=(
    "prod:frp_client:prod.example.com:prod_token"
    "staging:frp_client:staging.example.com:staging_token"
    "dev:standalone::dev_token"
)

for env in "${environments[@]}"; do
    IFS=':' read -r name mode host token <<< "$env"
    echo "部署环境: $name"
    
    if [[ "$mode" == "standalone" ]]; then
        ./scripts/deploy.sh --mode standalone --debug
    else
        ./scripts/deploy.sh --mode "$mode" --host "$host" --token "$token" --debug
    fi
done
```

#### 2. 自定义配置部署
```bash
# 创建自定义配置文件
cp .env.example .env.production

# 编辑生产环境配置
cat >> .env.production << EOF
DEPLOY_MODE=frp_client
FRP_SERVER_ADDR=prod.frp-server.com
FRP_TOKEN=production_secure_token_here
OPENVPN_EXTERNAL_HOST=prod.frp-server.com
MAX_CLIENTS=500
KEY_SIZE=4096
EOF

# 使用自定义配置部署
./scripts/deploy.sh --config .env.production --mode frp_client --host prod.frp-server.com --token production_secure_token_here
```

## 🔍 debug.sh

统一调试工具，整合了快速状态检查、日志查看、证书验证和客户端配置生成等功能。

### 语法
```bash
./scripts/debug.sh [命令] [选项]
```

### 主要命令

| 命令 | 描述 | 示例 |
|------|------|------|
| `status` | 快速状态检查 | `./scripts/debug.sh status` |
| `logs` | 查看服务日志 | `./scripts/debug.sh logs` |
| `client` | 生成客户端配置 | `./scripts/debug.sh client test-user` |
| `certs` | 验证证书 | `./scripts/debug.sh certs` |
| `all` | 执行所有检查 | `./scripts/debug.sh all` |
| `help` | 显示帮助信息 | `./scripts/debug.sh help` |

### 选项参数

| 参数 | 长选项 | 描述 | 默认值 | 示例 |
|------|--------|------|--------|------|
| `-v` | `--verbose` | 详细输出 | `false` | `--verbose` |
| `-d` | `--debug` | 调试模式 | `false` | `--debug` |
| `-q` | `--quiet` | 静默模式 | `false` | `--quiet` |

### 功能详解

#### 1. 状态检查 (status)
快速检查OpenVPN服务的运行状态，包括：
- 容器运行状态
- 端口监听状态
- OpenVPN进程状态
- TUN接口状态
- 最新日志摘要

```bash
# 基本状态检查
./scripts/debug.sh status

# 详细状态检查
./scripts/debug.sh status --verbose

# 静默状态检查（仅返回状态码）
./scripts/debug.sh status --quiet
```

#### 2. 日志查看 (logs)
查看OpenVPN服务的各种日志：
- Docker容器日志
- OpenVPN应用日志
- 连接状态日志

```bash
# 查看最近日志
./scripts/debug.sh logs

# 详细日志模式
./scripts/debug.sh logs --verbose

# 调试模式查看日志
./scripts/debug.sh logs --debug
```

#### 3. 客户端配置生成 (client)
为指定客户端生成OpenVPN配置文件：

```bash
# 生成默认客户端配置
./scripts/debug.sh client

# 生成指定客户端配置
./scripts/debug.sh client alice

# 生成配置（详细模式）
./scripts/debug.sh client bob --verbose
```

**配置生成特性：**
- 自动检测服务器IP
- 内联证书格式
- 完整配置验证
- 兼容多平台

#### 4. 证书验证 (certs)
验证PKI证书体系的完整性：
- CA证书验证
- 服务器证书验证
- 客户端证书验证
- 证书过期检查

```bash
# 验证所有证书
./scripts/debug.sh certs

# 详细证书验证
./scripts/debug.sh certs --verbose
```

#### 5. 完整检查 (all)
执行所有可用的检查和验证：

```bash
# 完整系统检查
./scripts/debug.sh all

# 详细完整检查
./scripts/debug.sh all --verbose

# 调试模式完整检查
./scripts/debug.sh all --debug
```

### 实际使用场景

#### 1. 日常运维检查
```bash
# 每日状态检查
./scripts/debug.sh status

# 问题排查
./scripts/debug.sh all --verbose
```

#### 2. 新用户配置
```bash
# 为新用户生成配置
./scripts/debug.sh client new-employee

# 验证生成的配置
./scripts/debug.sh status
```

#### 3. 故障诊断
```bash
# 快速故障诊断
./scripts/debug.sh all --debug

# 查看详细日志
./scripts/debug.sh logs --verbose
```

#### 4. 证书管理
```bash
# 检查证书状态
./scripts/debug.sh certs

# 完整证书验证
./scripts/debug.sh certs --verbose
```

### 输出示例

#### 状态检查输出示例
```
=======================================
    OpenVPN 快速状态检查
=======================================
[SUCCESS] OpenVPN 容器正在运行
[SUCCESS] 端口 1194/UDP 正在监听
[SUCCESS] OpenVPN 进程正在运行
[SUCCESS] TUN 接口已创建并分配IP地址
=======================================
[SUCCESS] OpenVPN 服务状态检查完成，未发现严重问题
=======================================
```

#### 证书验证输出示例
```
[INFO] 验证证书...
[SUCCESS] CA证书有效
  subject=CN = OpenVPN CA
  notAfter=Jan 25 08:18:09 2035 GMT
[SUCCESS] 服务器证书有效
  subject=CN = server
  notAfter=Jan 25 08:18:09 2035 GMT
[SUCCESS] 服务器证书验证通过
[SUCCESS] 发现 3 个客户端证书
```

### 集成其他工具

#### 1. 定时监控
```bash
# 添加到crontab
*/10 * * * * /path/to/openvpn-frp/scripts/debug.sh status --quiet || echo "OpenVPN异常" | mail admin@example.com
```

#### 2. 监控脚本
```bash
#!/bin/bash
# 持续监控脚本
while true; do
    if ! ./scripts/debug.sh status --quiet; then
        echo "$(date): OpenVPN服务异常" >> /var/log/openvpn-monitor.log
        # 发送告警
    fi
    sleep 60
done
```

#### 3. 自动化部署后验证
```bash
#!/bin/bash
# 部署后验证脚本
./scripts/deploy.sh
echo "等待服务启动..."
sleep 30
./scripts/debug.sh all --verbose
```

## 🐳 docker-tools.sh

Docker工具集，整合了镜像源测试、配置更新、验证等Docker相关功能。

### 语法
```bash
./scripts/docker-tools.sh [命令] [选项]
```

### 主要命令

| 命令 | 描述 | 示例 |
|------|------|------|
| `test` | 测试Docker镜像源连通性 | `./scripts/docker-tools.sh test` |
| `best` | 获取最佳镜像源 | `./scripts/docker-tools.sh best` |
| `update` | 更新Docker镜像源配置 | `./scripts/docker-tools.sh update` |
| `verify` | 验证镜像源修复结果 | `./scripts/docker-tools.sh verify` |
| `fix` | 一键修复Docker问题 | `./scripts/docker-tools.sh fix` |
| `help` | 显示帮助信息 | `./scripts/docker-tools.sh help` |

### 选项参数

| 参数 | 长选项 | 描述 | 默认值 | 示例 |
|------|--------|------|--------|------|
| `-v` | `--verbose` | 详细输出 | `false` | `--verbose` |
| `-q` | `--quiet` | 静默模式 | `false` | `--quiet` |
| - | `--timeout` | 网络测试超时时间 | `5` | `--timeout 10` |
| - | `--format` | 输出格式 | `table` | `--format json` |
| - | `--best` | 只显示最佳镜像源 | `false` | `--best` |

### 功能详解

#### 1. 镜像源连通性测试 (test)
测试所有可用的Docker镜像源，评估响应时间和可用性：

```bash
# 测试所有镜像源
./scripts/docker-tools.sh test

# 只显示最佳镜像源
./scripts/docker-tools.sh test --best

# 详细测试模式
./scripts/docker-tools.sh test --verbose

# JSON格式输出
./scripts/docker-tools.sh test --format json
```

**测试的镜像源包括：**
- Docker Hub (registry-1.docker.io)
- 1Panel社区 (docker.1panel.live)
- DaoCloud (docker.m.daocloud.io)
- 南京大学 (docker.nju.edu.cn)

#### 2. 获取最佳镜像源 (best)
静默模式获取响应最快的镜像源：

```bash
# 获取最佳镜像源URL
./scripts/docker-tools.sh best

# 在脚本中使用
BEST_MIRROR=$(./scripts/docker-tools.sh best)
echo "最佳镜像源: $BEST_MIRROR"
```

#### 3. 更新Docker配置 (update)
自动更新Docker daemon配置，使用可用的镜像源：

```bash
# 更新Docker镜像源配置
./scripts/docker-tools.sh update

# 详细模式更新
./scripts/docker-tools.sh update --verbose
```

**更新内容：**
- 自动备份现有配置
- 生成新的daemon.json配置文件
- 配置多个可用镜像源
- 在macOS上自动重启Docker Desktop

#### 4. 验证配置 (verify)
验证镜像源配置是否生效：

```bash
# 验证配置
./scripts/docker-tools.sh verify

# 详细验证模式
./scripts/docker-tools.sh verify --verbose
```

**验证过程：**
- 检查Docker服务状态
- 尝试拉取测试镜像
- 验证镜像源响应

#### 5. 一键修复 (fix)
自动修复Docker镜像源问题：

```bash
# 一键修复所有Docker问题
./scripts/docker-tools.sh fix

# 静默修复模式
./scripts/docker-tools.sh fix --quiet
```

**修复步骤：**
1. 测试镜像源连通性
2. 更新Docker配置
3. 重启Docker服务
4. 验证配置生效

### 实际使用场景

#### 1. 解决Docker镜像拉取问题
```bash
# 当docker pull失败时
./scripts/docker-tools.sh fix
```

#### 2. 项目部署前的环境准备
```bash
# 部署前检查和修复Docker环境
./scripts/docker-tools.sh test
./scripts/docker-tools.sh update
./scripts/build-openvpn.sh
```

#### 3. 自动化脚本中的镜像源选择
```bash
#!/bin/bash
# 在构建脚本中自动选择最佳镜像源
BEST_MIRROR=$(./scripts/docker-tools.sh best --quiet)
if [[ -n "$BEST_MIRROR" ]]; then
    echo "使用镜像源: $BEST_MIRROR"
    # 在构建中使用该镜像源
else
    echo "没有可用的镜像源"
    exit 1
fi
```

#### 4. 监控脚本
```bash
#!/bin/bash
# 定期检查镜像源状态
if ! ./scripts/docker-tools.sh verify --quiet; then
    echo "镜像源配置异常，尝试修复..."
    ./scripts/docker-tools.sh fix
fi
```

### 输出示例

#### 镜像源测试输出
```
[INFO] 开始测试镜像源连通性...

名称            地址                                     状态       响应时间
----            ----                                     ----       --------
Docker Hub      registry-1.docker.io                    ✗ 不可用   -
1Panel社区      docker.1panel.live                      ✓ 可用     0.245s
DaoCloud        docker.m.daocloud.io                     ✓ 可用     0.312s
南京大学        docker.nju.edu.cn                        ✓ 可用     0.158s

[INFO] 测试完成，共测试 4 个镜像源，3 个可用
[SUCCESS] 推荐镜像源: 南京大学 (docker.nju.edu.cn) - 响应时间: 0.158s
```

#### 配置更新输出
```
[INFO] 更新Docker镜像源配置...
[INFO] 已备份现有Docker配置
[SUCCESS] 已更新Docker daemon配置: /Users/username/.docker/daemon.json
[INFO] 重启Docker服务以应用新配置...
[SUCCESS] Docker服务已启动
```

### 集成其他工具

#### 1. 与构建脚本集成
```bash
# 在build-openvpn.sh中使用
if ! ./scripts/docker-tools.sh verify --quiet; then
    echo "检测到Docker镜像源问题，正在修复..."
    ./scripts/docker-tools.sh fix
fi
```

#### 2. 与部署脚本集成
```bash
# 在deploy.sh中使用
echo "检查Docker环境..."
./scripts/docker-tools.sh test --quiet || {
    echo "Docker镜像源不可用，尝试修复..."
    ./scripts/docker-tools.sh fix
}
```

#### 3. CI/CD环境中使用
```yaml
# GitHub Actions示例
- name: Setup Docker Mirrors
  run: |
    ./scripts/docker-tools.sh fix
    ./scripts/docker-tools.sh verify
```

## ⚙️ manage.sh

服务管理脚本，提供完整的服务生命周期管理功能。

### 语法
```bash
./scripts/manage.sh <命令> [选项]
```

### 主要命令

#### 1. 服务控制命令

##### start - 启动服务
```bash
# 启动所有服务
./scripts/manage.sh start

# 启动特定服务
./scripts/manage.sh start --service openvpn
./scripts/manage.sh start --service frpc
./scripts/manage.sh start --service frps

# 启动服务并显示日志
./scripts/manage.sh start --follow-logs
```

##### stop - 停止服务
```bash
# 停止所有服务
./scripts/manage.sh stop

# 停止特定服务
./scripts/manage.sh stop --service openvpn

# 强制停止服务
./scripts/manage.sh stop --force
```

##### restart - 重启服务
```bash
# 重启所有服务
./scripts/manage.sh restart

# 重启特定服务
./scripts/manage.sh restart --service openvpn

# 优雅重启（等待连接关闭）
./scripts/manage.sh restart --graceful
```

##### status - 查看状态
```bash
# 查看所有服务状态
./scripts/manage.sh status

# 查看详细状态
./scripts/manage.sh status --detailed

# JSON格式输出
./scripts/manage.sh status --format json
```

#### 2. 日志管理命令

##### logs - 查看日志
```bash
# 查看所有服务日志
./scripts/manage.sh logs

# 查看特定服务日志
./scripts/manage.sh logs openvpn
./scripts/manage.sh logs frpc
./scripts/manage.sh logs frps

# 实时跟踪日志
./scripts/manage.sh logs --follow
./scripts/manage.sh logs openvpn --follow

# 查看最近N行日志
./scripts/manage.sh logs --tail 100
./scripts/manage.sh logs openvpn --tail 50

# 查看指定时间后的日志
./scripts/manage.sh logs --since "2024-01-01T10:00:00"
./scripts/manage.sh logs --since "1h"
./scripts/manage.sh logs --since "30m"

# 保存日志到文件
./scripts/manage.sh logs openvpn --tail 1000 > openvpn.log
```

#### 3. 备份和恢复命令

##### backup - 创建备份
```bash
# 基本备份
./scripts/manage.sh backup

# 包含日志的完整备份
./scripts/manage.sh backup --include-logs

# 指定备份目录
./scripts/manage.sh backup --backup-dir /path/to/backup

# 压缩备份
./scripts/manage.sh backup --compress

# 备份到远程服务器
./scripts/manage.sh backup --remote user@backup-server:/backup/openvpn-frp/
```

##### restore - 恢复备份
```bash
# 从备份目录恢复
./scripts/manage.sh restore --backup-dir /path/to/backup

# 恢复前验证备份
./scripts/manage.sh restore --backup-dir /path/to/backup --verify

# 选择性恢复
./scripts/manage.sh restore --backup-dir /path/to/backup --exclude-logs
./scripts/manage.sh restore --backup-dir /path/to/backup --certs-only
```

#### 4. 客户端管理命令

##### client - 客户端管理
```bash
# 列出所有客户端
./scripts/manage.sh client --list-clients

# 添加新客户端
./scripts/manage.sh client --add-client username

# 删除客户端
./scripts/manage.sh client --remove-client username

# 显示客户端配置
./scripts/manage.sh client --show-config username

# 批量添加客户端
./scripts/manage.sh client --batch-add --file clients.txt

# 生成客户端报告
./scripts/manage.sh client --report --format json
```

#### 5. 证书管理命令

##### cert - 证书管理
```bash
# 列出所有证书
./scripts/manage.sh cert --list-certs

# 验证证书
./scripts/manage.sh cert --verify-certs

# 检查即将过期的证书
./scripts/manage.sh cert --list-expiring --days 30

# 更新服务器证书
./scripts/manage.sh cert --renew-cert server

# 更新客户端证书
./scripts/manage.sh cert --renew-cert client1

# 撤销证书
./scripts/manage.sh cert --revoke-cert compromised_client

# 生成CRL
./scripts/manage.sh cert --generate-crl
```

#### 6. 配置管理命令

##### config - 配置管理
```bash
# 验证配置文件
./scripts/manage.sh config

# 显示当前配置
./scripts/manage.sh config --show

# 检查配置差异
./scripts/manage.sh config --diff

# 重新生成配置文件
./scripts/manage.sh config --regenerate
```

#### 7. 系统维护命令

##### clean - 清理系统
```bash
# 清理未使用的Docker资源
./scripts/manage.sh clean

# 清理日志文件
./scripts/manage.sh clean --logs

# 清理备份文件
./scripts/manage.sh clean --backups --older-than 30

# 深度清理
./scripts/manage.sh clean --deep
```

##### update - 更新系统
```bash
# 更新Docker镜像
./scripts/manage.sh update

# 更新并重建镜像
./scripts/manage.sh update --rebuild

# 更新系统包
./scripts/manage.sh update --system
```

### 高级用法示例

#### 1. 自动化运维脚本
```bash
#!/bin/bash
# 日常运维脚本

echo "开始日常维护..."

# 1. 检查服务状态
echo "1. 检查服务状态"
./scripts/manage.sh status --detailed

# 2. 创建备份
echo "2. 创建备份"
./scripts/manage.sh backup --include-logs --compress

# 3. 清理旧日志
echo "3. 清理旧日志"
./scripts/manage.sh clean --logs --older-than 7

# 4. 检查证书状态
echo "4. 检查证书状态"
./scripts/manage.sh cert --list-expiring --days 30

# 5. 更新系统
echo "5. 检查更新"
./scripts/manage.sh update --check-only

echo "日常维护完成"
```

#### 2. 监控脚本
```bash
#!/bin/bash
# 服务监控脚本

while true; do
    # 检查服务状态
    if ! ./scripts/manage.sh status --quiet; then
        echo "服务异常，尝试重启..."
        ./scripts/manage.sh restart
        
        # 发送告警
        echo "OpenVPN服务异常重启 $(date)" | mail -s "OpenVPN Alert" admin@example.com
    fi
    
    sleep 300  # 5分钟检查一次
done
```

## 🏥 health-check.sh

系统健康检查脚本，提供全方位的系统监控和报告功能。

### 语法
```bash
./scripts/health-check.sh [选项]
```

### 选项参数

| 参数 | 长选项 | 描述 | 默认值 | 示例 |
|------|--------|------|--------|------|
| `-f` | `--format` | 输出格式 | `text` | `--format json` |
| `-o` | `--output` | 输出文件 | `stdout` | `--output health.json` |
| `-c` | `--check` | 检查类型 | `all` | `--check certificates` |
| `-s` | `--skip` | 跳过检查 | - | `--skip resources` |
| `-i` | `--interval` | 检查间隔 | `60` | `--interval 30` |
| - | `--continuous` | 连续监控 | `false` | `--continuous` |
| - | `--nagios` | Nagios兼容输出 | `false` | `--nagios` |
| - | `--zabbix` | Zabbix兼容输出 | `false` | `--zabbix` |
| - | `--alert-days` | 证书告警天数 | `30` | `--alert-days 7` |
| - | `--quiet` | 静默模式 | `false` | `--quiet` |

### 检查类型

#### 1. 全面检查（默认）
```bash
# 运行所有检查
./scripts/health-check.sh

# JSON格式输出
./scripts/health-check.sh --format json

# 保存结果到文件
./scripts/health-check.sh --format json --output health-report.json
```

#### 2. 特定类型检查
```bash
# 只检查Docker服务
./scripts/health-check.sh --check docker

# 只检查网络连接
./scripts/health-check.sh --check network

# 只检查证书状态
./scripts/health-check.sh --check certificates

# 只检查系统资源
./scripts/health-check.sh --check resources

# 只检查配置文件
./scripts/health-check.sh --check config
```

#### 3. 组合检查
```bash
# 检查服务和网络，跳过资源检查
./scripts/health-check.sh --check docker,network --skip resources

# 证书检查，7天内过期告警
./scripts/health-check.sh --check certificates --alert-days 7
```

### 输出格式

#### 1. 文本格式（默认）
```bash
./scripts/health-check.sh --format text
```

#### 2. JSON格式
```bash
# JSON输出
./scripts/health-check.sh --format json

# 美化的JSON输出
./scripts/health-check.sh --format json | jq '.'
```

#### 3. HTML格式
```bash
# 生成HTML报告
./scripts/health-check.sh --format html --output health-report.html
```

#### 4. Prometheus格式
```bash
# Prometheus指标格式
./scripts/health-check.sh --format prometheus --output metrics.prom
```

### 监控集成

#### 1. Nagios集成
```bash
# Nagios兼容检查
./scripts/health-check.sh --nagios

# 在Nagios中定义检查命令
define command{
    command_name    check_openvpn_frp
    command_line    /path/to/openvpn-frp/scripts/health-check.sh --nagios
}

define service{
    use                 generic-service
    host_name           openvpn-server
    service_description OpenVPN-FRP Health
    check_command       check_openvpn_frp
}
```

#### 2. Zabbix集成
```bash
# Zabbix兼容检查
./scripts/health-check.sh --zabbix

# 在Zabbix中配置UserParameter
UserParameter=openvpn.health,/path/to/openvpn-frp/scripts/health-check.sh --zabbix --format json
```

#### 3. Prometheus集成
```bash
# 生成Prometheus指标
./scripts/health-check.sh --format prometheus > /var/lib/prometheus/openvpn.prom

# 定时更新指标
*/5 * * * * /path/to/openvpn-frp/scripts/health-check.sh --format prometheus > /var/lib/prometheus/openvpn.prom
```

### 连续监控

#### 1. 连续监控模式
```bash
# 每60秒检查一次（默认）
./scripts/health-check.sh --continuous

# 每30秒检查一次
./scripts/health-check.sh --continuous --interval 30

# 连续监控并保存日志
./scripts/health-check.sh --continuous --interval 60 --format json >> health-monitoring.log
```

#### 2. 后台监控
```bash
# 启动后台监控
nohup ./scripts/health-check.sh --continuous --interval 300 --format json --output /var/log/openvpn-health.log &

# 创建systemd服务
cat > /etc/systemd/system/openvpn-health-monitor.service << EOF
[Unit]
Description=OpenVPN-FRP Health Monitor
After=docker.service

[Service]
Type=simple
User=openvpn
WorkingDirectory=/path/to/openvpn-frp
ExecStart=/path/to/openvpn-frp/scripts/health-check.sh --continuous --interval 300 --format json --output /var/log/openvpn-health.log
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable openvpn-health-monitor
sudo systemctl start openvpn-health-monitor
```

## 📱 generate-client-config.sh

客户端配置生成脚本，支持多平台和多种格式的配置文件生成。

### 语法
```bash
./scripts/generate-client-config.sh [选项]
```

### 选项参数

| 参数 | 长选项 | 描述 | 默认值 | 示例 |
|------|--------|------|--------|------|
| `-c` | `--client` | 客户端名称 | `client1` | `--client alice` |
| `-m` | `--mode` | 连接模式 | `auto` | `--mode direct` |
| `-h` | `--host` | 服务器地址 | 自动检测 | `--host 1.2.3.4` |
| `-p` | `--port` | 服务器端口 | `1194` | `--port 1194` |
| `-f` | `--format` | 输出格式 | `inline` | `--format separate` |
| `-o` | `--output` | 输出目录 | 当前目录 | `--output ./clients` |
| - | `--android` | Android优化 | `false` | `--android` |
| - | `--ios` | iOS优化 | `false` | `--ios` |
| - | `--windows` | Windows优化 | `false` | `--windows` |
| - | `--macos` | macOS优化 | `false` | `--macos` |
| - | `--linux` | Linux优化 | `false` | `--linux` |
| - | `--multiple` | 生成多个配置 | `false` | `--multiple` |
| - | `--qr-code` | 生成二维码 | `false` | `--qr-code` |
| - | `--zip` | 打包输出 | `false` | `--zip` |
| - | `--verify` | 验证配置 | `false` | `--verify` |

### 平台优化配置

#### 1. Android配置
```bash
# 基本Android配置
./scripts/generate-client-config.sh --client mobile1 --android

# Android配置（指定服务器）
./scripts/generate-client-config.sh --client phone --android --host vpn.example.com

# Android配置（FRP模式）
./scripts/generate-client-config.sh --client tablet --android --mode frp --host frp.example.com
```

**Android优化特性：**
- 使用UDP协议优化移动网络
- 启用快速重连
- 优化电池使用
- 支持网络切换

#### 2. iOS配置
```bash
# 基本iOS配置
./scripts/generate-client-config.sh --client iphone1 --ios

# iOS配置（带二维码）
./scripts/generate-client-config.sh --client ipad --ios --qr-code
```

**iOS优化特性：**
- 兼容iOS VPN框架
- 支持按需连接
- 优化电池使用
- 支持Siri快捷方式

#### 3. Windows配置
```bash
# 基本Windows配置
./scripts/generate-client-config.sh --client pc1 --windows

# Windows企业配置
./scripts/generate-client-config.sh --client workstation --windows --format separate
```

**Windows优化特性：**
- 支持Windows服务模式
- 优化TAP驱动性能
- 支持域用户认证
- 兼容Windows防火墙

#### 4. macOS配置
```bash
# 基本macOS配置
./scripts/generate-client-config.sh --client mac1 --macos

# macOS开发者配置
./scripts/generate-client-config.sh --client dev-mac --macos --verify
```

**macOS优化特性：**
- 支持Keychain集成
- 优化tun设备处理
- 支持macOS网络扩展
- 兼容Homebrew安装

#### 5. Linux配置
```bash
# 基本Linux配置
./scripts/generate-client-config.sh --client server1 --linux

# Linux服务器配置
./scripts/generate-client-config.sh --client ubuntu-server --linux --format separate
```

**Linux优化特性：**
- 支持systemd集成
- 优化路由配置
- 支持NetworkManager
- 兼容多种发行版

### 连接模式

#### 1. 自动模式（默认）
```bash
# 自动检测连接模式
./scripts/generate-client-config.sh --client user1 --mode auto
```

自动模式会根据当前部署配置选择最适合的连接方式。

#### 2. 直连模式
```bash
# 直连模式（适用于standalone部署）
./scripts/generate-client-config.sh --client user1 --mode direct --host 1.2.3.4
```

#### 3. FRP穿透模式
```bash
# FRP穿透模式（适用于frp_client/frp_full部署）
./scripts/generate-client-config.sh --client user1 --mode frp --host frp-server.com
```

### 输出格式

#### 1. 内联格式（推荐）
```bash
# 内联格式（所有证书内嵌在配置文件中）
./scripts/generate-client-config.sh --client user1 --format inline
```

**优点：**
- 单一文件，易于分发
- 不会丢失证书文件
- 适合移动设备

#### 2. 分离格式
```bash
# 分离格式（证书和配置分离）
./scripts/generate-client-config.sh --client user1 --format separate
```

**优点：**
- 便于证书管理
- 支持证书更新
- 适合企业环境

### 批量生成

#### 1. 生成多个客户端配置
```bash
# 生成所有现有客户端的配置
./scripts/generate-client-config.sh --multiple --output ./clients

# 生成特定平台的多个配置
./scripts/generate-client-config.sh --multiple --android --output ./mobile-clients
```

#### 2. 批量生成脚本
```bash
#!/bin/bash
# 批量生成客户端配置

clients=(
    "alice:android"
    "bob:windows"
    "charlie:macos"
    "david:ios"
    "server1:linux"
)

for client_info in "${clients[@]}"; do
    IFS=':' read -r name platform <<< "$client_info"
    echo "生成 $name 的 $platform 配置..."
    
    ./scripts/generate-client-config.sh \
        --client "$name" \
        --"$platform" \
        --format inline \
        --output "./clients/$platform"
done

echo "批量生成完成"
```

### 二维码生成

#### 1. 基本二维码
```bash
# 生成带二维码的配置
./scripts/generate-client-config.sh --client mobile1 --qr-code

# 移动设备专用二维码
./scripts/generate-client-config.sh --client phone --android --qr-code
```

#### 2. 二维码Web服务
```bash
#!/bin/bash
# 创建二维码Web服务

# 生成配置和二维码
./scripts/generate-client-config.sh --client "$1" --android --qr-code --output /tmp/qr

# 启动简单HTTP服务器
cd /tmp/qr
python3 -m http.server 8080
```

### 配置验证

#### 1. 基本验证
```bash
# 验证生成的配置
./scripts/generate-client-config.sh --verify

# 验证特定客户端配置
./scripts/generate-client-config.sh --client user1 --verify
```

#### 2. 高级验证
```bash
# 验证配置语法
openvpn --config client.ovpn --verb 3 --connect-timeout 1 &
PID=$!
sleep 5
kill $PID

# 验证证书有效性
openssl verify -CAfile pki/ca/ca.crt pki/clients/user1.crt
```

## 🔐 generate-certs.sh

证书生成脚本，负责创建完整的PKI证书体系。

### 语法
```bash
./scripts/generate-certs.sh [选项]
```

### 选项参数

| 参数 | 长选项 | 描述 | 默认值 | 示例 |
|------|--------|------|--------|------|
| `-f` | `--force` | 强制重新生成 | `false` | `--force` |
| `-c` | `--clients` | 客户端数量 | `3` | `--clients 5` |
| `-k` | `--key-size` | 密钥长度 | `2048` | `--key-size 4096` |
| `-d` | `--days` | 证书有效期 | `3650` | `--days 1825` |
| - | `--ca-only` | 只生成CA证书 | `false` | `--ca-only` |
| - | `--server-only` | 只生成服务器证书 | `false` | `--server-only` |
| - | `--client-only` | 只生成客户端证书 | `false` | `--client-only` |
| - | `--no-password` | 不设置密码 | `false` | `--no-password` |

### 基本用法

#### 1. 生成完整证书体系
```bash
# 基本证书生成
./scripts/generate-certs.sh

# 生成5个客户端证书
./scripts/generate-certs.sh --clients 5

# 使用4096位密钥
./scripts/generate-certs.sh --key-size 4096
```

#### 2. 部分证书生成
```bash
# 只生成CA证书
./scripts/generate-certs.sh --ca-only

# 只生成服务器证书
./scripts/generate-certs.sh --server-only

# 只生成客户端证书
./scripts/generate-certs.sh --client-only --clients 3
```

#### 3. 强制重新生成
```bash
# 强制重新生成所有证书
./scripts/generate-certs.sh --force

# 强制重新生成服务器证书
./scripts/generate-certs.sh --server-only --force
```

### 高级用法

#### 1. 企业级证书配置
```bash
#!/bin/bash
# 企业级证书生成脚本

# 设置环境变量
export KEY_SIZE=4096
export CA_EXPIRE_DAYS=7300  # 20年
export SERVER_EXPIRE_DAYS=3650  # 10年
export CLIENT_EXPIRE_DAYS=365    # 1年

# 生成证书
./scripts/generate-certs.sh --key-size 4096 --force

# 设置严格权限
chmod 600 pki/ca/private/ca.key
chmod 600 pki/server/private/server.key
chmod 600 pki/clients/private/*.key
```

#### 2. 自定义证书信息
```bash
# 修改OpenSSL配置
cat >> config/openssl.cnf << EOF
# 自定义证书信息
countryName_default = CN
stateOrProvinceName_default = Beijing
localityName_default = Beijing
organizationName_default = Your Company
organizationalUnitName_default = IT Department
emailAddress_default = admin@yourcompany.com
EOF

# 生成证书
./scripts/generate-certs.sh
```

## ✅ verify-certs.sh

证书验证脚本，用于检查证书的有效性和安全性。

### 语法
```bash
./scripts/verify-certs.sh [选项]
```

### 选项参数

| 参数 | 长选项 | 描述 | 默认值 | 示例 |
|------|--------|------|--------|------|
| `-v` | `--verbose` | 详细输出 | `false` | `--verbose` |
| `-a` | `--all` | 验证所有证书 | `true` | `--all` |
| `-c` | `--cert` | 验证特定证书 | - | `--cert server` |
| `-e` | `--expiry` | 检查过期时间 | `false` | `--expiry` |
| `-s` | `--security` | 安全检查 | `false` | `--security` |
| `-f` | `--format` | 输出格式 | `text` | `--format json` |

### 基本验证

#### 1. 验证所有证书
```bash
# 基本验证
./scripts/verify-certs.sh

# 详细验证
./scripts/verify-certs.sh --verbose

# JSON格式输出
./scripts/verify-certs.sh --format json
```

#### 2. 验证特定证书
```bash
# 验证CA证书
./scripts/verify-certs.sh --cert ca

# 验证服务器证书
./scripts/verify-certs.sh --cert server

# 验证客户端证书
./scripts/verify-certs.sh --cert client1
```

### 高级验证

#### 1. 安全检查
```bash
# 完整安全检查
./scripts/verify-certs.sh --security --verbose

# 检查证书链
./scripts/verify-certs.sh --security --cert server

# 检查密钥强度
./scripts/verify-certs.sh --security --format json
```

#### 2. 过期时间检查
```bash
# 检查所有证书过期时间
./scripts/verify-certs.sh --expiry

# 检查即将过期的证书（30天内）
./scripts/verify-certs.sh --expiry --days 30

# 生成过期报告
./scripts/verify-certs.sh --expiry --format json > cert-expiry-report.json
```

## 🐳 build-openvpn.sh & build-frp.sh

Docker镜像构建脚本。

### build-openvpn.sh

```bash
# 构建OpenVPN镜像
./scripts/build-openvpn.sh

# 强制重新构建
./scripts/build-openvpn.sh --no-cache

# 指定标签
./scripts/build-openvpn.sh --tag custom-openvpn:latest
```

### build-frp.sh

```bash
# 构建FRP镜像
./scripts/build-frp.sh

# 只构建客户端镜像
./scripts/build-frp.sh --client-only

# 只构建服务端镜像
./scripts/build-frp.sh --server-only
```

## 🔧 集成和自动化

### 1. CI/CD集成

#### GitHub Actions示例
```yaml
name: Deploy OpenVPN-FRP
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    
    - name: Deploy to Production
      run: |
        ./scripts/deploy.sh --mode frp_client \
          --host ${{ secrets.FRP_SERVER }} \
          --token ${{ secrets.FRP_TOKEN }} \
          --debug
    
    - name: Health Check
      run: |
        ./scripts/health-check.sh --format json \
          --output health-report.json
    
    - name: Upload Health Report
      uses: actions/upload-artifact@v2
      with:
        name: health-report
        path: health-report.json
```

### 2. 监控集成

#### Prometheus监控
```bash
# 创建监控脚本
cat > scripts/prometheus-exporter.sh << 'EOF'
#!/bin/bash
while true; do
    ./scripts/health-check.sh --format prometheus > /var/lib/prometheus/openvpn.prom
    sleep 60
done
EOF

chmod +x scripts/prometheus-exporter.sh
nohup ./scripts/prometheus-exporter.sh &
```

### 3. 告警集成

#### Slack通知
```bash
#!/bin/bash
# Slack告警脚本

SLACK_WEBHOOK="your-slack-webhook-url"

# 检查服务状态
if ! ./scripts/health-check.sh --quiet; then
    curl -X POST -H 'Content-type: application/json' \
        --data '{"text":"OpenVPN-FRP服务异常！"}' \
        $SLACK_WEBHOOK
fi
```

## 📋 脚本配置参考

### 环境变量

所有脚本都支持以下环境变量：

```bash
# 调试模式
export DEBUG_MODE=true

# 静默模式
export QUIET_MODE=true

# 日志级别
export LOG_LEVEL=debug  # debug|info|warn|error

# 输出格式
export OUTPUT_FORMAT=json  # text|json|yaml

# 配置文件路径
export CONFIG_FILE=/path/to/custom.env
```

### 配置文件

可以通过配置文件自定义脚本行为：

```bash
# scripts/config.conf
DEFAULT_CLIENT_COUNT=5
DEFAULT_KEY_SIZE=4096
DEFAULT_CERT_DAYS=365
BACKUP_RETENTION_DAYS=30
LOG_RETENTION_DAYS=7
```

---

## 📞 技术支持

如需帮助：

1. 使用 `--help` 参数查看脚本帮助
2. 使用 `--debug` 参数获取详细信息
3. 查看日志文件了解错误原因
4. 联系技术支持团队

**所有脚本都经过充分测试，支持生产环境使用！**