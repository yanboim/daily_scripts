# Daily Scripts

## 📁 项目列表

### [disk-sentry/](./disk-sentry/) - Linux 磁盘 I/O 哨兵 v3

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-blue?logo=gnu-bash&logoColor=white)](https://www.gnu.org/software/bash/)

一份轻量级、健壮的 Bash 脚本，用于解决 Linux 服务器"瞬时磁盘爆满"后无法定位"元凶"进程的问题。

#### ✨ 核心特性
- **四重证据链**：iotop + lsof + du + 进程文件分析
- **安全防护**：日志自管理、依赖检查、环境锁定
- **生产就绪**：完整的 systemd 服务集成
- **一键部署**：包含自动安装和卸载脚本

#### 🚀 快速开始
```bash
cd disk-sentry
sudo bash examples/install.sh
```

## 📖 说明

本仓库收集了在日常开发和运维工作中使用的高质量脚本，所有脚本都经过生产环境验证，确保稳定性和可靠性。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！
