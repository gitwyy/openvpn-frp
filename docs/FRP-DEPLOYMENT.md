# FRP内网穿透部署指南

本文档详细说明如何使用FRP实现OpenVPN服务的内网穿透功能。

## 架构概述

```
外网用户 --> 公网服务器(FRP服务端) --> 内网服务器(FRP客户端 + OpenVPN)
```

### 组件说明

- **FRP服务端 (frps)**: 部署在有公网IP的服务器上，作为流量转发中转站
- **FRP客户端 (frpc)**: 部署在OpenVPN所在的内网环境，负责建立反向连接
- **OpenVPN服务**: 实际的VPN服务，通过FRP暴露到公网

## 快速部署

### 1. 准备工作

确保你有：
- 一台有公网IP的服务器（用于部署FRP服务端）
- 一台内网服务器（用于部署OpenVPN和FRP客户端）
- Docker和Docker Compose环境

### 2. 配置FRP服务端

在**公网服务器**上：

```bash
# 1. 克隆项目
git clone <your-repo>
cd openvpn-frp

# 2. 修改FRP服务端配置
vim config/frps.ini
# 确认以下配置:
# - bind_port = 7000
# - dashboard_port = 7500
# - token = 你的安全密钥
#
# 参考: config/frps.ini 包含完整的配置示例

# 3. 构建FRP服务端镜像
./scripts/build-frp.sh --server-only

# 4. 启动FRP服务端
docker run -d \
  --name frps \
  --restart unless-stopped \
  -p 7000:7000 \
  -p 7500:7500 \
  -p 1194:1194/udp \
  -v $(pwd)/config/frps.ini:/opt/frp/conf/frps.ini:ro \
  -v $(pwd)/logs/frps:/opt/frp/logs \
  openvpn-frp/frps:latest
```

### 3. 配置FRP客户端

在**内网服务器**上：

```bash
# 1. 修改FRP客户端配置
vim config/frpc.ini
# 重要: 将 server_addr 改为你的公网服务器IP
# 确认 token 与服务端一致
#
# 参考: config/frpc.ini 包含完整的配置示例

# 2. 构建并启动完整服务
docker-compose --profile frp-client up -d
```

## 详细配置说明

### FRP服务端配置 (frps.ini)

```ini
[common]
bind_port = 7000                    # FRP控制端口
dashboard_port = 7500               # Web管理界面端口
dashboard_user = admin              # 管理界面用户名
dashboard_pwd = your_password       # 管理界面密码
token = your_secure_token           # 认证密钥
log_level = info                    # 日志级别
allow_ports = 7001-7010,1194,8080-8090  # 允许的端口范围
```

### FRP客户端配置 (frpc.ini)

```ini
[common]
server_addr = YOUR_PUBLIC_SERVER_IP  # 公网服务器IP
server_port = 7000                   # 服务端控制端口
token = your_secure_token            # 与服务端相同的密钥

[openvpn-udp]
type = udp                          # UDP协议
local_ip = openvpn                  # OpenVPN容器名
local_port = 1194                   # OpenVPN端口
remote_port = 1194                  # 映射到公网的端口
```

## 端口映射说明

| 服务 | 内网端口 | 公网端口 | 协议 | Profile | 说明 |
|------|----------|----------|------|---------|------|
| FRP控制 | 7000 | 7000 | TCP | frp-full | FRP服务端控制端口 |
| FRP管理 | 7500 | 7500 | TCP | frp-full | Web管理界面 |
| OpenVPN | 1194 | 1194 | UDP | 默认/frp-full | VPN连接端口 |
| OpenVPN管理 | 7505 | 7505 | TCP | 默认/frp-full | 管理接口(当ENABLE_MANAGEMENT=true时) |
| Web服务 | 8080 | 8080 | TCP | frp-full | 额外的Web服务端口 |

