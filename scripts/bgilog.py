#!/usr/bin/env python3
"""BGI 日志解析: 材料收集/路线健康监控 (纯标准库, Mac/Windows 通用)

解析思路参考 CanLiang (github.com/Because66666/CanLiang, Apache-2.0):
  - "交互或拾取" 行计物品, 按所属配置组归类, 过滤 调查/直接拾取
  - 日志时间段 (间隔 >5min 切段) 求有效运行时长
在其之上加了本项目需要的: 按路线统计、假跑/空路线识别、与历史基线对比找"坏掉的路线"

日志格式 (Serilog, 一条两行; 也兼容消息与头在同一行):
  [20:38:12.345] [INF] BetterGenshinImpact.Service.ScriptService
  开始执行地图追踪任务: "09-柔灯铃"

用法:
  python3 scripts/bgilog.py <日志或导出文件> [--date 2026-10-09] [--since 13:00] [--save] [--json]
  --save: 把当天汇总存到 data/bgi_stats/<date>.json, 作为后续日期的路线基线
"""
import argparse
import json
import re
import statistics
import sys
from collections import Counter
from dataclasses import asdict, dataclass, field
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
STATS_DIR = ROOT / "data" / "bgi_stats"

HEADER = re.compile(r"^\[(\d{2}):(\d{2}):(\d{2})(?:\.\d+)?\] \[(\w+)\]\s?(.*)$")
GROUP_START = re.compile(r'配置组 "([^"]*)" 加载完成，共(\d+)个脚本，开始执行')
GROUP_END = re.compile(r'配置组 "([^"]*)" 执行结束')
TASK_START = re.compile(r'开始执行(\S*?)[:：]\s*"([^"]+)"')
TASK_END = re.compile(r'执行结束[:：]\s*"([^"]+)"')
PICKUP = re.compile(r'交互或拾取[:：]\s*"?([^"\n]+?)"?\s*$')
IGNORED_ITEMS = {"调查", "直接拾取"}  # 非物品的交互, 同 CanLiang
ONEDRAGON_END = "一条龙和配置组任务结束"
ERROR_LEVELS = {"ERR", "ERROR", "FTL", "FATAL"}
ERROR_HINTS = re.compile(r"未能返回主界面|脱困|卡住|超时|异常")
SEGMENT_GAP = 300          # 日志间隔超过 5 分钟视为两段运行 (同 CanLiang)
FAKE_RUN_SECONDS = 20      # 错题本 §6: 健康路线应 >20s 且有传送
MISSING_ROUTE_SECONDS = 1  # 伊安珊文档: 路线文件不存在 = 0.003s 假成功


@dataclass
class Entry:
    t: int        # 当天秒数 (跨午夜已展开为 >86400)
    level: str
    msg: str


@dataclass
class TaskRun:
    name: str
    kind: str                 # 地图追踪任务 / JS脚本 / ...
    group: str | None
    start: int
    end: int | None = None
    pickups: Counter = field(default_factory=Counter)
    teleports: int = 0
    fights: int = 0
    errors: int = 0

    @property
    def duration(self) -> int | None:
        return None if self.end is None else self.end - self.start

    @property
    def verdict(self) -> str:
        """ok / missing(路线文件不存在) / fake(假跑) / empty(真跑了但没拾取) / running"""
        d = self.duration
        if d is None:
            return "running"
        if d <= MISSING_ROUTE_SECONDS:
            return "missing"
        if d < FAKE_RUN_SECONDS and self.teleports == 0 and not self.pickups:
            return "fake"
        if not self.pickups:
            return "empty"
        return "ok"


def parse_entries(text: str) -> list[Entry]:
    """头行 + 后续消息行合并为条目; 时间回绕 (跨午夜) 时 +24h"""
    entries: list[Entry] = []
    day_offset, last_t = 0, -1
    for line in text.splitlines():
        m = HEADER.match(line)
        if m:
            t = int(m[1]) * 3600 + int(m[2]) * 60 + int(m[3])
            if last_t >= 0 and t + day_offset < last_t - 3600:
                day_offset += 86400
            t += day_offset
            last_t = t
            entries.append(Entry(t, m[4], m[5].strip()))
        elif entries and line.strip():
            e = entries[-1]
            # 两行格式: 头行尾是类名, 真正的消息在下一行 → 消息替换类名
            e.msg = line.strip() if "\n" not in e.msg and _looks_like_class(e.msg) else e.msg + "\n" + line.strip()
    return entries


def _looks_like_class(s: str) -> bool:
    return not s or bool(re.fullmatch(r"\[?[\w.`<>]+\]?", s))


