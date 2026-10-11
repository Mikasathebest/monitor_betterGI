# -*- coding: utf-8 -*-
# 进度书签: 从 BGI 日志找最后执行的路线 → 在组 JSON 定位 → 写 nextScheduledTask 进 config.json
# 同时生成/删除 "续跑收集组" 子组 JSON (绕开 BGI nextScheduledTask 反序列化 bug:
#   BGI ConfigService.JsonOptions 未开 IncludeFields, ValueTuple 的 Item1-4 是 field,
#   加载后书签恒为 (null,0,null,null), 三字段匹配永远失败 → 每场从头跑。
#   故续跑不靠 BGI 书签, 而是由 session_online.ps1 直接启动本脚本生成的续跑子组。)
# 用法: python set_bookmark.py          (保存书签 + 生成续跑组)
#       python set_bookmark.py CLEAR    (跑完清空, 下轮从头, 删除续跑组)
import json, re, sys, glob, os

BASE = r"D:\projects\betterGI"
CFG = os.path.join(BASE, r"User\config.json")
GROUP = os.path.join(BASE, r"User\ScriptGroup\全自动循环.json")
RESUME = os.path.join(BASE, r"User\ScriptGroup\续跑收集组.json")
LOGDIR = os.path.join(BASE, "log")

def log(msg):
    print(msg, flush=True)

def write_resume(projs, start):
    """生成续跑子组 (start..末尾, 重编号); start<=0 或越界时删除"""
    if start is None or start <= 0 or start >= len(projs):
        if os.path.exists(RESUME):
            os.remove(RESUME)
            log("续跑组已删除 (无待续任务)")
        else:
            log("无需续跑组")
        return
    sub = {"index": 99, "name": "续跑收集组", "config": projs_group.get("config", {}), "projects": []}
    for j, p in enumerate(projs[start:]):
        q = dict(p)
        q["index"] = j
        sub["projects"].append(q)
    json.dump(sub, open(RESUME, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    log(f"续跑组已生成: idx {start}..{len(projs)-1} 共 {len(sub['projects'])} 条")

cfg = json.load(open(CFG, encoding="utf-8"))
projs_group = None

if len(sys.argv) > 1 and sys.argv[1] == "CLEAR":
    cfg["nextScheduledTask"] = []
    json.dump(cfg, open(CFG, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
    log("书签已清空 (跑完, 下轮从头)")
    if os.path.exists(RESUME):
        os.remove(RESUME)
        log("续跑组已删除")
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
resume_start = None
if last_route:
    group = json.load(open(GROUP, encoding="utf-8"))
    projs_group = group
    projs = group["projects"]
    for i, p in enumerate(projs):
        if p.get("name") == last_route:
            if i + 1 >= len(projs):
                log("最后路线已是组尾, 全部完成")
                break
            nxt = i + 1
            np = projs[nxt]
            bookmark = [{
                "Item1": "全自动循环",
                "Item2": nxt,               # 0-based, BGI 源码: nst.Item2 == item.Index (10-10 修复, 原 nxt+1 永远匹配不上)
                "Item3": np.get("folderName", ""),
                "Item4": np.get("name", ""),
            }]
            resume_start = nxt              # 续跑组从 nxt 开始
            log(f"书签: idx {nxt} = {np.get('name')}")
            break
    if not bookmark:
        log("路线不在组内, 从头开始")

cfg["nextScheduledTask"] = bookmark
json.dump(cfg, open(CFG, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
log(f"config.json 已写入书签 {len(bookmark)} 条")

if projs_group is not None:
    write_resume(projs_group["projects"], resume_start)
