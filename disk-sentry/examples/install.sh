#!/bin/bash

# 磁盘监控哨兵自动安装脚本
# 使用方法: sudo bash install.sh

set -e

echo "=== 磁盘 I/O 哨兵 v3 安装脚本 ==="
echo

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用 sudo 运行此脚本"
    exit 1
fi

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "项目目录: $PROJECT_DIR"
echo

# 1. 安装依赖
echo "步骤 1: 检查并安装依赖..."
if command -v apt-get &> /dev/null; then
    # Debian/Ubuntu 系统
    echo "检测到 Debian/Ubuntu 系统"
    apt-get update
    apt-get install -y iotop lsof
elif command -v yum &> /dev/null; then
    # RHEL/CentOS 系统
    echo "检测到 RHEL/CentOS 系统"
    yum install -y iotop lsof
elif command -v dnf &> /dev/null; then
    # Fedora 系统
    echo "检测到 Fedora 系统"
    dnf install -y iotop lsof
else
    echo "警告: 无法自动检测包管理器，请手动安装 iotop 和 lsof"
fi

# 2. 复制脚本文件
echo "步骤 2: 安装监控脚本..."
cp "$PROJECT_DIR/src/disk_sentry.sh" /usr/local/bin/disk_sentry.sh
chmod +x /usr/local/bin/disk_sentry.sh

# 3. 复制服务文件
echo "步骤 3: 安装 systemd 服务..."
cp "$PROJECT_DIR/config/disk-sentry.service" /etc/systemd/system/disk-sentry.service

# 4. 重新加载 systemd
echo "步骤 4: 重新加载 systemd..."
systemctl daemon-reload

# 5. 启用并启动服务
echo "步骤 5: 启用并启动服务..."
systemctl enable disk-sentry.service
systemctl start disk-sentry.service

# 6. 检查服务状态
echo "步骤 6: 检查服务状态..."
sleep 2
if systemctl is-active --quiet disk-sentry.service; then
    echo "✅ 服务启动成功！"
    echo
    echo "服务状态:"
    systemctl status disk-sentry.service --no-pager
    echo
    echo "安装完成！"
    echo
    echo "使用以下命令查看日志:"
    echo "  tail -f /var/log/disk_pressure_monitor.log"
    echo
    echo "使用以下命令管理服务:"
    echo "  启动: sudo systemctl start disk-sentry"
    echo "  停止: sudo systemctl stop disk-sentry"
    echo "  重启: sudo systemctl restart disk-sentry"
    echo "  状态: sudo systemctl status disk-sentry"
else
    echo "❌ 服务启动失败！"
    echo
    echo "查看详细错误信息:"
    journalctl -xeu disk-sentry.service
    exit 1
fi