def hhmm_to_seconds(s: str) -> int:
    h, m = s.split(":")[:2]
    return int(h) * 3600 + int(m) * 60


def fmt_t(t: int) -> str:
    t %= 86400
    return f"{t // 3600:02d}:{t % 3600 // 60:02d}:{t % 60:02d}"


def analyze(text: str, since: str | None = None) -> dict:
    entries = parse_entries(text)
    if since:
        cutoff = hhmm_to_seconds(since)
        entries = [e for e in entries if e.t >= cutoff]

    tasks: list[TaskRun] = []
    groups: list[dict] = []
    cur_group: str | None = None
    cur_task: TaskRun | None = None
    items_total: Counter = Counter()
    items_by_group: dict[str, Counter] = {}
    errors = Counter()
    onedragon_done = []

    for e in entries:
        msg = e.msg
        if m := GROUP_START.search(msg):
            cur_group = m[1]
            groups.append({"name": m[1], "scripts": int(m[2]), "start": fmt_t(e.t), "end": None})
        elif (m := GROUP_END.search(msg)) and cur_group == m[1]:
            groups[-1]["end"] = fmt_t(e.t)
            cur_group = None
        elif m := TASK_START.search(msg):
            if cur_task and cur_task.end is None:  # 上一条没写结束就开始新任务 → 以此刻为结束
                cur_task.end = e.t
            cur_task = TaskRun(name=m[2], kind=m[1] or "任务", group=cur_group, start=e.t)
            tasks.append(cur_task)
        elif (m := TASK_END.search(msg)) and cur_task and cur_task.name == m[1]:
            cur_task.end = e.t
        elif m := PICKUP.search(msg):
            item = m[1].strip()
            if item not in IGNORED_ITEMS:
                items_total[item] += 1
                items_by_group.setdefault(cur_group or "(无配置组)", Counter())[item] += 1
                if cur_task and cur_task.end is None:
                    cur_task.pickups[item] += 1
        if ONEDRAGON_END in msg:
            onedragon_done.append(fmt_t(e.t))
        if cur_task and cur_task.end is None:
            if "传送完成" in msg:
                cur_task.teleports += 1
            if "战斗结束" in msg:
                cur_task.fights += 1
        # 关键词只看引号外文本: 路线名里的"卡住"等字样不算异常
        is_err = e.level.upper() in ERROR_LEVELS or ERROR_HINTS.search(re.sub(r'"[^"]*"', "", msg))
        if is_err:
            errors[_error_key(msg)] += 1
            if cur_task and cur_task.end is None:
                cur_task.errors += 1

    verdicts = Counter(t.verdict for t in tasks)
    return {
        "range": [fmt_t(entries[0].t), fmt_t(entries[-1].t)] if entries else None,
        "active_seconds": active_seconds([e.t for e in entries]),
        "groups": groups,
        "onedragon_done": onedragon_done,
        "items_total": dict(items_total.most_common()),
        "items_by_group": {g: dict(c.most_common()) for g, c in items_by_group.items()},
        "task_verdicts": dict(verdicts),
        "tasks": [_task_dict(t) for t in tasks],
        "top_errors": dict(errors.most_common(8)),
    }


def _error_key(msg: str) -> str:
    """错误消息归一化: 去数字/引号内容, 便于聚合计数"""
    first = msg.splitlines()[-1]
    return re.sub(r'"[^"]*"|\d+(\.\d+)?', "#", first)[:80]


def _task_dict(t: TaskRun) -> dict:
    d = asdict(t)
    d["pickups"] = dict(t.pickups)
    d["start"] = fmt_t(t.start)
    d["end"] = None if t.end is None else fmt_t(t.end)
    d["duration"] = t.duration
    d["verdict"] = t.verdict
    return d


def active_seconds(times: list[int]) -> int:
    """日志时间按 >5min 间隔切段, 各段时长求和 (CanLiang 同款口径)"""
    total, seg_start, last = 0, None, None
    for t in times:
        if last is None or t - last > SEGMENT_GAP:
            if seg_start is not None:
                total += last - seg_start
            seg_start = t
        last = t
    if seg_start is not None:
        total += last - seg_start
    return total


# ---------- 历史基线: 找"以前能捡到东西, 今天捡不到"的路线 ----------

def load_baseline(before_date: str, days: int = 14) -> dict[str, list[int]]:
    """读 data/bgi_stats 下 before_date 之前最近 N 天, 返回 路线名 → 每次运行拾取数列表"""
    hist: dict[str, list[int]] = {}
    files = sorted(p for p in STATS_DIR.glob("*.json") if p.stem < before_date)[-days:]
    for p in files:
        for t in json.loads(p.read_text(encoding="utf-8")).get("tasks", []):
            if t["verdict"] in ("ok", "empty"):
                hist.setdefault(t["name"], []).append(sum(t["pickups"].values()))
    return hist


