# -*- coding: utf-8 -*-
# 把"松珀香"和"云岩裂叶"特产收集路线插入 全自动循环 组 (python 处理大 JSON, 避开 PS 5.1 坑)
# 背景: 用户要求在一条龙收集中增加 松柏香(=松珀香) 和 云岩裂叶 的收集
import json, io, shutil, os

# 实际运行的 BGI 目录 (session_online.ps1 / watchdog.ps1 均用此路径; 勿用源码构建目录)
BASE = r"D:\projects\betterGI"
GROUP = BASE + r"\User\ScriptGroup\全自动循环.json"
AP = BASE + r"\User\AutoPathing"

with io.open(GROUP, encoding="utf-8-sig") as f:
    group = json.load(f)

projects = group["projects"]

# 待插入的材料路线: (folderName, [文件名列表])
MATERIALS = [
    ("特产-挪德卡莱-松珀香", [
        "01-松珀香-皮拉米达城-14个.json",
        "02-松珀香-噩影泽地-上方-25个.json",
        "03-松珀香-噩影泽地-下方-15个.json",
        "04-松珀香-西风戍垒-18个.json",
    ]),
    ("特产-纳塔-云岩裂叶", [
        "01-云岩裂叶-沃陆之邦七天神像东-10个.json",
        "02-云岩裂叶-石火坠陨处-8个.json",
        "03-云岩裂叶-火山西北-3个.json",
        "04-云岩裂叶-火山西-7个.json",
        "05-云岩裂叶-火山南-11个.json",
        "06-云岩裂叶-无名岛-10个.json",
        "07-云岩裂叶-远古圣山-分流识海下方-8个.json",
        "08-云岩裂叶-远古圣山-聚火祭验所左侧-3个.json",
        "09-云岩裂叶-远古圣山-聚火祭验所-6个.json",
        "10-云岩裂叶-远古圣山-分流识海-8个.json",
    ]),
]

def make_entry(folder, name):
    return {
        "name": name,
        "folderName": folder,
        "jsScriptSettingsObject": None,
        "index": 0,
        "type": "Pathing",
        "status": "Enabled",
        "schedule": "Daily",
        "runNum": 1,
        "allowJsNotification": True,
        "allowJsHTTPHash": "",
    }

# 防重复: 已存在的 folderName 不再插入
existing_folders = set(p.get("folderName", "") for p in projects)
new_entries = []
for folder, files in MATERIALS:
    if folder in existing_folders:
        print("组内已存在 %s, 跳过" % folder)
        continue
    # 校验路线文件存在
    missing = [f for f in files if not os.path.isfile(os.path.join(AP, folder, f))]
    if missing:
        print("警告: %s 缺少路线文件: %s" % (folder, missing))
    for fn in files:
        new_entries.append(make_entry(folder, fn))

if not new_entries:
    print("无需插入 (全部已存在或无有效路线)")
    raise SystemExit(0)

# 插入位置: 末尾的 "树脂监控"(Javascript) + "cycle_offline"(Shell) 之前
# 即找最后一个 type=Javascript 且 name=树脂监控 的位置, 在其前插入
insert_at = None
for i in range(len(projects) - 1, -1, -1):
    p = projects[i]
    if p.get("type") == "Javascript" and p.get("name") == "树脂监控":
        insert_at = i
        break
if insert_at is None:
    insert_at = len(projects)  # 兜底: 直接追加

projects[insert_at:insert_at] = new_entries

# 重新编号 index (0-based, 与数组位置一致)
for i, p in enumerate(projects):
    p["index"] = i

shutil.copy2(GROUP, GROUP + ".pre_material.bak")
with io.open(GROUP, "w", encoding="utf-8") as f:
    json.dump(group, f, ensure_ascii=False, indent=2)

print("已在 idx %d 处插入 %d 条路线 (松珀香+云岩裂叶), 组任务总数 %d" % (
    insert_at, len(new_entries), len(projects)))
