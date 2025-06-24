# OpenVPN-FRP 完整部署指南

## 概述

OpenVPN-FRP 是一个完整的 OpenVPN 和 FRP 集成解决方案，提供一键部署功能，支持多种部署场景。

## 部署架构

### 支持的部署模式

1. **standalone 模式** - 纯 OpenVPN 服务
   - 适用于有公网 IP 的服务器
   - 客户端直接连接 OpenVPN 服务

2. **frp-client 模式** - OpenVPN + FRP 客户端
   - 适用于内网服务器
   - 通过 FRP 进行端口穿透

3. **frp-full 模式** - 完整 FRP 架构
   - 包含 FRP 服务端和客户端
   - 适用于完全控制的环境

## 快速开始

### 1. 环境准备

#### 系统要求
- 操作系统：Linux、macOS 或 Windows (WSL)
- Docker 和 Docker Compose
- OpenSSL
- 网络工具 (netcat)

#### macOS 环境安装
```bash
# 安装 Docker Desktop
# https://www.docker.com/products/docker-desktop

# 安装依赖工具
brew install openssl netcat

# 验证安装
docker --version
docker-compose --version
```

#### Linux 环境安装
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install docker.io docker-compose openssl netcat

# CentOS/RHEL
sudo yum install docker docker-compose openssl nc

# 启动 Docker
sudo systemctl start docker
sudo systemctl enable docker

# 将用户添加到 docker 组
sudo usermod -aG docker $USER
```

### 2. 项目配置

#### 下载项目
```bash
git clone <repository-url>
cd openvpn-frp
```

#### 配置环境变量
```bash
# 复制环境配置模板
cp .env.example .env

# 编辑配置文件
nano .env

# 参考配置说明: .env.example 包含详细的配置注释
```

#### 重要配置项
```bash
# 部署模式
DEPLOY_MODE=standalone  # standalone|frp_client|frp_full

# FRP 配置（frp_client 和 frp_full 模式需要）
FRP_SERVER_ADDR=YOUR_SERVER_IP
FRP_TOKEN=your_secure_token

# OpenVPN 配置
OPENVPN_EXTERNAL_HOST=YOUR_PUBLIC_IP
OPENVPN_PORT=1194

# 安全配置
FRP_DASHBOARD_PWD=your_secure_password
```

### 3. 一键部署

#### 基本部署（Standalone 模式）
```bash
./scripts/deploy.sh --mode standalone
```

#### FRP 客户端模式
```bash
./scripts/deploy.sh --mode frp_client --host 1.2.3.4 --token your_token
```

#### 完整 FRP 架构
```bash
./scripts/deploy.sh --mode frp_full --token your_token
```

#### 部署选项
```bash
# 调试模式部署
./scripts/deploy.sh --mode standalone --debug

# 演练模式（查看将执行的操作）
./scripts/deploy.sh --mode frp_client --host 1.2.3.4 --dry-run

# 跳过某些步骤
./scripts/deploy.sh --mode standalone --skip-certs --skip-build

# 强制重新部署
./scripts/deploy.sh --mode standalone --force
```

## 详细配置

### 环境变量详解

#### 部署模式配置
```bash
# 部署模式选择
DEPLOY_MODE=standalone              # 部署模式

# FRP 服务器配置
FRP_SERVER_ADDR=1.2.3.4            # FRP 服务器地址
FRP_SERVER_PORT=7000                # FRP 服务器端口
FRP_TOKEN=your_secure_token         # 认证令牌

# FRP 管理后台
FRP_DASHBOARD_PORT=7500             # 管理后台端口
FRP_DASHBOARD_USER=admin            # 管理用户名
FRP_DASHBOARD_PWD=secure_password   # 管理密码
```

#### OpenVPN 网络配置
```bash
# 基本网络配置
OPENVPN_PORT=1194                   # OpenVPN 端口
OPENVPN_PROTOCOL=udp                # 协议类型
OPENVPN_NETWORK=10.8.0.0            # VPN 网段
OPENVPN_NETMASK=255.255.255.0       # 子网掩码

# 客户端连接地址
OPENVPN_EXTERNAL_HOST=1.2.3.4      # 外部连接地址

# DNS 配置
DNS_SERVER_1=8.8.8.8               # 主 DNS
DNS_SERVER_2=8.8.4.4               # 备用 DNS
```

#### 证书和安全配置
```bash
# 证书有效期
CA_EXPIRE_DAYS=3650                 # CA 证书有效期
SERVER_EXPIRE_DAYS=3650             # 服务器证书有效期
CLIENT_EXPIRE_DAYS=3650             # 客户端证书有效期

