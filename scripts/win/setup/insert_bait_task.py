# -*- coding: utf-8 -*-
# 把"合成鱼饵"JS 任务插入 全自动循环 组钓鱼段之前 (python 处理大 JSON, 避开 PS 5.1 坑)
import json, io, shutil

BASE = r"D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0"
GROUP = BASE + r"\User\ScriptGroup\全自动循环.json"

with io.open(GROUP, encoding="utf-8-sig") as f:
    group = json.load(f)

projects = group["projects"]

# 防重复
if any(p.get("folderName") == "AutoFishingTeyvat-Bait" for p in projects):
    print("组内已存在鱼饵任务, 跳过")
    raise SystemExit(0)

# 找钓鱼段首条
first_fish = None
for i, p in enumerate(projects):
    if p.get("type") == "Pathing" and "钓鱼" in p.get("name", ""):
        first_fish = i
        break
if first_fish is None:
    raise SystemExit("未找到钓鱼段")

task = {
    "name": "合成鱼饵补足100",
    "folderName": "AutoFishingTeyvat-Bait",
    "jsScriptSettingsObject": None,
    "index": 1,
    "type": "Javascript",
    "status": "Enabled",
    "schedule": "Daily",
    "runNum": 1,
    "allowJsNotification": True,
    "allowJsHTTPHash": "",
}
projects.insert(first_fish, task)

shutil.copy2(GROUP, GROUP + ".pre_bait.bak")
with io.open(GROUP, "w", encoding="utf-8") as f:
    json.dump(group, f, ensure_ascii=False, indent=2)

print("已插入 idx %d (%s 之前), 组任务数 %d" % (first_fish, projects[first_fish + 1]["name"], len(projects)))
