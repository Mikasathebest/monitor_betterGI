#!/bin/bash
# feishu-bot 服务健康检查（在 MacBook 上执行；从 Windows 用:
#   ssh harryd@100.101.217.73 'bash -s' < scripts/mac/feishu_health.sh）
# 文档: ai_analyze_automation 仓库 docs/feishu-bot服务.md
set -u
LABEL=com.harryd.feishu-bot
DOMAIN=gui/$(id -u)

echo "=== launchd 状态 ==="
launchctl print "$DOMAIN/$LABEL" 2>/dev/null | grep -E 'state =|pid =|runs =|last exit code' || echo "未加载: bash scripts/install_feishu_bot_launchd.sh"

echo "=== 日志尾(最近启动/连接) ==="
LOG="$HOME/Documents/projects/financial_projects/analyze_automation/logs/feishu_bot.launchd.log"
tail -6 "$LOG" 2>/dev/null

echo "=== llmproxy(9002) 依赖 ==="
lsof -nP -iTCP:9002 -sTCP:LISTEN 2>/dev/null | tail -1 || echo "llmproxy 未运行"

echo "=== GUI 会话(Background=已登出; TCC 问题取证用) ==="
launchctl managername