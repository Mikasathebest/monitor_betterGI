# -*- coding: utf-8 -*-
# 按关键词从配置组删除路线 (如 嘟嘟莲: 需要纳西妲, 大世界队伍没有 → 每次 0.05s 跳过, 白占位)
# 同时处理主组和续跑子组, 删除后重编 index; 书签按路线名在下线时重算, 不受影响
# 用法: python drop_routes.py 嘟嘟莲           -> 干跑 (只打印将删除的路线)
#       python drop_routes.py 嘟嘟莲 --apply   -> 实际修改 (备份 .pre_drop_<关键词>.bak)
import io, json, os, shutil, sys

BASE = r"D:\projects\betterGI"
GROUPS = [BASE + r"\User\ScriptGroup\全自动循环.json", BASE + r"\User\ScriptGroup\续跑收集组.json"]

if len(sys.argv) < 2:
    sys.exit(__doc__ or "用法: python drop_routes.py <关键词> [--apply]")
keyword, apply = sys.argv[1], "--apply" in sys.argv

for path in GROUPS:
    if not os.path.exists(path):
        print(f"[跳过] 不存在: {path}")
        continue
    with io.open(path, encoding="utf-8-sig") as f:
        group = json.load(f)
    projects = group["projects"]
    drop = [p for p in projects if keyword in p.get("name", "") or keyword in p.get("folderName", "")]
    print(f"{os.path.basename(path)}: {len(projects)} 条, 匹配「{keyword}」{len(drop)} 条")
    for p in drop:
        print(f"  - [{p.get('index')}] {p.get('folderName', '')}/{p.get('name', '')}")
    if not drop or not apply:
        continue
    shutil.copy2(path, f"{path}.pre_drop_{keyword}.bak")
    group["projects"] = [p for p in projects if p not in drop]
    for i, p in enumerate(group["projects"]):
        p["index"] = i
    with io.open(path, "w", encoding="utf-8") as f:
        json.dump(group, f, ensure_ascii=False, indent=2)
    print(f"  已删除, 剩 {len(group['projects'])} 条 (备份 .pre_drop_{keyword}.bak)")

if not apply:
    print("\n干跑完成, 确认后加 --apply 执行")
