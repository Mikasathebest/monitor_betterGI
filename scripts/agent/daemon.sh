#!/bin/bash
# BGI Agent 常驻调度器: 每个场次后 2 分钟 (04:17/23:02) 触发 Agent 监控
# 场次作息 (2026-10-12 起): 早 04:15 / 夜 23:00, 每场 5h 窗口; 午场已取消 (session_online 12-17 点触发直接跳过)
# 注意: 不要在午场时段触发 Agent —— 巡检任务第一步是"游戏没开就启动", 会把取消的场次拉起来
# 从 Cursor 终端启动 (继承 Documents 访问权), 绕开 launchd 的 TCC 限制:
#   nohup scripts/agent/daemon.sh >> captures/agent_daemon.log 2>&1 &
# 重启 Mac 后需重新启动 (长期方案: 打包 .app 授全权后用 launchd, 见 docs/betterGI/全自动托管.md)
cd "$(dirname "$0")/../.." || exit 1
MISSION_FILE=scripts/agent/scheduled_mission.txt
echo "$(date '+%F %T') daemon 启动 PID=$$"
while true; do
  now=$(date '+%H:%M')
  case "$now" in
    04:17|23:02)
      echo "$(date '+%F %T') 触发 Agent 监控场次"
      .venv/bin/python scripts/agent/bgi_agent.py "$(cat "$MISSION_FILE")" >> captures/agent_scheduled.log 2>&1
      echo "$(date '+%F %T') Agent 结束 exit=$?"
      sleep 70  # 跳过这一分钟, 防止同分钟重复触发
      ;;
  esac
  sleep 20
done
