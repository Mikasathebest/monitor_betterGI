# -*- coding: utf-8 -*-
"""背包采集计数报告: 解析 BGI 日志中的计数记录, 配对 before/after 输出每轮采集增量。

用法:  python scripts/inventory_report.py [最近场次数, 默认 6]
日志:  D:\\projects\\betterGI\\log\\better-genshin-impact*.log
说明:  counts 值 -2 = 数字识别失败; null = 该物品在背包未找到(视为 0 处理, 用 · 标注)
"""
import json
import re
import sys
from pathlib import Path

LOG_DIR = Path(r"D:\projects\betterGI\log")
LOG_NAME_RE = re.compile(r"^better-genshin-impact(\d{8})\.log$")
TS_RE = re.compile(r"^\[(\d{2}:\d{2}:\d{2})\.\d+\]")
COUNT_RE = re.compile(r"背包采集计数\[(before|after)\]\s+已记录\s+\d+/\d+\s+种:\s*(\{.*\})")


def load():
    logs = []
    for path in LOG_DIR.glob("better-genshin-impact*.log"):
        match = LOG_NAME_RE.match(path.name)
        if match:
            logs.append((match.group(1), path))
    if not logs:
        print(f"暂无日志: {LOG_DIR / 'better-genshin-impact*.log'}")
        sys.exit(0)

    recs = []
    for day, path in sorted(logs):
        lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
        # BGI 日志为两行格式: 时间戳头行的下一行才是计数正文
        for i in range(len(lines) - 1):
            ts = TS_RE.match(lines[i])
            if not ts:
                continue
            match = COUNT_RE.search(lines[i + 1])
            if not match:
                continue
            try:
                counts = json.loads(match.group(2))
            except json.JSONDecodeError:
                print(f"{path.name} 第{i + 2}行计数 JSON 解析失败, 已跳过")
                continue
            recs.append({
                "time": f"{day[:4]}-{day[4:6]}-{day[6:]} {ts.group(1)}",
                "phase": match.group(1),
                "counts": counts,
            })
    return recs


def main():
    n = int(sys.argv[1]) if len(sys.argv) > 1 else 6
    recs = load()
    # 顺序配对 before -> after
    pairs = []
    i = 0
    while i < len(recs) - 1:
        if recs[i].get("phase") == "before" and recs[i + 1].get("phase") == "after":
            pairs.append((recs[i], recs[i + 1]))
            i += 2
        else:
            i += 1
    if not pairs:
        print(f"共 {len(recs)} 条记录, 尚无完整 before/after 配对")
        for r in recs[-4:]:
            print(f"  {r.get('time')} [{r.get('phase')}]")
        return
    print(f"共 {len(recs)} 条记录, {len(pairs)} 场配对, 显示最近 {min(n, len(pairs))} 场\n")
    for b, a in pairs[-n:]:
        print(f"=== {b['time']} → {a['time']} ===")
        items = sorted(set(b.get("counts", {})) | set(a.get("counts", {})))
        any_gain = False
        for k in items:
            bv = b.get("counts", {}).get(k)
            av = a.get("counts", {}).get(k)
            if bv in (None, -2) or av in (None, -2):
                print(f"  {k:<12} {'·' if bv is None else '?':>8} → {'·' if av is None else '?':<8} (基准缺失)")
                continue
            d = av - bv
            flag = "  ←" if d > 0 else ""
            if d > 0:
                any_gain = True
            print(f"  {k:<12} {bv:>8} → {av:<8} ({d:+d}){flag}")
        if not any_gain:
            print("  (本场无新增)")
        print()


if __name__ == "__main__":
    main()
