#!/usr/bin/env python3
"""BGI 托管监控 Agent — LLM 驱动的 Windows 原神自动化监控/恢复代理

架构: Mac (本机, Agent 大脑) --ssh--> Windows (跑原神+BetterGI)
模型: us/azure/openai/eccn-gpt-5.6-sol (NVIDIA inference API, responses API + function calling)

工具集: 读代码/文档、截图、传代码到 Windows、执行代码、监控数据、记录数据
规则来源: 启动时读 docs/betterGI/{Agent运行手册,总入口,错题本}.md 拼进 system prompt,
          代码里不手抄规则 (手抄必然和文档漂移)

配置 (.env): INFERENCE_API_KEY, BGI_SSH_HOST, 可选 BGI_WIN_HOME / FEISHU_WEBHOOK_URL / AGENT_MAX_MINUTES
运行产物: captures/agent_<时间戳>/ (transcript.jsonl、上传过的脚本、截图、拉回的文件)
"""
import fcntl
import json
import os
import re
import subprocess
import sys
import time
import urllib.request
from datetime import datetime
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

ROOT = Path(__file__).resolve().parent.parent.parent  # 项目根
sys.path.insert(0, str(Path(__file__).resolve().parent))
sys.path.insert(0, str(ROOT / "scripts"))
from vision import analyze_image  # noqa: E402  CV 模型, 见 vision.py
from to_win import to_win_bytes  # noqa: E402
import bgilog  # noqa: E402  日志解析: 材料/路线监控

load_dotenv(ROOT / ".env")

SSH_HOST = os.environ.get("BGI_SSH_HOST", "")
WIN_HOME = os.environ.get("BGI_WIN_HOME", "C:/Users/djf20")
FEISHU_WEBHOOK_URL = os.environ.get("FEISHU_WEBHOOK_URL", "")
MODEL = "us/azure/openai/eccn-gpt-5.6-sol"
MAX_OUTPUT_TOKENS = 20480
MAX_ROUNDS = 80
MAX_SECONDS = int(os.environ.get("AGENT_MAX_MINUTES", "150")) * 60  # 场次 3h, 留余量
KEEP_FULL_OUTPUTS = 12   # 最近 N 个工具结果保留全文, 更早的截断, 防上下文爆
OLD_OUTPUT_CHARS = 600
WIN_SCRIPTS = ROOT / "scripts" / "win" / "prod"  # 生产脚本 (shot_s1/export_log_events 等)
RULE_DOCS = ["Agent运行手册.md", "总入口.md", "错题本.md"]

RUN_DIR = ROOT / "captures" / f"agent_{datetime.now():%Y%m%d_%H%M%S}"
TRANSCRIPT = RUN_DIR / "transcript.jsonl"
LOCK_FILE = ROOT / "captures" / "agent.lock"

_client = None


def llm() -> OpenAI:
    global _client
    if _client is None:
        _client = OpenAI(
            base_url="https://inference-api.nvidia.com/v1",
            api_key=os.environ["INFERENCE_API_KEY"],
            timeout=300.0,
            max_retries=5,  # SDK 自带指数退避: 连接错误/408/429/5xx
        )
    return _client


def log_event(kind: str, data):
    """全量审计: 每轮输入/工具调用/结果落盘 jsonl"""
    with TRANSCRIPT.open("a", encoding="utf-8") as f:
        f.write(json.dumps({"t": datetime.now().isoformat(), "kind": kind, "data": data},
                           ensure_ascii=False) + "\n")


