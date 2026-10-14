# -*- coding: utf-8 -*-
"""BetterGI Dashboard v2 — localhost:8765
30 天日历总览 + 按天详情 (场次/进度/日常/月卡/物品分场次)
启动: python dashboard.py  → http://localhost:8765
"""
import http.server, json, re, os, glob, sys, subprocess, threading
from urllib.parse import urlparse, parse_qs
from collections import Counter
from datetime import datetime, timedelta, date

BGI_LOG_DIR = r"D:\projects\betterGI\log"
BGI_CONFIG = r"D:\projects\betterGI\User\config.json"
GROUP_JSON = r"D:\projects\betterGI\User\ScriptGroup\全自动循环.json"
CYCLE_LOG = r"C:\Users\djf20\cycle_log.txt"
STATE_FILE = r"C:\Users\djf20\session_state.txt"

ROUTE_RE = re.compile(r'开始执行地图追踪任务[:：]\s*"([^"]+)"')
PICK_RE  = re.compile(r'交互或拾取[:：]\s*"([^"]+)"')
TIME_RE  = re.compile(r'\[(\d{2}:\d{2}:\d{2})')
BATTLE_END_RE  = re.compile(r'识别到战斗结束')
BATTLE_FAIL_RE = re.compile(r'未识别到战斗结束')

# 一条龙/日常标记
MC_RE   = re.compile(r'月卡\(空月祝福\)检查/领取完成')          # 月卡
DC_END  = re.compile(r'前往冒险家协会领取奖励" 结束')            # 每日委托奖励任务跑完
EXP_OK  = re.compile(r'探索派遣[:：]\s*"全部领取"')               # 探索派遣领取
TEAPOT  = re.compile(r'领取尘歌壶奖励[:：]"领取好感和宝钱"')      # 尘歌壶
RESIN_RE= re.compile(r'原粹树脂[:：]\s*(\d+)')                   # 树脂余量
RESIN_GOT_RE = re.compile(r'提取到的原粹树脂数量[:：]\s*(\d+)')   # 合成消耗量

# cycle_log 事件
CL_START_RE  = re.compile(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) === 定时上线会话开始')
CL_SESS_RE   = re.compile(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) 场次: (\w+?场)')
CL_OFF_RE    = re.compile(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) === 会话下线')
CL_PROG_RE   = re.compile(r'^(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}) 今日收集进度: 书签 idx (\d+) / (\d+)')

_cache = {}       # date8 -> parsed dict
_cache_lock = threading.Lock()

def _t2s(t):
    h, m, s = map(int, t.split(':'))
    return h * 3600 + m * 60 + s

def _s2hms(sec):
    sec = max(0, int(sec))
    return f"{sec//3600}h{sec%3600//60:02d}m"

def _sess_name(hour):
    if 4 <= hour < 12: return '早场'
    if 12 <= hour < 18: return '午场'
    return '晚场'

# ---------- cycle_log 场次事件 ----------
def load_cycle_events():
    """返回 (按日事件, 全部进度线[(datetime, idx, total)])"""
    events = {}
    prog_all = []
    try:
        with open(CYCLE_LOG, encoding='utf-8', errors='ignore') as f:
            for line in f:
                for rex in (CL_SESS_RE, CL_OFF_RE, CL_PROG_RE):
                    m = rex.match(line)
                    if m:
                        dt = datetime.strptime(m.group(1), '%Y-%m-%d %H:%M:%S')
                        d8 = dt.strftime('%Y%m%d')
                        sec = _t2s(dt.strftime('%H:%M:%S'))
                        ev = events.setdefault(d8, {'starts': [], 'offline': None, 'progress': None})
                        if rex is CL_SESS_RE:
                            ev['starts'].append((sec, m.group(2)))
                        elif rex is CL_OFF_RE:
                            ev['offline'] = sec
                        else:
                            ev['progress'] = (sec, int(m.group(2)), int(m.group(3)))
                            prog_all.append((dt, int(m.group(2)), int(m.group(3))))
                        break
    except OSError:
        pass
    return events, prog_all

