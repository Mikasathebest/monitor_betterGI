# -*- coding: utf-8 -*-
# 绕开 BGI nextScheduledTask 反序列化 bug (STJ 无 IncludeFields, ValueTuple 字段加载为空, 书签永远无效)
# 方案: 从主组生成"续跑收集组"子组 JSON, 只含 bookmark 之后的任务, 由会话脚本/UIA 直接启动该子组
# 用法: python make_resume_group.py [start_idx]     (缺省读 config.json 书签; 0 或无书签则删除子组)
import json, os, sys

BASE = r"D:\projects\betterGI"
CFG = os.path.join(BASE, r"User\config.json")
GROUP = os.path.join(BASE, r"User\ScriptGroup\全自动循环.json")
RESUME = os.path.join(BASE, r"User\ScriptGroup\续跑收集组.json")

def log(m): print(m, flush=True)

start = None
if len(sys.argv) > 1:
    start = int(sys.argv[1])
else:
    cfg = json.load(open(CFG, encoding="utf-8"))
    nst = cfg.get("nextScheduledTask") or []
    if nst and isinstance(nst[0].get("Item2"), int):
        start = nst[0]["Item2"]

group = json.load(open(GROUP, encoding="utf-8"))
projs = group["projects"]
total = len(projs)
log(f"主组共 {total} 条, 续跑起点 idx={start}")

if start is None or start <= 0 or start >= total:
    if os.path.exists(RESUME):
        os.remove(RESUME)
        log("续跑组已删除 (从头跑主组)")
    else:
        log("无需续跑组 (从头跑主组)")
    sys.exit(0)

sub = {
    "index": 99,
    "name": "续跑收集组",
    "config": group.get("config", {}),
    "projects": [],
}
for j, p in enumerate(projs[start:]):
    q = dict(p)
    q["index"] = j          # 子组内重新编号
    sub["projects"].append(q)

json.dump(sub, open(RESUME, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
log(f"续跑组已生成: idx {start}..{total-1} 共 {len(sub['projects'])} 条 -> {RESUME}")
