#!/usr/bin/env python3
"""BGI 托管监控 Agent — LLM 驱动的 Windows 原神自动化监控/恢复代理

架构: Mac (本机, Agent 大脑) --ssh--> Windows (djf20@192.168.5.12, 跑原神+BetterGI)
模型: us/azure/openai/eccn-gpt-5.6-sol (NVIDIA inference API, responses API + function calling)

工具集: 读代码/文档、截图、传代码到 Windows、执行代码、监控数据、记录数据
铁律(来自 docs/betterGI/错题本.md, 已内化进 system prompt):
  - PS1 含中文必须 to_win.py 转 BOM+CRLF 再 scp
  - cmd 命令行禁中文; UI 操作必须 Session 1 计划任务 (InteractiveToken)
  - BGI 日志用 FileStream+ReadWrite 共享读; 大 JSON 用 python 改不用 PowerShell
"""
import json
import os
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

sys.path.insert(0, str(Path(__file__).resolve().parent))
from vision import analyze_image  # CV 模型: nvidia/qwen/eccn-qwen3.5-122b-a10b

ROOT = Path(__file__).resolve().parent.parent.parent  # 项目根
load_dotenv(ROOT / ".env")

SSH_HOST = "djf20@192.168.5.12"
WIN_HOME = "C:/Users/djf20"
MODEL = "us/azure/openai/eccn-gpt-5.6-sol"
MAX_OUTPUT_TOKENS = 20480  # 用户要求: 比 demo 的 1024 拉大 20 倍
MAX_ROUNDS = 80
TRANSCRIPT = ROOT / "captures" / f"agent_{datetime.now():%Y%m%d_%H%M%S}.jsonl"
TRANSCRIPT.parent.mkdir(exist_ok=True)

client = OpenAI(
    base_url="https://inference-api.nvidia.com/v1",
    api_key=os.environ["INFERENCE_API_KEY"],
    timeout=300.0,
)


def log_event(kind: str, data):
    """全量审计: 每轮输入/工具调用/结果落盘 jsonl"""
    with TRANSCRIPT.open("a", encoding="utf-8") as f:
        f.write(json.dumps({"t": datetime.now().isoformat(), "kind": kind, "data": data},
                           ensure_ascii=False) + "\n")


def sh(cmd: str, timeout: int = 120) -> str:
    """本地执行 shell, 返回 stdout+stderr (截断防爆)"""
    try:
        r = subprocess.run(cmd, shell=True, capture_output=True, text=True,
                           errors="replace", timeout=timeout)
        out = (r.stdout + r.stderr).strip()
    except subprocess.TimeoutExpired:
        out = f"[TIMEOUT after {timeout}s]"
    return out[-6000:] if len(out) > 6000 else out


def ssh_run(command: str, timeout: int = 120) -> str:
    """在 Windows 上执行命令 (cmd 语法)。铁律: 命令行里禁中文, 中文走 run_powershell 脚本文件"""
    return sh(f'ssh {SSH_HOST} "{command}"', timeout=timeout)


def run_powershell(filename: str, content: str, timeout: int = 300) -> str:
    """写 ps1 → to_win.py 转 BOM+CRLF → scp 到 Windows → 执行 → 回传输出"""
    local = ROOT / "scripts" / "win" / filename
    local.write_text(content, encoding="utf-8")
    conv = sh(f"python3 {ROOT}/scripts/to_win.py '{local}' /tmp/_agent_{filename}")
    if "Error" in conv:
        return f"to_win 转换失败: {conv}"
    up = sh(f"scp -q /tmp/_agent_{filename} {SSH_HOST}:{WIN_HOME}/{filename}")
    run = ssh_run(
        f"powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\\Users\\djf20\\{filename}",
        timeout=timeout)
    return f"[deploy] {conv}\n[scp] {up or 'ok'}\n[run]\n{run}"


