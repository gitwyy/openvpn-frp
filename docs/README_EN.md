# OpenVPN-FRP - Enterprise-Grade OpenVPN & FRP Integration Solution

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Docker](https://img.shields.io/badge/Docker-Ready-blue.svg)](https://www.docker.com/)
[![OpenVPN](https://img.shields.io/badge/OpenVPN-2.5+-green.svg)](https://openvpn.net/)
[![FRP](https://img.shields.io/badge/FRP-0.51+-orange.svg)](https://github.com/fatedier/frp)

## 🚀 Project Overview

OpenVPN-FRP is a comprehensive enterprise-grade VPN solution that integrates OpenVPN and FRP (Fast Reverse Proxy), providing:

- **One-Click Deployment** - Fully automated deployment process
- **Multi-Scenario Support** - Supports direct connection, NAT traversal and other deployment scenarios
- **Intelligent Management** - Comprehensive service management and monitoring capabilities
- **Auto Client Configuration** - Supports automatic configuration generation for multiple platforms
- **Health Monitoring** - Complete system health monitoring and reporting
- **Enterprise Security** - Enterprise-grade security configuration and certificate management

## ✨ Key Features

### 🏗️ Deployment Features
- **Three Deployment Modes**: Standalone, FRP-Client, FRP-Full architecture
- **Automated Deployment**: Complete configuration and deployment with one command
- **Intelligent Detection**: Automatic system environment and dependency detection
- **Configuration Validation**: Automatic validation of all configurations before deployment

### 🛠️ Management Features
- **Service Management**: Start, stop, restart, status monitoring
- **Log Management**: Real-time log viewing and analysis
- **Backup & Restore**: Complete configuration and data backup/restore
- **Client Management**: Client certificate CRUD operations

### 📊 Monitoring Features
- **Health Checks**: Comprehensive system health monitoring
- **Multiple Output Formats**: Support for JSON, HTML, Prometheus formats
- **Continuous Monitoring**: Support for continuous monitoring mode
- **Alert Integration**: Support for Nagios, Zabbix integration

### 🔧 Client Features
- **Multi-Platform Support**: Android, iOS, Windows, macOS, Linux
- **Smart Configuration**: Automatic generation of optimal configuration based on deployment mode
- **Multiple Formats**: Support for inline and separate configuration formats
- **QR Code Generation**: Mobile device scan configuration

## 🚀 Quick Start

### System Requirements

- **Operating System**: Linux, macOS or Windows (WSL)
- **Docker**: 20.10+
- **Docker Compose**: 1.29+
- **OpenSSL**: 1.1+
- **Network Tools**: netcat, curl

### One-Click Deployment

1. **Clone Project**
```bash
git clone <repository-url>
cd openvpn-frp
```

2. **Configure Environment**
```bash
# Copy configuration template
cp .env.example .env

# Edit configuration (must set server address)
nano .env
```

3. **Choose Deployment Mode and Deploy**

#### Standalone Mode (Server with Public IP)
```bash
./scripts/deploy.sh --mode standalone
```

#### FRP Client Mode (Internal Server NAT Traversal)
```bash
./scripts/deploy.sh --mode frp_client --host YOUR_PUBLIC_SERVER_IP --token YOUR_SECURE_TOKEN
```

#### Full FRP Architecture (Including Server and Client)
```bash
./scripts/deploy.sh --mode frp_full --token YOUR_SECURE_TOKEN
```

### Generate Client Configuration

```bash
# Generate default client configuration
./scripts/generate-client-config.sh

# Generate Android configuration
./scripts/generate-client-config.sh --client mobile1 --android

# Generate all client configurations
./scripts/generate-client-config.sh --multiple --output ./clients
```

## 📋 Core Components

### Deployment Script (`scripts/deploy.sh`)
- ✅ System dependency check
- ✅ Environment configuration validation
- ✅ Automatic certificate generation
- ✅ Docker image building
- ✅ Service startup and verification
- ✅ Post-deployment information display

### Management Script (`scripts/manage.sh`)
- ✅ Service lifecycle management
- ✅ Log viewing and analysis
- ✅ Configuration backup and restore
- ✅ Client certificate management
- ✅ System cleanup and updates

### Health Check (`scripts/health-check.sh`)
- ✅ Docker service status check
- ✅ Network connectivity verification
- ✅ Certificate validity monitoring
- ✅ System resource monitoring
- ✅ Security configuration check

### Client Configuration Generator (`scripts/generate-client-config.sh`)
- ✅ Multi-platform configuration generation
- ✅ Smart connection mode detection
- ✅ Inline and separate format support
- ✅ QR code generation
- ✅ Configuration validation

## 🏗️ Architecture

### Deployment Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    OpenVPN-FRP Architecture                  │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │  Standalone │    │ FRP-Client  │    │  FRP-Full   │      │
│  │    Mode     │    │    Mode     │    │    Mode     │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         │                   │                   │           │
│         │                   │                   │           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   OpenVPN   │    │   OpenVPN   │    │   OpenVPN   │      │
│  │   Service   │    │  + FRP-C    │    │ + FRP-S/C   │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│         │                   │                   │           │
│         │                   │                   │           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐      │
│  │   Direct    │    │  Tunneled   │    │  Complete   │      │
│  │ (Public IP) │    │ (Internal)  │    │ (Control)   │      │
│  └─────────────┘    └─────────────┘    └─────────────┘      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Network Topology

#### Standalone Mode
```
Client ──→ Internet ──→ OpenVPN Server (Public IP:1194)
```

#### FRP-Client Mode
```
Client ──→ Internet ──→ FRP Server ──→ FRP Client ──→ OpenVPN Server (Internal)
```

#### FRP-Full Mode
```
Client ──→ FRP Server ──→ FRP Client ──→ OpenVPN Server
          (Same server/network environment)
```

## 📁 Project Structure

```
openvpn-frp/
├── 📁 config/                    # Configuration files
│   ├── server.conf               # OpenVPN server configuration
│   ├── openssl.cnf              # SSL configuration
│   ├── frps.ini                 # FRP server configuration
│   └── frpc.ini                 # FRP client configuration
├── 📁 docker/                    # Docker build files
│   ├── openvpn/                 # OpenVPN Docker configuration
│   └── frp/                     # FRP Docker configuration
├── 📁 docs/                      # Documentation
│   ├── DEPLOYMENT-GUIDE.md      # Detailed deployment guide
│   ├── SECURITY-GUIDE.md        # Security configuration guide
│   ├── SCRIPTS-REFERENCE.md     # Scripts reference manual
│   ├── FAQ.md                   # Frequently asked questions
│   └── README_EN.md             # English documentation
├── 📁 pki/                       # Certificate directory (generated at runtime)
├── 📁 scripts/                   # Scripts directory
│   ├── 🚀 deploy.sh             # One-click deployment script
│   ├── ⚙️ manage.sh              # Service management script
│   ├── 🏥 health-check.sh       # Health check script
│   ├── 📱 generate-client-config.sh # Client configuration generator
│   ├── 🔐 generate-certs.sh     # Certificate generation script
│   ├── ✅ verify-certs.sh       # Certificate verification script
│   ├── 🐳 build-openvpn.sh      # OpenVPN build script
│   └── 🐳 build-frp.sh          # FRP build script
├── .env.example                  # Environment configuration template
├── docker-compose.yml           # Main orchestration file
├── CHANGELOG.md                  # Change log
├── LICENSE                       # Open source license
├── CONTRIBUTING.md               # Contribution guide
└── README.md                     # Project documentation
```

## 🛠️ Usage Guide

### Service Management

```bash
# Check service status
./scripts/manage.sh status

# Start all services
./scripts/manage.sh start

# Stop all services
./scripts/manage.sh stop

# Restart services
./scripts/manage.sh restart

# View real-time logs
./scripts/manage.sh logs --follow

# View specific service logs
./scripts/manage.sh logs openvpn --tail 100
```

### Health Monitoring

```bash
# Basic health check
./scripts/health-check.sh

# JSON format output
./scripts/health-check.sh --format json --output health.json

# Continuous monitoring (check every 30 seconds)
./scripts/health-check.sh --continuous --interval 30

# Check certificates only
./scripts/health-check.sh --check certificates

# Nagios compatible output (for monitoring integration)
./scripts/health-check.sh --nagios
```

### Client Management

```bash
# List all client certificates
./scripts/manage.sh client --list-clients

# Add new client
./scripts/manage.sh client --add-client newuser

# Remove client
./scripts/manage.sh client --remove-client olduser

# Generate client configuration
./scripts/generate-client-config.sh --client newuser --android

# Generate configuration with QR code
./scripts/generate-client-config.sh --client mobile --qr-code

# Verify client configuration
./scripts/generate-client-config.sh --verify
```

### Backup and Restore

```bash
# Create complete backup
./scripts/manage.sh backup --include-logs

# Restore backup
./scripts/manage.sh restore --backup-dir /path/to/backup

# Verify configuration files
./scripts/manage.sh config

# Clean unused Docker resources
./scripts/manage.sh clean
```

## 🔧 Advanced Configuration

### Environment Variables

```bash
# Deployment mode
DEPLOY_MODE=standalone                    # standalone|frp_client|frp_full

# FRP configuration
FRP_SERVER_ADDR=your.server.com          # FRP server address
FRP_TOKEN=your_secure_token_here          # Security token
FRP_DASHBOARD_PWD=secure_password         # Management dashboard password

# OpenVPN network configuration
OPENVPN_EXTERNAL_HOST=your.domain.com     # Client connection address
OPENVPN_PORT=1194                         # OpenVPN port
OPENVPN_PROTOCOL=udp                      # Protocol type
OPENVPN_NETWORK=10.8.0.0                 # VPN network segment

# Security configuration
CA_EXPIRE_DAYS=3650                       # CA certificate validity period
CLIENT_EXPIRE_DAYS=365                    # Client certificate validity period
KEY_SIZE=2048                             # RSA key length

# Performance configuration
MAX_CLIENTS=100                           # Maximum number of clients
CLIENT_TIMEOUT=120                        # Client timeout
ENABLE_COMPRESSION=true                   # Enable compression
```

### Docker Compose Profiles

```bash
# Start with specific profile
docker-compose --profile frp-client up -d
docker-compose --profile frp-full up -d
docker-compose --profile monitoring up -d

# Combine multiple profiles
docker-compose --profile frp-full --profile monitoring up -d
```

## 🔍 Troubleshooting

### Common Issues

#### 1. Deployment Failure
```bash
# Check system dependencies
./scripts/deploy.sh --skip-deps

# View detailed error information
./scripts/deploy.sh --debug

# Dry run mode to see operations to be executed
./scripts/deploy.sh --dry-run
```

#### 2. Client Cannot Connect
```bash
# Check service status
./scripts/health-check.sh

# Verify certificates
./scripts/manage.sh cert --verify-certs

# Regenerate client configuration
./scripts/generate-client-config.sh --client problematic_client
```

#### 3. FRP Connection Issues
```bash
# Check FRP logs
./scripts/manage.sh logs frpc
./scripts/manage.sh logs frps

# Verify network connectivity
ping $FRP_SERVER_ADDR
telnet $FRP_SERVER_ADDR 7000
```

### Log Analysis

```bash
# View all service logs
./scripts/manage.sh logs

# View last 100 lines of OpenVPN logs
./scripts/manage.sh logs openvpn --tail 100

# Real-time tracking of FRP client logs
./scripts/manage.sh logs frpc --follow

# View logs after specified time
./scripts/manage.sh logs --since 2024-01-01T10:00:00
```

## 📈 Monitoring Integration

### Prometheus Monitoring

```bash
# Generate Prometheus format metrics
./scripts/health-check.sh --format prometheus

# Set up scheduled task
echo "*/5 * * * * /path/to/openvpn-frp/scripts/health-check.sh --format prometheus > /var/lib/prometheus/openvpn-frp.prom" | crontab -
```

### Nagios Integration

```bash
# Nagios check command
define command{
    command_name    check_openvpn_frp
    command_line    /path/to/openvpn-frp/scripts/health-check.sh --nagios
}
```

### Log Forwarding

```bash
# Configure rsyslog to forward OpenVPN logs
echo "local0.*    @@your-log-server:514" >> /etc/rsyslog.conf
systemctl restart rsyslog
```

## 🔒 Security Recommendations

### Basic Security
- ✅ Change all default passwords
- ✅ Use strong encryption algorithms and key lengths
- ✅ Regularly update certificates
- ✅ Configure appropriate firewall rules
- ✅ Restrict management interface access

### Advanced Security
- ✅ Enable two-factor authentication
- ✅ Configure intrusion detection system
- ✅ Implement network segmentation
- ✅ Regular security audits
- ✅ Establish log monitoring and alerting

### Network Security
```bash
# Example firewall rule configuration
sudo ufw allow 1194/udp              # OpenVPN
sudo ufw allow 7000/tcp              # FRP control port
sudo ufw allow from trusted_ip to any port 7500  # FRP management dashboard
```

## 🚀 Performance Optimization

### System Optimization
```bash
# Increase file descriptor limit
echo "* soft nofile 65536" >> /etc/security/limits.conf
echo "* hard nofile 65536" >> /etc/security/limits.conf

# Optimize network parameters
echo "net.core.rmem_max = 134217728" >> /etc/sysctl.conf
echo "net.core.wmem_max = 134217728" >> /etc/sysctl.conf
echo "net.ipv4.tcp_rmem = 4096 87380 134217728" >> /etc/sysctl.conf
sysctl -p
```

### OpenVPN Optimization
```bash
# Configure in .env file
ENABLE_COMPRESSION=true               # Enable compression
MAX_CLIENTS=500                       # Increase client limit
CLIENT_TIMEOUT=300                    # Adjust timeout
```

## 📚 Documentation

- [Detailed Deployment Guide](DEPLOYMENT-GUIDE.md) - Complete deployment and configuration guide
- [Security Configuration Guide](SECURITY-GUIDE.md) - Comprehensive security configuration
- [Scripts Reference Manual](SCRIPTS-REFERENCE.md) - Detailed script documentation
- [FAQ](FAQ.md) - Frequently asked questions and troubleshooting
- [Chinese Documentation](../README.md) - Chinese version documentation

## 🤝 Contributing

Welcome to submit Issues and Pull Requests to improve this project!

### Development Environment Setup
```bash
git clone <repository-url>
cd openvpn-frp
cp .env.example .env
# Edit .env file
./scripts/deploy.sh --mode standalone --debug
```

### Code Standards
- Shell scripts follow [ShellCheck](https://www.shellcheck.net/) standards
- Configuration files use appropriate comments
- Documentation uses Markdown format

## 📄 License

This project uses the MIT license. See [LICENSE](../LICENSE) file for details.

## 🆘 Support

If you encounter problems:

1. Check the [Troubleshooting](#-troubleshooting) section
2. Check existing [Issues](../../issues)
3. Create a new [Issue](../../issues/new) and provide detailed information
4. Check the [Detailed Deployment Guide](DEPLOYMENT-GUIDE.md)

## 📊 Project Status

- ✅ Core functionality complete
- ✅ Dockerized deployment
- ✅ Automated scripts
- ✅ Health checks
- ✅ Client configuration generation
- ✅ Multi-platform support
- ✅ Complete documentation

---

**OpenVPN-FRP** - Making VPN deployment simple and reliable! 🚀

## 🌍 Language Versions

- [中文文档 (Chinese)](../README.md)
- [English Documentation](README_EN.md) (Current)

---

For more detailed information, please refer to the [Chinese documentation](../README.md) or visit our [documentation directory](.).