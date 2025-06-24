# macOS 环境部署指南

## 问题描述

在macOS环境下运行OpenVPN-FRP服务时，可能会遇到`/dev/net/tun`设备不存在的错误。这是因为macOS默认不提供TUN/TAP设备，需要特殊配置。

## 解决方案

### 方案一：使用Docker容器内TUN设备（推荐）

这是最简单的解决方案，利用容器的特权模式在容器内创建TUN设备。

```bash
# 直接运行部署脚本，会自动跳过主机TUN检查
./scripts/deploy.sh --mode standalone
```

### 方案二：安装TunTap OSX驱动

如果需要在主机系统上使用TUN/TAP设备，可以安装第三方驱动。

#### 下载和安装

1. **下载TunTap OSX**
   ```bash
   # 方法1: 从官方下载
   curl -L -o tuntap.pkg "https://sourceforge.net/projects/tuntaposx/files/latest/download"
   
   # 方法2: 使用Homebrew（推荐）
   brew install --cask tuntap
   ```

2. **安装驱动**
   ```bash
   # 如果下载了pkg文件
   sudo installer -pkg tuntap.pkg -target /
   
   # 重启系统以加载内核扩展
   sudo reboot
   ```

3. **验证安装**
   ```bash
   # 检查设备是否存在
   ls -la /dev/tun*
   
   # 应该看到类似输出：
   # crw-------  1 root  wheel   17,   0 Dec  1 10:00 /dev/tun0
   # crw-------  1 root  wheel   17,   1 Dec  1 10:00 /dev/tun1
   ```

#### 权限配置

```bash
# 确保当前用户可以访问TUN设备
sudo chown $USER /dev/tun*
sudo chmod 660 /dev/tun*

# 或者将用户添加到相应的组
sudo dseditgroup -o edit -a $USER -t user wheel
```

### 方案三：使用Docker Desktop网络模式

利用Docker Desktop的内置网络功能，无需TUN设备。

1. **配置Docker Compose**
   ```yaml
   # 在docker-compose.yml中添加网络模式配置
   services:
     openvpn:
       network_mode: "host"  # 使用主机网络
       # 或者
       network_mode: "bridge"  # 使用桥接网络
   ```

2. **修改部署脚本参数**
   ```bash
   # 跳过TUN设备检查
   ./scripts/deploy.sh --skip-deps --mode standalone
   ```

## macOS特定配置

### Docker Desktop设置

1. **启用特权容器**
   - 打开Docker Desktop
   - 进入Settings > Advanced
   - 确保允许特权容器运行

2. **网络配置**
   ```bash
   # 检查Docker网络配置
   docker network ls
   
   # 创建自定义网络（如需要）
   docker network create --driver bridge openvpn-net
   ```

### 防火墙配置

```bash
# 检查macOS防火墙状态
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --getglobalstate

# 如果防火墙开启，需要允许Docker和OpenVPN
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /Applications/Docker.app
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --unblock /Applications/Docker.app
```

## 部署步骤

### 快速部署（推荐）

```bash
# 1. 克隆项目
git clone <repository-url>
cd openvpn-frp

# 2. 检查系统依赖
brew install docker docker-compose openssl netcat

# 3. 启动Docker Desktop
open /Applications/Docker.app

# 4. 运行部署脚本
./scripts/deploy.sh --mode standalone

# 5. 验证服务状态
docker-compose ps
```

### 详细部署步骤

```bash
# 1. 环境准备
echo "准备macOS环境..."

# 安装Homebrew（如未安装）
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# 安装必要依赖
brew install docker docker-compose openssl netcat

# 2. 配置环境变量
cp .env.example .env
vim .env  # 根据需要修改配置

# 3. 生成证书
./scripts/generate-certs.sh

# 4. 构建镜像
./scripts/build-openvpn.sh

# 5. 启动服务
docker-compose up -d

# 6. 生成客户端配置
./scripts/generate-client-config.sh
```

## 故障排除

### 常见错误

1. **TUN设备权限错误**
   ```bash
   # 错误信息：Permission denied opening TUN device
   # 解决方案：
   sudo chmod 666 /dev/tun*
   ```

2. **Docker权限错误**
   ```bash
   # 错误信息：permission denied while trying to connect to Docker
   # 解决方案：
   sudo dseditgroup -o edit -a $USER -t user docker
   # 然后重新登录或重启终端
   ```

3. **端口占用错误**
   ```bash
   # 检查端口占用
   lsof -i :1194
   
   # 停止占用进程
   sudo kill -9 <PID>
   ```

### 日志查看

```bash
# 查看容器日志
docker-compose logs openvpn

# 查看系统日志
tail -f /var/log/system.log | grep openvpn

# 查看Docker日志
docker logs openvpn
```

### 性能优化

```bash
# 增加Docker资源限制
# 在Docker Desktop中：
# Settings > Resources > Advanced
# 增加CPU和内存分配

# 优化网络性能
sysctl -w net.inet.ip.forwarding=1
```

## 安全注意事项

1. **防火墙配置**
   - 确保只开放必要端口
   - 使用强密码和证书

2. **证书管理**
   ```bash
   # 定期更新证书
   ./scripts/generate-certs.sh
   
   # 备份重要文件
   tar -czf openvpn-backup-$(date +%Y%m%d).tar.gz pki/ config/
   ```

3. **系统更新**
   ```bash
   # 定期更新系统和Docker
   sudo softwareupdate -ia
   brew upgrade docker docker-compose
   ```

## 参考资源

- [TunTap OSX 官方项目](https://sourceforge.net/projects/tuntaposx/)
- [Docker Desktop for Mac 文档](https://docs.docker.com/desktop/mac/)
- [OpenVPN 官方文档](https://openvpn.net/community-resources/)
- [macOS 网络配置指南](https://developer.apple.com/documentation/network)