#!/bin/bash

# 锁定语言环境为 C，确保 df/iotop/stat 等命令的输出格式一致
export LANG=C
export LC_ALL=C

################################################################################
#
# 脚本名称: 磁盘 I/O 哨兵 v3 (Disk I/O Sentry v3)
# 适用系统: Linux (Debian/RHEL-based)
# 依赖工具: iotop, lsof, df, du, awk, sed, stat, mv
#
# ----------
# ** 脚本作用 (v3 安全版) **
# ----------
#
# 解决"瞬时磁盘爆满"后无法定位元凶的问题。
#
# v3 版本核心安全特性：
# 1. [日志自管理]: 防止本脚本的日志文件无限增长撑爆磁盘 (MAX_LOG_SIZE)。
# 2. [依赖检查]: 启动时检查所有依赖命令，防止关键时刻掉链子。
# 3. [环境锁定]: 强制 LANG=C，防止因系统语言不同导致 df 等命令解析失败。
# 4. [精确定位]: 增加 [证据 4]，lsof -p <PID>，反查元凶进程打开的具体文件。
#
################################################################################

# --- 配置区 (请根据需要修改) ---

# 1. 监控分区
MONITORED_PARTITION="/"

# 2. 触发阈值 (百分比, 不带%)
THRESHOLD=80

# 3. 日志文件位置
LOG_FILE="/var/log/disk_pressure_monitor.log"

# 4. 检查间隔 (秒)
SLEEP_INTERVAL=5

# 5. 重点怀疑目录 (数组, 用空格隔开)
SUSPECT_DIRS=("/var/log" "/tmp")

# 6. [v3 安全] 哨兵日志最大大小 (50MB = 50 * 1024 * 1024 = 52428800 bytes)
MAX_LOG_SIZE=52428800

# --- 脚本主逻辑 ---

# [v3 安全] 步骤 1: 启动时依赖检查
COMMANDS_NEEDED="iotop lsof df du awk sed stat mv"
for cmd in $COMMANDS_NEEDED; do
    if ! command -v "$cmd" &> /dev/null; then
        # 同时输出到 stderr (systemctl status 可见) 和日志文件
        echo "[$(date)] [致命错误] 依赖命令 '$cmd' 未找到。请安装它。" | tee -a "$LOG_FILE" >&2
        exit 1
    fi
done

# 步骤 2: 初始化日志文件
touch "$LOG_FILE"
if [ $? -ne 0 ]; then
    echo "[$(date)] [致命错误] 无法创建或写入日志文件 $LOG_FILE。请检查权限。" >&2
    exit 1
fi

echo "--- 磁盘I/O哨兵(v3)已启动 [$(date)] ---" | tee -a "$LOG_FILE"
echo "监控分区: $MONITORED_PARTITION" | tee -a "$LOG_FILE"
echo "触发阈值: ${THRESHOLD}%" | tee -a "$LOG_FILE"
echo "重点分析目录: ${SUSPECT_DIRS[*]}" | tee -a "$LOG_FILE"
echo "日志自管理大小: $(($MAX_LOG_SIZE / 1024 / 1024))MB" | tee -a "$LOG_FILE"
echo "----------------------------------------------------" | tee -a "$LOG_FILE"


# 步骤 3: 主循环
while true; do

    # [v3 安全] 步骤 3.1: 日志自管理 (防自爆)
    # 每次循环前都检查日志文件大小
    if [ -f "$LOG_FILE" ] && [ $(stat -c%s "$LOG_FILE") -gt "$MAX_LOG_SIZE" ]; then
        # 备份旧日志, 并清空当前日志文件 (使用 > 而不是 >>)
        mv "$LOG_FILE" "$LOG_FILE.1"
        echo "[$(date)] 哨兵日志已轮替 (超过 $(($MAX_LOG_SIZE / 1024 / 1024))MB)" > "$LOG_FILE"
    fi

    # 步骤 3.2: 获取当前磁盘使用率
    CURRENT_USAGE=$(df -P "$MONITORED_PARTITION" | awk 'NR==2 {print $5}' | sed 's/%//')

    # 检查是否成功获取
    if ! [[ "$CURRENT_USAGE" =~ ^[0-9]+$ ]]; then
        echo "[$(date)] 错误：无法解析 '$MONITORED_PARTITION' 的磁盘使用率。" >> "$LOG_FILE"
        sleep 60 # 出错时休息1分钟
        continue
    fi

    # 步骤 3.3: 检查是否超过阈值
    if [ "$CURRENT_USAGE" -ge "$THRESHOLD" ]; then

        # --- 触发告警！开始取证 ---
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> "$LOG_FILE"
        echo "!! 告警触发: $MONITORED_PARTITION 使用率 $CURRENT_USAGE% (阈值 $THRESHOLD%)" >> "$LOG_FILE"
        echo "!! 快照时间: $(date)" >> "$LOG_FILE"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!" >> "$LOG_FILE"

        # [证据 1] Top I/O 进程 (iotop)
        # 运行一次, 存入变量, 供 证据 1 和 4 共同使用
        echo "--- [证据 1] Top I/O 进程 (by iotop) ---" >> "$LOG_FILE"
        IOTOP_OUTPUT=$(iotop -b -n 1 -o -P || echo "iotop 运行出错")
        echo "$IOTOP_OUTPUT" >> "$LOG_FILE"

        # [证据 2] 已删除但未释放的文件 (lsof)
        echo "" >> "$LOG_FILE"
        echo "--- [证据 2] 已删除但未释放的文件 (by lsof +L1) ---" >> "$LOG_FILE"
        (lsof +L1 "$MONITORED_PARTITION" 2>/dev/null || echo "lsof +L1 运行出错或未找到") >> "$LOG_FILE"

        # [证据 3] 可疑目录大小分析 (du)
        echo "" >> "$LOG_FILE"
        echo "--- [证据 3] 可疑目录大小分析 (Top 15) ---" >> "$LOG_FILE"
        for dir in "${SUSPECT_DIRS[@]}"; do
            echo "" >> "$LOG_FILE"
            echo "--- 分析中: $dir ---" >> "$LOG_FILE"
            (du -sh "$dir"/* 2>/dev/null | sort -rh | head -n 15 || echo "du 运行 '$dir' 出错或目录为空") >> "$LOG_FILE"
        done

        # [v3 功能] [证据 4] 精确定位: 反查元凶 PID 打开的文件
        echo "" >> "$LOG_FILE"
        echo "--- [证据 4] 元凶进程文件句柄分析 (by lsof -p PID) ---" >> "$LOG_FILE"

        # 从 [证据 1] 的输出中解析出第一个 PID (更健壮的解析)
        TOP_PID=$(echo "$IOTOP_OUTPUT" | awk 'NR > 2 && $1 ~ /^[0-9]+$/ {print $1; exit}')

        if [[ "$TOP_PID" =~ ^[0-9]+$ ]]; then
            echo "分析 Top I/O 进程 PID: $TOP_PID" >> "$LOG_FILE"
            # 使用 lsof 反查该 PID 打开的所有文件
            (lsof -p "$TOP_PID" 2>/dev/null || echo "lsof 无法分析 PID: $TOP_PID") >> "$LOG_FILE"
        else
            echo "无法从 iotop 输出中自动解析元凶 PID。" >> "$LOG_FILE"
        fi

        echo "--------------------------------------------------------------" >> "$LOG_FILE"

        # 告警触发后，休息30秒，避免日志刷屏
        sleep 30

    else
        # 步骤 3.4: 未超过阈值，正常休眠
        sleep "$SLEEP_INTERVAL"

    fi
done