def route_regressions(report: dict, baseline: dict[str, list[int]], min_median: float = 3) -> list[dict]:
    out = []
    for t in report["tasks"]:
        runs = baseline.get(t["name"])
        if not runs or t["verdict"] == "running":
            continue
        med = statistics.median(runs)
        got = sum(t["pickups"].values())
        if med >= min_median and got <= med * 0.3:
            out.append({"name": t["name"], "group": t["group"], "got": got, "median": med,
                        "verdict": t["verdict"], "start": t["start"]})
    return out


def to_markdown(report: dict, regressions: list[dict] | None = None, title: str = "") -> str:
    L = [f"### {title}" if title else "### BGI 材料/路线报告"]
    if not report["range"]:
        return L[0] + "\n\n(无日志条目)"
    L.append(f"- 日志范围 {report['range'][0]}–{report['range'][1]}，有效运行 {report['active_seconds'] // 60} 分钟")
    if report["onedragon_done"]:
        L.append(f"- 一条龙完成：{', '.join(report['onedragon_done'])}")
    for g in report["groups"]:
        L.append(f"- 配置组「{g['name']}」{g['scripts']} 个脚本，{g['start']} → {g['end'] or '未结束'}")
    v = report["task_verdicts"]
    if v:
        L.append("- 任务判定：" + "，".join(f"{k}={n}" for k, n in sorted(v.items())))
    bad = v.get("fake", 0) + v.get("missing", 0)
    total = sum(v.values())
    if total and bad / total > 0.5:
        L.append(f"- ⚠️ **假跑告警**：{bad}/{total} 条任务为假跑/空路线（见错题本 §6，先截图查弹窗）")

    if report["items_total"]:
        L.append("\n| 物品 | 数量 |\n|---|---|")
        L += [f"| {k} | {n} |" for k, n in list(report["items_total"].items())[:30]]
        if len(report["items_total"]) > 30:
            L.append(f"| …其余 {len(report['items_total']) - 30} 种 | |")
    else:
        L.append("- 本时段**无拾取记录**")

    suspects = [t for t in report["tasks"] if t["verdict"] in ("fake", "missing")]
    if suspects:
        L.append(f"\n**假跑/缺失路线 {len(suspects)} 条**（前 10）：")
        L += [f"- {t['start']} {t['name']}（{t['duration']}s，{t['verdict']}）" for t in suspects[:10]]
    if regressions:
        L.append(f"\n**比历史基线明显变少的路线 {len(regressions)} 条**（可能路线失效/被挡/矿点未刷新）：")
        L += [f"- {r['start']} {r['name']}：本次 {r['got']}，历史中位 {r['median']:g}" for r in regressions[:15]]
    if report["top_errors"]:
        L.append("\n**高频异常**：")
        L += [f"- ×{n} {k}" for k, n in report["top_errors"].items()]
    return "\n".join(L)


def build_report(text: str, date: str, since: str | None = None, save: bool = False) -> tuple[dict, str]:
    """解析 + 基线对比 + markdown。save 仅在整天统计 (无 since) 时落盘"""
    report = analyze(text, since)
    regressions = route_regressions(report, load_baseline(date))
    if save and not since:
        STATS_DIR.mkdir(parents=True, exist_ok=True)
        (STATS_DIR / f"{date}.json").write_text(
            json.dumps({"date": date, **report}, ensure_ascii=False, indent=1), encoding="utf-8")
    title = f"{date} BGI 材料/路线报告" + (f"（{since} 起）" if since else "")
    return report, to_markdown(report, regressions, title)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("log")
    ap.add_argument("--date", help="日志日期 YYYY-MM-DD (默认从文件名 better-genshin-impactYYYYMMDD 推断)")
    ap.add_argument("--since", help="只统计 HH:MM 之后")
    ap.add_argument("--save", action="store_true", help="存当天汇总到 data/bgi_stats 作基线")
    ap.add_argument("--json", action="store_true", help="输出 JSON 而不是 markdown")
    a = ap.parse_args()
    date = a.date
    if not date:
        m = re.search(r"(\d{4})(\d{2})(\d{2})", Path(a.log).name)
        date = f"{m[1]}-{m[2]}-{m[3]}" if m else "unknown"
    text = Path(a.log).read_text(encoding="utf-8", errors="replace")
    report, md = build_report(text, date, a.since, a.save)
    print(json.dumps(report, ensure_ascii=False, indent=1) if a.json else md)


if __name__ == "__main__":
    sys.exit(main())
