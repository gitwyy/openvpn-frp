# OpenVPN-FRP 安全配置指南

## 概述

本指南提供OpenVPN-FRP项目的全面安全配置建议，包括PKI证书管理、OpenVPN安全配置、FRP安全设置以及网络安全最佳实践。

## 🔐 PKI证书管理最佳实践

### 证书架构设计

```
PKI架构层次：
├── CA根证书 (ca.crt/ca.key)
│   ├── 服务器证书 (server.crt/server.key)
│   └── 客户端证书 (client1.crt/client1.key, ...)
└── Diffie-Hellman参数 (dh2048.pem)
└── TLS-Auth密钥 (ta.key)
```

### 证书生成安全配置

#### 1. 强化密钥长度
```bash
# 在.env文件中配置
KEY_SIZE=4096              # RSA密钥长度（推荐4096位）
DH_KEY_SIZE=4096           # DH参数长度
```

#### 2. 合理设置证书有效期
```bash
# 证书有效期配置
CA_EXPIRE_DAYS=3650        # CA证书：10年
SERVER_EXPIRE_DAYS=1825    # 服务器证书：5年
CLIENT_EXPIRE_DAYS=365     # 客户端证书：1年（推荐短期）
```

#### 3. 安全的证书生成
```bash
# 生成带有强随机性的证书
export RANDFILE=/dev/urandom
./scripts/generate-certs.sh

# 验证证书强度
./scripts/verify-certs.sh --security-check
```

### 证书权限管理

#### 文件权限设置
```bash
# 设置正确的文件权限
chmod 600 pki/ca/private/ca.key           # CA私钥
chmod 600 pki/server/private/server.key   # 服务器私钥
chmod 600 pki/clients/private/*.key       # 客户端私钥
chmod 644 pki/ca/ca.crt                   # CA证书
chmod 644 pki/server/server.crt           # 服务器证书
chmod 644 pki/clients/*.crt               # 客户端证书
chmod 600 pki/ta.key                      # TLS-Auth密钥
```

#### 证书存储安全
```bash
# 创建安全的备份
tar -czf pki-backup-$(date +%Y%m%d).tar.gz pki/
gpg --symmetric --cipher-algo AES256 pki-backup-$(date +%Y%m%d).tar.gz

# 定期备份到安全位置
rsync -av --delete pki/ user@secure-server:/backup/pki/
```

### 证书生命周期管理

#### 1. 证书监控
```bash
# 添加到crontab，每日检查证书有效期
0 2 * * * /path/to/openvpn-frp/scripts/health-check.sh --check certificates --alert-days 30
```

#### 2. 证书更新流程
```bash
# 1. 检查即将过期的证书
./scripts/manage.sh cert --list-expiring --days 30

# 2. 更新服务器证书
./scripts/manage.sh cert --renew-cert server

# 3. 更新客户端证书
./scripts/manage.sh cert --renew-cert client1

# 4. 验证新证书
./scripts/verify-certs.sh
```

#### 3. 证书撤销管理
```bash
# 撤销泄露的客户端证书
./scripts/manage.sh cert --revoke-cert compromised_client

# 生成并部署CRL
./scripts/manage.sh cert --generate-crl
```

## 🛡️ OpenVPN安全配置

### 基础安全配置

#### 1. 强化server.conf配置
```bash
# 强化的OpenVPN服务器配置
cat >> config/server.conf << EOF

# 安全增强配置
auth SHA512                    # 使用SHA512认证
cipher AES-256-GCM            # 使用AES-256-GCM加密
data-ciphers AES-256-GCM:AES-128-GCM:AES-256-CBC
tls-version-min 1.2           # 最低TLS版本
tls-cipher TLS-DHE-RSA-WITH-AES-256-GCM-SHA384
ecdh-curve secp384r1          # 使用安全的椭圆曲线

# 认证增强
tls-auth ta.key 0             # TLS认证
remote-cert-tls client        # 验证客户端证书类型
verify-client-cert require    # 要求客户端证书

# 安全选项
user nobody                   # 降权运行
group nogroup
chroot /tmp/openvpn          # chroot监狱
persist-key
persist-tun

# 日志和监控
log-append /var/log/openvpn.log
status /var/log/openvpn-status.log 60
verb 3                        # 适当的日志级别
mute 20

# DDoS防护
connect-freq 1 10            # 连接频率限制
max-clients 100              # 最大客户端数限制
EOF
```

