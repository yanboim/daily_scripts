#!/bin/bash

# 磁盘监控哨兵卸载脚本
# 使用方法: sudo bash uninstall.sh

set -e

echo "=== 磁盘 I/O 哨兵 v3 卸载脚本 ==="
echo

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then
    echo "错误: 请使用 sudo 运行此脚本"
    exit 1
fi

# 确认卸载
read -p "确定要卸载磁盘监控哨兵吗？(y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "取消卸载"
    exit 0
fi

# 1. 停止并禁用服务
echo "步骤 1: 停止并禁用服务..."
if systemctl is-active --quiet disk-sentry.service 2>/dev/null; then
    systemctl stop disk-sentry.service
    echo "✅ 服务已停止"
fi

if systemctl is-enabled --quiet disk-sentry.service 2>/dev/null; then
    systemctl disable disk-sentry.service
    echo "✅ 服务已禁用"
fi

# 2. 删除服务文件
echo "步骤 2: 删除 systemd 服务文件..."
if [ -f /etc/systemd/system/disk-sentry.service ]; then
    rm /etc/systemd/system/disk-sentry.service
    echo "✅ 服务文件已删除"
fi

# 3. 删除脚本文件
echo "步骤 3: 删除监控脚本..."
if [ -f /usr/local/bin/disk_sentry.sh ]; then
    rm /usr/local/bin/disk_sentry.sh
    echo "✅ 脚本文件已删除"
fi

# 4. 重新加载 systemd
echo "步骤 4: 重新加载 systemd..."
systemctl daemon-reload

# 5. 询问是否删除日志文件
echo
read -p "是否删除日志文件？(/var/log/disk_pressure_monitor.log*) (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -f /var/log/disk_pressure_monitor.log ]; then
        rm -f /var/log/disk_pressure_monitor.log*
        echo "✅ 日志文件已删除"
    else
        echo "ℹ️ 日志文件不存在"
    fi
else
    echo "ℹ️ 日志文件保留在 /var/log/disk_pressure_monitor.log"
fi

echo
echo "🎉 卸载完成！磁盘监控哨兵已从系统中移除。"