# -*- coding: utf-8 -*-
# 进度书签: 从 BGI 日志找最后执行的路线 → 在组 JSON 定位 → 写 nextScheduledTask 进 config.json
# 用法: python set_bookmark.py          (保存书签, 续跑)
#       python set_bookmark.py CLEAR    (跑完清空, 下轮从头)
import json, re, sys, glob, os

BASE = r"D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0"
CFG = os.path.join(BASE, r"User\config.json")
GROUP = os.path.join(BASE, r"User\ScriptGroup\全自动循环.json")
LOGDIR = os.path.join(BASE, "log")

def log(msg):
    print(msg, flush=True)

cfg = json.load(open(CFG, encoding="utf-8"))

if len(sys.argv) > 1 and sys.argv[1] == "CLEAR":
    cfg["nextScheduledTask"] = []
    json.dump(cfg, open(CFG, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    log("书签已清空 (跑完, 下轮从头)")
    sys.exit(0)

# 最新日志文件
logs = sorted(glob.glob(os.path.join(LOGDIR, "better-genshin-impact*.log")), key=os.path.getmtime)
last_route = None
if logs:
    text = open(logs[-1], encoding="utf-8", errors="ignore").read()
    matches = re.findall(r'开始执行地图追踪任务[:：]\s*"([^"]+)"', text)
    if matches:
        last_route = matches[-1]
log(f"日志最后路线: {last_route}")

bookmark = []
if last_route:
    group = json.load(open(GROUP, encoding="utf-8"))
    projs = group["projects"]
    for i, p in enumerate(projs):
        if p.get("name") == last_route:
            nxt = min(i + 1, len(projs) - 1)
            np = projs[nxt]
            bookmark = [{
                "Item1": "全自动循环",
                "Item2": nxt + 1,           # 1-based index
                "Item3": np.get("folderName", ""),
                "Item4": np.get("name", ""),
            }]
            log(f"书签: idx {nxt+1} = {np.get('name')}")
            break
    if not bookmark:
        log("路线不在组内, 从头开始")

cfg["nextScheduledTask"] = bookmark
json.dump(cfg, open(CFG, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
log(f"config.json 已写入书签 {len(bookmark)} 条")
