#!/bin/bash
# launchd 定时触发 BGI Agent — 监控 6h 场次是否正常跑通
cd /Users/harryd/Documents/projects/GenshinDetect
MISSION="现在是凌晨场次刚触发的时间。请监控 Windows 端 04:30 场次 (BGI_Session → session_online.ps1) 是否正常跑通: 1) 拉 C:/Users/djf20/cycle_log.txt 看场次是否开始; 2) 检查 session_state.txt 的 PHASE 是否从 STARTING 进入 RUNNING; 3) 关键节点用 screenshot 验证: 游戏是否进大世界 (门界面卡住就按错题本处理: 确认冻结后杀游戏重开); 4) 确认 F9 一条龙启动并跑完 (日志出现'一条龙和配置组任务结束'), 然后大组续跑; 5) 任何一步卡住超过预期, 先诊断再修复, 修复手段参考 docs/betterGI/错题本.md 和 docs/betterGI/全自动托管.md; 6) 写结论到 docs/betterGI/logs/2026-09-16_0430场次_Agent.md。注意铁律: 不要密集操作 Windows, 每次 Session 1 操作后等 30-60s。"
exec .venv/bin/python scripts/agent/bgi_agent.py "$MISSION" >> captures/agent_scheduled.log 2>&1
