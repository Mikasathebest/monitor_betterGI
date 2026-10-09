# -*- coding: utf-8 -*-
# 配置调优 (BGI 进程关闭后执行, 防回写覆盖):
# 1) autoFightConfig.enableCombatTargeting=True  战斗索敌(自动面向敌人), 治"视角卡死打不到背后怪"
# 2) autoLeyLineOutcropConfig.fightConfig.seekEnemyEnabled=True  地脉花多波次主动寻敌
# 3) 一条龙 CompletionAction "关闭游戏" -> "无"  否则一条龙跑完就退游戏, 大组永远轮不上 (23:36 事故)
# 不动 rotateFindEnemyEnabled (万能策略作者警告: 转速过快会卡检测/乱转, 保持关闭)
import json, io, os, shutil, datetime

BASE = r"D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0"
CFG = os.path.join(BASE, r"User\config.json")
OD = os.path.join(BASE, r"User\OneDragon\默认配置.json")
stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
changes = []

# --- config.json ---
with io.open(CFG, encoding="utf-8") as f:
    cfg = json.load(f)
shutil.copy2(CFG, CFG + "." + stamp + ".bak")

af = cfg.get("autoFightConfig", {})
if not af.get("enableCombatTargeting"):
    af["enableCombatTargeting"] = True
    changes.append("autoFightConfig.enableCombatTargeting: False -> True")

ll = cfg.get("autoLeyLineOutcropConfig", {}).get("fightConfig", {})
if not ll.get("seekEnemyEnabled"):
    ll["seekEnemyEnabled"] = True
    changes.append("leyline.fightConfig.seekEnemyEnabled: False -> True")

with io.open(CFG, "w", encoding="utf-8") as f:
    json.dump(cfg, f, ensure_ascii=False, indent=2)

# --- 一条龙 默认配置.json ---
with io.open(OD, encoding="utf-8") as f:
    od = json.load(f)
shutil.copy2(OD, OD + "." + stamp + ".bak")

if od.get("CompletionAction") != "无":
    changes.append("OneDragon.CompletionAction: %s -> 无" % od.get("CompletionAction"))
    od["CompletionAction"] = "无"

with io.open(OD, "w", encoding="utf-8") as f:
    json.dump(od, f, ensure_ascii=False, indent=2)

print("changes: " + ("; ".join(changes) if changes else "none (already set)"))