#### 2. 网络安全配置
```bash
# 在.env文件中配置
CLIENT_TO_CLIENT=false        # 禁用客户端间通信（默认）
DUPLICATE_CN=false           # 禁用重复CN（默认）

# 推送安全路由
push "redirect-gateway def1 bypass-dhcp"
push "dhcp-option DNS 1.1.1.1"
push "dhcp-option DNS 1.0.0.1"
```

### 访问控制和认证

#### 1. 客户端证书管理
```bash
# 为每个用户创建独立证书
./scripts/manage.sh client --add-client alice
./scripts/manage.sh client --add-client bob

# 生成用户专用配置
./scripts/generate-client-config.sh --client alice --format inline
./scripts/generate-client-config.sh --client bob --format inline
```

#### 2. 动态访问控制
```bash
# 创建客户端连接脚本
cat > scripts/client-connect.sh << 'EOF'
#!/bin/bash
# 客户端连接时执行的脚本
CLIENT_CN="$1"
CLIENT_IP="$2"

# 记录连接日志
echo "$(date): Client $CLIENT_CN connected from $CLIENT_IP" >> /var/log/openvpn-connections.log

# 根据用户设置不同的路由（可选）
case "$CLIENT_CN" in
    "admin")
        # 管理员全网访问
        echo "push \"route 192.168.0.0 255.255.0.0\"" > $1
        ;;
    "user"*)
        # 普通用户限制访问
        echo "push \"route 192.168.1.0 255.255.255.0\"" > $1
        ;;
esac
EOF

chmod +x scripts/client-connect.sh

# 在server.conf中启用
echo "client-connect scripts/client-connect.sh" >> config/server.conf
```

## 🔧 FRP安全配置

### FRP服务端安全

#### 1. 强化frps.ini配置
```ini
[common]
bind_port = 7000
dashboard_port = 7500
dashboard_user = admin
dashboard_pwd = your_very_secure_password_here
dashboard_tls_mode = true           # 启用HTTPS

# 安全配置
token = your_very_secure_token_here_with_64_chars_minimum_length_required
authentication_timeout = 900       # 认证超时
heartbeat_timeout = 90             # 心跳超时
max_clients = 10                   # 限制客户端数量
max_ports_per_client = 5          # 限制每客户端端口数

# 日志配置
log_file = /var/log/frps.log
log_level = info
log_max_days = 7

# TLS配置
tls_only = true                    # 仅TLS连接
```

#### 2. FRP管理后台安全
```bash
# 生成强密码
FRP_DASHBOARD_PWD=$(openssl rand -base64 32)

# 限制管理后台访问
# 在防火墙中只允许特定IP访问7500端口
sudo ufw deny 7500
sudo ufw allow from 192.168.1.100 to any port 7500

# 或使用nginx反向代理增加额外认证层
```

### FRP客户端安全

#### 1. 强化frpc.ini配置
```ini
[common]
server_addr = your-frp-server.com
server_port = 7000
token = your_very_secure_token_here_with_64_chars_minimum_length_required

# 安全配置
tls_enable = true                  # 启用TLS
login_fail_exit = true            # 登录失败即退出
protocol = kcp                    # 使用KCP协议（可选）

# 连接配置
heartbeat_interval = 30
heartbeat_timeout = 90
dial_server_timeout = 10

# 日志配置
log_file = /var/log/frpc.log
log_level = info
log_max_days = 7

[openvpn]
type = udp
local_ip = 127.0.0.1
local_port = 1194
remote_port = 1194
use_encryption = true             # 启用加密
use_compression = true            # 启用压缩
```

### Token安全管理

#### 1. 生成安全Token
```bash
# 生成64位随机Token
FRP_TOKEN=$(openssl rand -hex 32)
echo "Generated FRP Token: $FRP_TOKEN"

# 在.env文件中设置
echo "FRP_TOKEN=$FRP_TOKEN" >> .env
```

