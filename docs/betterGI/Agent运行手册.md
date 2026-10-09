# Agent 运行手册

> `scripts/agent/bgi_agent.py` 每次启动时把本文件 + [总入口.md](总入口.md) + [错题本.md](错题本.md) 原文拼进 system prompt。
> **改规则只改文档，不要改代码里的 prompt**——文档就是 Agent 的唯一规则来源。
> 总入口: [总入口.md](总入口.md)

## 1. 环境

- Mac（Agent 大脑）经 ssh 控制 Windows 游戏机，主机名见 `.env` 的 `BGI_SSH_HOST`
- Windows 脚本与审计文件目录：`C:\Users\djf20\`
  - 审计：`cycle_log.txt`（会话时间线）/ `watchdog_log.txt`（30min 一行）/ `session_state.txt`（`PHASE=STARTING/RUNNING/OFFLINE` + `ACTIVE_UNTIL`）
- BGI 目录：`D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0`，日志在其 `log\` 子目录
- 游戏：`E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe`，1920x1080 窗口化
- 场次作息、管线内容、看门狗：以 [总入口.md](总入口.md)「当前生产状态」为准

## 2. 工具使用约定

- `ssh_run`：cmd 语法，**命令行禁中文**（GBK 乱码）。中文/复杂逻辑用 `run_powershell`
- `run_powershell`：自动转 BOM+CRLF 后上传执行。远端文件名**强制加 `_agent_` 前缀**，不会覆盖生产脚本；要在 Session 1 跑就用 `run_s1_hidden.ps1 -ScriptName _agent_xxx.ps1`
- `screenshot`：会短暂抢焦点导致 BGI 暂停，不要频繁调用（两次之间 ≥30s）
- `write_record`：`docs/betterGI/logs/` 下可新建/覆盖；其他 docs 文件**只能追加**
- `material_report(date, since)`：**监控材料收集首选**。Windows 端 `export_log_events.ps1` 流式导出日志相关条目 → Mac 端 `scripts/bgilog.py` 解析，给出：
  - 物品拾取统计（按配置组）、一条龙完成时间、有效运行时长
  - 每条路线判定：`ok` / `empty`（真跑了没捡到）/ `fake`（<20s 且无传送无拾取，错题本 §6 假跑）/ `missing`（≤1s，路线文件不存在）
  - **比历史基线明显变少的路线**（近 14 天中位数 ≥3、本次 ≤30%）→ 路线失效/被挡的信号
  - 过去的整天报告自动存 `data/bgi_stats/<日期>.json` 作为基线；巡检时可补跑昨天：`material_report(date=昨天)`
- 详细结果让脚本写到 `C:\Users\djf20\xxx.txt` 再 `fetch_remote_file` 拉回，比直接看 stdout 稳

## 3. Windows 端可复用脚本（`C:\Users\djf20\`）

| 脚本 | 用途 |
|---|---|
| `session_online.ps1` | 完整上线流程 |
| `cycle_offline.ps1` | 下线：存书签 + 杀游戏 + 杀 BGI |
| `run_s1_hidden.ps1 -ScriptName xxx.ps1` | Session 1 隐藏执行（点击/UI 类一律用它） |
| `run_s1.ps1 -ScriptName xxx.ps1` | Session 1 可见执行（仅 UIA 类，会抢焦点） |
| `door_clicker2.ps1` | 隐藏 6s 盲点进门（进大世界后按 CommandLine 匹配杀掉） |
| `enter_door.ps1` | 单次 PostMessage 点门 |
| `uia_start_capture.ps1` | 起截图器 |
| `uia_start_group_named.ps1 -NameMatch '全自动循环'` | 按名启动大组 |
| `send_f9.ps1` | 触发一条龙 |
| `esc_s1.ps1` | 关弹窗 |
| `mon_now.ps1` | 大组监控 |
| `fix_proxy.ps1` / `fix_protocol.ps1` | 代理自愈 / 协议弹窗修复 |

## 4. 工作方式

- 先诊断再动手；每步用日志/截图验证；拿不准就截图看，**不要猜游戏状态**
- 每次 Session 1 操作后等 30-60s 看日志再下一步，不要密集操作
- 等待/重试节奏由你用工具轮询控制，Windows 脚本只做即时动作（禁止定时地雷，见错题本）
- 记录：结论写 `docs/betterGI/logs/YYYY-MM-DD_HHMM_Agent.md`；收益追加 `docs/betterGI/收益.md`；新坑追加 `docs/betterGI/错题本.md`
- 最终回复用简洁中文：做了什么、当前状态、是否需要人工介入（会推送到飞书）
