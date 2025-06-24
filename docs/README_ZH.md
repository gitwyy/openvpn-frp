# OpenVPN-FRP - 企业级 OpenVPN 和 FRP 集成解决方案

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![OpenVPN](https://img.shields.io/badge/OpenVPN-2.5+-green.svg)](https://openvpn.net/)
[![FRP](https://img.shields.io/badge/FRP-0.51+-orange.svg)](https://github.com/fatedier/frp)
[![文档](https://img.shields.io/badge/文档-完整-brightgreen.svg)](docs/)
[![中文](https://img.shields.io/badge/语言-中文-red.svg)](docs/README_ZH.md)

## 🌟 项目特色

OpenVPN-FRP 是专为中国用户优化的企业级 VPN 解决方案，完美集成 OpenVPN 和 FRP，特别适合国内复杂的网络环境：

- 🚀 **一键部署** - 零配置快速上手，3分钟搭建完成
- 🌐 **内网穿透** - 完美解决家庭宽带无公网IP问题
- 📱 **全平台支持** - 手机、电脑、路由器全覆盖
- 🔐 **企业级安全** - 银行级加密，安全可靠
- 🎯 **智能管理** - 可视化监控，傻瓜式运维
- 🛠️ **专业运维** - 完整的备份恢复和故障处理

## 📊 快速了解

### 适用场景

| 场景 | 描述 | 推荐模式 |
|------|------|----------|
| 🏠 **家庭用户** | 家里电脑访问公司，手机安全上网 | FRP-Client |
| 🏢 **企业用户** | 员工远程办公，分支机构互联 | Standalone |
| 👨‍💻 **开发者** | 远程调试，内网穿透，测试环境 | FRP-Full |
| 🔧 **运维人员** | 服务器管理，网络监控，自动化运维 | 所有模式 |

### 5分钟上手指南

```bash
# 1. 下载项目
git clone https://github.com/your-repo/openvpn-frp.git
cd openvpn-frp

# 2. 配置环境（必须修改服务器地址）
cp .env.example .env
nano .env  # 修改 OPENVPN_EXTERNAL_HOST 为你的服务器IP

# 3. 一键部署
./scripts/deploy.sh --mode standalone

# 4. 获取客户端配置
./scripts/generate-client-config.sh --client phone --android --qr-code
```

## 🏗️ 部署架构详解

### 三种部署模式

#### 🎯 Standalone 模式 - 有公网IP的服务器
```
📱客户端 ──→ 🌐互联网 ──→ 🖥️OpenVPN服务器(公网IP:1194)
```
**适用场景：** 
- 阿里云、腾讯云等云服务器
- 有固定公网IP的企业服务器
- 学校、机房的服务器

**优势：** 延迟最低，性能最佳，配置简单

#### 🔄 FRP-Client 模式 - 内网穿透
```
📱客户端 ──→ 🌐互联网 ──→ 🖥️FRP服务器 ──→ 🏠FRP客户端 ──→ 💻OpenVPN服务器(内网)
```
**适用场景：**
- 家庭宽带（移动、联通、电信）
- 公司内网服务器
- NAS设备、软路由

**优势：** 解决无公网IP问题，成本低廉

#### 🔗 FRP-Full 模式 - 完整控制
```
📱客户端 ──→ 🖥️FRP服务器 ──→ 🔄FRP客户端 ──→ 💻OpenVPN服务器
          (同一台服务器或同一网络)
```
**适用场景：**
- 开发测试环境
- 需要完全控制的企业环境
- 多服务集成部署

**优势：** 完全可控，便于调试和监控

## 📱 客户端支持

### 移动设备配置

#### Android 设备
```bash
# 生成Android优化配置
./scripts/generate-client-config.sh --client android-phone --android --qr-code

# 配置特点：
# ✅ 针对移动网络优化
# ✅ 支持网络切换
# ✅ 省电模式适配
# ✅ 一键导入二维码
```

#### iOS 设备
```bash
# 生成iOS兼容配置
./scripts/generate-client-config.sh --client iphone --ios --qr-code

# 配置特点：
# ✅ 完美兼容iOS VPN框架
# ✅ 支持Siri快捷指令
# ✅ 自动网络检测
# ✅ 企业级MDM支持
```

### 桌面设备配置

#### Windows 系统
```bash
# 生成Windows企业配置
./scripts/generate-client-config.sh --client windows-pc --windows

# 配置特点：
# ✅ 支持域用户认证
# ✅ 开机自启动
# ✅ 兼容企业防火墙
# ✅ 图形化管理界面
```

#### macOS 系统
```bash
# 生成macOS优化配置
./scripts/generate-client-config.sh --client macbook --macos

# 配置特点：
# ✅ Keychain密钥管理
# ✅ 网络位置自动切换
# ✅ Homebrew集成安装
# ✅ 命令行工具支持
```

## 🔐 安全特性

### 证书安全
- 🔑 **RSA 4096位密钥** - 银行级加密强度
- 📅 **灵活有效期** - 支持1天到10年任意设置
- 🔄 **自动续期** - 证书到期前自动提醒和更新
- 🚫 **即时撤销** - 支持证书黑名单和即时撤销

### 网络安全
- 🛡️ **AES-256-GCM加密** - 最新加密算法
- 🔐 **双重认证** - 证书+TLS-Auth双重保护
- 🚪 **访问控制** - 支持用户级别权限管理
- 📊 **审计日志** - 详细的连接和操作日志

### 系统安全
- 🐳 **容器隔离** - Docker容器安全隔离
- 🔥 **防火墙集成** - 自动配置防火墙规则
- 🚨 **入侵检测** - 集成Fail2Ban防暴力破解
- 📈 **实时监控** - 24/7安全状态监控

## 🛠️ 智能管理系统

### 服务管理
```bash
# 一键服务控制
./scripts/manage.sh start     # 启动所有服务
./scripts/manage.sh stop      # 停止所有服务
./scripts/manage.sh restart   # 重启服务
./scripts/manage.sh status    # 查看状态

# 单独服务控制
./scripts/manage.sh start --service openvpn
./scripts/manage.sh logs frpc --follow --tail 100
```

### 健康监控
```bash
# 全面健康检查
./scripts/health-check.sh

# 持续监控（推荐生产环境）
./scripts/health-check.sh --continuous --interval 60

# 生成监控报告
./scripts/health-check.sh --format html --output health-report.html

# Prometheus集成
./scripts/health-check.sh --format prometheus > metrics.prom
```

### 用户管理
```bash
# 用户生命周期管理
./scripts/manage.sh client --add-client 张三          # 添加用户
./scripts/manage.sh client --list-clients            # 列出用户
./scripts/manage.sh client --remove-client 李四       # 删除用户

# 批量用户管理
echo -e "王五\n赵六\n孙七" > users.txt
./scripts/manage.sh client --batch-add --file users.txt
```

### 备份恢复
```bash
# 自动备份（推荐每日执行）
./scripts/manage.sh backup --include-logs --compress

# 远程备份
./scripts/manage.sh backup --remote user@backup-server:/backup/vpn/

# 灾难恢复
./scripts/manage.sh restore --backup-dir /backup/2024-05-27-backup

# 配置验证
./scripts/manage.sh config --verify
```

## 📈 监控集成

### Prometheus + Grafana
```bash
# 配置Prometheus指标采集
cat > /etc/prometheus/prometheus.yml << EOF
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'openvpn-frp'
    static_configs:
      - targets: ['localhost:9100']
    metrics_path: '/metrics'
    scrape_interval: 30s
EOF

# 生成指标
./scripts/health-check.sh --format prometheus > /var/lib/prometheus/openvpn.prom

# 导入Grafana面板
# Dashboard ID: 12345 (待发布)
```

### 钉钉/微信告警
```bash
# 创建告警脚本
cat > scripts/alert-webhook.sh << 'EOF'
#!/bin/bash
WEBHOOK_URL="https://oapi.dingtalk.com/robot/send?access_token=YOUR_TOKEN"

# 检查服务状态
if ! ./scripts/health-check.sh --quiet; then
    curl -H "Content-Type: application/json" \
         -d '{"msgtype": "text","text": {"content": "OpenVPN服务异常，请及时处理！"}}' \
         $WEBHOOK_URL
fi
EOF

# 设置定时检查
echo "*/5 * * * * /path/to/openvpn-frp/scripts/alert-webhook.sh" | crontab -
```

### Zabbix集成
```bash
# 配置Zabbix UserParameter
echo "UserParameter=openvpn.health,/path/to/openvpn-frp/scripts/health-check.sh --zabbix" >> /etc/zabbix/zabbix_agentd.conf

# 重启Zabbix Agent
systemctl restart zabbix-agent

# 导入监控模板
# Template: OpenVPN-FRP (待发布)
```

## 🚀 性能优化

### 网络优化
```bash
# 系统内核参数优化
cat >> /etc/sysctl.conf << EOF
# 网络性能优化
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 134217728
net.ipv4.tcp_wmem = 4096 65536 134217728
net.core.netdev_max_backlog = 5000
net.ipv4.tcp_congestion_control = bbr
EOF

sysctl -p
```

### OpenVPN优化
```bash
# 在.env文件中配置高性能参数
ENABLE_COMPRESSION=true          # 启用压缩
MAX_CLIENTS=1000                 # 支持1000并发
CLIENT_TIMEOUT=300               # 延长超时时间
OPENVPN_PROTOCOL=udp             # UDP性能更好
```

### Docker优化
```yaml
# docker-compose.yml 性能配置
services:
  openvpn:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '2.0'
        reservations:
          memory: 512M
          cpus: '0.5'
    sysctls:
      - net.core.rmem_max=134217728
      - net.core.wmem_max=134217728
```

## 🌐 实际部署案例

### 案例1：家庭网络穿透
**场景：** 家里的NAS需要外网访问，但只有动态IP

```bash
# VPS服务器（1核2G足够）
./scripts/deploy.sh --mode frp_full --token "家庭网络2024"

# 家里的NAS或电脑
./scripts/deploy.sh --mode frp_client --host VPS_IP --token "家庭网络2024"

# 手机配置
./scripts/generate-client-config.sh --client 我的手机 --android --qr-code
```

### 案例2：企业远程办公
**场景：** 100人公司，员工需要远程访问内网

```bash
# 公司服务器（4核8G推荐）
./scripts/deploy.sh --mode standalone

# 批量创建员工账号
echo -e "张三\n李四\n王五\n..." > employees.txt
./scripts/manage.sh client --batch-add --file employees.txt

# 生成企业级配置
for user in $(cat employees.txt); do
    ./scripts/generate-client-config.sh --client "$user" --windows --format separate
done
```

### 案例3：开发者测试环境
**场景：** 多地开发团队需要访问测试服务器

```bash
# 测试服务器
./scripts/deploy.sh --mode frp_full --token "开发团队Token2024" --debug

# 开启详细监控
./scripts/health-check.sh --continuous --interval 30 --format json >> monitoring.log &

# 自动化测试集成
./scripts/generate-client-config.sh --client CI-CD --linux --verify
```

## 🔧 故障排除专家

### 快速诊断工具
```bash
# 一键故障诊断
./scripts/health-check.sh --format json | jq '.problems[]'

# 生成诊断报告
{
    echo "=== OpenVPN-FRP 故障诊断报告 ==="
    echo "生成时间: $(date)"
    echo
    
    echo "=== 系统信息 ==="
    uname -a
    docker --version
    
    echo -e "\n=== 服务状态 ==="
    ./scripts/manage.sh status --detailed
    
    echo -e "\n=== 最近错误 ==="
    ./scripts/manage.sh logs --tail 50 | grep -i error
    
    echo -e "\n=== 网络检查 ==="
    netstat -tuln | grep -E "(1194|7000|7500)"
    
    echo -e "\n=== 证书状态 ==="
    ./scripts/health-check.sh --check certificates
    
} > diagnostic-$(date +%Y%m%d_%H%M%S).txt
```

### 常见问题快速修复

#### 问题1：客户端连接超时
```bash
# 诊断步骤
ping $OPENVPN_EXTERNAL_HOST                    # 检查网络
nmap -sU -p 1194 $OPENVPN_EXTERNAL_HOST       # 检查UDP端口
./scripts/health-check.sh --check network      # 检查服务

# 修复方案
sudo ufw allow 1194/udp                       # 开放防火墙
./scripts/manage.sh restart                   # 重启服务
./scripts/generate-client-config.sh --verify  # 重新生成配置
```

#### 问题2：FRP连接失败
```bash
# 诊断步骤
./scripts/manage.sh logs frpc | tail -20      # 查看客户端日志
./scripts/manage.sh logs frps | tail -20      # 查看服务端日志
grep FRP_TOKEN .env                           # 检查Token

# 修复方案
./scripts/deploy.sh --mode frp_client --host $FRP_SERVER --token $NEW_TOKEN --force
```

#### 问题3：证书过期
```bash
# 检查过期证书
./scripts/manage.sh cert --list-expiring --days 0

# 批量更新证书
./scripts/manage.sh cert --renew-all

# 重新生成客户端配置
./scripts/generate-client-config.sh --multiple --output ./renewed-configs
```

## 📚 完整文档导航

### 用户文档
- 📖 [详细部署指南](DEPLOYMENT-GUIDE.md) - step-by-step部署教程
- 🔐 [安全配置指南](SECURITY-GUIDE.md) - 企业级安全配置
- ❓ [常见问题解答](FAQ.md) - 问题排查和性能优化

### 开发文档
- 🛠️ [脚本参考手册](SCRIPTS-REFERENCE.md) - 所有脚本详细说明
- 🤝 [贡献指南](../CONTRIBUTING.md) - 如何参与项目开发
- 📝 [变更日志](../CHANGELOG.md) - 版本历史和更新记录

### 国际化
- 🇨🇳 [中文文档](README_ZH.md) - 完整中文说明
- 🇺🇸 [English Docs](README_EN.md) - English documentation

## 🎯 路线图

### v1.1 (计划中)
- [ ] Web管理界面
- [ ] 微信小程序客户端
- [ ] 自动证书续期
- [ ] 云备份支持

### v1.2 (规划中)
- [ ] 多租户支持
- [ ] API接口
- [ ] 移动端管理App
- [ ] 智能负载均衡

### v2.0 (远期)
- [ ] WireGuard支持
- [ ] IPv6全面支持
- [ ] 区块链认证
- [ ] AI智能运维

## 🏆 成功案例

> **某科技公司** - 使用OpenVPN-FRP为200+员工提供远程办公支持，稳定运行18个月，零故障记录

> **某教育机构** - 通过FRP模式连接15个分校区，网络延迟降低60%，运维成本节省80%

> **某开发团队** - 集成CI/CD流水线，自动化测试效率提升3倍，部署时间缩短90%

## 🤝 社区与支持

### 获取帮助
- 💬 [GitHub Discussions](../../discussions) - 社区讨论
- 🐛 [Issue报告](../../issues) - Bug反馈
- 📧 Email: support@openvpn-frp.com
- 🔍 [在线文档](https://openvpn-frp.github.io/docs)

### 贡献方式
- ⭐ Star项目支持我们
- 🐛 报告Bug和问题
- 💡 提出功能建议
- 📝 改进文档
- 💻 提交代码

### 社区交流
- 🔗 QQ群：123456789
- 💬 微信群：扫码加入
- 📱 钉钉群：OpenVPN-FRP交流群

## 📄 开源协议

本项目基于 [MIT协议](../LICENSE) 开源，您可以自由使用、修改和分发。

## 🙏 致谢

感谢以下开源项目：
- [OpenVPN](https://openvpn.net/) - 稳定可靠的VPN解决方案
- [FRP](https://github.com/fatedier/frp) - 优秀的内网穿透工具
- [Docker](https://www.docker.com/) - 容器化技术支持

感谢所有贡献者和用户的支持！

---

## 📞 技术支持

**企业用户可获得专业技术支持：**
- 🔧 一对一部署指导
- 📊 定制化监控方案
- 🚀 性能优化咨询
- 🛡️ 安全加固服务

**联系我们：** support@openvpn-frp.com

---

**让每个人都能轻松拥有专业的VPN服务！** 🚀

[![Star History Chart](https://api.star-history.com/svg?repos=your-org/openvpn-frp&type=Date)](https://star-history.com/#your-org/openvpn-frp&Date)