# ---------- 会话构建 ----------
def build_sessions(date8, route_pts, pick_pts, prog_all):
    """用 cycle_log 场次事件切分会话; 无事件时按日志活动间隙推断"""
    ev = load_cycle_events()[0].get(date8)
    sessions = []
    if ev and ev['starts']:
        raw = sorted(set(ev['starts']))
        # 合并 60 秒内的重复启动 (重试); 手动干预(杀卡死实例后重触发)产生的同场次 start 间隔 <40 分钟也合并
        starts = []
        for sec, name in raw:
            if starts and sec - starts[-1][0] < (60 if starts[-1][1] == name else 40 * 60):
                continue
            starts.append((sec, name))
        for i, (s, name) in enumerate(starts):
            nxt = starts[i+1][0] if i+1 < len(starts) else None
            if nxt is not None:
                e = nxt                       # 下一场开始 = 本场结束 (无下线记录时, 如午场覆盖下线任务)
            elif ev['offline'] and ev['offline'] > s:
                e = ev['offline']
            else:
                e = max([_t2s(t) for t, _ in route_pts + pick_pts] + [s])
            if e <= s:
                e = min(s + 4 * 3600, 86399)
            prog = None
            if ev['progress'] and s - 5 <= ev['progress'][0] <= e + 15:
                prog = ev['progress'][1:]
            sessions.append({'name': name, 'start': s, 'end': e, 'progress': prog})
    else:
        # 日志活动间隙推断 (>25 分钟无日志 = 分场)
        times = sorted(set(_t2s(t) for t, _ in route_pts + pick_pts))
        if times:
            blocks, cur_s, cur_e = [], times[0], times[0]
            for t in times[1:]:
                if t - cur_e > 25 * 60:
                    blocks.append((cur_s, cur_e)); cur_s = t
                cur_e = t
            blocks.append((cur_s, cur_e))
            for s, e in blocks:
                sessions.append({'name': _sess_name(s // 3600), 'start': s, 'end': e, 'progress': None})
    # 归属路线/物品
    ridx = group_route_index()   # 路线名 → 当前组内 index (仅用于识别"从组头跑")
    start_dt0 = datetime.strptime(date8, '%Y%m%d')
    for ses in sessions:
        s, e = ses['start'], ses['end']
        ses['routes'] = [n for t, n in route_pts if s <= _t2s(t) <= e]
        items = Counter(n for t, n in pick_pts if s <= _t2s(t) <= e)
        ses['pick_kinds'] = len(items)
        ses['pick_count'] = sum(items.values())
        ses['items'] = items
        ses['duration'] = _s2hms(e - s)
        ses['estimated'] = False
        # 进度: a) cycle_log 直接进度 (准确)  b) 从组头推算  c) 前场书签+执行数推算
        if ses['progress'] is None and ses['routes']:
            executed = len(ses['routes'])
            sd = start_dt0.replace(hour=s // 3600, minute=s % 3600 // 60, second=s % 60)
            prior = None
            for dt, pidx, ptot in prog_all:
                if dt < sd:
                    prior = (pidx, ptot)
                else:
                    break
            from_head = ridx.get(ses['routes'][0], 999) <= 2   # 组头允许有树脂监控等非路线任务
            if from_head:
                # 新的一天从头跑 (每日去重设计): 停在 executed-1, 下一条 = executed
                ses['progress'] = (min(executed, 9999), None)
                ses['estimated'] = True
            elif prior:
                ses['progress'] = ((prior[0] + executed) % prior[1], prior[1])
                ses['estimated'] = True
    return sessions

_route_idx_cache = None
def group_route_index():
    global _route_idx_cache
    if _route_idx_cache is None:
        try:
            g = json.load(open(GROUP_JSON, encoding='utf-8'))
            _route_idx_cache = {p.get('name'): i for i, p in enumerate(g.get('projects', [])) if p.get('name')}
        except Exception:
            _route_idx_cache = {}
    return _route_idx_cache

# ---------- 日志解析 ----------
def parse_day(date8):
    path = os.path.join(BGI_LOG_DIR, f'better-genshin-impact{date8}.log')
    if not os.path.exists(path):
        return None
    # 缓存绑定日志文件 mtime: 日志还在写入(当天场次)时自动重新解析, 否则会缓存住早场刚启动时的空结果
    mtime = os.path.getmtime(path)
    with _cache_lock:
        hit = _cache.get(date8)
        if hit and hit[0] == mtime:
            return hit[1]
    route_pts, pick_pts = [], []
    battle_ok = battle_fail = 0
    monthly = daily = expedition = teapot = False
    resin = None
    with open(path, encoding='utf-8', errors='ignore') as f:
        last_t = None
        for line in f:
            tm = TIME_RE.match(line)
            if tm:
                last_t = tm.group(1)
            t = last_t  # 路线/拾取行无时间戳, 继承最近一条日志时间
            m = ROUTE_RE.search(line)
            if m and t:
                route_pts.append((t, m.group(1).strip()))
            m = PICK_RE.search(line)
            if m and t:
                pick_pts.append((t, m.group(1).strip()))
            if BATTLE_END_RE.search(line): battle_ok += 1
            if BATTLE_FAIL_RE.search(line): battle_fail += 1
            if MC_RE.search(line): monthly = True
            if DC_END.search(line): daily = True
            if EXP_OK.search(line): expedition = True
            if TEAPOT.search(line): teapot = True
            m = RESIN_RE.search(line)
            if m: resin = int(m.group(1))
    sessions = build_sessions(date8, route_pts, pick_pts, load_cycle_events()[1])
    evs = load_cycle_events()[0]
    dp = (evs.get(date8) or {}).get('progress')
    day_total = dp[2] if dp else None   # 当天实际组规模 (如 10-13 跑的是 175 条版组)
    day_items = Counter(n for _, n in pick_pts)
    total = sum(items['pick_count'] for items in sessions)
    # 错题本: 当天重复执行的路线 (同一组内路线跑了多次 = 书签失效白跑)
    all_routes = [n for _, n in route_pts]
    route_exec = Counter(all_routes)
    duplicates = {n: c for n, c in route_exec.items() if c > 1}
    wasted_routes = sum(c - 1 for c in duplicates.values())  # 多跑的次数
    # 组总数: 优先当天的真实规模, 否则当前组
    grp_total = day_total or current_group_total()
    result = {
        'date': date8,
        'date_fmt': f"{date8[:4]}-{date8[4:6]}-{date8[6:]}",
        'weekday': '一二三四五六日'[date(int(date8[:4]), int(date8[4:6]), int(date8[6:])).weekday()],
        'route_total': len(route_pts),
        'route_unique': len(set(n for _, n in route_pts)),
        'pick_kinds': len(day_items),
        'pick_count': total or sum(day_items.values()),
        'battle_ok': battle_ok, 'battle_fail': battle_fail,
        'battle_fail_rate': round(battle_fail / max(1, battle_ok + battle_fail) * 100, 1),
        'od': {'monthly_card': monthly, 'daily_commission': daily,
               'expedition': expedition, 'teapot': teapot, 'resin': resin},
        'sessions': [{'name': s['name'], 'start': f"{s['start']//3600:02d}:{s['start']%3600//60:02d}",
                      'end': f"{s['end']//3600:02d}:{s['end']%3600//60:02d}", 'duration': s['duration'],
                      'routes': len(s['routes']), 'pick_kinds': s['pick_kinds'], 'pick_count': s['pick_count'],
                      'progress_idx': s['progress'][0] if s['progress'] else None,
                      'progress_total': (s['progress'][1] or day_total or grp_total) if s['progress'] else None,
                      'progress_est': s['estimated'],
                      'items': dict(s['items'].most_common())} for s in sessions],
        'items': dict(day_items.most_common()),
        'wasted_routes': wasted_routes,
        'duplicates': dict(sorted(duplicates.items(), key=lambda x: -x[1])),
    }
    with _cache_lock:
        _cache[date8] = (mtime, result)
    return result

def current_group_total():
    try:
        g = json.load(open(GROUP_JSON, encoding='utf-8'))
        return len(g.get('projects', []))
    except Exception:
        return None

def current_status():
    st = {'bgi_running': False, 'game_running': False, 'phase': '?', 'active_until': '',
          'bookmark_idx': None, 'group_total': current_group_total(), 'bookmark_name': '',
          'last_log_write': ''}
    try:
        out = subprocess.check_output(['tasklist', '/NH', '/FI', 'IMAGENAME eq BetterGI.exe'],
                                      text=True, stderr=subprocess.DEVNULL)
        st['bgi_running'] = 'BetterGI.exe' in out
        out = subprocess.check_output(['tasklist', '/NH', '/FI', 'IMAGENAME eq YuanShen.exe'],
                                      text=True, stderr=subprocess.DEVNULL)
        st['game_running'] = 'YuanShen.exe' in out
    except Exception:
        pass
    try:
        for line in open(STATE_FILE, encoding='utf-8', errors='ignore'):
            if line.startswith('PHASE='): st['phase'] = line.strip().split('=', 1)[1]
            if line.startswith('ACTIVE_UNTIL='): st['active_until'] = line.strip().split('=', 1)[1].split(' ')[-1]
    except OSError:
        pass
    try:
        cfg = json.load(open(BGI_CONFIG, encoding='utf-8'))
        nst = cfg.get('nextScheduledTask') or []
        if nst:
            st['bookmark_idx'] = nst[0].get('Item2')
            st['bookmark_name'] = nst[0].get('Item4', '')
    except Exception:
        pass
    logs = sorted(glob.glob(os.path.join(BGI_LOG_DIR, 'better-genshin-impact*.log')))
    if logs:
        st['last_log_write'] = datetime.fromtimestamp(os.path.getmtime(logs[-1])).strftime('%H:%M:%S')
    try:
        st['cycle_tail'] = open(CYCLE_LOG, encoding='utf-8', errors='ignore').read().splitlines()[-4:]
    except OSError:
        st['cycle_tail'] = []
    return st

def list_days():
    days = []
    for p in glob.glob(os.path.join(BGI_LOG_DIR, 'better-genshin-impact*.log')):
        m = re.search(r'(\d{8})\.log$', p)
        if m: days.append(m.group(1))
    return sorted(days)

def overview(days=30):
    all_days = list_days()[-days:]
    out = []
    for d in all_days:
        info = parse_day(d)
        if info:
            out.append({'date': info['date'], 'date_fmt': info['date_fmt'], 'weekday': info['weekday'],
                        'routes': info['route_total'], 'picks': info['pick_count'],
                        'wasted': info['wasted_routes'],
                        'sessions': [{'name': s['name'], 'duration': s['duration'], 'routes': s['routes'],
                                      'idx': s['progress_idx'], 'total': s['progress_total'],
                                      'progress_est': s['progress_est']} for s in info['sessions']],
                        'od': info['od']})
    return {'days': out, 'status': current_status()}

# ---------- HTML ----------
PAGE = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>BetterGI 收集 Dashboard</title>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family:-apple-system,"PingFang SC","Microsoft YaHei",sans-serif;
         background:#0d1117; color:#dce3ec; padding:18px; min-height:100vh; }
  h1 { font-size:20px; color:#58a6ff; margin-bottom:14px; }
  h2 { font-size:15px; color:#79c0ff; margin:18px 0 10px; }
  a { color:#58a6ff; text-decoration:none; }
  .pills { display:flex; gap:8px; flex-wrap:wrap; margin-bottom:16px; }
  .pill { background:#161b22; border:1px solid #30363d; border-radius:16px; padding:4px 12px; font-size:12px; color:#8b949e; }
  .pill b { color:#dce3ec; font-weight:600; }
  .pill.on { border-color:#238636; } .pill.on b { color:#3fb950; }
  .pill.off { border-color:#6e2a2a; } .pill.off b { color:#f85149; }
  /* 日历 */
  .cal { display:grid; grid-template-columns:repeat(7,1fr); gap:8px; }
  .cal .head { text-align:center; color:#8b949e; font-size:12px; padding:4px 0; }
  .day { background:#161b22; border:1px solid #30363d; border-radius:10px; padding:10px; cursor:pointer;
         transition:border-color .15s, transform .15s; min-height:104px; position:relative; }
  .day:hover { border-color:#58a6ff; transform:translateY(-2px); }
  .day.empty { opacity:.35; cursor:default; }
  .day.empty:hover { border-color:#30363d; transform:none; }
  .day.today { border-color:#1f6feb; box-shadow:0 0 0 1px #1f6feb; }
  .day.warn { border-color:#6e2a2a; background:#1c1414; }
  .day .d-head { display:flex; justify-content:space-between; align-items:baseline; margin-bottom:6px; }
  .day .d-num { font-size:16px; font-weight:700; }
  .day .d-wk { font-size:11px; color:#8b949e; }
  .day .d-stat { font-size:11px; color:#8b949e; line-height:1.5; }
  .day .d-stat b { color:#79c0ff; font-weight:600; }
  .day .d-stat b.pk { color:#3fb950; }
  .chips { display:flex; gap:4px; flex-wrap:wrap; margin-top:6px; }
  .chip { font-size:10px; padding:1px 7px; border-radius:8px; background:#21262d; color:#8b949e; }
  .chip b { color:#dce3ec; }
  .badge { font-size:10px; margin-left:3px; }
  .badge.ok { color:#3fb950; } .badge.no { color:#484f58; }
  .prog { font-size:10px; color:#d29922; margin-top:4px; }
  /* 详情页 */
  .cards { display:grid; grid-template-columns:repeat(auto-fit,minmax(150px,1fr)); gap:10px; margin-bottom:6px; }
  .card { background:#161b22; border:1px solid #30363d; border-radius:10px; padding:14px; }
  .card .n { font-size:26px; font-weight:700; color:#58a6ff; }
  .card .l { font-size:11px; color:#8b949e; margin-top:2px; }
  .card.g .n { color:#3fb950; } .card.y .n { color:#d29922; } .card.r .n { color:#f85149; }
  .od-row { display:flex; gap:8px; flex-wrap:wrap; }
  .od { background:#161b22; border:1px solid #30363d; border-radius:10px; padding:10px 14px; font-size:13px; }
  .od.ok { border-color:#238636; } .od.ok::before { content:"✓ "; color:#3fb950; font-weight:700; }
  .od.no { opacity:.55; } .od.no::before { content:"✗ "; color:#f85149; }
  .sess { background:#161b22; border:1px solid #30363d; border-radius:10px; padding:14px; margin-bottom:10px; }
  .sess .s-head { display:flex; align-items:center; gap:10px; flex-wrap:wrap; }
  .sess .s-name { font-size:15px; font-weight:700; color:#79c0ff; }
  .sess .s-time { font-size:12px; color:#8b949e; }
  .sess .s-dur { font-size:12px; color:#d29922; }
  .sess .s-routes { font-size:12px; color:#8b949e; margin-left:auto; }
  .sess .s-routes b { color:#58a6ff; }
  .pbar { height:8px; background:#21262d; border-radius:4px; overflow:hidden; margin:8px 0 4px; }
  .pbar > div { height:100%; background:linear-gradient(90deg,#1f6feb,#3fb950); border-radius:4px; }
  .pbar.y > div { background:linear-gradient(90deg,#9e6a03,#d29922); }
  .ptxt { font-size:11px; color:#8b949e; }
  .ptxt b { color:#d29922; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  th, td { padding:7px 10px; text-align:left; border-bottom:1px solid #21262d; }
  th { color:#8b949e; font-weight:500; font-size:12px; }
  th.num, td.num { text-align:right; }
  tr:hover td { background:#161b22; }
  td.tot { color:#79c0ff; font-weight:600; }
  .sess-cols { display:grid; grid-template-columns:repeat(auto-fit,minmax(260px,1fr)); gap:10px; }
  .ibox { background:#161b22; border:1px solid #30363d; border-radius:10px; padding:12px; }
  .ibox h3 { font-size:13px; color:#79c0ff; margin-bottom:8px; }
  .ibox h3 small { color:#8b949e; font-weight:400; }
  .ilist { font-size:12px; max-height:340px; overflow-y:auto; }
  .ilist .row { display:flex; justify-content:space-between; padding:3px 4px; border-bottom:1px solid #21262d; }
  .ilist .row:hover { background:#1c2129; }
  .ilist .cnt { color:#3fb950; font-weight:600; }
  .back { display:inline-block; margin-bottom:12px; font-size:13px; background:#21262d; padding:6px 14px; border-radius:8px; }
  .back:hover { background:#30363d; }
  .note { color:#8b949e; font-size:12px; margin:8px 0; }
  @media (max-width:760px){ .cal{grid-template-columns:repeat(3,1fr);} }
</style>
</head>
<body>
<div id="app"></div>
<script>
const $app = document.getElementById('app');
const esc = s => String(s).replace(/[&<>"]/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const odBadge = od => {
  const items = [['月卡', od.monthly_card], ['委托', od.daily_commission], ['派遣', od.expedition], ['尘歌壶', od.teapot]];
  return items.map(([n, ok]) => `<span class="badge ${ok?'ok':'no'}">${ok?'✓':'✗'}${n}</span>`).join('');
};

function statusPills(s) {
  return `<div class="pills">
    <span class="pill ${s.bgi_running?'on':'off'}">BGI <b>${s.bgi_running?'运行中':'停止'}</b></span>
    <span class="pill ${s.game_running?'on':'off'}">游戏 <b>${s.game_running?'运行中':'关闭'}</b></span>
    <span class="pill">书签 <b>${s.bookmark_idx!=null ? s.bookmark_idx+'/'+s.group_total : '无'}</b></span>
    <span class="pill">日志 <b>${esc(s.last_log_write||'-')}</b></span>
  </div>`;
}

function renderOverview(data) {
  const s = data.status;
  // 补齐日历前的星期偏移 (周日开头)
  let html = `<h1>🧊 BetterGI 收集 Dashboard</h1>${statusPills(s)}`;
  html += `<div class="note">点击任意日期查看当日详情 · 近 30 天</div><div class="cal">`;
  ['日','一','二','三','四','五','六'].forEach(w => html += `<div class="head">周${w}</div>`);
  const days = data.days;
  if (days.length) {
    const first = new Date(days[0].date_fmt + 'T00:00:00');
    for (let i = 0; i <= first.getDay(); i++) html += `<div></div>`;
  }
  const todayFmt = new Date().toISOString().slice(0,10);
  days.forEach(d => {
    const chips = d.sessions.map(x => {
      const prog = (x.idx != null && x.total) ? ` <b>${x.progress_est?'~':''}${x.idx}/${x.total}</b>` : '';
      return `<span class="chip">${x.name[0]}${x.duration}${prog}</span>`;
    }).join('');
    const progAll = d.sessions.filter(x=>x.idx!=null).map(x=>`${x.idx}/${x.total}`).pop();
    html += `<div class="day ${d.date_fmt===todayFmt?'today':''} ${d.wasted>0?'warn':''}" onclick="location.hash='#/${d.date}'">
      <div class="d-head"><span class="d-num">${d.date_fmt.slice(5)}</span><span class="d-wk">${d.weekday}</span></div>
      <div class="d-stat">路线 <b>${d.routes}</b> · 拾取 <b class="pk">${d.picks}</b>${d.wasted>0?` · <b style="color:#f85149">重复${d.wasted}</b>`:''}</div>
      ${odBadge(d.od)}
      <div class="chips">${chips || '<span class="chip">无场次</span>'}</div>
      ${progAll ? `<div class="prog">进度 ${progAll}</div>` : ''}
    </div>`;
  });
  html += `</div>`;
  $app.innerHTML = html;
}

function sessionCard(s) {
  const idx = s.progress_idx, total = s.progress_total;
  const mark = s.progress_est ? '~' : '';
  let bar = '';
  if (idx != null && total) {
    const pct = Math.min(100, Math.round(idx/total*100));
    bar = `<div class="pbar ${pct>=100?'':'y'}"><div style="width:${pct}%"></div></div>
           <div class="ptxt">收集进度 <b>${mark}${idx} / ${total}</b> (${pct}%${s.progress_est?', 估':''})</div>`;
  }
  return `<div class="sess">
    <div class="s-head">
      <span class="s-name">${esc(s.name)}</span>
      <span class="s-time">${s.start} – ${s.end}</span>
      <span class="s-dur">⏱ ${s.duration}</span>
      <span class="s-routes">路线 <b>${s.routes}</b> 条 · 拾取 <b>${s.pick_kinds}</b> 种 <b>${s.pick_count}</b> 个</span>
    </div>
    ${bar}
  </div>`;
}

function renderDay(d) {
  const od = d.od;
  const odItems = [['月卡 (空月祝福)', od.monthly_card], ['每日委托奖励', od.daily_commission],
                   ['探索派遣', od.expedition], ['尘歌壶奖励', od.teapot]];
  const resin = od.resin != null ? `<div class="od ${od.resin>0?'ok':'no'}">剩余树脂 ${od.resin}</div>` : '';
  let html = `<a class="back" href="javascript:location.hash=''">← 返回日历</a>
    <h1>${d.date_fmt} 周${d.weekday} 执行详情</h1>
    <div class="cards">
      <div class="card"><div class="n">${d.route_total}</div><div class="l">路线执行 (含重试)</div></div>
      <div class="card"><div class="n">${d.route_unique}</div><div class="l">唯一路线</div></div>
      <div class="card g"><div class="n">${d.pick_count}</div><div class="l">拾取总数</div></div>
      <div class="card"><div class="n">${d.pick_kinds}</div><div class="l">物品种类</div></div>
      <div class="card ${d.battle_fail_rate>50?'r':'y'}"><div class="n">${d.battle_fail_rate}%</div><div class="l">战斗检测失败率</div></div>
    </div>
    <h2>日常任务</h2>
    <div class="od-row">${odItems.map(([n,ok])=>`<div class="od ${ok?'ok':'no'}">${n}</div>`).join('')}${resin}</div>
    <h2>场次 (${d.sessions.length})</h2>
    ${d.sessions.map(sessionCard).join('') || '<div class="note">无场次记录</div>'}`;
  if (d.wasted && d.wasted > 0) {
    html += `<h2>错题本 · 当天重复执行的路线 (共 ${d.wasted} 次白跑)</h2>
      <table><tr><th>路线</th><th class="num">执行次数</th><th class="num">多跑</th></tr>${
      Object.entries(d.duplicates).map(([n,c]) =>
        `<tr><td>${esc(n)}</td><td class="num" style="color:#ff6b6b">${c}</td><td class="num" style="color:#f85149">+${c-1}</td></tr>`).join('')}
      </table>`;
  }
  html += `<h2>物品拾取明细 (按场次)</h2>`;
  if (d.sessions.length) {
    html += `<div class="sess-cols">` + d.sessions.map(s => `
      <div class="ibox"><h3>${esc(s.name)} <small>${s.start}–${s.end} · ${s.pick_kinds}种 ${s.pick_count}个</small></h3>
      <div class="ilist">${Object.entries(s.items).map(([n,c]) =>
        `<div class="row"><span>${esc(n)}</span><span class="cnt">${c}</span></div>`).join('') || '<div class="note">无拾取</div>'}
      </div></div>`).join('') + `</div>`;
  } else {
    html += `<div class="ibox"><div class="ilist">${Object.entries(d.items).map(([n,c]) =>
      `<div class="row"><span>${esc(n)}</span><span class="cnt">${c}</span></div>`).join('') || '<div class="note">无拾取</div>'}</div></div>`;
  }
  // 全部物品汇总表
  html += `<h2>全天物品汇总 (${d.pick_kinds} 种)</h2>
    <table><tr><th>物品</th><th class="num">数量</th>${d.sessions.map(s=>`<th class="num">${esc(s.name)}</th>`).join('')}</tr>`;
  const si = d.sessions.map(s => s.items);
  Object.entries(d.items).forEach(([n, c]) => {
    html += `<tr><td>${esc(n)}</td><td class="num tot">${c}</td>${si.map(m=>`<td class="num">${m[n]||'·'}</td>`).join('')}</tr>`;
  });
  html += `</table>`;
  $app.innerHTML = html;
}

async function route() {
  const h = location.hash.slice(2);
  if (h) {
    const d = await (await fetch('/api/day?date=' + h)).json();
    if (d && !d.error) renderDay(d); else $app.innerHTML = '<a class="back" href="javascript:location.hash=\'\'">← 返回</a><div class="note">无当日数据</div>';
  } else {
    const data = await (await fetch('/api/overview')).json();
    renderOverview(data);
  }
}
window.addEventListener('hashchange', route);
route();
setInterval(async () => {           // 状态条静默刷新
  if (location.hash.slice(2)) return;
  const data = await (await fetch('/api/overview')).json();
  renderOverview(data);
}, 30000);
</script>
</body>
</html>'''

# ---------- HTTP ----------
class Handler(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a): pass
    def do_GET(self):
        parsed = urlparse(self.path)
        try:
            if parsed.path == '/api/overview':
                self._json(overview())
            elif parsed.path == '/api/status':
                self._json(current_status())
            elif parsed.path == '/api/day':
                date8 = parse_qs(parsed.query).get('date', [''])[0]
                info = parse_day(date8) if date8.isdigit() and len(date8) == 8 else None
                self._json(info or {'error': 'not found'})
            elif parsed.path in ('/', '/index.html'):
                self._html(PAGE)
            else:
                super().do_GET()
        except Exception as e:
            self._json({'error': str(e)}, 500)
    def _json(self, obj, code=200):
        body = json.dumps(obj, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    def _html(self, text):
        body = text.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

def run(port=8765):
    with http.server.ThreadingHTTPServer(('127.0.0.1', port), Handler) as httpd:
        print(f"BetterGI Dashboard v2 → http://localhost:{port}", flush=True)
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            pass

if __name__ == '__main__':
    run(int(sys.argv[1]) if len(sys.argv) > 1 else 8765)
