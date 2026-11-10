# -*- coding: utf-8 -*-
"""背包采集计数报告: 读取 BGI 侧 inventory_log.jsonl, 配对 before/after 输出每轮采集增量。

用法:  python scripts/inventory_report.py [最近场次数, 默认 6]
日志:  D:\\projects\\betterGI\\User\\JsScript\\背包采集计数\\inventory_log.jsonl
说明:  counts 值 -2 = 数字识别失败; null = 该物品在背包未找到(视为 0 处理, 用 · 标注)
"""
import json
import sys
from pathlib import Path

LOG = Path(r"D:\projects\betterGI\User\JsScript\背包采集计数\inventory_log.jsonl")


def load():
    if not LOG.exists():
        print(f"暂无日志: {LOG}")
        sys.exit(0)
    recs = []
    for ln, line in enumerate(LOG.read_text(encoding="utf-8").splitlines(), 1):
        line = line.strip()
        if not line:
            continue
        try:
            recs.append(json.loads(line))
        except json.JSONDecodeError:
            print(f"第{ln}行解析失败, 已跳过")
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
