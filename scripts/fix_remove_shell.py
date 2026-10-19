# -*- coding: utf-8 -*-
"""移除主组中的 Shell 自杀条目 (idx 71), 重编号, 重生成续跑组/A/B组。

问题: 原 182 组 orig-idx 151 有个 Shell 条目 (执行 cycle_offline.ps1),
瘦身后落到新 idx 71 — 正好被 10-16 早场书签指中 → 续跑组首条=Shell → 午场立即自杀。
修复: 删除该 Shell 条目; 主组 104→103; 书签 71 调整为删除后的 idx 71 (= 原 idx 72 = 史莱姆速刷);
续跑组 71..102 共 32 条 (无 Shell)。
"""
import json
from pathlib import Path

BASE = Path(r"D:\projects\betterGI")
GROUP_DIR = BASE / "User" / "ScriptGroup"
MASTER = GROUP_DIR / "全自动循环.json"
GROUP_A = GROUP_DIR / "收集A组.json"
GROUP_B = GROUP_DIR / "收集B组.json"
RESUME = GROUP_DIR / "续跑收集组.json"
CONFIG = BASE / "User" / "config.json"

# 1. 读主组, 删除 Shell 条目
group = json.loads(MASTER.read_text(encoding="utf-8-sig"))
projs = group["projects"]
shell_indices = [i for i, p in enumerate(projs) if p.get("type") == "Shell"]
print(f"Shell 条目位置: {shell_indices}")
for si in sorted(shell_indices, reverse=True):
    del projs[si]
# 重编号
for j, p in enumerate(projs):
    p["index"] = j
group["projects"] = projs
MASTER.write_text(json.dumps(group, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"主组: {len(projs)} 条 (Shell 已删)")

# 2. 重生成 A/B 组 (连续对半)
half = len(projs) // 2
a, b = projs[:half], projs[half:]
for path, lst, name in ((GROUP_A, a, "收集A组"), (GROUP_B, b, "收集B组")):
    sub = {"index": 0, "name": name, "config": group.get("config", {}), "projects": []}
    for j, p in enumerate(lst):
        q = dict(p); q["index"] = j
        sub["projects"].append(q)
    path.write_text(json.dumps(sub, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"{name}: {len(lst)} 条")

# 3. 修正书签 + 重生成续跑组
# 当前书签 idx 71 指向已删的 Shell → 调整为删除后的 idx 71 (= 原 idx 72)
cfg = json.loads(CONFIG.read_text(encoding="utf-8-sig"))
bk = 0
if cfg.get("nextScheduledTask") and len(cfg["nextScheduledTask"]) > 0:
    bk = int(cfg["nextScheduledTask"][0]["Item2"])
print(f"原书签 idx: {bk}")

# Shell 在 idx 71 被删 → 删除后 idx 71 = 原 idx 72. 书签 71 仍然有效 (指向原 72, 即删除后的 71)
# 如果书签正好指向 Shell 的位置, 保持不变即可 (删后 idx N = 原 idx N+1)
# 如果书签 > 71, 减 1
if bk in shell_indices:
    # 书签正好指向 Shell → 保持 (删后 idx 71 = 原 72 = 下一条路线)
    print(f"书签 {bk} 正好指向 Shell → 删除后自动指向原 {bk+1} (={projs[bk].get('name','')[:60]})")
elif bk > max(shell_indices):
    bk_new = bk - len(shell_indices)
    cfg["nextScheduledTask"] = [{"Item1": "全自动循环", "Item2": bk_new}]
    CONFIG.write_text(json.dumps(cfg, ensure_ascii=False, indent=2), encoding="utf-8")
    bk = bk_new
    print(f"书签调整: {bk} → {bk_new}")
else:
    print(f"书签 {bk} 不受影响")

# 4. 重生成续跑组
resume_projs = projs[bk:]
sub = {"index": 0, "name": "续跑收集组", "config": group.get("config", {}), "projects": []}
for j, p in enumerate(resume_projs):
    q = dict(p); q["index"] = j
    sub["projects"].append(q)
RESUME.write_text(json.dumps(sub, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"续跑收集组: {len(resume_projs)} 条 (idx {bk}..{len(projs)-1})")
print(f"续跑组首条: {resume_projs[0].get('name','')[:80]}  type={resume_projs[0].get('type','?')}")