# 密钥长度
KEY_SIZE=2048                       # RSA 密钥长度
DH_KEY_SIZE=2048                    # DH 参数长度
```

### Docker Compose 配置

项目使用 Docker Compose 进行服务编排，支持多种 profile：

#### Profile 说明
- **默认**：只启动 OpenVPN 服务
- **frp-client**：启动 OpenVPN + FRP 客户端
- **frp-full**：启动完整的 FRP 架构
- **monitoring**：启动监控服务

#### 手动启动服务
```bash
# 启动默认服务
docker-compose up -d

# 启动 FRP 客户端模式
docker-compose --profile frp-client up -d

# 启动完整 FRP 架构
docker-compose --profile frp-full up -d

# 启动监控服务
docker-compose --profile monitoring up -d
```

## 服务管理

### 管理脚本使用

#### 服务控制
```bash
# 启动服务
./scripts/manage.sh start

# 停止服务
./scripts/manage.sh stop

# 重启服务
./scripts/manage.sh restart

# 查看状态
./scripts/manage.sh status

# 查看日志
./scripts/manage.sh logs --follow
```

#### 特定服务管理
```bash
# 管理特定服务
./scripts/manage.sh start --service openvpn
./scripts/manage.sh logs frpc --tail 100
./scripts/manage.sh restart --service frps
```

#### 配置和备份
```bash
# 验证配置
./scripts/manage.sh config

# 创建备份
./scripts/manage.sh backup --include-logs

# 恢复备份
./scripts/manage.sh restore --backup-dir ./backups/backup-20240527-143000

# 清理资源
./scripts/manage.sh clean
```

#### 客户端管理
```bash
# 列出客户端
./scripts/manage.sh client --list-clients

# 添加客户端
./scripts/manage.sh client --add-client user1

# 删除客户端
./scripts/manage.sh client --remove-client user1

# 显示客户端配置
./scripts/manage.sh client --show-config user1
```

#### 证书管理
```bash
# 列出证书
./scripts/manage.sh cert --list-certs

# 验证证书
./scripts/manage.sh cert --verify-certs

# 更新证书
./scripts/manage.sh cert --renew-cert server
```

### 健康检查

#### 基本健康检查
```bash
# 运行健康检查
./scripts/health-check.sh

# JSON 格式输出
./scripts/health-check.sh --format json --output health.json

# 连续监控模式
./scripts/health-check.sh --continuous --interval 30
```

#### 特定检查类别
```bash
# 只检查证书
./scripts/health-check.sh --check certificates

# 只检查网络
./scripts/health-check.sh --check network

# 跳过资源检查
./scripts/health-check.sh --skip resources
```

#### 监控集成
```bash
# Nagios 兼容输出
./scripts/health-check.sh --nagios

# Zabbix 兼容输出
./scripts/health-check.sh --zabbix

# Prometheus 格式
./scripts/health-check.sh --format prometheus
```

## 客户端配置

### 生成客户端配置

#### 基本用法
```bash
# 生成默认客户端配置
./scripts/generate-client-config.sh

# 指定客户端名称
./scripts/generate-client-config.sh --client user1

# 生成所有客户端配置
./scripts/generate-client-config.sh --multiple --output ./clients
```

#### 平台特定配置
```bash
# Android 配置
./scripts/generate-client-config.sh --client mobile1 --android

# iOS 配置
./scripts/generate-client-config.sh --client iphone1 --ios

# Windows 配置
./scripts/generate-client-config.sh --client pc1 --windows

# macOS 配置
./scripts/generate-client-config.sh --client mac1 --macos
```

#### 连接模式
```bash
# 直接连接模式
./scripts/generate-client-config.sh --mode direct --host 1.2.3.4

# FRP 穿透模式
./scripts/generate-client-config.sh --mode frp --host frp-server.com

# 自动检测模式（默认）
./scripts/generate-client-config.sh --mode auto
```

#### 输出格式
```bash
# 内联格式（推荐）
./scripts/generate-client-config.sh --format inline

# 分离格式
./scripts/generate-client-config.sh --format separate

# 生成二维码
./scripts/generate-client-config.sh --qr-code

