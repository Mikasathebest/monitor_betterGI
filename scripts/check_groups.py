import json

# 1. 当前主组中的非路线条目
g = json.load(open(r'D:/Projects/BetterGI/User/ScriptGroup/全自动循环.json', encoding='utf-8-sig'))
print('=== 当前主组 非路线条目 ===')
for i, p in enumerate(g['projects']):
    t = p.get('type', '?')
    if t != 'Pathing':
        nm = str(p.get('name', ''))[:120]
        print('idx %d: type=%s  name=%s' % (i, t, nm))
print('当前主组总条数:', len(g['projects']))

# 2. 原始 182 条备份中的 Shell 条目
g2 = json.load(open(r'D:/Projects/monitor_betterGI/backups/全自动循环.182.20261015.json', encoding='utf-8-sig'))
print('=== 原始182条备份 Shell条目 ===')
for i, p in enumerate(g2['projects']):
    if p.get('type') == 'Shell':
        nm = str(p.get('name', ''))[:120]
        print('orig-idx %d: name=%s' % (i, nm))
print('原始组总条数:', len(g2['projects']))