def screenshot(question: str = "") -> str:
    """Session 1 截图 (SSH 直跑 CopyFromScreen 必败) → 拉回 Mac → CV 模型分析 → 返回文字结论

    注意: 截图任务会短暂抢前台焦点导致 BGI 暂停, 用完后游戏重新获焦会自动恢复, 不要过于频繁调用。
    """
    q = question or (
        "这是原神截图。请识别: 1) 当前界面(登录门-点击进入/大世界/队伍配置/地图/秘境/其他)? "
        "2) 如果在登录门界面, 明确指出'在门界面'; 如果在大世界, 指出当前队伍角色名(右下角/右侧头像); "
        "3) 有无弹窗/错误/卡住的迹象?")
    shot_ps1 = (ROOT / "scripts" / "win" / "shot_s1.ps1").read_text(encoding="utf-8")
    r = run_powershell("_agent_shot_s1.ps1", shot_ps1, timeout=90)
    if "SHOT_OK" not in r:
        return f"截图失败(任务执行): {r[-500:]}"
    sh(f"scp -q {SSH_HOST}:{WIN_HOME}/screen.png /tmp/_agent_screen.png", timeout=60)
    png = Path("/tmp/_agent_screen.png")
    if not png.exists() or png.stat().st_size < 10000:
        return "截图失败: 文件未拉回或过小"
    sh("sips -Z 1280 /tmp/_agent_screen.png --out /tmp/_agent_screen_small.png >/dev/null 2>&1")
    try:
        analysis = analyze_image("/tmp/_agent_screen_small.png", q)
    except Exception as e:
        return f"截图成功但 CV 分析失败: {e} (原图 /tmp/_agent_screen.png)"
    return f"[CV 画面分析] {analysis}"


def read_file(path: str) -> str:
    p = (ROOT / path).resolve()
    if not str(p).startswith(str(ROOT)):
        return "拒绝: 只能读项目目录内文件"
    if not p.exists():
        return f"文件不存在: {path}"
    text = p.read_text(encoding="utf-8", errors="replace")
    return text[-12000:] if len(text) > 12000 else text


def write_local_file(path: str, content: str, append: bool = False) -> str:
    p = (ROOT / path).resolve()
    if not str(p).startswith(str(ROOT / "docs")):
        return "拒绝: 只能写 docs/ 下的文件 (记录数据用途)"
    p.parent.mkdir(parents=True, exist_ok=True)
    if append and p.exists():
        with p.open("a", encoding="utf-8") as f:
            f.write("\n" + content)
    else:
        p.write_text(content, encoding="utf-8")
    return f"已写入 {path} ({len(content)} 字符)"