# 打包输出
./scripts/generate-client-config.sh --zip
```

## 部署场景示例

### 场景 1：家庭网络穿透

#### 环境描述
- 家里有一台内网服务器（192.168.1.100）
- 有一台公网 VPS（1.2.3.4）
- 希望通过 VPS 访问家里的服务器

#### 部署步骤

1. **在 VPS 上部署 FRP 服务端**
```bash
# VPS 配置
DEPLOY_MODE=frp_full
FRP_TOKEN=my_secure_token_2024
OPENVPN_EXTERNAL_HOST=1.2.3.4

# 部署
./scripts/deploy.sh --mode frp_full --token my_secure_token_2024
```

2. **在家里服务器部署 OpenVPN + FRP 客户端**
```bash
# 家里服务器配置
DEPLOY_MODE=frp_client
FRP_SERVER_ADDR=1.2.3.4
FRP_TOKEN=my_secure_token_2024

# 部署
./scripts/deploy.sh --mode frp_client --host 1.2.3.4 --token my_secure_token_2024
```

3. **生成客户端配置**
```bash
# 生成手机配置
./scripts/generate-client-config.sh --client phone --android

# 生成电脑配置
./scripts/generate-client-config.sh --client laptop --windows
```

### 场景 2：公司网络访问

#### 环境描述
- 公司有公网 IP（5.6.7.8）
- 在公司内网部署 OpenVPN
- 员工远程访问公司网络

#### 部署步骤

1. **在公司服务器部署**
```bash
# 公司服务器配置
DEPLOY_MODE=standalone
OPENVPN_EXTERNAL_HOST=5.6.7.8
OPENVPN_PORT=1194

# 部署
./scripts/deploy.sh --mode standalone
```

2. **配置防火墙**
```bash
# 开放 OpenVPN 端口
sudo ufw allow 1194/udp
```

3. **生成员工配置**
```bash
# 为每个员工生成配置
./scripts/generate-client-config.sh --client employee1 --windows
./scripts/generate-client-config.sh --client employee2 --macos
./scripts/generate-client-config.sh --client employee3 --android
```

### 场景 3：多地点连接

#### 环境描述
- 主服务器在北京（有公网 IP）
- 分支机构在上海（内网）
- 分支机构在深圳（内网）

#### 部署步骤

1. **北京主服务器**
```bash
DEPLOY_MODE=frp_full
FRP_TOKEN=multi_site_token_2024
./scripts/deploy.sh --mode frp_full --token multi_site_token_2024
```

2. **上海分支机构**
```bash
DEPLOY_MODE=frp_client
FRP_SERVER_ADDR=beijing_server_ip
FRP_TOKEN=multi_site_token_2024
./scripts/deploy.sh --mode frp_client --host beijing_server_ip --token multi_site_token_2024
```

3. **深圳分支机构**
```bash
DEPLOY_MODE=frp_client
FRP_SERVER_ADDR=beijing_server_ip
FRP_TOKEN=multi_site_token_2024
./scripts/deploy.sh --mode frp_client --host beijing_server_ip --token multi_site_token_2024
```

## 故障排除

### 常见问题

#### 1. 服务启动失败

**症状**：Docker 容器无法启动

**排查步骤**：
```bash
# 查看容器状态
docker-compose ps

# 查看详细日志
docker-compose logs

# 检查配置文件
./scripts/manage.sh config

# 重新构建镜像
./scripts/manage.sh update
```

#### 2. 客户端无法连接

**症状**：OpenVPN 客户端连接超时

**排查步骤**：
```bash
# 检查服务状态
./scripts/health-check.sh

# 检查端口监听
netstat -tuln | grep 1194

# 检查防火墙
sudo ufw status

# 验证证书
./scripts/manage.sh cert --verify-certs
```

#### 3. FRP 连接问题

**症状**：FRP 客户端无法连接到服务端

**排查步骤**：
```bash
# 检查 FRP 服务端状态
docker logs frps

# 检查 FRP 客户端日志
docker logs frpc

# 验证 token 配置
grep FRP_TOKEN .env

# 检查网络连通性
ping $FRP_SERVER_ADDR
telnet $FRP_SERVER_ADDR 7000
```

#### 4. 证书问题

**症状**：证书验证失败

**解决方法**：
```bash
# 重新生成证书
rm -rf pki/
./scripts/generate-certs.sh

# 重新生成客户端配置
./scripts/generate-client-config.sh --client client1
```

### 日志分析

#### 重要日志位置
```bash
# OpenVPN 日志
docker logs openvpn

# FRP 服务端日志
docker logs frps

# FRP 客户端日志
docker logs frpc

