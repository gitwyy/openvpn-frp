# 贡献指南

欢迎为OpenVPN-FRP项目做出贡献！我们非常感谢您的参与，无论是报告Bug、提出功能建议、改进文档还是提交代码。

## 📋 目录

- [如何贡献](#-如何贡献)
- [开发环境设置](#-开发环境设置)
- [代码规范](#-代码规范)
- [提交规范](#-提交规范)
- [Pull Request流程](#-pull-request流程)
- [问题报告](#-问题报告)
- [功能建议](#-功能建议)
- [文档贡献](#-文档贡献)
- [测试贡献](#-测试贡献)
- [社区行为准则](#-社区行为准则)

## 🤝 如何贡献

### 贡献类型

1. **代码贡献**
   - Bug修复
   - 新功能开发
   - 性能优化
   - 代码重构

2. **文档贡献**
   - 文档改进
   - 示例添加
   - 翻译工作
   - FAQ更新

3. **测试贡献**
   - Bug报告
   - 测试用例
   - 性能测试
   - 兼容性测试

4. **设计贡献**
   - UI/UX改进
   - 架构设计
   - 流程优化

## 🛠️ 开发环境设置

### 系统要求

```bash
# 基础要求
- Git 2.20+
- Docker 20.10+
- Docker Compose 1.29+
- OpenSSL 1.1+

# 可选工具
- ShellCheck（Shell脚本检查）
- Hadolint（Dockerfile检查）
- yamllint（YAML文件检查）
```

### 环境准备

1. **Fork并克隆项目**
```bash
# Fork项目到您的GitHub账号
# 然后克隆到本地
git clone https://github.com/YOUR_USERNAME/openvpn-frp.git
cd openvpn-frp

# 添加上游仓库
git remote add upstream https://github.com/ORIGINAL_OWNER/openvpn-frp.git
```

2. **安装开发工具**
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install shellcheck yamllint

# macOS
brew install shellcheck yamllint hadolint

# 或使用Docker
docker run --rm -v "$PWD:/mnt" koalaman/shellcheck:stable scripts/*.sh
```

3. **设置开发环境**
```bash
# 复制环境配置
cp .env.example .env.dev

# 编辑开发配置
nano .env.dev

# 开发环境配置示例
DEBUG_MODE=true
LOG_LEVEL=debug
SKIP_CERT_VERIFY=false  # 即使在开发环境也要验证证书
```

4. **验证环境**
```bash
# 运行基础检查
./scripts/deploy.sh --dry-run --debug

# 验证脚本语法
find scripts -name "*.sh" -exec shellcheck {} \;

# 验证Docker配置
docker-compose config
```

## 📝 代码规范

### Shell脚本规范

#### 1. 基本规范
```bash
#!/bin/bash
# 文件头部注释
# 描述脚本功能和用途

# 启用严格模式
set -euo pipefail

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 项目根目录
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
```

#### 2. 函数规范
```bash
# 函数命名：使用下划线分隔的小写字母
function_name() {
    local param1="$1"
    local param2="${2:-default_value}"
    
    # 函数逻辑
    echo "Processing $param1..."
    
    # 返回值
    return 0
}

# 日志函数
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}
```

#### 3. 变量规范
```bash
# 常量：大写字母+下划线
readonly DEFAULT_PORT=1194
readonly CONFIG_FILE="config/server.conf"

# 变量：小写字母+下划线
local_variable="value"
global_variable="value"

# 数组
declare -a client_list=("client1" "client2" "client3")

# 关联数组
declare -A config_map
config_map["key1"]="value1"
config_map["key2"]="value2"
```

#### 4. 错误处理
```bash
# 检查命令执行结果
if ! command -v docker &> /dev/null; then
    log_error "Docker not found"
    exit 1
fi

# 检查文件存在
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# 陷阱处理
cleanup() {
    log_info "Cleaning up..."
    # 清理逻辑
}
trap cleanup EXIT
```

### Docker配置规范

#### 1. Dockerfile规范
```dockerfile
# 使用官方基础镜像
FROM alpine:3.18

# 维护者信息
LABEL maintainer="OpenVPN-FRP Team"
LABEL description="OpenVPN-FRP Container"
LABEL version="1.0.0"

# 安装依赖（合并RUN指令减少层数）
RUN apk add --no-cache \
    openvpn \
    openssl \
    bash \
    && rm -rf /var/cache/apk/*

# 创建工作目录
WORKDIR /app

# 复制文件
COPY scripts/ ./scripts/
COPY config/ ./config/

# 设置权限
RUN chmod +x scripts/*.sh

# 健康检查
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD ./scripts/health-check.sh --quiet || exit 1

# 启动命令
CMD ["./scripts/start-openvpn.sh"]
```

#### 2. Docker Compose规范
```yaml
version: '3.8'

services:
  openvpn:
    build:
      context: .
      dockerfile: docker/openvpn/Dockerfile
    container_name: openvpn
    restart: unless-stopped
    
    # 网络配置
    networks:
      - openvpn-network
    
    # 端口映射
    ports:
      - "${OPENVPN_PORT:-1194}:1194/udp"
    
    # 环境变量
    environment:
      - TZ=${TZ:-Asia/Shanghai}
      - DEBUG=${DEBUG_MODE:-false}
    
    # 卷挂载
    volumes:
      - ./pki:/etc/openvpn/pki:ro
      - ./config:/etc/openvpn/config:ro
      - openvpn-logs:/var/log/openvpn
    
    # 健康检查
    healthcheck:
      test: ["CMD", "nc", "-zu", "localhost", "1194"]
      interval: 30s
      timeout: 10s
      retries: 3
    
    # 安全配置
    cap_add:
      - NET_ADMIN
    devices:
      - /dev/net/tun

networks:
  openvpn-network:
    driver: bridge
    ipam:
      config:
        - subnet: ${DOCKER_NETWORK_SUBNET:-172.20.0.0/16}

volumes:
  openvpn-logs:
    driver: local
```

### 配置文件规范

#### 1. 环境变量命名
```bash
# 模块前缀
OPENVPN_*        # OpenVPN相关配置
FRP_*            # FRP相关配置
DOCKER_*         # Docker相关配置

# 配置类型后缀
*_HOST           # 主机地址
*_PORT           # 端口号
*_TOKEN          # 认证令牌
*_PWD            # 密码
*_ENABLE         # 布尔开关
*_DAYS           # 天数
*_SIZE           # 大小
```

#### 2. 配置文件注释
```bash
# =============================================================================
# OpenVPN 网络配置
# =============================================================================
# OpenVPN监听端口
OPENVPN_PORT=1194

# OpenVPN协议 (udp/tcp)
OPENVPN_PROTOCOL=udp

# OpenVPN虚拟网段
OPENVPN_NETWORK=10.8.0.0
OPENVPN_NETMASK=255.255.255.0
```

## 📤 提交规范

### 提交消息格式

```
<类型>(<范围>): <简短描述>

<详细描述>

<Footer>
```

#### 类型说明
- `feat`: 新功能
- `fix`: Bug修复
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建过程或辅助工具的变动

#### 示例
```
feat(deploy): 添加自动证书更新功能

- 增加证书过期检查
- 实现自动续期机制
- 添加邮件通知功能

Closes #123
```

### 分支命名规范

```bash
# 功能分支
feature/add-auto-cert-renewal
feature/web-dashboard

# 修复分支
bugfix/fix-android-connection
hotfix/security-patch

# 文档分支
docs/update-deployment-guide
docs/add-api-reference

# 发布分支
release/v1.1.0
```

## 🔄 Pull Request流程

### 1. 准备工作

```bash
# 更新fork仓库
git fetch upstream
git checkout main
git merge upstream/main
git push origin main

# 创建功能分支
git checkout -b feature/your-feature-name
```

### 2. 开发和测试

```bash
# 开发您的功能
# 编写代码...

# 运行测试
./scripts/deploy.sh --dry-run --debug
./scripts/health-check.sh
find scripts -name "*.sh" -exec shellcheck {} \;

# 提交更改
git add .
git commit -m "feat(scope): your feature description"
```

### 3. 提交Pull Request

1. **推送分支**
```bash
git push origin feature/your-feature-name
```

2. **创建PR**
   - 访问GitHub仓库
   - 点击"New Pull Request"
   - 选择您的分支
   - 填写PR模板

3. **PR模板**
```markdown
## 变更描述
简要描述此PR的变更内容

## 变更类型
- [ ] Bug修复
- [ ] 新功能
- [ ] 文档更新
- [ ] 性能改进
- [ ] 代码重构

## 测试
- [ ] 已通过现有测试
- [ ] 已添加新测试
- [ ] 已进行手动测试

## 检查清单
- [ ] 代码遵循项目规范
- [ ] 已更新相关文档
- [ ] 已添加必要的测试
- [ ] 提交消息符合规范

## 相关Issue
Closes #(issue_number)

## 截图（如适用）
```

### 4. 代码审查

- **响应反馈**：及时回应审查意见
- **修改代码**：根据建议进行修改
- **更新PR**：推送新的提交

```bash
# 修改代码后
git add .
git commit -m "fix: address review comments"
git push origin feature/your-feature-name
```

## 🐛 问题报告

### Bug报告模板

```markdown
## Bug描述
简要描述遇到的问题

## 环境信息
- 操作系统：
- Docker版本：
- Docker Compose版本：
- 项目版本：
- 部署模式：

## 重现步骤
1. 执行命令：`./scripts/deploy.sh --mode standalone`
2. 观察结果：
3. 期望行为：
4. 实际行为：

## 错误日志
```
粘贴相关错误日志
```

## 附加信息
- 配置文件内容（删除敏感信息）
- 系统日志
- 其他相关信息
```

### 严重程度分类

- **Critical**: 系统崩溃、数据丢失、安全漏洞
- **High**: 核心功能无法正常工作
- **Medium**: 功能部分受影响
- **Low**: 文档错误、界面问题

## 💡 功能建议

### 功能请求模板

```markdown
## 功能描述
简要描述建议的新功能

## 使用场景
描述什么情况下需要此功能

## 建议实现
如果有想法，描述如何实现

## 替代方案
是否考虑过其他解决方案

## 附加信息
- 参考资料
- 相关项目
- 设计图（如有）
```

## 📚 文档贡献

### 文档类型

1. **用户文档**
   - 安装指南
   - 使用教程
   - 故障排除
   - 最佳实践

2. **开发文档**
   - API文档
   - 架构说明
   - 贡献指南
   - 代码注释

3. **运维文档**
   - 部署手册
   - 监控配置
   - 备份策略
   - 安全规范

### 文档规范

#### Markdown格式
```markdown
# 一级标题

## 二级标题

### 三级标题

- 无序列表项
- 另一个列表项

1. 有序列表项
2. 另一个有序列表项

`内联代码`

```bash
# 代码块
echo "Hello World"
```

> 引用文本

| 表头1 | 表头2 |
|-------|-------|
| 内容1 | 内容2 |

[链接文本](https://example.com)
```

#### 中文文档规范
- 使用简体中文
- 专业术语保持一致
- 提供英文对照（如需要）
- 考虑国内用户特殊需求

## 🧪 测试贡献

### 测试类型

1. **功能测试**
```bash
# 基本功能测试脚本
#!/bin/bash
set -e

echo "测试基本部署功能..."
./scripts/deploy.sh --mode standalone --dry-run

echo "测试健康检查功能..."
./scripts/health-check.sh --format json

echo "测试客户端配置生成..."
./scripts/generate-client-config.sh --client test --verify

echo "所有测试通过!"
```

2. **集成测试**
```bash
# 完整流程测试
#!/bin/bash
set -e

# 清理环境
docker-compose down --volumes
rm -rf pki/

# 部署系统
./scripts/deploy.sh --mode standalone

# 等待服务启动
sleep 30

# 验证服务
./scripts/health-check.sh

# 生成客户端配置
./scripts/generate-client-config.sh --client integration-test

# 清理
docker-compose down
```

3. **性能测试**
```bash
# 性能基准测试
#!/bin/bash

echo "性能测试开始..."

# 启动时间测试
start_time=$(date +%s)
./scripts/deploy.sh --mode standalone
end_time=$(date +%s)
echo "启动时间: $((end_time - start_time))秒"

# 内存使用测试
memory_usage=$(docker stats --no-stream --format "{{.MemUsage}}" openvpn)
echo "内存使用: $memory_usage"

# 连接数测试
echo "测试最大连接数..."
# 连接测试逻辑...
```

### 测试环境

```bash
# 测试环境配置
# .env.test
DEPLOY_MODE=standalone
DEBUG_MODE=true
LOG_LEVEL=debug
SKIP_CERT_VERIFY=false
TEST_MODE=true

# Docker测试网络
DOCKER_NETWORK_SUBNET=172.99.0.0/16
```

## 👥 社区行为准则

### 我们的承诺

我们致力于为每个人提供友好、安全和受欢迎的环境，无论其：
- 经验水平
- 性别认同和表达
- 性取向
- 身体或精神状况
- 外貌
- 种族或民族
- 年龄
- 宗教或信仰

### 期望行为

- **友善和耐心**：对所有参与者保持友善和耐心
- **尊重差异**：尊重不同的观点和经验
- **建设性反馈**：提供和接受建设性的批评
- **责任感**：为自己的错误承担责任并学习
- **关注社区**：关注对整个社区最有利的事情

### 不当行为

- 使用与性有关的语言或图像
- 人身攻击或政治攻击
- 公开或私下的骚扰
- 发布他人的私人信息
- 其他在专业环境中合理认为不当的行为

### 执行

如果您遇到或观察到不当行为，请通过以下方式报告：
- 发送邮件至：[maintainer-email]
- 私信项目维护者
- 在相关Issue中标记维护者

所有报告都将被保密处理。

## 📞 获取帮助

### 联系方式

- **GitHub Issues**：报告Bug和功能请求
- **GitHub Discussions**：一般讨论和问题
- **Email**：[project-email] （敏感问题）

### 响应时间

- **Bug报告**：48小时内回应
- **功能请求**：1周内回应
- **Pull Request**：72小时内开始审查
- **安全问题**：24小时内回应

### 支持资源

- [项目文档](docs/)
- [常见问题](docs/FAQ.md)
- [故障排除指南](docs/FAQ.md#故障排除)
- [最佳实践](docs/SECURITY-GUIDE.md)

---

## 🙏 致谢

感谢所有为OpenVPN-FRP项目做出贡献的开发者、测试者和用户！

您的参与让这个项目变得更好！🚀

### 贡献者列表

<!-- 这里将自动更新贡献者列表 -->

---

**快来加入我们，一起构建更好的OpenVPN-FRP！**