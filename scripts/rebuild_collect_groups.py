# -*- coding: utf-8 -*-
"""重建收集组: 按配额瘦身穿自动循环, 拆成 收集A组(早场)/收集B组(午场)。

背景 (2026-10-15 用户需求):
- 每天场次从头循环 → 组头材料溢出、组尾材料 (慕风蘑菇 idx170-178 / 风车菊 idx163-169) 永远采不到
- 削减: 万相石全删; 异种合成魔兽/发条机关 → 1/3; 丘丘萨满/丘丘人射手 → 1/5;
        紫晶块/水晶块(跨5个folder合计) → 1/5; 树脂监控 JS → 1/3
- 主组 全自动循环.json 就地瘦身 (set_bookmark.py 按路线名在主组定位, 索引空间必须一致)
- A/B = 主组前/后缀连续拆分; 早场跑 A、午场跑 B, 每天两组都从头 → 全材料每日覆盖

用法: 先确认 BetterGI.exe 已关闭!  python scripts/rebuild_collect_groups.py [--dry-run]
"""
import json
import shutil
import sys
from collections import OrderedDict
from pathlib import Path

BASE = Path(r"D:\projects\betterGI")
GROUP_DIR = BASE / "User" / "ScriptGroup"
MASTER = GROUP_DIR / "全自动循环.json"
GROUP_A = GROUP_DIR / "收集A组.json"
GROUP_B = GROUP_DIR / "收集B组.json"
REPO_BACKUP = Path(__file__).resolve().parent.parent / "backups"

# folderName -> 保留条数 (未列出的类别全保留)
KEEP_BY_FOLDER = OrderedDict([
    ("特产-须弥-万相石", 0),
    ("敌人-异种合成魔兽", 2),      # 6 → 1/3
    ("敌人-发条机关", 3),          # 8 → 1/3
    ("敌人-丘丘萨满", 2),          # 12 → 1/5
    ("敌人-丘丘人射手", 3),        # 15 → 1/5
    ("紫晶块-大剑", 3),            # 14 → 1/5
])
SHUIJING_KEEP = 4      # 水晶块 5 个 folder 合计 19 → 1/5 ≈ 4
JS_NAME_KEEP = 4       # 树脂监控 JS 12 → 1/3
JS_NAME = "树脂监控"


def cat_of(p):
    if p.get("type") == "Javascript":
        return "JS-" + str(p.get("name"))
    return str(p.get("folderName") or "(无folder)")


