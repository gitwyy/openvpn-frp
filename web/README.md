# OpenVPN-FRP Web管理界面

## 🎯 概述

这是一个极简化的Web管理界面，专为OpenVPN-FRP项目设计，提供基础的服务管理和监控功能。

## ✨ 主要特性

- **🎛️ 服务控制**: 启动/停止/重启 OpenVPN 和 FRP 服务
- **📊 状态监控**: 实时查看服务运行状态和系统信息
- **📋 日志查看**: 实时查看和搜索服务日志
- **👥 客户端管理**: 查看在线客户端，生成客户端配置
- **🔒 简单认证**: 基于用户名/密码的访问控制
- **📱 响应式设计**: 支持桌面和移动设备访问

## 🚀 快速开始

### 1. 部署Web管理界面

```bash
# 一键部署
./scripts/web-deploy.sh --deploy

# 或者手动启动
docker-compose --profile web up -d web
```

### 2. 访问Web界面

- **访问地址**: http://localhost:8080
- **默认账户**: admin
- **默认密码**: admin123

### 3. 基本操作

#### 服务管理
- 在仪表板页面可以查看所有服务状态
- 使用控制按钮启动/停止/重启服务
- 实时监控服务运行状态

#### 日志查看
- 切换到"日志"页面
- 选择要查看的服务日志
- 支持自动刷新和实时更新

#### 客户端管理
- 在"客户端"页面查看在线客户端
- 生成新的客户端配置文件
- 查看客户端连接信息和流量统计

## ⚙️ 配置说明

### 环境变量配置

在`.env`文件中配置以下参数：

```bash
# Web管理界面配置
WEB_ENABLED=true                    # 是否启用Web界面
WEB_PORT=8080                       # Web界面端口
WEB_SECRET_KEY=your_secret_key      # 安全密钥（请修改）
WEB_ADMIN_USER=admin                # 管理员用户名
WEB_ADMIN_PASSWORD=your_password    # 管理员密码（请修改）
WEB_SESSION_TIMEOUT=3600            # 会话超时时间（秒）
```

### 安全建议

1. **修改默认密码**: 首次部署后立即修改默认密码
2. **使用强密码**: 设置复杂的管理员密码
3. **限制访问**: 通过防火墙限制Web界面的访问IP
4. **定期更新**: 定期更新安全密钥

## 🛠️ 管理命令

### 使用web-deploy.sh脚本

```bash
# 部署Web管理界面
./scripts/web-deploy.sh --deploy

# 启动Web管理界面
./scripts/web-deploy.sh --start

# 停止Web管理界面
./scripts/web-deploy.sh --stop

# 重启Web管理界面
./scripts/web-deploy.sh --restart

# 查看状态
./scripts/web-deploy.sh --status

# 查看日志
./scripts/web-deploy.sh --logs

# 重新构建镜像
./scripts/web-deploy.sh --build

# 完全移除
./scripts/web-deploy.sh --remove
```

### 使用Docker Compose

```bash
# 启动Web界面
docker-compose --profile web up -d web

# 停止Web界面
docker-compose stop web

# 查看日志
docker-compose logs -f web

# 重新构建
docker-compose build web
```

## 🔧 故障排除

### 常见问题

#### 1. 无法访问Web界面
- 检查容器是否正常运行: `docker ps | grep openvpn-web`
- 检查端口是否被占用: `netstat -tlnp | grep 8080`
- 查看容器日志: `docker logs openvpn-web`

#### 2. 登录失败
- 确认用户名和密码是否正确
- 检查.env文件中的配置
- 重启Web容器: `docker-compose restart web`

#### 3. 服务控制失败
- 确认Docker socket挂载正确
- 检查容器权限设置
- 查看Web应用日志

#### 4. 日志显示异常
- 确认脚本文件权限: `ls -la scripts/`
- 检查脚本路径挂载: `docker exec openvpn-web ls -la /app/scripts/`
- 验证脚本可执行性

### 调试模式

启用调试模式查看详细日志：

```bash
# 设置调试环境变量
export DEBUG_MODE=true

# 重启Web容器
docker-compose restart web

# 查看详细日志
docker-compose logs -f web
```

## 📁 文件结构

```
web/
├── app.py                  # Flask应用主文件
├── requirements.txt        # Python依赖
├── Dockerfile             # Docker构建文件
├── templates/             # HTML模板
│   ├── base.html          # 基础模板
│   ├── login.html         # 登录页面
│   ├── dashboard.html     # 仪表板
│   ├── logs.html          # 日志页面
│   └── clients.html       # 客户端管理
└── README.md              # 说明文档
```

## 🔒 安全特性

- **会话管理**: 基于Flask Session的用户会话
- **密码保护**: 管理员账户密码保护
- **权限控制**: 所有管理功能需要登录
- **安全头**: 基本的HTTP安全头设置
- **容器隔离**: 运行在独立的Docker容器中

## 📊 API接口

Web界面提供以下REST API接口：

- `GET /api/status` - 获取服务状态
- `POST /api/service/action` - 服务控制操作
- `GET /api/logs` - 获取服务日志
- `GET /api/clients` - 获取客户端列表
- `POST /api/client/create` - 生成客户端配置
- `GET /api/health` - 健康检查

## 🤝 贡献

欢迎提交Issue和Pull Request来改进Web管理界面！

## 📄 许可证

本项目采用MIT许可证，详见主项目LICENSE文件。
