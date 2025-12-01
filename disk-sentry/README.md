# Linux 磁盘 I/O 哨兵 (Disk I/O Sentry) v3

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Systemd](https://img.shields.io/badge/Service-Systemd-green?logo=systemd&logoColor=white)](https://systemd.io/)

一份轻量级、健壮的 Bash 脚本，用于解决 Linux 服务器"瞬时磁盘爆满"后无法定位"元凶"进程的问题。

当 Prometheus 等监控系统告警磁盘已满，但管理员登录时 `logrotate` 或其他清理任务已执行，导致现场丢失。此脚本专为抓取这一"瞬时快照"而设计。

## 🌟 核心特性

### v3 网络增强版

- **📊 五重证据链**：全面捕获磁盘问题的根本原因和网络连接
  - [证据 1] `iotop` - 实时 I/O 最高的进程
  - [证据 2] `lsof +L1` - 已删除但未释放的文件句柄
  - [证据 3] `du` - 可疑目录的 Top 15 大文件分析
  - [证据 4] `lsof -p PID` - 元凶进程的具体文件访问记录
  - [证据 5] `网络连接分析` - 元凶进程的网络连接和端口占用

- **🛡️ 安全防护**：
  - **日志自管理**：防止哨兵自己的日志无限增长（默认 50MB 轮替）
  - **启动依赖检查**：确保 `iotop`、`lsof` 等工具已安装
  - **环境锁定**：强制 `LANG=C`，确保跨语言环境兼容性

- **⚙️ 生产就绪**：
  - **Systemd 集成**：完整的 systemd 服务配置
  - **自动重启**：服务异常时自动重启
  - **资源轻量**：最小化系统资源占用

## 🚀 快速开始

### 一键安装（推荐）

```bash
# 下载项目
git clone https://github.com/yourusername/disk-sentry.git
cd disk-sentry

# 运行自动安装脚本（默认使用增强版）
sudo bash examples/install.sh
```

**✨ v3 网络增强版优势**：
- 保持原 v3 的所有稳定性和可靠性
- 新增网络连接分析功能，快速定位问题来源
- 帮助识别是哪个应用程序或客户端 IP 导致的磁盘压力
- 适合排查复杂的 Web 应用、数据库服务等场景

### 升级到增强版

如果你已经在使用原版 v3 脚本，升级到增强版非常简单：

```bash
# 备份现有脚本
sudo cp /usr/local/bin/disk_sentry.sh /usr/local/bin/disk_sentry.sh.backup

# 部署更新版
sudo cp src/disk_sentry.sh /usr/local/bin/disk_sentry.sh
sudo chmod +x /usr/local/bin/disk_sentry.sh

# 重启服务
sudo systemctl restart disk-sentry
sudo systemctl status disk-sentry
```

### 手动安装

如果需要自定义配置，可以按照以下步骤手动安装：

#### 1. 安装依赖

```bash
# Debian / Ubuntu
sudo apt-get update && sudo apt-get install -y iotop lsof

# RHEL / CentOS / Fedora
sudo yum install -y iotop lsof
# 或者 sudo dnf install -y iotop lsof
```

#### 2. 部署脚本

```bash
# 复制脚本到系统路径（v3 网络增强版）
sudo cp src/disk_sentry.sh /usr/local/bin/disk_sentry.sh
sudo chmod +x /usr/local/bin/disk_sentry.sh

# 复制 systemd 服务文件
sudo cp config/disk-sentry.service /etc/systemd/system/disk-sentry.service
```

#### 3. 启动服务

```bash
sudo systemctl daemon-reload
sudo systemctl enable disk-sentry.service
sudo systemctl start disk-sentry.service
sudo systemctl status disk-sentry.service
```

## 📁 项目结构

```
disk-sentry/
├── src/                          # 源代码目录
│   └── disk_sentry.sh           # v3 网络增强版监控脚本
├── config/                      # 配置文件目录
│   └── disk-sentry.service      # Systemd 服务配置
├── examples/                    # 示例和工具
│   ├── install.sh              # 自动安装脚本
│   ├── uninstall.sh            # 卸载脚本
│   └── disk_sentry_custom.conf # 自定义配置示例
└── README.md                    # 项目文档
```

## ⚙️ 配置说明

脚本顶部的配置区域可以根据实际需求进行调整：

```bash
# 监控配置
MONITORED_PARTITION="/"          # 监控的分区（默认根分区）
THRESHOLD=80                     # 触发阈值（百分比）
SLEEP_INTERVAL=5                 # 检查间隔（秒）

# 日志配置
LOG_FILE="/var/log/disk_pressure_monitor.log"
MAX_LOG_SIZE=52428800            # 日志轮替大小（50MB）

# 监控目录
SUSPECT_DIRS=("/var/log" "/tmp") # 重点分析目录
```

## 🕵️ 使用指南

### 日常使用

部署后，哨兵会在后台持续运行，无需人工干预。当磁盘使用率超过设定阈值时，会自动记录详细的现场信息。

### 事后分析

当收到磁盘告警后，可以通过以下命令查看 captured 的证据：

```bash
# 查看最新的告警记录（显示最近一次触发的完整快照）
grep -A 50 "!! 告警触发" /var/log/disk_pressure_monitor.log | tail -n 51

# 实时监控日志
tail -f /var/log/disk_pressure_monitor.log

# 查看服务状态
sudo systemctl status disk-sentry

# 查看服务日志
sudo journalctl -u disk-sentry -f
```

### 证据解读

告警触发后，日志会包含五个关键证据：

1. **[证据 1] Top I/O 进程**：显示当前磁盘 I/O 最高的进程
2. **[证据 2] 已删除未释放文件**：发现被删除但仍占用空间的文件
3. **[证据 3] 目录大小分析**：分析指定目录下的大文件
4. **[证据 4] 进程文件句柄**：详细分析元凶进程的文件访问
5. **[证据 5] 网络连接分析**（v3 增强版）：显示元凶进程的网络连接统计和主要连接来源

**网络连接分析示例**：
```
--- [证据 5] 网络连接分析 (PID: 32655) ---
监听端口: 3306/mysql
连接统计: 总连接 11 个，来自 3 个不同 IP
主要连接来源:
  172.17.100.123: 11 个连接
```

## 🛠️ 管理操作

### 服务管理

```bash
# 启动服务
sudo systemctl start disk-sentry

# 停止服务
sudo systemctl stop disk-sentry

# 重启服务
sudo systemctl restart disk-sentry

# 查看状态
sudo systemctl status disk-sentry

# 查看详细日志
sudo journalctl -xeu disk-sentry.service
```

### 配置更新

1. 编辑脚本配置：
   ```bash
   sudo nano /usr/local/bin/disk_sentry.sh
   ```

2. 重启服务使配置生效：
   ```bash
   sudo systemctl restart disk-sentry
   ```

### 卸载

```bash
# 使用提供的卸载脚本
sudo bash examples/uninstall.sh

# 或手动卸载
sudo systemctl stop disk-sentry
sudo systemctl disable disk-sentry
sudo rm /etc/systemd/system/disk-sentry.service
sudo rm /usr/local/bin/disk_sentry.sh
sudo systemctl daemon-reload
```

## 🔧 高级配置

### 自定义监控目录

编辑脚本中的 `SUSPECT_DIRS` 数组：

```bash
# 监控多个关键目录
SUSPECT_DIRS=(
    "/var/log"
    "/tmp"
    "/opt/app/logs"
    "/home/user/tmp"
)
```

### 调整告警阈值

根据服务器类型和业务需求调整阈值：

```bash
# 生产服务器建议设置为 80%
THRESHOLD=80

# 测试环境可以设置为 90%
THRESHOLD=90
```

### 日志轮替策略

根据存储需求调整日志大小：

```bash
# 生产环境建议 100MB
MAX_LOG_SIZE=104857600

# 资源受限环境可以设置为 20MB
MAX_LOG_SIZE=20971520
```

## 🐛 故障排除

### 常见问题

1. **服务启动失败**
   ```bash
   # 检查依赖是否安装
   which iotop lsof

   # 查看详细错误
   sudo journalctl -xeu disk-sentry.service
   ```

2. **权限问题**
   ```bash
   # 确保脚本有执行权限
   sudo chmod +x /usr/local/bin/disk_sentry.sh

   # 检查日志文件权限
   sudo touch /var/log/disk_pressure_monitor.log
   sudo chmod 644 /var/log/disk_pressure_monitor.log
   ```

3. **依赖缺失**
   ```bash
   # 安装所需依赖
   # Debian/Ubuntu
   sudo apt-get install iotop lsof

   # RHEL/CentOS
   sudo yum install iotop lsof
   ```

### 调试模式

如果需要调试，可以临时修改脚本：

```bash
# 在脚本开头添加调试输出
set -x  # 启用调试模式

# 或者降低阈值进行测试
THRESHOLD=1  # 立即触发告警用于测试
```

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！

### 开发环境设置

```bash
# 克隆项目
git clone https://github.com/yanboim/daily_scripts.git
cd disk-sentry

# 在开发环境测试
sudo bash src/disk_sentry.sh
```

### 提交规范

- 代码风格遵循 Shell Style Guide
- 提交信息使用 Conventional Commits 规范
- 新功能需要添加相应的测试和文档

## 📄 许可证

本项目采用 [MIT 许可证](LICENSE)。
---

**⚡ 让磁盘问题无处可藏！** 🚀