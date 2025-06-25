#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OpenVPN-FRP 极简Web管理界面
单文件Flask应用，提供基础的服务管理功能
"""

import os
import subprocess
import json
import time
from datetime import datetime
from flask import Flask, render_template, request, jsonify, session, redirect, url_for, flash
from functools import wraps
import logging

# 配置
app = Flask(__name__)
app.secret_key = os.environ.get('WEB_SECRET_KEY', 'openvpn-frp-web-secret-2024')
app.config['PERMANENT_SESSION_LIFETIME'] = 3600  # 1小时

# 管理员认证配置
ADMIN_USERNAME = os.environ.get('WEB_ADMIN_USER', 'admin')
ADMIN_PASSWORD = os.environ.get('WEB_ADMIN_PASSWORD', 'admin123')

# 项目根目录 - 在容器中，脚本位于 /app/scripts/
PROJECT_ROOT = '/app'

# 日志配置
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def require_auth(f):
    """认证装饰器"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        if 'authenticated' not in session:
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    return decorated_function

def run_script(script_name, *args):
    """执行项目脚本"""
    try:
        script_path = os.path.join(PROJECT_ROOT, 'scripts', script_name)
        cmd = [script_path] + list(args)
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
        return {
            'success': result.returncode == 0,
            'stdout': result.stdout,
            'stderr': result.stderr,
            'returncode': result.returncode
        }
    except subprocess.TimeoutExpired:
        return {'success': False, 'error': '脚本执行超时'}
    except Exception as e:
        return {'success': False, 'error': str(e)}

def docker_service_action(action, service=None):
    """真正的Docker服务操作"""
    try:
        service_names = {
            'openvpn': 'OpenVPN',
            'frpc': 'FRP Client',
            'frps': 'FRP Server',
            'all': '所有服务'
        }

        action_names = {
            'start': '启动',
            'stop': '停止',
            'restart': '重启'
        }

        if action not in action_names:
            return {'success': False, 'error': f'不支持的操作: {action}'}

        if service not in service_names:
            return {'success': False, 'error': f'未知服务: {service}'}

        # 构建Docker命令
        if service == 'all':
            # 操作所有服务
            containers = ['openvpn', 'frpc', 'frps']
        else:
            containers = [service]

        results = []
        for container in containers:
            try:
                cmd = ['docker', action, container]
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)

                if result.returncode == 0:
                    results.append(f"{service_names.get(container, container)}{action_names[action]}成功")
                else:
                    # 如果容器不存在或已经是目标状态，也认为是成功的
                    if 'is not running' in result.stderr and action == 'stop':
                        results.append(f"{service_names.get(container, container)}已经停止")
                    elif 'is already running' in result.stderr and action == 'start':
                        results.append(f"{service_names.get(container, container)}已经运行")
                    else:
                        results.append(f"{service_names.get(container, container)}{action_names[action]}失败: {result.stderr}")
            except subprocess.TimeoutExpired:
                results.append(f"{service_names.get(container, container)}{action_names[action]}超时")
            except Exception as e:
                results.append(f"{service_names.get(container, container)}{action_names[action]}错误: {str(e)}")

        return {
            'success': True,
            'stdout': '\\n'.join(results),
            'stderr': '',
            'returncode': 0
        }
    except Exception as e:
        return {'success': False, 'error': str(e)}

def get_docker_status():
    """获取Docker容器状态 - 简化版本，通过网络检查服务状态"""
    try:
        containers = {}

        # 检查OpenVPN服务 - 通过端口检查
        try:
            import socket
            sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
            sock.settimeout(1)
            result = sock.connect_ex(('localhost', 1194))
            sock.close()
            containers['openvpn'] = {
                'status': 'Up' if result == 0 else 'Down',
                'state': 'running' if result == 0 else 'stopped',
                'ports': '1194/udp'
            }
        except:
            containers['openvpn'] = {
                'status': 'Unknown',
                'state': 'unknown',
                'ports': '1194/udp'
            }

        # FRP状态检查 - 直接检查Docker容器状态
        try:
            frpc_result = subprocess.run(['docker', 'ps', '--filter', 'name=frpc', '--format', '{{.Status}}'],
                                       capture_output=True, text=True, timeout=10)
            if frpc_result.returncode == 0 and frpc_result.stdout.strip():
                status = frpc_result.stdout.strip()
                frp_status = 'Up' if 'Up' in status else 'Down'
                containers['frpc'] = {
                    'status': frp_status,
                    'state': 'running' if frp_status == 'Up' else 'stopped',
                    'ports': 'various'
                }
            else:
                containers['frpc'] = {
                    'status': 'Down',
                    'state': 'stopped',
                    'ports': 'various'
                }
        except Exception as e:
            containers['frpc'] = {
                'status': 'Unknown',
                'state': 'unknown',
                'ports': 'various'
            }

        return containers
    except Exception as e:
        logger.error(f"获取服务状态失败: {e}")
        return {}

