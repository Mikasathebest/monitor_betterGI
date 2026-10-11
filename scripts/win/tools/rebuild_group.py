# -*- coding: utf-8 -*-
# 组重建: 删 盗宝团/松珀香/云岩裂叶/萃凝晶/遗迹守卫; 加 丘丘萨满/丘丘人射手(前15)/便携轴承/嘟嘟莲/万相石
# 部族龙形武士组内已有 7 条, 不重复加
import json, io, os, re, shutil

BASE = r"D:\projects\betterGI"
GROUP = BASE + r"\User\ScriptGroup\全自动循环.json"
AP = BASE + r"\User\AutoPathing"
CFG = BASE + r"\User\config.json"
RESUME = BASE + r"\User\ScriptGroup\续跑收集组.json"

REMOVE_FOLDERS = {
    "敌人-遗迹守卫", "敌人-盗宝团", "特产-挪德卡莱-松珀香",
    "特产-纳塔-云岩裂叶", "萃凝晶-枫丹",
}

def list_routes(folder):
    d = os.path.join(AP, folder)
    return sorted(f for f in os.listdir(d) if f.endswith(".json"))

def count_of(fn):
    m = re.search(r"(\d+)个", fn)
    return int(m.group(1)) if m else 0

def make_entry(folder, name):
    return {
        "name": name, "folderName": folder, "jsScriptSettingsObject": None,
        "index": 0, "type": "Pathing", "status": "Enabled", "schedule": "Daily",
        "runNum": 1, "allowJsNotification": True, "allowJsHTTPHash": "",
    }

with io.open(GROUP, encoding="utf-8-sig") as f:
    group = json.load(f)
projects = group["projects"]
before = len(projects)

# 1. 删除 (必须原地改 group["projects"], 重绑局部变量不会写回 JSON!)
removed = [p for p in group["projects"] if p.get("folderName") in REMOVE_FOLDERS]
group["projects"] = [p for p in group["projects"] if p.get("folderName") not in REMOVE_FOLDERS]
projects = group["projects"]
print("删除 %d 条 (目标 39): %s" % (len(removed), sorted(set(p["folderName"] for p in removed))))

# 2. 新增块: (folder, 取多少条; None=全部)
ADD = [
    ("敌人-丘丘萨满", None),
    ("敌人-丘丘人射手", 15),
    ("特产-挪德卡莱-便携轴承", None),
    ("特产-蒙德-嘟嘟莲", None),
    ("特产-须弥-万相石", None),
]
existing_folders = set(p.get("folderName", "") for p in projects)
new_entries = []
for folder, limit in ADD:
    if folder in existing_folders:
        print("已存在 %s, 跳过" % folder)
        continue
    files = list_routes(folder)
    if limit is not None and len(files) > limit:
        files = sorted(files, key=lambda x: -count_of(x))[:limit]
    missing = [f for f in files if not os.path.isfile(os.path.join(AP, folder, f))]
    if missing:
        print("警告: %s 缺文件 %s" % (folder, missing))
    for fn in sorted(files):
        new_entries.append(make_entry(folder, fn))
    print("新增 %s: %d 条" % (folder, len(files)))

# 3. 插入位置: 尾部"树脂监控"(JS) 之前
insert_at = len(projects)
for i in range(len(projects) - 1, -1, -1):
    if projects[i].get("type") == "Javascript" and projects[i].get("name") == "树脂监控":
        insert_at = i
        break
projects[insert_at:insert_at] = new_entries
print("插入位置 idx %d, 新增 %d 条" % (insert_at, len(new_entries)))

# 4. 重编号 + 备份 + 写回
for i, p in enumerate(projects):
    p["index"] = i
shutil.copy2(GROUP, GROUP + ".pre_rebuild.bak")
with io.open(GROUP, "w", encoding="utf-8") as f:
    json.dump(group, f, ensure_ascii=False, indent=2)
print("组任务总数: %d -> %d" % (before, len(projects)))

# 5. 清书签 + 删续跑组 (索引已变, 旧书签/子组全部失效)
cfg = json.load(open(CFG, encoding="utf-8"))
cfg["nextScheduledTask"] = []
json.dump(cfg, open(CFG, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
print("config.json 书签已清空")
if os.path.exists(RESUME):
    os.remove(RESUME)
    print("续跑收集组.json 已删除")
