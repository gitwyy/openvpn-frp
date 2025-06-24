# OpenVPN-FRP - 企业级 OpenVPN 和 FRP 集成解决方案

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![OpenVPN](https://img.shields.io/badge/OpenVPN-2.5+-green.svg)](https://openvpn.net/)
[![FRP](https://img.shields.io/badge/FRP-0.51+-orange.svg)](https://github.com/fatedier/frp)
[![文档](https://img.shields.io/badge/文档-完整-brightgreen.svg)](docs/)

## 🌍 语言版本 / Language Versions

- [🇨🇳 完整中文文档](docs/README_ZH.md) - 专为中国用户优化的详细说明
- [🇺🇸 English Documentation](docs/README_EN.md) - Complete English guide
- [📚 所有文档](docs/) - All documentation

## 🚀 项目概述

OpenVPN-FRP 是一个完整的企业级 VPN 解决方案，集成了 OpenVPN 和 FRP（Fast Reverse Proxy），提供：

- **一键部署** - 完全自动化的部署过程
- **多场景支持** - 支持公网直连、内网穿透等多种部署场景
- **智能管理** - 全方位的服务管理和监控功能
- **客户端配置自动生成** - 支持多平台客户端配置自动生成
- **网络优化** - 自动选择最佳Docker镜像源，专为中国大陆网络环境优化
- **健康检查** - 完整的系统健康监控和报告
- **安全可靠** - 企业级安全配置和证书管理

## ✨ 主要特性

### 🏗️ 部署特性
- **三种部署模式**：standalone（独立）、frp-client（FRP客户端）、frp-full（完整FRP架构）
- **自动化部署**：一个命令完成所有配置和部署
- **智能检测**：自动检测系统环境和依赖
- **配置验证**：部署前自动验证所有配置

### 🛠️ 管理特性
- **服务管理**：启动、停止、重启、状态查看
- **日志管理**：实时日志查看和分析
- **备份恢复**：完整的配置和数据备份恢复
- **客户端管理**：客户端证书的增删改查

### 📊 监控特性
- **健康检查**：全方位的系统健康监控
- **多种输出格式**：支持 JSON、HTML、Prometheus 等格式
- **连续监控**：支持连续监控模式
- **告警集成**：支持 Nagios、Zabbix 集成

### 🔧 客户端特性
- **多平台支持**：Android、iOS、Windows、macOS、Linux
- **智能配置**：根据部署模式自动生成最佳配置
- **多种格式**：支持内联和分离的配置格式
- **二维码生成**：移动设备扫码配置

## 🚀 快速开始

### 系统要求

- **操作系统**：Linux、macOS 或 Windows (WSL)
- **Docker**：20.10+
- **Docker Compose**：1.29+
- **OpenSSL**：1.1+
- **网络工具**：netcat、curl

### 一键部署

1. **克隆项目**
```bash
git clone https://github.com/your-org/openvpn-frp.git
cd openvpn-frp
```

2. **配置环境**
```bash
# 复制配置模板
cp .env.example .env

# 编辑配置（必须设置服务器地址）
nano .env
```

3. **macOS用户特别注意**

如果您在macOS环境下遇到TUN设备问题，请先运行macOS修复脚本：

```bash
# 使用Docker模式修复（推荐）
./scripts/macos-fix.sh --docker-mode

# 或者安装TunTap驱动
./scripts/macos-fix.sh --install-tuntap

# 仅检查环境状态
./scripts/macos-fix.sh --check-only
```

详细的macOS部署指南请参考：[📍 macOS部署指南](docs/MACOS-DEPLOYMENT.md)

4. **选择部署模式并部署**

#### standalone 模式（有公网IP的服务器）
```bash
./scripts/deploy.sh --mode standalone
```

#### FRP客户端模式（内网服务器穿透）
```bash
./scripts/deploy.sh --mode frp-client --host YOUR_PUBLIC_SERVER_IP --token YOUR_SECURE_TOKEN
```

#### 完整FRP架构（包含服务端和客户端）
```bash
./scripts/deploy.sh --mode frp-full --token YOUR_SECURE_TOKEN
```

## 🧩 三种模式详细教程

### 🏗️ 1. standalone 模式（公网服务器）

#### 构建流程
```bash
# 1. 生成CA和服务器证书
./scripts/generate-certs.sh --server

# 2. 构建OpenVPN镜像
./scripts/build-openvpn.sh

# 3. 启动服务
docker-compose up -d openvpn
```

#### 服务管理
```bash
# 启动服务
./scripts/manage.sh start

# 停止服务
./scripts/manage.sh stop

# 重启服务
./scripts/manage.sh restart

# 查看实时日志
./scripts/manage.sh logs --follow
```

#### 日常维护
```bash
# 更新证书（有效期延长）
./scripts/generate-certs.sh --renew --days 730

# 调整VPN网段
sed -i '' 's/OPENVPN_NETWORK=10.8.0.0/OPENVPN_NETWORK=10.9.0.0/' .env
./scripts/manage.sh restart
```

### 🔌 2. frp-client 模式（内网穿透）

此模式适用于内网服务器通过FRP客户端连接到公网FRP服务器实现穿透访问。

#### 端口映射配置
根据实际的 [`docker-compose.yml`](docker-compose.yml:96) 配置：
- FRP服务器端口：7000
- FRP管理后台：7500
- OpenVPN端口：1194/udp
- 管理接口：7505

#### 特殊配置
```bash
# 编辑FRP客户端配置
nano config/frpc.ini

# 关键参数设置
[common]
server_addr = YOUR_PUBLIC_SERVER_IP
server_port = 7000
token = YOUR_SECURE_TOKEN

[openvpn]
type = udp
local_ip = openvpn
local_port = 1194
remote_port = 1194  # 公网暴露端口
```

#### 穿透验证
```bash
# 检查FRP连接状态
docker-compose logs frpc | grep "login success"

# 测试公网访问
nc -vzu YOUR_PUBLIC_SERVER_IP 1194
```

#### 故障转移
```bash
# FRP连接中断自动恢复（使用profiles启动）
docker-compose --profile frp-client up -d

# 查看重连日志
./scripts/manage.sh logs frpc --tail 50
```

### 🌐 3. frp-full 模式（完整架构）

此模式在同一环境中部署FRP服务端和客户端，实现完整的内网穿透架构。

#### 架构部署
```bash
# 使用完整FRP架构profile启动
docker-compose --profile frp-full up -d

# 验证组件状态
./scripts/health-check.sh --check frp
```

#### 服务依赖关系
根据 [`docker-compose.yml`](docker-compose.yml:70) 的配置：
- frpc 依赖 openvpn 服务健康检查
- frps 独立运行在 frp-full profile 中
- 端口映射：7000（控制）、7500（管理）、1194（OpenVPN）、7505（管理接口）

#### 安全加固
```bash
# 每月轮换FRP token
./scripts/manage.sh config --rotate-frp-token

# 查看当前token
grep "FRP_TOKEN" .env
```

## 🌐 网络访问优化（中国大陆用户必读）

如果您在中国大陆地区遇到Docker镜像下载失败的问题，我们提供了完整的解决方案：

### 🔧 自动镜像源选择（推荐）

项目已集成智能镜像源选择功能，会自动测试并选择最快的镜像源：

```bash
# 所有构建脚本都已支持自动镜像源选择
./scripts/deploy.sh --mode standalone

# 使用Docker工具集测试镜像源连通性
./scripts/docker-tools.sh test

# 查看最佳镜像源
./scripts/docker-tools.sh best
```

### 🛠️ 手动指定镜像源

如果需要手动指定镜像源，请使用 [`scripts/docker-tools.sh`](scripts/docker-tools.sh:1)：

```bash
# 测试所有可用镜像源
./scripts/docker-tools.sh test

# 一键修复Docker镜像源问题
./scripts/docker-tools.sh fix

# 更新Docker daemon配置
./scripts/docker-tools.sh update

# 验证镜像源配置
./scripts/docker-tools.sh verify
```

### 📊 可用镜像源（2024年更新）

根据 [`config/registry-mirrors.conf`](config/registry-mirrors.conf:6) 配置的可用镜像源：

- **1Panel社区镜像源**：`docker.1panel.live`
- **DaoCloud镜像源**：`docker.m.daocloud.io`
- **南京大学镜像源**：`docker.nju.edu.cn`

### 🚨 常见网络错误解决

如果遇到以下错误：
```
ERROR: failed to solve: alpine:3.18: failed to resolve source metadata
```

请执行：
```bash
# 1. 测试网络连通性
./scripts/docker-tools.sh test

# 2. 一键修复所有Docker问题
./scripts/docker-tools.sh fix

# 3. 如果仍有问题，手动更新配置
./scripts/docker-tools.sh configure
```

### 生成客户端配置

```bash
# 生成默认客户端配置
./scripts/generate-client-config.sh

# 生成Android配置
./scripts/generate-client-config.sh --client mobile1 --android

# 生成所有客户端配置
./scripts/generate-client-config.sh --multiple --output ./clients
```

## 📋 核心组件

### 部署脚本 (`scripts/deploy.sh`)
- ✅ 系统依赖检查
- ✅ 环境配置验证
- ✅ 证书自动生成
- ✅ Docker镜像构建
- ✅ 服务启动和验证
- ✅ 部署后信息展示

### 管理脚本 (`scripts/manage.sh`)
- ✅ 服务生命周期管理
- ✅ 日志查看和分析
- ✅ 配置备份和恢复
- ✅ 客户端证书管理
- ✅ 系统清理和更新

### 健康检查 (`scripts/health-check.sh`)
- ✅ Docker服务状态检查
- ✅ 网络连通性验证
- ✅ 证书有效期监控
- ✅ 系统资源监控
- ✅ 安全配置检查
- ✅ **macOS完全兼容** - 已完全适配macOS Sequoia和Apple Silicon
- ✅ **高性能执行** - 26项检查在1秒内完成

### 客户端配置生成器 (`scripts/generate-client-config.sh`)
- ✅ 多平台配置生成
- ✅ 智能连接模式检测
- ✅ 内联和分离格式支持
- ✅ 二维码生成
- ✅ 配置验证

## 🏗️ 架构说明

### 部署架构图

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenVPN-FRP 架构                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │ standalone  │    │ frp-client  │    │  frp-full   │      │
│  │    模式     │    │    模式     │    │    模式     │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         │                   │                   │           │
│         │                   │                   │           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   OpenVPN   │    │   OpenVPN   │    │   OpenVPN   │      │
│  │    服务     │    │  + FRP-C    │    │ + FRP-S/C   │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         │                   │                   │           │
│         │                   │                   │           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │    直连     │    │   穿透连接   │    │   完整架构   │      │
│  │   (公网IP)  │    │   (内网)    │    │  (全控制)   │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### 网络拓扑

#### standalone 模式
```
客户端 ──→ 公网 ──→ OpenVPN服务器 (公网IP:1194)
```

#### frp-client 模式
```
客户端 ──→ 公网 ──→ FRP服务器 ──→ FRP客户端 ──→ OpenVPN服务器 (内网)
```

#### frp-full 模式
```
客户端 ──→ FRP服务器 ──→ FRP客户端 ──→ OpenVPN服务器
          (同一服务器/网络环境)
```

## 📁 项目结构

```
openvpn-frp/
├── 📁 config/                    # 配置文件目录
│   ├── server.conf               # OpenVPN服务器配置
│   ├── openssl.cnf              # SSL配置
│   ├── frps.ini                 # FRP服务端配置
│   └── frpc.ini                 # FRP客户端配置
├── 📁 docker/                    # Docker构建文件
│   ├── openvpn/                 # OpenVPN Docker配置
│   └── frp/                     # FRP Docker配置
├── 📁 docs/                      # 文档目录
│   ├── DEPLOYMENT-GUIDE.md      # 详细部署指南
│   ├── SECURITY-GUIDE.md        # 安全配置指南
│   ├── SCRIPTS-REFERENCE.md     # 脚本参考手册
│   ├── FAQ.md                   # 常见问题解答
│   ├── README_ZH.md             # 中文详细文档
│   ├── README_EN.md             # 英文详细文档
│   └── FRP-DEPLOYMENT.md        # FRP部署文档
├── 📁 pki/                       # 证书目录 (运行时生成)
├── 📁 scripts/                   # 脚本目录
│   ├── 🚀 deploy.sh             # 一键部署脚本
│   ├── ⚙️ manage.sh              # 服务管理脚本
│   ├── 🏥 health-check.sh       # 健康检查脚本
│   ├── 📱 generate-client-config.sh # 客户端配置生成
│   ├── 🔐 generate-certs.sh     # 证书生成脚本
│   ├── ✅ verify-certs.sh       # 证书验证脚本
│   ├── 🐳 build-openvpn.sh      # OpenVPN构建脚本
│   ├── 🐳 build-frp.sh          # FRP构建脚本
│   ├── 🔧 docker-tools.sh       # Docker工具集（镜像源测试等）
│   └── 🍎 macos-fix.sh          # macOS环境修复脚本
├── .env.example                  # 环境配置模板
├── docker-compose.yml           # 主要编排文件
├── docker-compose.frp.yml       # FRP专用编排文件
├── CHANGELOG.md                  # 变更日志
├── LICENSE                       # 开源许可证
├── CONTRIBUTING.md               # 贡献指南
└── README.md                     # 项目说明（本文件）
```

## 🛠️ 使用指南

### 服务管理

```bash
# 查看服务状态
./scripts/manage.sh status

# 启动所有服务
./scripts/manage.sh start

# 停止所有服务
./scripts/manage.sh stop

# 重启服务
./scripts/manage.sh restart

# 查看实时日志
./scripts/manage.sh logs --follow

# 查看特定服务日志
./scripts/manage.sh logs openvpn --tail 100
```

### 健康监控

健康检查脚本 [`scripts/health-check.sh`](scripts/health-check.sh:1) 提供全面的系统监控：

```bash
# 基本健康检查（完全兼容macOS和Linux）
./scripts/health-check.sh

# JSON格式输出
./scripts/health-check.sh --format json --output health.json

# 连续监控（每30秒检查一次）
./scripts/health-check.sh --continuous --interval 30

# 只检查证书状态
./scripts/health-check.sh --check certificates

# Nagios兼容输出（用于监控集成）
./scripts/health-check.sh --nagios
```

#### 跨平台兼容性

健康检查脚本已完全兼容不同操作系统：

- **macOS支持**: 完全适配macOS Sequoia和Apple Silicon
- **系统检测**: 自动识别macOS/Linux，使用对应的系统命令
- **端口检测**: 适配macOS的lsof命令格式差异
- **内存监控**: 使用vm_stat替代Linux的free命令
- **证书解析**: 支持macOS的date命令和GMT时间格式
- **性能优化**: 26项检查在1秒内完成，性能优异

### 客户端管理

```bash
# 列出所有客户端证书
./scripts/manage.sh client --list-clients

# 添加新客户端
./scripts/manage.sh client --add-client newuser

# 删除客户端
./scripts/manage.sh client --remove-client olduser

# 生成客户端配置
./scripts/generate-client-config.sh --client newuser --android

# 生成包含二维码的配置
./scripts/generate-client-config.sh --client mobile --qr-code

# 验证客户端配置
./scripts/generate-client-config.sh --verify
```

### 备份和恢复

```bash
# 创建完整备份
./scripts/manage.sh backup --include-logs

# 恢复备份
./scripts/manage.sh restore --backup-dir /path/to/backup

# 验证配置文件
./scripts/manage.sh config

# 清理未使用的Docker资源
./scripts/manage.sh clean
```

## 📚 完整文档

### 📖 用户文档
- [📋 详细部署指南](docs/DEPLOYMENT-GUIDE.md) - 完整的部署和配置指南
- [🍎 macOS部署指南](docs/MACOS-DEPLOYMENT.md) - macOS环境专用部署说明
- [� 故障排除指南](docs/TROUBLESHOOTING.md) - 服务状态检查和连接测试
- [� 安全配置指南](docs/SECURITY-GUIDE.md) - 企业级安全配置和最佳实践
- [❓ 常见问题解答](docs/FAQ.md) - 故障排除和性能优化
- [🌐 FRP部署文档](docs/FRP-DEPLOYMENT.md) - FRP专门的部署说明

### 🛠️ 开发文档
- [📖 脚本参考手册](docs/SCRIPTS-REFERENCE.md) - 所有脚本的详细参数说明
- [🤝 贡献指南](CONTRIBUTING.md) - 如何参与项目开发
- [📝 变更日志](CHANGELOG.md) - 版本历史和更新记录

### 🌍 多语言文档
- [🇨🇳 完整中文文档](docs/README_ZH.md) - 专为中国用户优化的详细说明
- [🇺🇸 English Documentation](docs/README_EN.md) - Complete English guide

## 🔧 高级配置

### 环境变量配置

```bash
# 部署模式
DEPLOY_MODE=standalone                    # standalone|frp-client|frp-full

# FRP配置
FRP_SERVER_ADDR=your.server.com          # FRP服务器地址
FRP_TOKEN=your_secure_token_here          # 安全令牌
FRP_DASHBOARD_PWD=secure_password         # 管理后台密码

# OpenVPN网络配置
OPENVPN_EXTERNAL_HOST=your.domain.com     # 客户端连接地址
OPENVPN_PORT=1194                         # OpenVPN端口
OPENVPN_PROTOCOL=udp                      # 协议类型
OPENVPN_NETWORK=10.8.0.0                 # VPN网段

# 安全配置
CA_EXPIRE_DAYS=3650                       # CA证书有效期
CLIENT_EXPIRE_DAYS=365                    # 客户端证书有效期
KEY_SIZE=2048                             # RSA密钥长度

# 性能配置
MAX_CLIENTS=100                           # 最大客户端数
CLIENT_TIMEOUT=120                        # 客户端超时
ENABLE_COMPRESSION=true                   # 启用压缩
```

### Docker Compose Profiles

根据 [`docker-compose.yml`](docker-compose.yml:82) 的profiles配置：

```bash
# FRP客户端模式（内网穿透）
docker-compose --profile frp-client up -d

# 完整FRP架构（服务端+客户端）
docker-compose --profile frp-full up -d

# 监控服务（可选）
docker-compose --profile monitoring up -d

# 组合多个profile
docker-compose --profile frp-full --profile monitoring up -d
```

#### 可用的Profiles：
- **frp-client**: 启动OpenVPN + FRP客户端
- **frp-full**: 启动OpenVPN + FRP服务端 + FRP客户端
- **monitoring**: 启动监控服务

## 🔍 故障排除

### 常见问题解决

#### 1. 部署失败
```bash
# 检查系统依赖
./scripts/deploy.sh --skip-deps

# 查看详细错误信息
./scripts/deploy.sh --debug

# 演练模式查看将执行的操作
./scripts/deploy.sh --dry-run
```

#### 2. macOS TUN设备问题
```bash
# 检查macOS环境
./scripts/macos-fix.sh --check-only

# 使用Docker模式修复（推荐）
./scripts/macos-fix.sh --docker-mode

# 安装TunTap驱动
./scripts/macos-fix.sh --install-tuntap

# 跳过TUN设备检查直接部署
./scripts/deploy.sh --skip-deps --mode standalone
```

#### 3. 客户端无法连接
```bash
# 检查服务状态
./scripts/health-check.sh

# 验证证书
./scripts/manage.sh cert --verify-certs

# 重新生成客户端配置
./scripts/generate-client-config.sh --client problematic_client
```

#### 4. FRP连接问题
```bash
# 检查FRP日志
./scripts/manage.sh logs frpc
./scripts/manage.sh logs frps

# 验证网络连通性
ping $FRP_SERVER_ADDR
telnet $FRP_SERVER_ADDR 7000
```

### 日志分析

```bash
# 查看所有服务日志
./scripts/manage.sh logs

# 查看最近100行OpenVPN日志
./scripts/manage.sh logs openvpn --tail 100

# 实时跟踪FRP客户端日志
./scripts/manage.sh logs frpc --follow

# 查看指定时间后的日志
./scripts/manage.sh logs --since 2024-01-01T10:00:00
```

## 📈 监控集成

### Prometheus监控

```bash
# 生成Prometheus格式的指标
./scripts/health-check.sh --format prometheus

# 设置定时任务
echo "*/5 * * * * /path/to/openvpn-frp/scripts/health-check.sh --format prometheus > /var/lib/prometheus/openvpn-frp.prom" | crontab -
```

### Nagios集成

```bash
# Nagios检查命令
define command{
    command_name    check_openvpn_frp
    command_line    /path/to/openvpn-frp/scripts/health-check.sh --nagios
}
```

### 日志转发

```bash
# 配置rsyslog转发OpenVPN日志
echo "local0.*    @@your-log-server:514" >> /etc/rsyslog.conf
systemctl restart rsyslog
```

## 🔒 安全建议

### 基础安全
- ✅ 更改所有默认密码
- ✅ 使用强加密算法和密钥长度
- ✅ 定期更新证书
- ✅ 配置适当的防火墙规则
- ✅ 限制管理接口访问

### 高级安全
- ✅ 启用双因子认证
- ✅ 配置入侵检测系统
- ✅ 实施网络分段
- ✅ 定期安全审计
- ✅ 建立日志监控和告警

### 网络安全
```bash
# 配置防火墙规则示例
sudo ufw allow 1194/udp              # OpenVPN
sudo ufw allow 7000/tcp              # FRP控制端口
sudo ufw allow from trusted_ip to any port 7500  # FRP管理后台
```

## 🚀 性能优化

### 系统优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# 优化网络参数
echo "net.core.rmem_max = 134217728" >> /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 134217728" >> /etc/sysctl.conf
sysctl -p
```

### OpenVPN优化
```bash
# 在.env文件中配置
ENABLE_COMPRESSION=true               # 启用压缩
MAX_CLIENTS=500                       # 增加客户端限制
CLIENT_TIMEOUT=300                    # 调整超时时间
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目！

### 开发环境设置
```bash
git clone https://github.com/your-org/openvpn-frp.git
cd openvpn-frp
cp .env.example .env
# 编辑 .env 文件
./scripts/deploy.sh --mode standalone --debug
```

### 代码规范
- Shell脚本遵循 [ShellCheck](https://www.shellcheck.net/) 规范
- 配置文件使用适当的注释
- 文档使用Markdown格式

详细贡献指南请查看 [CONTRIBUTING.md](CONTRIBUTING.md)

## 📄 许可证

本项目采用 MIT 许可证。详见 [LICENSE](LICENSE) 文件。

## 🆘 支持

如果遇到问题：

1. 查看 [常见问题解答](docs/FAQ.md)
2. 检查现有的 [Issues](../../issues)
3. 创建新的 [Issue](../../issues/new) 并提供详细信息
4. 查看 [详细部署指南](docs/DEPLOYMENT-GUIDE.md)
5. 阅读 [完整中文文档](docs/README_ZH.md)

## 📊 项目状态

- ✅ 核心功能完成
- ✅ Docker化部署
- ✅ 自动化脚本
- ✅ 健康检查
- ✅ 客户端配置生成
- ✅ 多平台支持
- ✅ 完整文档系统
- ✅ 多语言支持
- ✅ 安全配置指南
- ✅ 故障排除手册

## 🎯 适用场景

- 🏠 **家庭用户**：内网穿透，远程访问家里设备
- 🏢 **企业用户**：员工远程办公，分支机构互联
- 👨‍💻 **开发者**：测试环境访问，开发调试
- 🔧 **运维人员**：服务器管理，网络监控

---

**OpenVPN-FRP** - 让VPN部署变得简单可靠！🚀

### 📞 获取更多帮助

- 📚 [完整中文文档](docs/README_ZH.md) - 专为中国用户优化
- 📚 [English Documentation](docs/README_EN.md) - Complete English guide  
- 📁 [所有文档](docs/) - 包含详细的部署、安全、脚本参考等文档
- 🤝 [贡献指南](CONTRIBUTING.md) - 如何参与项目开发
- 📝 [变更日志](CHANGELOG.md) - 版本历史和更新记录