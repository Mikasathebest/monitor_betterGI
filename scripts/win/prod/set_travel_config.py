# -*- coding: utf-8 -*-
# 组配置批量更新 (幂等): 跑图赶路角色=玛薇卡, 战斗策略=根据队伍自动选择
# 由 cycle_offline.ps1 在 BGI 关闭后调用
# (BGI 运行时会用内存配置覆盖组 JSON, 必须在 BGI 关闭后改 — 10-15 教训)
# 背景 10-22: 组里写死 strategyName=培养队轮换, 队伍不匹配仍强用 → 战斗减员复活重跑;
#             hurryOnAvatar 空 → 玛薇卡跑图没开E赶路 (BGI 0.65.0 支持 hurryOnAvatar 赶路角色)
import json, os

BASE = r'D:\projects\betterGI\User\ScriptGroup'
GROUPS = ['收集A组', '收集B组', '全自动循环', '续跑收集组']

for name in GROUPS:
    fp = os.path.join(BASE, name + '.json')
    if not os.path.exists(fp):
        continue
    try:
        with open(fp, encoding='utf-8') as f:
            g = json.load(f)
        pc = g.get('config', {}).get('pathingConfig')
        if not pc:
            continue
        dirty = False
        if pc.get('hurryOnAvatar') != '玛薇卡':
            pc['hurryOnAvatar'] = '玛薇卡'
            dirty = True
        afc = pc.get('autoFightConfig')
        if afc and afc.get('strategyName') != '根据队伍自动选择':
            afc['strategyName'] = '根据队伍自动选择'
            dirty = True
        if dirty:
            with open(fp, 'w', encoding='utf-8') as f:
                json.dump(g, f, ensure_ascii=False, indent=2)
            print(f'{name}: 已更新 (赶路=玛薇卡, 战斗策略=自动选择)', flush=True)
        else:
            print(f'{name}: 已是目标配置, 跳过', flush=True)
    except Exception as e:
        print(f'{name}: 更新失败 {e}', flush=True)
