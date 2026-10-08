#!/bin/bash
# BGI Agent 常驻调度器: 每个场次后 2 分钟 (04:17/13:02/23:02) 触发 Agent 监控
# 场次作息 (2026-09-17 用户定稿): 早 04:15-07:15 / 午 13:00-16:00 / 夜 23:00-02:00
# 从 Cursor 终端启动 (继承 Documents 访问权), 绕开 launchd 的 TCC 限制:
#   nohup scripts/agent/daemon.sh >> captures/agent_daemon.log 2>&1 &
# 重启 Mac 后需重新启动 (长期方案: 打包 .app 授全权后用 launchd, 见 docs/betterGI/全自动托管.md)
cd "$(dirname "$0")/../.." || exit 1
MISSION_FILE=scripts/agent/scheduled_mission.txt
echo "$(date '+%F %T') daemon 启动 PID=$$"
while true; do
  now=$(date '+%H:%M')
  case "$now" in
    04:17|13:02|23:02)
      echo "$(date '+%F %T') 触发 Agent 监控场次"
      .venv/bin/python scripts/agent/bgi_agent.py "$(cat "$MISSION_FILE")" >> captures/agent_scheduled.log 2>&1
      echo "$(date '+%F %T') Agent 结束 exit=$?"
      sleep 70  # 跳过这一分钟, 防止同分钟重复触发
      ;;
  esac
  sleep 20
done
