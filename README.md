# monitor_betterGI

从 Mac 远程托管 Windows 上的 [BetterGI](https://github.com/babalae/better-genshin-impact) + 原神：每天定时上线清日常/体力、跑材料路线，Mac 端 LLM Agent 巡检和自动恢复。

**文档入口：[docs/betterGI/总入口.md](docs/betterGI/总入口.md)**（架构、当前生产状态、铁律、代码目录）。动手前先读 [错题本](docs/betterGI/错题本.md)。

## 快速开始（Mac）

```bash
python3 -m venv .venv && .venv/bin/pip install -r requirements.txt
cp .env.example .env   # 填 INFERENCE_API_KEY / BGI_SSH_HOST, 可选 FEISHU_WEBHOOK_URL

# 手动跑一次 Agent 巡检
.venv/bin/python scripts/agent/bgi_agent.py "$(cat scripts/agent/scheduled_mission.txt)"

# 定时巡检 (每场开始后 2 分钟)
nohup scripts/agent/daemon.sh >> captures/agent_daemon.log 2>&1 &

# 部署 / 检查 Windows 脚本是否与仓库一致
python3 scripts/win_sync.py push session_online.ps1
python3 scripts/win_sync.py diff

# 离线解析一份 BGI 日志 (材料统计 + 路线假跑识别)
python3 scripts/bgilog.py better-genshin-impact20261009.log

# 测试
python3 -m unittest discover tests
```

Agent 运行产物（transcript、截图、拉回的日志）在 `captures/agent_<时间戳>/`，不入库。

## 致谢

`scripts/bgilog.py` 的拾取统计与运行时长口径参考了 [CanLiang 参量质变仪](https://github.com/Because66666/CanLiang)（Apache-2.0）。
