# -*- coding: utf-8 -*-
# 裁剪 全自动循环 组: 删月莲/冬凌草, 萃凝晶减半, 水晶块减3/4, 紫晶块减半, 去重
# 逻辑: 先去重(树脂监控为故意周期穿插, 跳过), 再在去重后的集合上按比例裁剪
# 用法: python trim_group_routes.py          -> 干跑分析(只打印)
#       python trim_group_routes.py --apply  -> 实际修改(备份 .pre_trim.bak)
import json, io, re, shutil, math, sys
from collections import Counter

BASE = r"D:\projects\betterGI"
GROUP = BASE + r"\User\ScriptGroup\全自动循环.json"

with io.open(GROUP, encoding="utf-8-sig") as f:
    group = json.load(f)
projects = group["projects"]

def yield_of(p):
    m = re.search(r"(\d+)\s*个", p.get("name", ""))
    return int(m.group(1)) if m else 0

def is_duplicated_marker(p):
    return p.get("folderName", "") == "树脂监控"  # 周期性体力检查, 不参与去重/裁剪

# --- 计算去重删除集 ---
dup_drop = set()
seen = {}
for i, p in enumerate(projects):
    if is_duplicated_marker(p):
        continue
    k = (p.get("folderName", ""), p.get("name", ""))
    if k in seen:
        dup_drop.add(i)
    else:
        seen[k] = i

# --- 目标材料: (关键字, 模式, 保留比例) ---
targets = [
    ("月莲",   "remove_all", None),
    ("冬凌草", "remove_all", None),
    ("萃凝晶", "keep_ratio", 0.5),
    ("水晶块", "keep_ratio", 0.25),
    ("紫晶块", "keep_ratio", 0.5),
]

# --- 计算比例删除集 (基于去重后的幸存条目) ---
ratio_drop = set()
for key, mode, ratio in targets:
    if mode != "keep_ratio":
        continue
    idxs = [i for i, p in enumerate(projects)
            if key in p.get("folderName", "") and i not in dup_drop]
    keep_n = math.ceil(len(idxs) * ratio)
    ranked = sorted(idxs, key=lambda i: (-yield_of(projects[i]), i))
    ratio_drop.update(set(idxs) - set(ranked[:keep_n]))

# --- 全量删除集: 目标全删 + 去重 + 比例 ---
all_drop = set(dup_drop) | set(ratio_drop)
for key, mode, ratio in targets:
    if mode == "remove_all":
        all_drop.update(i for i, p in enumerate(projects) if key in p.get("folderName", ""))

# --- 打印分析 ---
print("=== 目标材料统计 (去重后) ===")
for key, mode, ratio in targets:
    idxs_all = [i for i, p in enumerate(projects) if key in p.get("folderName", "")]
    idxs_keep = [i for i in idxs_all if i not in dup_drop]
    total_yield = sum(yield_of(projects[i]) for i in idxs_keep)
    if mode == "remove_all":
        print("%s: %d 条 (含重复 %d), 总产量约 %d -> 全部删除" % (
            key, len(idxs_all), len(idxs_all) - len(idxs_keep), total_yield))
    else:
        keep_n = math.ceil(len(idxs_keep) * ratio)
        keep = sorted(sorted(idxs_keep, key=lambda i: (-yield_of(projects[i]), i))[:keep_n])
        kept_yield = sum(yield_of(projects[i]) for i in keep)
        print("%s: %d 条 (去重后 %d), 产量约 %d -> 保留 %d 条(产量约 %d)" % (
            key, len(idxs_all), len(idxs_keep), total_yield, len(keep), kept_yield))

print("\n=== 重复条目 ===")
if dup_drop:
    for i in sorted(dup_drop):
        print("删重复: [%s] %s (idx %d)" % (projects[i]["folderName"], projects[i]["name"], i))
else:
    print("无")

print("\n=== 汇总 ===")
print("原任务数: %d, 删除: %d (重复 %d), 保留: %d" % (
    len(projects), len(all_drop), len(dup_drop), len(projects) - len(all_drop)))

print("\n顶层字段:", [k for k in group.keys() if k != "projects"])

# --- apply: 实际修改 ---
if "--apply" in sys.argv:
    new_projects = [p for i, p in enumerate(projects) if i not in all_drop]
    for i, p in enumerate(new_projects):
        p["index"] = i
    group["projects"] = new_projects
    shutil.copy2(GROUP, GROUP + ".pre_trim.bak")
    with io.open(GROUP, "w", encoding="utf-8") as f:
        json.dump(group, f, ensure_ascii=False, indent=2)
    print("\n[APPLY] 已写入, 备份: .pre_trim.bak")