def notify(title: str, body: str):
    """飞书自定义机器人推送; 未配置 webhook 则跳过。推送失败不影响主流程"""
    if not FEISHU_WEBHOOK_URL:
        return
    payload = {"msg_type": "text", "content": {"text": f"{title}\n{body[:3000]}\n\n{RUN_DIR.name}"}}
    req = urllib.request.Request(FEISHU_WEBHOOK_URL, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"})
    try:
        urllib.request.urlopen(req, timeout=10).read()
    except Exception as e:
        print(f"[notify] 飞书推送失败: {e}", flush=True)


def run(args: list[str], timeout: int = 120) -> tuple[int, str]:
    """本地执行命令 (列表参数, 不过 shell), 返回 (退出码, stdout+stderr 截断)"""
    try:
        r = subprocess.run(args, capture_output=True, text=True, errors="replace", timeout=timeout)
        code, out = r.returncode, (r.stdout + r.stderr).strip()
    except subprocess.TimeoutExpired:
        code, out = -1, f"[TIMEOUT after {timeout}s]"
    return code, out[-6000:]


def ssh_run(command: str, timeout: int = 120) -> str:
    """在 Windows 上执行命令 (cmd 语法)。铁律: 命令行里禁中文, 中文走 run_powershell 脚本文件"""
    code, out = run(["ssh", SSH_HOST, command], timeout=timeout)
    return out if code == 0 else f"[exit {code}]\n{out}"


def scp_from(remote_path: str, local: Path, timeout: int = 60) -> tuple[bool, str]:
    code, out = run(["scp", "-q", f"{SSH_HOST}:{remote_path}", str(local)], timeout=timeout)
    return code == 0 and local.exists(), out


def run_powershell(filename: str, content: str, timeout: int = 300, script_args: str = "") -> str:
    """写 ps1 → 转 BOM+CRLF → scp 到 Windows → 执行 → 回传输出

    远端文件名强制 _agent_ 前缀, 防止 Agent 覆盖 C:\\Users\\djf20 下的生产脚本。
    """
    name = Path(filename).name
    if not re.fullmatch(r"[\w.-]+\.ps1", name, flags=re.ASCII):
        return "拒绝: 文件名只能是 ASCII 字母数字/下划线/点/横线, 且以 .ps1 结尾"
    if not name.startswith("_agent_"):
        name = "_agent_" + name
    local = RUN_DIR / "ps1" / name
    local.parent.mkdir(exist_ok=True)
    local.write_bytes(to_win_bytes(content))
    code, up = run(["scp", "-q", str(local), f"{SSH_HOST}:{WIN_HOME}/{name}"], timeout=60)
    if code != 0:
        return f"scp 上传失败: {up}"
    win_path = WIN_HOME.replace("/", "\\") + "\\" + name
    out = ssh_run(f"powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File {win_path} {script_args}".rstrip(),
                  timeout=timeout)
    return f"[已上传为 {name}]\n{out}"


_shot_no = 0


def screenshot(question: str = "") -> str:
    """Session 1 截图 (SSH 直跑 CopyFromScreen 必败) → 拉回 Mac → CV 模型分析 → 返回文字结论

    注意: 截图任务会短暂抢前台焦点导致 BGI 暂停, 用完后游戏重新获焦会自动恢复, 不要过于频繁调用。
    """
    global _shot_no
    _shot_no += 1
    q = question or (
        "这是原神截图。请识别: 1) 当前界面(登录门-点击进入/大世界/队伍配置/地图/秘境/其他)? "
        "2) 如果在登录门界面, 明确指出'在门界面'; 如果在大世界, 指出当前队伍角色名(右下角/右侧头像); "
        "3) 有无弹窗/错误/卡住的迹象?")
    shot_ps1 = (WIN_SCRIPTS / "shot_s1.ps1").read_text(encoding="utf-8")
    r = run_powershell("_agent_shot_s1.ps1", shot_ps1, timeout=90)
    if "SHOT_OK" not in r:
        return f"截图失败(任务执行): {r[-500:]}"
    png = RUN_DIR / f"screen_{_shot_no:02d}.png"
    ok, err = scp_from(f"{WIN_HOME}/screen.png", png)
    if not ok or png.stat().st_size < 10000:
        return f"截图失败: 文件未拉回或过小 {err}"
    small = png.with_name(png.stem + "_small.png")
    run(["sips", "-Z", "1280", str(png), "--out", str(small)])
    try:
        analysis = analyze_image(str(small if small.exists() else png), q)
    except Exception as e:
        return f"截图成功但 CV 分析失败: {e} (原图 {png})"
    return f"[CV 画面分析] {analysis}"


def material_report(date: str = "", since: str = "") -> str:
    """Windows 端导出当天日志相关条目 → 拉回 → bgilog 解析 → 材料/路线报告 (含历史基线对比)

    过去的整天报告会存进 data/bgi_stats/ 作为之后的路线基线; 当天/部分时段不存。
    """
    today = datetime.now().strftime("%Y-%m-%d")
    date = date or today
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", date):
        return "date 格式应为 YYYY-MM-DD"
    if since and not re.fullmatch(r"\d{1,2}:\d{2}", since):
        return "since 格式应为 HH:MM"
    ymd = date.replace("-", "")
    exporter = (WIN_SCRIPTS / "export_log_events.ps1").read_text(encoding="utf-8")
    r = run_powershell("export_log_events.ps1", exporter, timeout=600, script_args=f"-Date {ymd}")
    if "EXPORT_NOLOG" in r:
        return f"Windows 上没有 {date} 的 BGI 日志"
    if "EXPORT_OK" not in r:
        return f"日志导出失败: {r[-800:]}"
    local = RUN_DIR / "fetch" / f"log_events_{ymd}.txt"
    local.parent.mkdir(exist_ok=True)
    ok, err = scp_from(f"{WIN_HOME}/_agent_log_events_{ymd}.txt", local, timeout=180)
    if not ok:
        return f"拉回导出文件失败: {err}"
    text = local.read_text(encoding="utf-8", errors="replace")
    _, md = bgilog.build_report(text, date, since or None, save=(date < today and not since))
    return md


def project_path(path: str) -> Path | None:
    """解析为项目内路径; 越界返回 None"""
    p = (ROOT / path).resolve()
    return p if p.is_relative_to(ROOT) else None


def read_file(path: str) -> str:
    p = project_path(path)
    if p is None:
        return "拒绝: 只能读项目目录内文件"
    if not p.is_file():
        return f"文件不存在: {path}"
    text = p.read_text(encoding="utf-8", errors="replace")
    return text[-12000:]


def list_files(path: str) -> str:
    p = project_path(path)
    if p is None:
        return "拒绝: 只能列项目目录"
    if not p.is_dir():
        return f"目录不存在: {path}"
    return "\n".join(sorted(x.name + ("/" if x.is_dir() else "") for x in p.iterdir()))


def fetch_remote_file(remote_path: str) -> str:
    local = RUN_DIR / "fetch" / f"{int(time.time())}_{Path(remote_path.replace(chr(92), '/')).name}"
    local.parent.mkdir(exist_ok=True)
    ok, err = scp_from(remote_path, local)
    if not ok:
        return f"拉取失败: {err}"
    return local.read_text(encoding="utf-8", errors="replace")[-10000:]


def write_record(path: str, content: str, append: bool = False) -> str:
    """docs/betterGI/logs/ 下可新建/覆盖; 其他 docs 文件只能追加 (防 Agent 冲掉错题本等)"""
    p = project_path(path)
    if p is None or not p.is_relative_to(ROOT / "docs"):
        return "拒绝: 只能写 docs/ 下的文件"
    if p.suffix != ".md":
        return "拒绝: 只能写 .md 文件"
    in_logs = p.is_relative_to(ROOT / "docs" / "betterGI" / "logs")
    if not in_logs and p.exists() and not append:
        return "拒绝: logs/ 以外的已有文档只能追加 (append=true)"
    p.parent.mkdir(parents=True, exist_ok=True)
    sep = "\n" if append and p.exists() else ""
    with p.open("a" if append else "w", encoding="utf-8") as f:
        f.write(sep + content)
    return f"已写入 {path} ({len(content)} 字符)"


TOOLS = [
    {"type": "function", "name": "read_file", "description": "读项目内文件 (docs/betterGI 经验文档、scripts 代码)。路径相对项目根, 如 docs/betterGI/一条龙.md",
     "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}},
    {"type": "function", "name": "list_files", "description": "列项目内目录内容",
     "parameters": {"type": "object", "properties": {"path": {"type": "string"}}, "required": ["path"]}},
    {"type": "function", "name": "ssh_run", "description": "在 Windows 执行 cmd 命令 (经 ssh)。禁止中文! 中文/复杂逻辑用 run_powershell。例: 'type C:\\Users\\djf20\\session_state.txt'",
     "parameters": {"type": "object", "properties": {"command": {"type": "string"}, "timeout": {"type": "integer"}}, "required": ["command"]}},
    {"type": "function", "name": "run_powershell", "description": "写 PowerShell 脚本(支持中文)→自动转 BOM+CRLF→传到 Windows→执行→返回输出。远端文件名会自动加 _agent_ 前缀(不会覆盖生产脚本), 结果里会告诉你实际文件名。详细结果写到 C:\\Users\\djf20\\xxx.txt 再 fetch 回来更稳",
     "parameters": {"type": "object", "properties": {"filename": {"type": "string"}, "content": {"type": "string"}, "timeout": {"type": "integer"}}, "required": ["filename", "content"]}},
    {"type": "function", "name": "fetch_remote_file", "description": "把 Windows 上的文件 scp 回 Mac 并返回内容(最后 10000 字符)。例: C:/Users/djf20/cycle_log.txt",
     "parameters": {"type": "object", "properties": {"remote_path": {"type": "string"}}, "required": ["remote_path"]}},
    {"type": "function", "name": "screenshot", "description": "拍 Windows 屏幕截图并用 CV 视觉模型分析, 返回文字结论。可传 question 指定要识别什么 (如'当前队伍角色是谁''是否在门界面')。注意: 会短暂抢焦点, 不要太频繁",
     "parameters": {"type": "object", "properties": {"question": {"type": "string"}}, "required": []}},
    {"type": "function", "name": "material_report", "description": "材料收集/路线健康报告: 解析 Windows 上某天的 BGI 日志, 返回 物品拾取统计(按配置组)、每条路线判定(ok/empty/fake 假跑/missing 路线文件缺失)、比历史基线明显变少的路线、高频异常。监控大组是否真在收材料时首选它, 比自己 grep 日志准。date 默认今天, since=HH:MM 只看某场次之后",
     "parameters": {"type": "object", "properties": {"date": {"type": "string"}, "since": {"type": "string"}}, "required": []}},
    {"type": "function", "name": "write_record", "description": "写 markdown 记录到 docs/ 下。docs/betterGI/logs/ 下可新建/覆盖; 收益.md/错题本.md 等已有文档必须 append=true 追加",
     "parameters": {"type": "object", "properties": {"path": {"type": "string"}, "content": {"type": "string"}, "append": {"type": "boolean"}}, "required": ["path", "content"]}},
]

HANDLERS = {
    "read_file": lambda a: read_file(a["path"]),
    "list_files": lambda a: list_files(a["path"]),
    "ssh_run": lambda a: ssh_run(a["command"], a.get("timeout", 120)),
    "run_powershell": lambda a: run_powershell(a["filename"], a["content"], a.get("timeout", 300)),
    "fetch_remote_file": lambda a: fetch_remote_file(a["remote_path"]),
    "screenshot": lambda a: screenshot(a.get("question", "")),
    "material_report": lambda a: material_report(a.get("date", ""), a.get("since", "")),
    "write_record": lambda a: write_record(a["path"], a["content"], a.get("append", False)),
}


def build_system_prompt() -> str:
    """角色说明 + 规则文档原文。规则只在文档维护"""
    parts = [
        "你是 BetterGI 原神托管系统的监控恢复 Agent, 运行在 Mac 上, 通过 ssh 控制 Windows 游戏机。",
        f"现在是 {datetime.now():%Y-%m-%d %H:%M} (Mac 本地时间)。",
        "以下是项目文档原文, 是你的全部规则来源。文档间有冲突时: 错题本 > Agent运行手册 > 总入口; "
        "同一文档内以日期更新的条目为准。需要细节时用 read_file 读 docs/betterGI/ 下的分册。",
    ]
    for name in RULE_DOCS:
        text = (ROOT / "docs" / "betterGI" / name).read_text(encoding="utf-8")
        parts.append(f"\n\n===== docs/betterGI/{name} =====\n{text}")
    return "\n".join(parts)


def compact_history(items: list):
    """把较早的工具结果截短 (原文已在 transcript 里), 控制上下文体积"""
    outputs = [it for it in items if it.get("type") == "function_call_output"]
    for it in outputs[:-KEEP_FULL_OUTPUTS]:
        if len(it["output"]) > OLD_OUTPUT_CHARS:
            it["output"] = it["output"][:OLD_OUTPUT_CHARS] + "\n...[较早的工具结果已截断]"


def message_text(o) -> str:
    return "".join(c.text for c in o.content if getattr(c, "text", None))


def run_agent(mission: str) -> tuple[str, str]:
    """返回 (状态, 最终结论文本)。状态: done / max_rounds / timeout"""
    started = time.monotonic()
    input_items = [
        {"role": "system", "content": build_system_prompt()},
        {"role": "user", "content": mission},
    ]
    last_text = ""
    for round_no in range(1, MAX_ROUNDS + 1):
        if time.monotonic() - started > MAX_SECONDS:
            return "timeout", last_text
        print(f"\n===== Round {round_no} =====", flush=True)
        compact_history(input_items)
        resp = llm().responses.create(
            model=MODEL, input=input_items, tools=TOOLS,
            max_output_tokens=MAX_OUTPUT_TOKENS,
        )
        # 回传 output 时手工重建, 只保留白名单字段: Azure 后端对 id/加密字段等会 400
        calls = []
        for o in resp.output:
            if o.type == "message":
                txt = message_text(o)
                if txt.strip():
                    last_text = txt
                    print(f"[Agent] {txt}", flush=True)
                    input_items.append({"role": "assistant", "content": txt})
            elif o.type == "function_call":
                calls.append(o)
                input_items.append({"type": "function_call", "call_id": o.call_id,
                                    "name": o.name, "arguments": o.arguments})
            # reasoning 等其他类型不回传
        log_event("round", {"n": round_no, "output_types": [o.type for o in resp.output],
                            "usage": resp.usage.model_dump() if resp.usage else None})
        if not calls:
            log_event("final", {"text": last_text})
            return "done", last_text
        for c in calls:
            print(f"[Tool] {c.name}({c.arguments[:200]})", flush=True)
            handler = HANDLERS.get(c.name)
            try:
                result = handler(json.loads(c.arguments)) if handler else f"未知工具: {c.name}"
            except Exception as e:
                result = f"工具执行异常: {type(e).__name__}: {e}"
            result = str(result)
            print(f"[Result] {result[:300]}", flush=True)
            log_event("tool", {"name": c.name, "args": c.arguments, "result": result})
            input_items.append({"type": "function_call_output", "call_id": c.call_id, "output": result})
    return "max_rounds", last_text


def acquire_lock():
    """单实例锁: daemon 定时触发与手动运行不能同时操作 Windows。返回的文件对象需保持存活"""
    LOCK_FILE.parent.mkdir(exist_ok=True)
    f = LOCK_FILE.open("a+")
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        f.seek(0)
        print(f"已有 Agent 在运行 ({f.read().strip()}), 退出", flush=True)
        sys.exit(2)
    f.seek(0)
    f.truncate()
    f.write(f"pid={os.getpid()} run={RUN_DIR.name}")
    f.flush()
    return f


def main():
    if len(sys.argv) < 2:
        sys.exit("用法: bgi_agent.py '<任务描述>'  (定时巡检任务见 scripts/agent/scheduled_mission.txt)")
    missing = [k for k in ("INFERENCE_API_KEY", "BGI_SSH_HOST") if not os.environ.get(k)]
    if missing:
        sys.exit(f"缺少环境变量: {', '.join(missing)} (见 .env.example)")
    mission = sys.argv[1]
    _lock = acquire_lock()  # noqa: F841  持有到进程退出
    RUN_DIR.mkdir(parents=True)
    print(f"Mission: {mission[:100]}...", flush=True)
    print(f"Run dir: {RUN_DIR}", flush=True)
    log_event("mission", {"text": mission})
    try:
        status, text = run_agent(mission)
    except Exception as e:
        log_event("crash", {"error": repr(e)})
        notify("❌ BGI Agent 异常退出", f"{type(e).__name__}: {e}")
        raise
    titles = {"done": "✅ BGI Agent 完成",
              "max_rounds": f"⚠️ BGI Agent 达到最大轮数 {MAX_ROUNDS}",
              "timeout": f"⚠️ BGI Agent 超时 ({MAX_SECONDS // 60} 分钟)"}
    print(f"[Agent] 结束: {status}", flush=True)
    notify(titles[status], text or "(无结论文本)")
    sys.exit(0 if status == "done" else 1)


if __name__ == "__main__":
    main()