**注意**:
- 默认Profile只启动OpenVPN服务
- frp-client Profile启动OpenVPN + FRP客户端(无端口暴露)
- frp-full Profile启动完整FRP架构,包含所有端口映射

## 安全配置

### 1. 修改默认密码

```bash
# 修改 config/frps.ini 中的管理密码
dashboard_pwd = your_strong_password

# 修改认证Token
token = your_very_secure_token_2024
```

### 2. 防火墙配置

公网服务器防火墙规则：
```bash
# 允许FRP端口
ufw allow 7000/tcp
ufw allow 7500/tcp
ufw allow 1194/udp

# 可选：限制管理界面访问
ufw allow from YOUR_ADMIN_IP to any port 7500
```

### 3. SSL/TLS加密（可选）

在生产环境中，建议为FRP管理界面配置SSL证书。

## 故障排查

### 1. 检查服务状态

```bash
# 查看FRP服务端状态
docker logs frps

# 查看FRP客户端状态  
docker logs frpc

# 查看OpenVPN状态
docker logs openvpn
```

### 2. 网络连通性测试

```bash
# 测试FRP服务端连通性
telnet YOUR_PUBLIC_SERVER_IP 7000

# 测试OpenVPN端口
nc -u YOUR_PUBLIC_SERVER_IP 1194
```

### 3. 常见问题

**问题1**: FRP客户端连接失败
- 检查公网服务器IP配置是否正确
- 确认Token是否与服务端一致
- 检查网络防火墙设置

**问题2**: OpenVPN连接失败
- 确认OpenVPN服务正常运行
- 检查UDP端口转发是否正常
- 验证客户端配置文件

**问题3**: 管理界面无法访问
- 检查7500端口是否开放
- 确认用户名密码是否正确

## 管理和监控

### 1. 访问FRP管理界面

打开浏览器访问：`http://YOUR_PUBLIC_SERVER_IP:7500`
- 用户名：admin
- 密码：配置文件中设置的密码

### 2. 查看连接状态

在管理界面可以看到：
- 客户端连接状态
- 代理配置信息
- 流量统计
- 在线隧道列表

### 3. 日志监控

```bash
# 实时查看日志
docker logs -f frps
docker logs -f frpc

# 查看日志文件
tail -f logs/frps/frps.log
tail -f logs/frpc/frpc.log
```

## 性能优化

### 1. 网络优化

```ini
# 在frpc.ini中添加
pool_count = 5              # 连接池大小
tcp_mux = true             # 启用TCP多路复用
```

### 2. 压缩优化

```ini
# 启用压缩
use_compression = true
```

### 3. 加密优化

```ini
# 启用加密
use_encryption = true
```

## 备份和恢复

### 1. 配置备份

```bash
# 备份配置文件
tar -czf frp-config-backup.tar.gz config/frp*.ini

# 备份日志
tar -czf frp-logs-backup.tar.gz logs/frp*
```

### 2. 快速恢复

```bash
# 恢复配置
tar -xzf frp-config-backup.tar.gz

# 重启服务
docker-compose restart
```

## 升级说明

### 1. FRP版本升级

```bash
# 使用构建脚本升级到新版本
./scripts/build-frp.sh -v 0.54.0

# 重新部署
docker-compose --profile frp-client up -d
```

### 2. 配置兼容性

升级前请检查新版本的配置文件格式变化，必要时更新配置文件。

## 生产环境建议

1. **高可用性**: 部署多个FRP服务端实例
2. **负载均衡**: 使用nginx等负载均衡器
3. **监控告警**: 集成Prometheus+Grafana监控
4. **自动化**: 使用ansible等工具自动化部署
5. **安全加固**: 定期更新密码和证书

## 技术支持

如遇到问题，请：
1. 查看日志文件获取详细错误信息
2. 检查网络连通性和防火墙设置
3. 参考FRP官方文档：https://github.com/fatedier/frp
4. 提交Issue到项目仓库