#### 2. Token轮换策略
```bash
# 创建Token轮换脚本
cat > scripts/rotate-frp-token.sh << 'EOF'
#!/bin/bash
# FRP Token轮换脚本

OLD_TOKEN=$(grep FRP_TOKEN .env | cut -d'=' -f2)
NEW_TOKEN=$(openssl rand -hex 32)

# 更新配置文件
sed -i "s/FRP_TOKEN=.*/FRP_TOKEN=$NEW_TOKEN/" .env
sed -i "s/token = .*/token = $NEW_TOKEN/" config/frps.ini
sed -i "s/token = .*/token = $NEW_TOKEN/" config/frpc.ini

echo "Token updated from $OLD_TOKEN to $NEW_TOKEN"
echo "Please restart FRP services"
EOF

chmod +x scripts/rotate-frp-token.sh

# 定期轮换（建议每月）
# 0 0 1 * * /path/to/openvpn-frp/scripts/rotate-frp-token.sh
```

## 🌐 网络安全配置

### 防火墙配置

#### 1. 基础防火墙规则
```bash
# UFW防火墙配置
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing

# 允许SSH
sudo ufw allow 22/tcp

# OpenVPN端口
sudo ufw allow 1194/udp

# FRP端口（根据部署模式）
sudo ufw allow 7000/tcp           # FRP控制端口

# FRP管理后台（限制IP）
sudo ufw allow from 192.168.1.0/24 to any port 7500

# 启用防火墙
sudo ufw --force enable
```

#### 2. iptables高级规则
```bash
# 创建OpenVPN专用链
iptables -N OPENVPN_RULES
iptables -A OPENVPN_RULES -j ACCEPT

# DDoS防护
iptables -A INPUT -p udp --dport 1194 -m state --state NEW -m recent --set
iptables -A INPUT -p udp --dport 1194 -m state --state NEW -m recent --update --seconds 60 --hitcount 10 -j DROP

# 端口扫描防护
iptables -A INPUT -m recent --name portscan --rcheck --seconds 86400 -j DROP
iptables -A INPUT -m recent --name portscan --remove
iptables -A INPUT -p tcp --tcp-flags SYN,ACK,FIN,RST RST -m limit --limit 1/s -j ACCEPT
```

### 网络隔离

#### 1. VLAN隔离（推荐）
```bash
# 创建管理VLAN
ip link add link eth0 name eth0.100 type vlan id 100
ip addr add 192.168.100.1/24 dev eth0.100
ip link set dev eth0.100 up

# OpenVPN使用隔离网段
OPENVPN_NETWORK=10.8.0.0
OPENVPN_NETMASK=255.255.255.0
```

#### 2. Docker网络隔离
```bash
# 创建隔离的Docker网络
docker network create --driver bridge \
  --subnet=172.30.0.0/16 \
  --ip-range=172.30.1.0/24 \
  --gateway=172.30.0.1 \
  openvpn-isolated

# 在docker-compose.yml中使用
networks:
  openvpn-isolated:
    external: true
```

### 入侵检测

#### 1. 安装Fail2Ban
```bash
sudo apt-get install fail2ban

# 创建OpenVPN规则
cat > /etc/fail2ban/filter.d/openvpn.conf << 'EOF'
[Definition]
failregex = ^.*WARNING.* bad session-id at packet.*<HOST>.*$
            ^.*TLS Error: cannot locate HMAC in incoming packet from \[AF_INET\]<HOST>:.*$
            ^.*Fatal TLS error.*from \[AF_INET\]<HOST>:.*$
ignoreregex =
EOF

# 配置jail
cat >> /etc/fail2ban/jail.local << 'EOF'
[openvpn]
enabled = true
port = 1194
protocol = udp
filter = openvpn
logpath = /var/log/openvpn.log
maxretry = 3
bantime = 3600
findtime = 600
EOF

sudo systemctl restart fail2ban
```

#### 2. 日志监控
```bash
# 安装logwatch
sudo apt-get install logwatch

# 配置OpenVPN日志监控
cat > /etc/logwatch/conf/services/openvpn.conf << 'EOF'
Title = "OpenVPN"
LogFile = openvpn
*OnlyService = openvpn
*RemoveHeaders
EOF

# 每日发送报告
echo "0 6 * * * /usr/sbin/logwatch --detail Med --service openvpn --mailto admin@example.com" | sudo crontab -
```

## 🔍 安全监控和审计

### 系统监控