def main():
    dry = "--dry-run" in sys.argv
    group = json.loads(MASTER.read_text(encoding="utf-8-sig"))
    projs = group["projects"]
    print(f"原组条数: {len(projs)}")

    # 原始分类统计
    stat = OrderedDict()
    for p in projs:
        stat[cat_of(p)] = stat.get(cat_of(p), 0) + 1
    print("--- 原始分类 ---")
    for k, v in stat.items():
        print(f"{v:4d}  {k}")

    # 先备份
    if not dry:
        REPO_BACKUP.mkdir(exist_ok=True)
        bak = REPO_BACKUP / f"全自动循环.{len(projs)}.20261015.json"
        if not bak.exists():
            shutil.copyfile(MASTER, bak)
            print(f"已备份 → {bak}")

    # 1) 按类别削减 (保持原始交错顺序, 类内均匀间隔保留, 每天采的点位更多样)
    pos_by_cat = OrderedDict()
    for i, p in enumerate(projs):
        pos_by_cat.setdefault(cat_of(p), []).append(i)

    shuijing_pos = []
    for cat, poss in pos_by_cat.items():
        if cat.startswith("水晶块"):
            shuijing_pos.extend(poss)

    keep_pos = set()
    for cat, poss in pos_by_cat.items():
        if cat.startswith("水晶块"):
            continue  # 水晶块跨 folder 合计, 后面统一处理
        if cat == f"JS-{JS_NAME}":
            keep_n = JS_NAME_KEEP
        elif cat in KEEP_BY_FOLDER:
            keep_n = KEEP_BY_FOLDER[cat]
        else:
            keep_n = len(poss)  # 不削减
        n = len(poss)
        if keep_n >= n:
            keep_pos.update(poss)
            continue
        idxs = [round(i * n / keep_n) for i in range(keep_n)]
        keep_pos.update(poss[i] for i in idxs)
        print(f"削减 {cat}: {n} → {keep_n} (保留序号 {idxs})")

    n = len(shuijing_pos)
    keep_n = min(SHUIJING_KEEP, n)   # 主组若已提前瘦身, 不能超过实际条数
    idxs = [round(i * n / keep_n) for i in range(keep_n)]
    keep_pos.update(shuijing_pos[i] for i in idxs)
    print(f"削减 水晶块(跨folder合计): {n} → {keep_n} (保留序号 {idxs})")

    kept = [p for i, p in enumerate(projs) if i in keep_pos]

    print(f"\n瘦身后: {len(kept)} 条 (原 {len(projs)})")
    stat2 = OrderedDict()
    for p in kept:
        stat2[cat_of(p)] = stat2.get(cat_of(p), 0) + 1
    print("--- 削减对照 (原→新) ---")
    for k in stat:
        if stat2.get(k, 0) != stat[k]:
            print(f"{k}: {stat[k]} → {stat2.get(k, 0)}")

    # 2) 连续对半拆 A/B (A=前缀, B=后缀), 再把 A 内多余的树脂监控 JS 挪到 B 中段
    #    (原 JS 集中在组头 idx0-24 簇, 均匀采样后仍全落 A; 午场 4h 也需要树脂检查)
    half = len(kept) // 2
    a, b = kept[:half], kept[half:]

    def is_js(p):
        return p.get("type") == "Javascript" and str(p.get("name")) == JS_NAME

    js_a = [i for i, p in enumerate(a) if is_js(p)]
    while len(js_a) > 2:
        p = a.pop(js_a.pop())          # 挪 A 内最靠后的 JS
        b.insert(len(b) // 2, p)
        js_a = [i for i, q in enumerate(a) if is_js(q)]
    kept = a + b                        # 主组 = 平衡后的 A+B, 保证书签索引一致
    print(f"树脂监控分布: A={sum(1 for p in a if is_js(p))} B={sum(1 for p in b if is_js(p))}")

    # 3) A/B 组首尾挂 背包采集计数 JS (before/after), 主组不挂 (不影响书签索引)
    def counter(phase):
        return {
            "name": "背包采集计数", "folderName": "背包采集计数",
            # 必须是 JSON 对象: BGI 用 dynamic(ExpandoObject) 反序列化, 写成字符串会抛
            # InvalidCastException → 整组读取失败、组从调度器列表消失 (11-10 事故)
            "jsScriptSettingsObject": {"phase": phase},
            "index": 0, "type": "Javascript", "status": "Enabled", "schedule": "Daily",
            "runNum": 1, "allowJsNotification": True, "allowJsHTTPHash": "",
        }
    a = [counter("before")] + a + [counter("after")]
    b = [counter("before")] + b + [counter("after")]

    # 4) 重编号 + 落盘
    def renum(lst, start=0):
        for j, p in enumerate(lst):
            p["index"] = start + j

    if not dry:
        renum(kept)
        group["projects"] = kept
        MASTER.write_text(json.dumps(group, ensure_ascii=False, indent=2), encoding="utf-8")

        for path, lst, name in ((GROUP_A, a, "收集A组"), (GROUP_B, b, "收集B组")):
            sub = {
                "index": 0,
                "name": name,
                "config": group.get("config", {}),
                "projects": [],
            }
            for j, p in enumerate(lst):
                q = dict(p)
                q["index"] = j
                sub["projects"].append(q)
            path.write_text(json.dumps(sub, ensure_ascii=False, indent=2), encoding="utf-8")
            print(f"已写 {path.name}: {len(lst)} 条")

    print(f"\nA组(早场): {len(a)} 条 | B组(午场): {len(b)} 条")
    print(f"A组末条: {a[-1].get('name')}")
    print(f"B组首条: {b[0].get('name')} | B组末条: {b[-1].get('name')}")
    # 边界材料检查
    for label, lst in (("A", a), ("B", b)):
        cats = []
        for p in lst:
            c = cat_of(p)
            if not cats or cats[-1] != c:
                cats.append(c)
        print(f"{label} 组类别序列: {' | '.join(cats)}")


if __name__ == "__main__":
    main()