TOOLS = [
    {"type": "function", "name": "read_file", "description": "读项目内文件 (docs/betterGI 经验文档、scripts 代码)。路径相对项目根, 如 docs/betterGI/错题本.md",
     "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}},
    {"type": "function", "name": "list_files", "description": "列项目内目录内容",
     "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}},
    {"type": "function", "name": "ssh_run", "description": "在 Windows 执行 cmd 命令 (经 ssh)。禁止中文! 中文/复杂逻辑用 run_powershell。例: 'type C:\\Users\\djf20\\session_state.txt'",
     "parameters": {"type": "object", "properties": {"command": {"type": "string"}, "timeout": {"type": "integer"}}, "required": ["command"]}},
    {"type": "function", "name": "run_powershell", "description": "写 PowerShell 脚本(支持中文)→自动转 BOM+CRLF→传到 Windows→执行→返回输出。脚本里把详细结果写到 C:\\Users\\djf20\\xxx.txt 再 fetch 回来更稳",
     "parameters": {"type": "object", "properties": {"filename": {"type": "string"}, "content": {"type": "string"}, "timeout": {"type": "integer"}}, "required": ["filename", "content"]}},
    {"type": "function", "name": "fetch_remote_file", "description": "把 Windows 上的文件 scp 回 Mac 并返回内容。例: C:/Users/djf20/cycle_log.txt",
     "parameters": {"type": "object", "properties": {"remote_path": {"type": "string"}}, "required": ["remote_path"]}},
    {"type": "function", "name": "screenshot", "description": "拍 Windows 屏幕截图并用 CV 视觉模型分析, 返回文字结论。可传 question 指定要识别什么 (如'当前队伍角色是谁''是否在门界面')。注意: 会短暂抢焦点, 不要太频繁",
     "parameters": {"type": "object", "properties": {"question": {"type": "string"}}, "required": []}},
    {"type": "function", "name": "write_record", "description": "写记录到 docs/ 下 (收益台账/错题本/运行报告)。append=true 追加",
     "parameters": {"type": "object", "properties": {"path": {"type": "string"}, "content": {"type": "string"}, "append": {"type": "boolean"}}, "required": ["path", "content"]}},
]

SYSTEM_PROMPT = f"""你是 BetterGI 原神托管系统的监控恢复 Agent, 运行在 Mac 上, 通过 ssh 控制 Windows 游戏机 (djf20@192.168.5.12)。

## 系统架构 (6h 全自动循环)
- BGI_Session 计划任务 (04:30/10:30/16:30/22:30) → session_online.ps1: 预排 SessionEnd(+3h 下线) → 杀残留 → 起 BGI → 截图器 → 起游戏 → 进门 → F9 一条龙(清日常+体力) → 全自动循环大组(采矿/材料/钓鱼, 书签续跑) → PHASE=RUNNING
- BGI_Watchdog 每 30min 巡检, 按 C:\\Users\\djf20\\session_state.txt 的 PHASE 干预
- Windows 关键路径: BGI 目录 D:\\Projects\\better-genshin-impact\\BetterGenshinImpact\\bin\\Release\\net8.0-windows10.0.22621.0; 日志在其 log\\ 子目录; 脚本在 C:\\Users\\djf20\\*.ps1; 审计日志 cycle_log.txt / watchdog_log.txt / session_state.txt
- 游戏: E:\\YS\\miHoYo Launcher\\games\\Genshin Impact Game\\YuanShen.exe, 1920x1080 窗口化

## 铁律 (错题本精华, 违反必翻车)
1. cmd 命令行禁中文 (会 GBK 乱码); 中文逻辑一律 run_powershell 写脚本文件
2. ps1 已自动转 BOM+CRLF, 直接写中文内容即可
3. UI 操作 (UIA/点击) 必须在 Session 1: 用 schtasks 创建 InteractiveToken 计划任务再 /run; SSH 直跑是 Session 0 看不到窗口
4. 读 BGI 日志必须 FileStream+FileShare.ReadWrite (独占锁), 判活性看内容时间戳
5. 游戏启动后安静等 ≥1 分钟再点门, 低频轮询 (每 3s), 高频狂点会卡死登录。点击后用 screenshot(CV) 验证是否真进门 —— 卡登录背景时点击不生效, 需杀游戏重开再试
6. 大 JSON 配置别用 PowerShell ConvertFrom-Json 改 (会卡死); PowerShell 5.1 没有三元运算符
7. 现有可复用脚本 (C:\\Users\\djf20\\): uia_start_capture.ps1(起截图器), uia_start_group_named.ps1 -NameMatch '全自动循环'(起大组), enter_door.ps1(盲点进门), door_clicker.ps1(轮询进门), send_f9.ps1(一条龙), screen.ps1(截图, 只能 Session 1 跑), shot_s1.ps1(注册截图任务), run_s1.ps1 -ScriptName xxx.ps1(通用 Session 1 执行器), mon_now.ps1(大组监控), session_online.ps1(完整上线流程), cycle_offline.ps1(下线: 存书签+杀游戏+杀BGI)
8. 改任何配置前先读 docs/betterGI/错题本.md 和相关文档
9. 按天统计收益到 docs/betterGI/收益.md
10. 任何 Session 1 可见控制台任务都会抢前台焦点+遮挡游戏窗口 → 点击可能落空、BGI 暂停。UI/点击类操作一律用 run_s1_hidden.ps1 -ScriptName xxx.ps1 (wscript 隐藏运行, 无窗口); 只有 UIA 类必须用可见的 run_s1.ps1
11. 判断游戏状态不要猜, 用 screenshot (CV 模型会告诉你: 门界面(有无沙漏)/大世界/队伍配置/弹窗/当前队伍角色)。门上有沙漏=正在连服务器, 点击无效, 等沙漏消失再点
12. 严禁在 Windows 脚本里写"长 sleep + 杀进程/重启"的延时逻辑 —— 那是定时地雷: 即使你被杀掉, 脚本照样到点爆炸, 会把别人刚起好的游戏杀掉 (09-16 09:29 事故)。等待和重试节奏由你自己用工具调用轮询控制, Windows 脚本只做即时动作
13. 进门流程 (用户定): 起游戏后安静等 2 分钟 → run_s1_hidden.ps1 跑 door_clicker2.ps1 (6s 一次盲点, 隐藏不抢焦点) → 你每 30s screenshot CV 验证一次 → 进大世界后立即杀掉 door_clicker2 进程 (Stop-Process 按 CommandLine 匹配 door_clicker2)
## 你的工作方式
- 先诊断再动手; 每步用日志/截图验证; 拿不准就截图看
- 重要发现和结果用 write_record 记录 (收益→docs/betterGI/收益.md, 新坑→docs/betterGI/错题本.md, 报告→docs/betterGI/agent_runs.md)
- 输出简洁中文结论到 docs/betterGI/logs/年月日_Agent_结论.md"""


def dispatch(name: str, args: dict):
    if name == "read_file":
        return read_file(args["path"]), None
    if name == "list_files":
        p = (ROOT / args["path"]).resolve()
        if not str(p).startswith(str(ROOT)):
            return "拒绝: 只能列项目目录", None
        return "\n".join(sorted(x.name + ("/" if x.is_dir() else "") for x in p.iterdir())), None
    if name == "ssh_run":
        return ssh_run(args["command"], args.get("timeout", 120)), None
    if name == "run_powershell":
        return run_powershell(args["filename"], args["content"], args.get("timeout", 300)), None
    if name == "fetch_remote_file":
        local = f"/tmp/_agent_fetch_{int(time.time())}.txt"
        r = sh(f"scp -q '{SSH_HOST}:{args['remote_path']}' {local}", timeout=60)
        p = Path(local)
        if p.exists():
            text = p.read_text(encoding="utf-8", errors="replace")
            return (text[-10000:] if len(text) > 10000 else text), None
        return f"拉取失败: {r}", None
    if name == "screenshot":
        return screenshot(args.get("question", "")), None
    if name == "write_record":
        return write_local_file(args["path"], args["content"], args.get("append", False)), None
    return f"未知工具: {name}", None


def run_agent(mission: str):
    input_items = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": mission},
    ]
    for round_no in range(1, MAX_ROUNDS + 1):
        print(f"\n===== Round {round_no} =====", flush=True)
        resp = client.responses.create(
            model=MODEL, input=input_items, tools=TOOLS,
            max_output_tokens=MAX_OUTPUT_TOKENS,
        )
        # 回传 output 时手工重建, 只保留白名单字段: Azure 后端对 id/加密字段等会 400
        for o in resp.output:
            if o.type == "message":
                txt = "".join(c.text for c in o.content if getattr(c, "text", None))
                if txt.strip():
                    input_items.append({"role": "assistant", "content": txt})
            elif o.type == "function_call":
                input_items.append({"type": "function_call", "call_id": o.call_id,
                                    "name": o.name, "arguments": o.arguments})
            # reasoning 等其他类型不回传
        calls = [o for o in resp.output if o.type == "function_call"]
        texts = [o for o in resp.output if o.type == "message"]
        for t in texts:
            msg = "".join(c.text for c in t.content if getattr(c, "text", None))
            if msg.strip():
                print(f"[Agent] {msg}", flush=True)
        log_event("round", {"n": round_no, "output_types": [o.type for o in resp.output],
                            "usage": resp.usage.model_dump() if resp.usage else None})
        if not calls:
            log_event("final", {"text": ["".join(c.text for c in t.content if getattr(c, "text", None)) for t in texts]})
            return
        for c in calls:
            print(f"[Tool] {c.name}({c.arguments[:200]})", flush=True)
            try:
                result, img = dispatch(c.name, json.loads(c.arguments))
            except Exception as e:
                result, img = f"工具执行异常: {e}", None
            print(f"[Result] {str(result)[:300]}", flush=True)
            log_event("tool", {"name": c.name, "args": c.arguments, "result": str(result)[:3000]})
            input_items.append({"type": "function_call_output", "call_id": c.call_id, "output": str(result)})
    print("[Agent] 达到最大轮数, 停止", flush=True)


if __name__ == "__main__":
    mission = sys.argv[1] if len(sys.argv) > 1 else (
        "当前故障: 22:30 场次 session_online 在启动 BGI 约 75 秒等待期间被杀 (任务结果码 3221225786=0xC000013A), "
        "游戏进程不存在, BGI 在跑但空转, PHASE 卡在 STARTING。10:30 场次也在 F9 等待阶段同样中断。"
        "请你: 1) 先读 docs/betterGI/错题本.md 和 docs/betterGI/全自动托管.md 了解背景; "
        "2) 诊断场次被杀的根因 (查 watchdog_log.txt、计划任务历史、Windows 事件日志); "
        "3) 恢复管线: 让游戏进大世界、跑一条龙清日常和体力、再续跑全自动循环大组; "
        "4) 截图确认游戏状态, 用日志确认大组在跑; "
        "5) 把诊断结论和恢复过程记录到 docs/betterGI/agent_runs.md, 新发现的坑记到错题本。")
    print(f"Mission: {mission[:100]}...", flush=True)
    print(f"Transcript: {TRANSCRIPT}", flush=True)
    run_agent(mission)
