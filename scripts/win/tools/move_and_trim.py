# -*- coding: utf-8 -*-
# 第二步优化: 前移松珀香/云岩裂叶 + 再裁低优先级路线
# 目标: 总任务数 ~150, 确保 3 小时内能跑完并覆盖松珀香/云岩裂叶
import json, io, re, shutil, math, sys

BASE = r"D:\projects\betterGI"
GROUP = BASE + r"\User\ScriptGroup\全自动循环.json"

with io.open(GROUP, encoding="utf-8-sig") as f:
    group = json.load(f)
projects = group["projects"]

def yield_of(p):
    m = re.search(r"(\d+)\s*个", p.get("name", ""))
    return int(m.group(1)) if m else 0

# 1. 抽出松珀香 + 云岩裂叶 (要前移的)
move_keys = ["特产-挪德卡莱-松珀香", "特产-纳塔-云岩裂叶"]
move_items = [p for p in projects if p.get("folderName") in move_keys]
others = [p for p in projects if p.get("folderName") not in move_keys]
print("抽出松珀香+云岩裂叶: %d 条, 剩余: %d 条" % (len(move_items), len(others)))

# 2. 在剩余中再裁剪 (保留比例, 按产量降序)
#    敌人/怪物段保留(为角色材料), 特产/矿石再裁
trim = {
    "萃凝晶-枫丹": 0.6,         # 20 -> 12
    "水晶块": 0.5,              # 29 -> 15 (跨文件夹)
    "紫晶块": 0.5,              # 27 -> 14
    "虹滴晶": 0.5,              # 21 -> 11
    "特产-璃月-清水玉": 0.5,    # 19 -> 10
    "特产-枫丹-苍晶螺": 0.5,    # 19 -> 10
    "特产-蒙德-慕风蘑菇": 0.5,  # 17 -> 9
    "特产-蒙德-风车菊": 0.5,    # 14 -> 7
    "特产-纳塔-琉鳞石": 0.5,    # 6 -> 3
    "星银矿石-大剑": 0.5,      # 5 -> 3
    "铁块-富集": 0.5,          # 6 -> 3
}
# 敌人段不裁
enemy_folders = {"敌人-遗迹守卫","敌人-发条机关","敌人-盗宝团","敌人-嵌合翼骏狮",
                 "敌人-隙境原体","敌人-部族龙形武士","敌人-异种合成魔兽","敌人-史莱姆",""}
# 树脂监控不裁
resin_folder = "树脂监控"

def match_trim_key(folder):
    for k, v in trim.items():
        if k in folder:
            return v
    return None

kept = []
dropped = 0
from collections import defaultdict
folder_items = defaultdict(list)
for i, p in enumerate(others):
    folder_items[p.get("folderName","")].append(p)

new_others = []
for folder, items in folder_items.items():
    if folder == resin_folder or folder in enemy_folders:
        new_others.extend(items)
        continue
    ratio = match_trim_key(folder)
    if ratio is None:
        new_others.extend(items)
        continue
    keep_n = max(1, math.ceil(len(items) * ratio))
    ranked = sorted(items, key=lambda p: (-yield_of(p), p.get("name","")))
    new_others.extend(ranked[:keep_n])
    dropped += len(items) - keep_n

print("裁剪删除: %d 条, 剩余 others: %d 条" % (dropped, len(new_others)))

# 3. 重组: [敌人段] + [松珀香+云岩裂叶] + [树脂监控穿插 + 其他]
#    找第一个树脂监控的位置, 把松珀香/云岩裂叶插在它之后
#    树脂监控保持原穿插位置
resin_idxs = [i for i, p in enumerate(new_others) if p.get("folderName") == resin_folder]
if resin_idxs:
    insert_pos = resin_idxs[0] + 1  # 紧跟第一个树脂监控
    new_others[insert_pos:insert_pos] = move_items
else:
    new_others = move_items + new_others

# 4. 重排 index
for i, p in enumerate(new_others):
    p["index"] = i
group["projects"] = new_others

print("最终总任务数: %d" % len(new_others))
print("松珀香/云岩裂叶已前移到 idx %d-%d" % (
    [i for i,p in enumerate(new_others) if p.get("folderName") in move_keys][0],
    [i for i,p in enumerate(new_others) if p.get("folderName") in move_keys][-1]))

if "--apply" in sys.argv:
    shutil.copy2(GROUP, GROUP + ".pre_move_trim.bak")
    with io.open(GROUP, "w", encoding="utf-8") as f:
        json.dump(group, f, ensure_ascii=False, indent=2)
    print("[APPLY] 已写入, 备份: .pre_move_trim.bak")
else:
    print("\n[DRY-RUN] 加 --apply 执行")
