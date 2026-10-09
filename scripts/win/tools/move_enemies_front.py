# -*- coding: utf-8 -*-
# 荒野树妖入库 + 与异种合成魔兽一起前移到 松珀香/云岩裂叶 之后 (用户 10-09 要求)
import json, io, shutil, os, re

BASE = r"D:\projects\betterGI"
GROUP = BASE + r"\User\ScriptGroup\全自动循环.json"
AP = BASE + r"\User\AutoPathing"

with io.open(GROUP, encoding="utf-8-sig") as f:
    group = json.load(f)
projects = group["projects"]
print("处理前总数: %d" % len(projects))

ENEMY_FOLDERS = ["敌人-荒野树妖", "敌人-异种合成魔兽"]

# 1. 荒野树妖路线入库 (若组内没有)
if not any(p.get("folderName") == "敌人-荒野树妖" for p in projects):
    folder = "敌人-荒野树妖"
    files = sorted(os.listdir(os.path.join(AP, folder)))
    print("荒野树妖路线文件: %s" % files)
    for fn in files:
        projects.append({
            "name": fn, "folderName": folder, "jsScriptSettingsObject": None,
            "index": 0, "type": "Pathing", "status": "Enabled", "schedule": "Daily",
            "runNum": 1, "allowJsNotification": True, "allowJsHTTPHash": "",
        })
    print("已追加荒野树妖 %d 条" % len(files))
else:
    print("组内已有荒野树妖")

# 2. 抽出两个敌人段
enemies = [p for p in projects if p.get("folderName") in ENEMY_FOLDERS]
rest = [p for p in projects if p.get("folderName") not in ENEMY_FOLDERS]
print("抽出敌人路线 %d 条 (树妖+%d)" % (
    sum(1 for p in enemies if p.get("folderName") == "敌人-荒野树妖"),
    sum(1 for p in enemies if p.get("folderName") == "敌人-异种合成魔兽")))

# 3. 插入点: 最后一个 松珀香/云岩裂叶 路线之后
insert_at = 0
for i, p in enumerate(rest):
    if re.search(r"松珀香|云岩裂叶", p.get("name", "")):
        insert_at = i + 1
print("插入点: idx %d (云岩裂叶块之后)" % insert_at)
rest[insert_at:insert_at] = enemies

# 4. 重编号
for i, p in enumerate(rest):
    p["index"] = i
group["projects"] = rest
print("处理后总数: %d" % len(rest))

shutil.copy2(GROUP, GROUP + ".pre_enemy_front.bak")
with io.open(GROUP, "w", encoding="utf-8") as f:
    json.dump(group, f, ensure_ascii=False, indent=2)
print("已写入, 备份: .pre_enemy_front.bak")

# 5. 打印前 32 条确认
print("\n=== 前 32 条 ===")
for p in rest[:32]:
    print("idx=%3d  [%s] %s" % (p["index"], p.get("type"), p.get("name")))