#### 1. 健康检查增强
```bash
# 扩展健康检查脚本
cat >> scripts/security-check.sh << 'EOF'
#!/bin/bash
# 安全检查脚本

# 检查证书有效期
./scripts/health-check.sh --check certificates --alert-days 30

# 检查异常连接
netstat -tuln | grep :1194 | wc -l > /tmp/openvpn_connections
if [ $(cat /tmp/openvpn_connections) -gt 50 ]; then
    echo "WARNING: High number of OpenVPN connections detected"
fi

# 检查失败的认证
grep "AUTH_FAILED" /var/log/openvpn.log | tail -10

# 检查FRP连接状态
curl -s http://localhost:7500/api/proxy/tcp | jq '.proxies[].status'
EOF

chmod +x scripts/security-check.sh
```

#### 2. Prometheus监控
```bash
# OpenVPN指标导出
cat > scripts/openvpn-exporter.sh << 'EOF'
#!/bin/bash
# OpenVPN Prometheus指标导出

STATUS_FILE="/var/log/openvpn-status.log"
METRICS_FILE="/var/lib/prometheus/openvpn.prom"

# 连接数
CONNECTIONS=$(grep "CLIENT_LIST" $STATUS_FILE | wc -l)
echo "openvpn_connected_clients $CONNECTIONS" > $METRICS_FILE

# 数据传输
RX_BYTES=$(grep "CLIENT_LIST" $STATUS_FILE | awk '{sum+=$5} END {print sum+0}')
TX_BYTES=$(grep "CLIENT_LIST" $STATUS_FILE | awk '{sum+=$6} END {print sum+0}')
echo "openvpn_bytes_received $RX_BYTES" >> $METRICS_FILE
echo "openvpn_bytes_sent $TX_BYTES" >> $METRICS_FILE

# 证书过期时间
CERT_EXPIRY=$(openssl x509 -in pki/server/server.crt -noout -enddate | cut -d= -f2)
EXPIRY_TIMESTAMP=$(date -d "$CERT_EXPIRY" +%s)
echo "openvpn_cert_expiry_timestamp $EXPIRY_TIMESTAMP" >> $METRICS_FILE
EOF

chmod +x scripts/openvpn-exporter.sh

# 添加到crontab
echo "*/5 * * * * /path/to/openvpn-frp/scripts/openvpn-exporter.sh" | crontab -
```

### 安全事件响应

#### 1. 事件响应计划
```bash
# 创建安全事件响应脚本
cat > scripts/incident-response.sh << 'EOF'
#!/bin/bash
# 安全事件响应脚本

case "$1" in
    "cert-compromise")
        echo "证书泄露响应:"
        echo "1. 撤销受影响的证书"
        echo "2. 生成新的证书"
        echo "3. 更新客户端配置"
        echo "4. 通知相关用户"
        ;;
    "brute-force")
        echo "暴力破解响应:"
        echo "1. 临时禁用相关IP"
        echo "2. 增强认证机制"
        echo "3. 检查日志异常"
        ;;
    "service-disruption")
        echo "服务中断响应:"
        echo "1. 检查服务状态"
        echo "2. 恢复服务"
        echo "3. 分析中断原因"
        ;;
esac
EOF

chmod +x scripts/incident-response.sh
```

## 🛠️ 定期维护和更新

### 定期安全任务

#### 1. 每日任务
```bash
# 创建每日安全检查脚本
cat > scripts/daily-security-check.sh << 'EOF'
#!/bin/bash
# 每日安全检查

echo "===== 每日安全检查报告 $(date) ====="

# 1. 检查服务状态
echo "1. 服务状态检查:"
./scripts/health-check.sh --format text

# 2. 检查异常连接
echo -e "\n2. 连接状态检查:"
docker logs openvpn 2>&1 | grep "AUTH_FAILED" | tail -5

# 3. 检查磁盘空间
echo -e "\n3. 磁盘空间检查:"
df -h | grep -E "(8[0-9]|9[0-9])%"

# 4. 检查证书状态
echo -e "\n4. 证书状态检查:"
./scripts/health-check.sh --check certificates

echo -e "\n===== 检查完成 ====="
EOF

chmod +x scripts/daily-security-check.sh

# 添加到crontab
echo "0 8 * * * /path/to/openvpn-frp/scripts/daily-security-check.sh | mail -s 'OpenVPN Daily Security Report' admin@example.com" | crontab -
```