@app.route('/login', methods=['GET', 'POST'])
def login():
    """登录页面"""
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        if username == ADMIN_USERNAME and password == ADMIN_PASSWORD:
            session['authenticated'] = True
            session['username'] = username
            session.permanent = True
            flash('登录成功', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('用户名或密码错误', 'error')
    
    return render_template('login.html')

@app.route('/logout')
def logout():
    """退出登录"""
    session.clear()
    flash('已退出登录', 'info')
    return redirect(url_for('login'))

@app.route('/')
@require_auth
def dashboard():
    """仪表板页面"""
    return render_template('dashboard.html')

@app.route('/logs')
@require_auth
def logs():
    """日志查看页面"""
    return render_template('logs.html')

@app.route('/clients')
@require_auth
def clients():
    """客户端管理页面"""
    return render_template('clients.html')

# API接口
@app.route('/api/status')
@require_auth
def api_status():
    """获取服务状态"""
    try:
        # 获取Docker容器状态
        containers = get_docker_status()
        
        # 运行健康检查
        health_result = run_script('health-check.sh', '--format', 'json')
        health_data = {}
        if health_result['success']:
            try:
                health_data = json.loads(health_result['stdout'])
            except:
                pass
        
        # 获取系统信息
        uptime_result = subprocess.run(['uptime'], capture_output=True, text=True)
        uptime = uptime_result.stdout.strip() if uptime_result.returncode == 0 else 'Unknown'
        
        return jsonify({
            'success': True,
            'timestamp': datetime.now().isoformat(),
            'containers': containers,
            'health': health_data,
            'system': {
                'uptime': uptime,
                'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S')
            }
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/service/action', methods=['POST'])
@require_auth
def api_service_action():
    """服务操作"""
    try:
        data = request.get_json()
        action = data.get('action')  # start, stop, restart
        service = data.get('service', '')  # openvpn, frpc, frps, all

        if action not in ['start', 'stop', 'restart']:
            return jsonify({'success': False, 'error': '无效的操作'})

        # 使用真正的Docker服务操作
        result = docker_service_action(action, service)

        return jsonify({
            'success': result['success'],
            'message': result.get('stdout', ''),
            'error': result.get('stderr', '') if not result['success'] else None
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

def get_docker_logs(service='all', lines='100'):
    """获取Docker容器日志"""
    try:
        # 服务名称映射
        service_containers = {
            'all': ['openvpn', 'frpc', 'frps', 'openvpn-web'],
            'openvpn': ['openvpn'],
            'frpc': ['frpc'],
            'frps': ['frps'],
            'web': ['openvpn-web']
        }

        containers = service_containers.get(service, [service])
        all_logs = []

        for container in containers:
            try:
                # 检查容器是否存在
                check_result = subprocess.run(['docker', 'ps', '-a', '--filter', f'name={container}', '--format', '{{.Names}}'],
                                            capture_output=True, text=True, timeout=10)

                if check_result.returncode == 0 and container in check_result.stdout:
                    # 获取容器日志
                    log_result = subprocess.run(['docker', 'logs', '--tail', lines, container],
                                              capture_output=True, text=True, timeout=30)

                    if log_result.returncode == 0:
                        if log_result.stdout.strip():
                            all_logs.append(f"=== {container.upper()} LOGS ===")
                            all_logs.append(log_result.stdout.strip())
                            all_logs.append("")
                        if log_result.stderr.strip():
                            all_logs.append(f"=== {container.upper()} ERRORS ===")
                            all_logs.append(log_result.stderr.strip())
                            all_logs.append("")
                    else:
                        all_logs.append(f"=== {container.upper()} - 获取日志失败 ===")
                        all_logs.append(f"错误: {log_result.stderr}")
                        all_logs.append("")
                else:
                    if service != 'all':  # 只有在指定特定服务时才显示容器不存在的消息
                        all_logs.append(f"=== {container.upper()} - 容器不存在或未运行 ===")
                        all_logs.append("")

            except subprocess.TimeoutExpired:
                all_logs.append(f"=== {container.upper()} - 获取日志超时 ===")
                all_logs.append("")
            except Exception as e:
                all_logs.append(f"=== {container.upper()} - 错误 ===")
                all_logs.append(f"异常: {str(e)}")
                all_logs.append("")

        if not all_logs:
            return {
                'success': True,
                'logs': '暂无日志内容',
                'error': None
            }

        return {
            'success': True,
            'logs': '\\n'.join(all_logs),
            'error': None
        }

    except Exception as e:
        return {
            'success': False,
            'logs': '',
            'error': str(e)
        }

@app.route('/api/logs')
@require_auth
def api_logs():
    """获取日志"""
    try:
        service = request.args.get('service', 'all')
        lines = request.args.get('lines', '100')

        result = get_docker_logs(service, lines)

        return jsonify(result)
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/clients')
@require_auth
def api_clients():
    """获取客户端列表"""
    try:
        # 获取OpenVPN状态文件中的客户端信息
        status_file = '/var/log/openvpn/openvpn-status.log'
        clients = []
        
        if os.path.exists(status_file):
            with open(status_file, 'r') as f:
                content = f.read()
                # 简单解析状态文件
                lines = content.split('\n')
                in_client_section = False
                for line in lines:
                    if line.startswith('CLIENT_LIST'):
                        in_client_section = True
                        continue
                    elif line.startswith('ROUTING_TABLE'):
                        in_client_section = False
                        break
                    elif in_client_section and line.strip():
                        parts = line.split(',')
                        if len(parts) >= 5:
                            clients.append({
                                'name': parts[0],
                                'real_address': parts[1],
                                'virtual_address': parts[2],
                                'bytes_received': parts[3],
                                'bytes_sent': parts[4],
                                'connected_since': parts[5] if len(parts) > 5 else 'Unknown'
                            })
        
        return jsonify({
            'success': True,
            'clients': clients,
            'count': len(clients)
        })
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/client/create', methods=['POST'])
@require_auth
def api_create_client():
    """生成客户端配置"""
    try:
        data = request.get_json()
        client_name = data.get('name', '').strip()
        android_optimized = data.get('android', False)
        inline_certs = data.get('inline', True)

        if not client_name:
            return jsonify({'success': False, 'error': '客户端名称不能为空'})

        # 验证客户端名称格式
        import re
        if not re.match(r'^[a-zA-Z0-9_-]+$', client_name):
            return jsonify({'success': False, 'error': '客户端名称只能包含字母、数字、下划线和连字符'})

        # 首先检查是否需要生成证书
        cert_file = f'/app/pki/clients/{client_name}.crt'
        if not os.path.exists(cert_file):
            # 生成客户端证书
            logger.info(f"生成客户端证书: {client_name}")
            cert_result = run_script('generate-certs.sh', '--client', client_name)
            if not cert_result['success']:
                return jsonify({
                    'success': False,
                    'error': f'证书生成失败: {cert_result.get("stderr", "未知错误")}'
                })

        # 构建配置生成参数
        config_args = ['generate-client-config.sh', '--client', client_name]

        if android_optimized:
            config_args.append('--android')

        if inline_certs:
            config_args.append('--include-keys')

        # 设置输出目录
        config_args.extend(['--output', '/app/data/clients'])

        # 生成客户端配置
        logger.info(f"生成客户端配置: {client_name}")
        result = run_script(*config_args)

        if result['success']:
            return jsonify({
                'success': True,
                'message': f'客户端配置生成成功: {client_name}',
                'client_name': client_name,
                'config_path': f'/app/data/clients/{client_name}.ovpn'
            })
        else:
            return jsonify({
                'success': False,
                'error': f'配置生成失败: {result.get("stderr", result.get("stdout", "未知错误"))}'
            })

    except Exception as e:
        logger.error(f"客户端配置生成异常: {str(e)}")
        return jsonify({'success': False, 'error': str(e)})

@app.route('/api/health')
def api_health():
    """健康检查接口"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })

if __name__ == '__main__':
    # 开发模式
    app.run(host='0.0.0.0', port=5000, debug=True)