# 系统日志
sudo journalctl -u docker
```

#### 常见错误信息

**OpenVPN 错误**：
- `VERIFY ERROR: could not verify peer cert signature` - 证书验证失败
- `TLS Error: TLS key negotiation failed` - TLS 握手失败
- `AUTH: Received control message: AUTH_FAILED` - 认证失败

**FRP 错误**：
- `authentication failed` - 认证失败，检查 token
- `connection refused` - 连接被拒绝，检查服务端
- `proxy name conflicts` - 代理名称冲突

### 性能调优

#### 系统优化
```bash
# 增加文件描述符限制
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# 优化网络参数
echo "net.core.rmem_max = 134217728" >> /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" >> /etc/sysctl.conf
sysctl -p
```

#### OpenVPN 优化
```bash
# 在 .env 文件中调整
MAX_CLIENTS=100                    # 最大客户端数
CLIENT_TIMEOUT=120                 # 客户端超时
ENABLE_COMPRESSION=true            # 启用压缩
LOG_LEVEL=3                        # 适当的日志级别
```

## 安全建议

### 基本安全
1. **更改默认密码**
   - 修改 FRP 管理后台密码
   - 使用强密码策略

2. **证书管理**
   - 定期更新证书
   - 妥善保管私钥
   - 及时撤销过期证书

3. **网络安全**
   - 配置防火墙规则
   - 限制管理端口访问
   - 使用 VPN 访问管理界面

### 高级安全
1. **多因子认证**
   - 集成 LDAP 认证
   - 使用客户端证书 + 密码

2. **网络隔离**
   - 使用 VLAN 隔离
   - 配置访问控制列表

3. **监控和审计**
   - 启用详细日志
   - 配置日志转发
   - 定期安全检查

## 维护和更新

### 定期维护
```bash
# 每周执行
./scripts/health-check.sh --format json --output weekly-health.json
./scripts/manage.sh backup --include-logs

# 每月执行
./scripts/manage.sh cert --verify-certs
./scripts/manage.sh clean

# 每季度执行
./scripts/manage.sh update
```

### 更新流程
```bash
# 1. 备份当前配置
./scripts/manage.sh backup --backup-dir ./backup-before-update

# 2. 停止服务
./scripts/manage.sh stop

# 3. 更新代码
git pull origin main

# 4. 更新镜像
./scripts/manage.sh update

# 5. 启动服务
./scripts/manage.sh start

# 6. 验证服务
./scripts/health-check.sh
```

## 支持和帮助

### 获取帮助
```bash
# 查看脚本帮助
./scripts/deploy.sh --help
./scripts/manage.sh --help
./scripts/health-check.sh --help
./scripts/generate-client-config.sh --help
```

### 社区支持
- 提交 Issue 报告问题
- 查看 Wiki 文档
- 参与社区讨论

### 技术支持
- 查看日志文件
- 使用调试模式
- 联系技术支持团队

---

## 附录

### A. 端口使用说明

| 服务 | 端口 | 协议 | Profile | 说明 |
|------|------|------|---------|------|
| OpenVPN | 1194 | UDP | 默认/frp-full | VPN 连接端口 |
| FRP Control | 7000 | TCP | frp-full | FRP 控制端口 |
| FRP Dashboard | 7500 | TCP | frp-full | FRP 管理后台 |
| OpenVPN Management | 7505 | TCP | 默认/frp-full | OpenVPN 管理接口(当ENABLE_MANAGEMENT=true时) |
| Web服务 | 8080 | TCP | frp-full | 额外的Web服务端口 |

**注意**:
- frp-client Profile 不会暴露任何端口到主机，仅用于内网穿透
- 端口映射通过环境变量可配置，上表为默认值

### B. 文件结构说明

```
openvpn-frp/
├── config/                 # 配置文件目录
├── docker/                 # Docker 构建文件
├── docs/                   # 文档目录
├── pki/                    # 证书目录
├── scripts/                # 脚本目录
├── .env.example            # 环境配置模板
├── docker-compose.yml      # Docker Compose 主配置文件
└── README.md              # 项目说明
```

### C. 常用命令速查

```bash
# 快速部署
./scripts/deploy.sh --mode standalone

# 查看状态
./scripts/manage.sh status

# 健康检查
./scripts/health-check.sh

# 生成客户端配置
./scripts/generate-client-config.sh --client user1

# 查看日志
./scripts/manage.sh logs --follow

# 备份配置
./scripts/manage.sh backup