#### 2. 每周任务
```bash
# 创建每周安全维护脚本
cat > scripts/weekly-maintenance.sh << 'EOF'
#!/bin/bash
# 每周安全维护

echo "===== 每周安全维护 $(date) ====="

# 1. 备份配置和证书
echo "1. 创建备份..."
./scripts/manage.sh backup --include-logs

# 2. 清理日志
echo "2. 清理旧日志..."
find /var/log -name "*.log" -mtime +30 -delete

# 3. 更新系统
echo "3. 检查系统更新..."
apt list --upgradable 2>/dev/null | grep -v "WARNING"

# 4. 安全扫描
echo "4. 执行安全扫描..."
./scripts/security-check.sh

echo "===== 维护完成 ====="
EOF

chmod +x scripts/weekly-maintenance.sh

# 添加到crontab
echo "0 2 * * 0 /path/to/openvpn-frp/scripts/weekly-maintenance.sh" | crontab -
```

### 更新策略

#### 1. 安全更新流程
```bash
# 创建安全更新脚本
cat > scripts/security-update.sh << 'EOF'
#!/bin/bash
# 安全更新脚本

echo "开始安全更新流程..."

# 1. 备份当前配置
echo "1. 备份当前配置..."
./scripts/manage.sh backup --backup-dir "./backup-before-update-$(date +%Y%m%d)"

# 2. 停止服务
echo "2. 停止服务..."
./scripts/manage.sh stop

# 3. 更新系统包
echo "3. 更新系统包..."
sudo apt-get update && sudo apt-get upgrade -y

# 4. 更新Docker镜像
echo "4. 更新Docker镜像..."
docker-compose pull

# 5. 重新构建镜像
echo "5. 重新构建镜像..."
./scripts/manage.sh update

# 6. 启动服务
echo "6. 启动服务..."
./scripts/manage.sh start

# 7. 验证服务
echo "7. 验证服务..."
sleep 30
./scripts/health-check.sh

echo "安全更新完成！"
EOF

chmod +x scripts/security-update.sh
```

## 📋 安全检查清单

### 部署前检查清单

- [ ] 已修改所有默认密码
- [ ] 已生成强随机Token
- [ ] 已配置适当的证书有效期
- [ ] 已设置正确的文件权限
- [ ] 已配置防火墙规则
- [ ] 已启用TLS认证
- [ ] 已禁用不必要的功能
- [ ] 已配置日志记录

### 运行时检查清单

- [ ] 定期检查证书有效期
- [ ] 监控异常连接尝试
- [ ] 检查服务运行状态
- [ ] 验证备份完整性
- [ ] 更新安全补丁
- [ ] 检查日志异常
- [ ] 验证网络配置
- [ ] 测试灾难恢复流程

### 月度安全审计

- [ ] 审查用户访问权限
- [ ] 检查证书使用情况
- [ ] 分析连接日志
- [ ] 更新安全文档
- [ ] 测试安全响应程序
- [ ] 评估威胁模型
- [ ] 更新安全培训
- [ ] 进行渗透测试

## 🆘 安全事件响应

### 常见安全事件

#### 1. 证书泄露
```bash
# 立即响应步骤
./scripts/manage.sh cert --revoke-cert compromised_client
./scripts/manage.sh cert --generate-crl
./scripts/manage.sh restart
```

#### 2. 暴力破解攻击
```bash
# 分析攻击源
grep "AUTH_FAILED" /var/log/openvpn.log | awk '{print $NF}' | sort | uniq -c | sort -nr

# 临时阻止IP
sudo ufw deny from <攻击IP>
```

#### 3. 服务异常
```bash
# 检查服务状态
./scripts/health-check.sh --format json

# 查看详细日志
./scripts/manage.sh logs --tail 100

# 重启服务
./scripts/manage.sh restart
```

---

## 📞 技术支持

如遇到安全相关问题：

1. 立即隔离受影响的系统
2. 查看安全事件响应指南
3. 联系技术支持团队
4. 保留相关日志文件
5. 按照事件响应流程处理

**记住：安全是一个持续的过程，需要定期评估和改进！**