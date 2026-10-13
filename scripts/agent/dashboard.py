# -*- coding: utf-8 -*-
"""BetterGI Dashboard — localhost:8765
单文件 dashboard: HTTP server + 日志解析 API + HTML 前端
启动: python dashboard.py  (然后浏览器打开 http://localhost:8765)
"""
import http.server, json, re, os, glob, sys, subprocess
from urllib.parse import urlparse, parse_qs
from collections import Counter, defaultdict
from datetime import datetime, timedelta

BGI_LOG_DIR = r"D:\projects\betterGI\log"
BGI_CONFIG = r"D:\projects\betterGI\User\config.json"
GROUP_JSON = r"D:\projects\betterGI\User\ScriptGroup\全自动循环.json"
CYCLE_LOG = r"C:\Users\djf20\cycle_log.txt"
STATE_FILE = r"C:\Users\djf20\session_state.txt"

# ---------- 日志解析 ----------
ROUTE_RE = re.compile(r'开始执行地图追踪任务[:：]\s*"([^"]+)"')
PICK_RE  = re.compile(r'交互或拾取[:：]\s*"([^"]+)"')
BATTLE_END_RE   = re.compile(r'识别到战斗结束')
BATTLE_FAIL_RE  = re.compile(r'未识别到战斗结束')
OD_DONE_RE      = re.compile(r'一条龙.{0,8}任务结束')
OD_COMPLETE_RE  = re.compile(r'全部任务执行完毕')
ROUTE_LINE_RE   = re.compile(r'^\[(\d{4}-\d{2}-\d{2})')

def parse_log(path):
    """解析单个 BGI 日志文件，返回 dict"""
    routes, picks, battle_ok, battle_fail, od_done = [], [], 0, 0, 0
    route_times = {}  # route_name -> list of (date, time)
    current_date = None
    time_re = re.compile(r'\[(\d{2}:\d{2}:\d{2})')
    
    with open(path, encoding='utf-8', errors='ignore') as f:
        for line in f:
            dm = ROUTE_LINE_RE.match(line)
            if dm:
                current_date = dm.group(1)
                continue
            m = ROUTE_RE.search(line)
            if m:
                name = m.group(1).strip()
                routes.append(name)
                if current_date:
                    tm = time_re.search(line)
                    route_times.setdefault(name, []).append(f"{current_date} {tm.group(1) if tm else ''}")
            m = PICK_RE.search(line)
            if m:
                picks.append(m.group(1).strip())
            if BATTLE_END_RE.search(line):
                battle_ok += 1
            if BATTLE_FAIL_RE.search(line):
                battle_fail += 1
            if OD_DONE_RE.search(line):
                od_done += 1
    
    # 路线去重但保留顺序 (只算唯一路线 vs 执行次数)
    unique_routes = list(dict.fromkeys(routes))
    pick_counter = Counter(picks)
    
    # 按物品类型分组
    item_groups = defaultdict(int)
    for item, cnt in pick_counter.items():
        g = guess_item_group(item)
        item_groups[g] += cnt
    
    return {
        'file': os.path.basename(path),
        'date': os.path.basename(path).replace('better-genshin-impact','').replace('.log',''),
        'route_total': len(routes),      # 执行次数 (含重试)
        'route_unique': len(unique_routes),  # 唯一路线数
        'routes': unique_routes,          # 路线名列表
        'route_times': route_times,       # 每条路线的执行时间点
        'pick_count': len(picks),         # 拾取动作总次数
        'pick_items': dict(pick_counter.most_common(50)),  # 物品→数量 top50
        'pick_groups': dict(sorted(item_groups.items(), key=lambda x:-x[1])),
        'battle_ok': battle_ok,
        'battle_fail': battle_fail,
        'battle_fail_rate': round(battle_fail/(battle_ok+battle_fail)*100,1) if (battle_ok+battle_fail) else 0,
        'od_done': od_done,
    }

# 物品名 → 大类映射 (简化版, 命中模糊关键词)
_GROUP_RULES = [
    ('水晶/矿石', ['水晶块', '紫晶块', '白铁矿', '黑铁矿', '铁矿', '黄金矿', '夜珀石', '萃凝晶', '魔晶块', '晶化骨髓']),
    ('植物',     ['清心', '琉璃', '甜甜花', '薄荷', '风车菊', '蘑菇', '绝云椒', '蒲公英', '萝卜', '松茸', '马尾', '琉璃百合', '海灵芝', '珊瑚', '落落莓', '钩钩果', '嘟嘟莲', '松珀', '云岩', '香', '叶']),
    ('魔兽材料', ['嵌合种', '并生', '沉积', '幻造', '霜凝', '冰晶', '兽肉', '禽肉', '鱼肉', '黄金鲈鱼', '冰晶蝶', '蝴蝶', '晶核']),
    ('精英掉落', ['角斗士', '乐团', '魔女', '苍白', '千岩', '绝缘', '追忆', '辰砂', '余响', '沙上楼阁', '往昔四', '猎人', '行者', '战狂', '守护', '奇迹', '勇者', '冒险家', '学士', '祭雷', '染血', '骑士', '流放者', '游医', '幸运', '圣遗物', '原胚', '破魔', '刀镡', '弓矢', '枪柄', '遗迹', '混沌', '深渊']),
    ('丘丘人',   ['箭簇', '羽箭', '面具', '丘丘', '萨满']),
    ('史莱姆',   ['史莱姆']),
    ('盗宝团',   ['鸦印', '徽记', '盗宝团']),
    ('遗迹守卫', ['守卫', '核心', '齿轮', '遗迹机']),
    ('其他',     []),
]

def guess_item_group(name):
    for group, kws in _GROUP_RULES:
        if any(k in name for k in kws):
            return group
    return '其他'

def list_days():
    """列出近 N 天有 BGI 日志的日期"""
    logs = sorted(glob.glob(os.path.join(BGI_LOG_DIR, 'better-genshin-impact*.log')))
    days = []
    for p in logs:
        m = re.search(r'(\d{8})\.log$', p)
        if m:
            days.append(m.group(1))
    return days

def get_summary():
    """近 14 天汇总"""
    days = list_days()[-14:]
    summary = []
    for d in days:
        log_path = os.path.join(BGI_LOG_DIR, f'better-genshin-impact{d}.log')
        if os.path.exists(log_path):
            info = parse_log(log_path)
            summary.append({
                'date': d,
                'route_total': info['route_total'],
                'route_unique': info['route_unique'],
                'pick_count': info['pick_count'],
                'battle_fail_rate': info['battle_fail_rate'],
            })
    
    # 当前运行状态
    status = get_status()
    summary_data = {
        'days': summary,
        'today': summary[-1] if summary else None,
        'status': status,
    }
    
    # 今日物品汇总
    if days:
        today_log = os.path.join(BGI_LOG_DIR, f'better-genshin-impact{days[-1]}.log')
        if os.path.exists(today_log):
            info = parse_log(today_log)
            summary_data['today_items'] = info['pick_items']
            summary_data['today_groups'] = info['pick_groups']
    
    return summary_data

def get_status():
    """当前运行状态"""
    result = {
        'bgi_running': False,
        'game_running': False,
        'phase': 'UNKNOWN',
        'active_until': '',
        'bookmark_idx': -1,
        'group_total': 0,
        'bookmark_name': '',
        'last_log_write': '',
    }
    try:
        procs = subprocess.check_output(['tasklist', '/FI', 'IMAGENAME eq BetterGI.exe', '/NH'], text=True, stderr=subprocess.DEVNULL)
        result['bgi_running'] = 'BetterGI.exe' in procs
    except: pass
    try:
        procs = subprocess.check_output(['tasklist', '/FI', 'IMAGENAME eq YuanShen.exe', '/NH'], text=True, stderr=subprocess.DEVNULL)
        result['game_running'] = 'YuanShen.exe' in procs
    except: pass
    
    if os.path.exists(STATE_FILE):
        for line in open(STATE_FILE, encoding='utf-8', errors='ignore'):
            if line.startswith('PHASE='): result['phase'] = line.strip().split('=',1)[1]
            if line.startswith('ACTIVE_UNTIL='): result['active_until'] = line.strip().split('=',1)[1]
    
    # 书签
    try:
        if os.path.exists(BGI_CONFIG):
            cfg = json.load(open(BGI_CONFIG, encoding='utf-8'))
            nst = cfg.get('nextScheduledTask') or []
            if nst:
                result['bookmark_idx'] = nst[0].get('Item2', -1)
                result['bookmark_name'] = nst[0].get('Item4', '')
    except: pass
    try:
        if os.path.exists(GROUP_JSON):
            g = json.load(open(GROUP_JSON, encoding='utf-8'))
            result['group_total'] = len(g.get('projects', []))
    except: pass
    
    # 最新日志写入时间
    days = list_days()
    if days:
        last_log = os.path.join(BGI_LOG_DIR, f'better-genshin-impact{days[-1]}.log')
        if os.path.exists(last_log):
            result['last_log_write'] = datetime.fromtimestamp(os.path.getmtime(last_log)).strftime('%H:%M:%S')
    
    # 会话日志尾部
    if os.path.exists(CYCLE_LOG):
        result['cycle_tail'] = open(CYCLE_LOG, encoding='utf-8', errors='ignore').read().splitlines()[-5:]
    
    return result

def get_day(date):
    """某一天的完整数据"""
    log_path = os.path.join(BGI_LOG_DIR, f'better-genshin-impact{date}.log')
    if not os.path.exists(log_path):
        return None
    return parse_log(log_path)

# ---------- HTTP Handler ----------
class Handler(http.server.SimpleHTTPRequestHandler):
    server_version = "BetterGI-Dashboard/1.0"
    
    def log_message(self, fmt, *args):
        pass  # 静默
    
    def do_GET(self):
        parsed = urlparse(self.path)
        path = parsed.path
        
        if path == '/api/days':
            self._json(list_days())
        elif path == '/api/summary':
            self._json(get_summary())
        elif path == '/api/status':
            self._json(get_status())
        elif path.startswith('/api/day'):
            q = parse_qs(parsed.query)
            date = q.get('date', [''])[0]
            data = get_day(date) if date else None
            self._json(data or {'error': 'not found'})
        elif path == '/' or path == '/index.html':
            self._serve_html()
        else:
            super().do_GET()
    
    def _json(self, obj):
        body = json.dumps(obj, ensure_ascii=False, indent=2).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)
    
    def _serve_html(self):
        html = DASHBOARD_HTML.encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'text/html; charset=utf-8')
        self.send_header('Content-Length', str(len(html)))
        self.end_headers()
        self.wfile.write(html)

def run(port=8765):
    os.chdir(os.path.dirname(os.path.abspath(__file__)))
    with http.server.HTTPServer(('127.0.0.1', port), Handler) as httpd:
        print(f"BetterGI Dashboard → http://localhost:{port}")
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\nStopped.")

# ---------- Dashboard HTML ----------
DASHBOARD_HTML = r'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
<meta charset="UTF-8">
<title>BetterGI 收集 Dashboard</title>
<script src="https://cdn.jsdelivr.net/npm/echarts@5/dist/echarts.min.js"></script>
<style>
  * { margin:0; padding:0; box-sizing:border-box; }
  body { font-family: -apple-system, "PingFang SC", "Microsoft YaHei", sans-serif;
         background:#0f1217; color:#e0e0e0; padding:20px; }
  h1 { font-size:22px; margin-bottom:16px; color:#7ec4ff; }
  h2 { font-size:16px; margin:16px 0 10px; color:#a0d8ff; border-bottom:1px solid #2a3040; padding-bottom:6px; }
  .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(280px,1fr)); gap:14px; margin-bottom:16px; }
  .card { background:#1a1f2e; border-radius:10px; padding:16px; border:1px solid #2a3040; }
  .card .num { font-size:32px; font-weight:700; color:#7ec4ff; }
  .card .lbl { font-size:12px; color:#8899aa; margin-top:4px; }
  .card.ok .num { color:#6dd67a; }
  .card.warn .num { color:#ffb347; }
  .card.err .num { color:#ff6b6b; }
  #status-bar { display:flex; gap:10px; margin-bottom:16px; flex-wrap:wrap; }
  .pill { background:#1a1f2e; padding:6px 12px; border-radius:20px; font-size:13px; border:1px solid #2a3040; }
  .pill.green { border-color:#2e6b35; color:#6dd67a; }
  .pill.red { border-color:#7a2e2e; color:#ff6b6b; }
  .pill.blue { border-color:#2e4a7a; color:#7ec4ff; }
  .pill.gray { color:#8899aa; }
  .chart { width:100%; height:300px; }
  .chart.sm { height:220px; }
  .two-col { display:grid; grid-template-columns:1fr 1fr; gap:14px; }
  table { width:100%; border-collapse:collapse; font-size:13px; }
  th, td { padding:8px 10px; text-align:left; border-bottom:1px solid #2a3040; }
  th { color:#8899aa; font-weight:500; }
  tr:hover td { background:#1e2436; }
  .item-cat { display:inline-block; font-size:11px; padding:2px 8px; border-radius:10px;
              background:#2a3040; color:#a0d8ff; margin-right:4px; }
  .bar { height:10px; background:#2a3040; border-radius:5px; overflow:hidden; }
  .bar > div { height:100%; background:linear-gradient(90deg,#7ec4ff,#5a9fd4); border-radius:5px; transition:width .3s; }
  .btn { background:#2a3040; color:#e0e0e0; border:none; padding:6px 14px; border-radius:6px; cursor:pointer;
         font-size:13px; margin-right:6px; }
  .btn:hover { background:#3a4055; }
  .select { background:#1a1f2e; color:#e0e0e0; border:1px solid #2a3040; padding:6px 10px; border-radius:6px; font-size:13px; }
  .route-list { max-height:400px; overflow-y:auto; }
  .route-item { padding:6px 10px; font-size:13px; border-bottom:1px solid #222838;
                cursor:pointer; display:flex; justify-content:space-between; }
  .route-item:hover { background:#1e2436; }
  .route-item .idx { color:#8899aa; min-width:30px; }
  .route-item .name { flex:1; padding:0 10px; }
  .route-item .count { color:#7ec4ff; font-weight:600; }
  .route-item.dup .name { color:#ffa040; }
  .empty { color:#8899aa; text-align:center; padding:40px; }
  .tag { font-size:11px; padding:1px 6px; border-radius:3px; }
  .tag.ice { background:#2e4a7a; color:#7ec4ff; }
  .tag.pyro { background:#7a3a2e; color:#ff9966; }
  .tag.water { background:#2e5a7a; color:#7edfff; }
  .tag.geo { background:#7a6a2e; color:#ffcc66; }
  .tag.electro { background:#6a2e7a; color:#d999ff; }
  .tag.anemo { background:#2e7a5a; color:#6dd67a; }
  .tag.dendro { background:#4a7a2e; color:#9ed966; }
  .tag.cryo { background:#2e6b7a; color:#8fdfff; }
  @media (max-width:800px) { .two-col { grid-template-columns:1fr; } }
</style>
</head>
<body>

<h1>🧊 BetterGI 收集 Dashboard</h1>

<div id="status-bar">
  <span class="pill" id="pill-bgi">BGI: 查询中...</span>
  <span class="pill" id="pill-game">游戏: 查询中...</span>
  <span class="pill blue" id="pill-phase">阶段: -</span>
  <span class="pill" id="pill-session">会话: -</span>
  <span class="pill" id="pill-bookmark">书签: -</span>
  <span class="pill gray" id="pill-log">日志: -</span>
</div>

<div class="grid" id="today-cards"></div>

<div class="two-col">
  <div class="card">
    <h2>近 14 天趋势</h2>
    <div id="chart-trend" class="chart"></div>
  </div>
  <div class="card">
    <h2>物品大类分布 (今日)</h2>
    <div id="chart-groups" class="chart sm"></div>
  </div>
</div>

<div class="two-col">
  <div class="card">
    <h2>物品拾取明细 (Top 30)
      <select class="select" id="day-select" style="float:right;">
        <option value="">今日</option>
      </select>
    </h2>
    <div id="chart-items" class="chart" style="height:380px;"></div>
  </div>
  <div class="card">
    <h2>路线执行记录
      <button class="btn" onclick="loadDay()">刷新</button>
    </h2>
    <div id="route-list" class="route-list empty">加载中...</div>
  </div>
</div>

<div class="card">
  <h2>会话日志尾部</h2>
  <pre id="cycle-tail" style="font-size:12px; color:#8899aa; overflow-x:auto; white-space:pre-wrap;"></pre>
</div>

<script>
const $ = id => document.getElementById(id);
let trendChart, groupsChart, itemsChart;

async function api(p) {
  const r = await fetch(p);
  return r.json();
}

function tagFromRoute(name) {
  if (/寒|冰|霜|雪|至冬/i.test(name)) return '<span class="tag ice">冰</span>';
  if (/火|炎|熔|煅/i.test(name)) return '<span class="tag pyro">火</span>';
  if (/水|海|湖|河/i.test(name)) return '<span class="tag water">水</span>';
  if (/石|矿|岩|层岩|沉玉/i.test(name)) return '<span class="tag geo">岩</span>';
  if (/雷|电|稻妻|神无/i.test(name)) return '<span class="tag electro">雷</span>';
  if (/风|蒙德/i.test(name)) return '<span class="tag anemo">风</span>';
  if (/草|沉玉|枫丹|新枫丹/i.test(name)) return '<span class="tag dendro">草</span>';
  return '';
}

function renderStatus(s) {
  $('pill-bgi').className = 'pill ' + (s.bgi_running ? 'green' : 'red');
  $('pill-bgi').textContent = 'BGI: ' + (s.bgi_running ? '运行中' : '已停止');
  $('pill-game').className = 'pill ' + (s.game_running ? 'green' : 'red');
  $('pill-game').textContent = '游戏: ' + (s.game_running ? '运行中' : '已关闭');
  
  const phaseMap = {RUNNING:'运行中', OFFLINE:'已下线', WAITING:'等待', STARTING:'启动中'};
  $('pill-phase').textContent = '阶段: ' + (phaseMap[s.phase] || s.phase);
  
  let sess = '';
  if (s.active_until) sess = '下线: ' + s.active_until.split(' ')[1];
  $('pill-session').textContent = sess || '会话: -';
  
  if (s.bookmark_idx >= 0) {
    const total = s.group_total;
    const pct = total ? Math.round(s.bookmark_idx/total*100) : 0;
    $('pill-bookmark').innerHTML = `书签: ${s.bookmark_idx}/${total} (${pct}%)`;
  } else {
    $('pill-bookmark').textContent = '书签: 已跑完 / 无';
  }
  $('pill-log').textContent = '日志最后写入: ' + (s.last_log_write || '-');
  
  if (s.cycle_tail) $('cycle-tail').textContent = s.cycle_tail.join('\n');
}

function renderTodayCards(s) {
  const t = s.today;
  const g = s.status;
  const cards = [
    {cls:'', num: t ? t.route_total : 0, lbl:'路线执行次数 (含重试)'},
    {cls:'', num: t ? t.route_unique : 0, lbl:'唯一路线数'},
    {cls:'', num: t ? t.pick_count : 0, lbl:'拾取动作次数'},
    {cls:'', num: t ? t.battle_fail_rate + '%' : 0, lbl:'战斗识别失败率'},
    {cls: g.bgi_running?'ok':'warn', num: g.group_total ? (g.bookmark_idx>=0 ? g.bookmark_idx : g.group_total) + '/' + g.group_total : '-', 
     lbl: g.bookmark_idx>=0 ? '已跑到 / 总数 (续跑中)' : '已跑到 / 总数 (从头)'},
    {cls:'', num: t && t.route_total ? Math.round(t.route_total/4) + ' min' : '-', lbl:'估算战斗时长 (2.5min/条)'},
  ];
  $('today-cards').innerHTML = cards.map(c => 
    `<div class="card ${c.cls}"><div class="num">${c.num}</div><div class="lbl">${c.lbl}</div></div>`
  ).join('');
}

function renderTrend(days) {
  const dates = days.map(d => d.date.slice(4,6)+'/'+d.date.slice(6));
  const routes = days.map(d => d.route_total);
  const picks = days.map(d => d.pick_count);
  const fails = days.map(d => d.battle_fail_rate);
  
  if (!trendChart) trendChart = echarts.init($('chart-trend'));
  trendChart.setOption({
    tooltip:{trigger:'axis'},
    legend:{data:['路线数','拾取次数','战斗失败率%'], textStyle:{color:'#aaa'}},
    grid:{left:40,right:40,top:30,bottom:30},
    xAxis:{type:'category',data:dates,axisLine:{lineStyle:{color:'#444'}},axisLabel:{color:'#aaa'}},
    yAxis:[
      {type:'value',name:'数量',axisLine:{lineStyle:{color:'#444'}},axisLabel:{color:'#aaa'}},
      {type:'value',name:'%',axisLine:{lineStyle:{color:'#444'}},axisLabel:{color:'#aaa'},min:0,max:100}
    ],
    series:[
      {name:'路线数',type:'bar',data:routes,itemStyle:{color:'#7ec4ff'}},
      {name:'拾取次数',type:'bar',data:picks,itemStyle:{color:'#6dd67a'}},
      {name:'战斗失败率%',type:'line',yAxisIndex:1,data:fails,itemStyle:{color:'#ff6b6b'},smooth:true}
    ]
  }, true);
}

function renderGroups(groups) {
  if (!groups || !Object.keys(groups).length) { $('chart-groups').innerHTML = '<div class="empty">无数据</div>'; return; }
  if (!groupsChart) groupsChart = echarts.init($('chart-groups'));
  const colors = ['#7ec4ff','#6dd67a','#ffb347','#ff6b6b','#d999ff','#ffcc66','#8fdfff','#aaa'];
  groupsChart.setOption({
    tooltip:{trigger:'item',formatter:'{b}: {c} ({d}%)'},
    series:[{type:'pie',radius:['40%','70%'],avoidLabelOverlap:true,
      data:Object.entries(groups).map(([k,v])=>({name:k,value:v})),
      label:{color:'#e0e0e0'},
      itemStyle:{borderColor:'#1a1f2e',borderWidth:2},
      color:colors
    }]
  }, true);
}

function renderItems(items) {
  if (!items || !Object.keys(items).length) { $('chart-items').innerHTML = '<div class="empty">无拾取数据</div>'; return; }
  if (!itemsChart) itemsChart = echarts.init($('chart-items'));
  const sorted = Object.entries(items).sort((a,b)=>a[1]-b[1]).slice(-30);
  itemsChart.setOption({
    tooltip:{trigger:'axis'},
    grid:{left:100,right:30,top:10,bottom:20},
    xAxis:{type:'value',axisLabel:{color:'#aaa'}},
    yAxis:{type:'category',data:sorted.map(x=>x[0]),axisLabel:{color:'#e0e0e0'}},
    series:[{type:'bar',data:sorted.map(x=>x[1]),itemStyle:{
      color:p=>{
        const n = p.name;
        if (/水晶|矿|白铁|黑铁|铁矿|夜珀|萃凝|魔晶/.test(n)) return '#7ec4ff';
        if (/清心|琉璃|甜甜|薄荷|蘑菇|萝卜|松茸|马尾|百合|海灵|珊瑚|松珀|云岩/.test(n)) return '#6dd67a';
        if (/嵌合|沉积|幻造|霜凝|冰晶|兽肉|禽肉|鱼肉|黄金鲈|冰晶蝶|蝴蝶|晶核/.test(n)) return '#ffb347';
        if (/角斗|乐团|魔女|苍白|千岩|绝缘|追忆|圣遗物|原胚|破魔|刀镡|弓矢|枪柄|遗迹|混沌|深渊/.test(n)) return '#ff6b6b';
        if (/箭簇|羽箭|面具|丘丘|萨满/.test(n)) return '#d999ff';
        if (/鸦印|徽记|盗宝/.test(n)) return '#ffcc66';
        return '#aaa';
      }
    }, label:{show:true,position:'right',color:'#e0e0e0'}}]
  }, true);
}

async function loadDay() {
  const sel = $('day-select');
  const date = sel.value;
  const data = date ? await api('/api/day?date='+date) : await api('/api/summary');
  
  const info = date ? data : null;
  const items = date ? (info.pick_items || {}) : (data.today_items || {});
  
  renderItems(items);
  
  if (info) {
    const dupCount = {};
    info.routes.forEach(r => dupCount[r] = (dupCount[r]||0)+1);
    const list = info.routes.map((name,i) => {
      const dup = dupCount[name] > 1 ? ' dup' : '';
      return `<div class="route-item${dup}"><span class="idx">${i+1}</span><span class="name">${tagFromRoute(name)}${name}</span><span class="count">${dupCount[name]}</span></div>`;
    }).join('');
    $('route-list').innerHTML = list || '<div class="empty">今日无路线</div>';
  }
}

async function init() {
  const summary = await api('/api/summary');
  renderStatus(summary.status);
  renderTodayCards(summary);
  renderTrend(summary.days);
  renderGroups(summary.today_groups || {});
  renderItems(summary.today_items || {});
  
  // 日期下拉
  const days = await api('/api/days');
  const sel = $('day-select');
  sel.innerHTML = '<option value="">今日</option>' + 
    days.slice(-14).reverse().map(d => `<option value="${d}">${d.slice(0,4)}-${d.slice(4,6)}-${d.slice(6)}</option>`).join('');
  sel.addEventListener('change', loadDay);
  
  // 初始路线列表用今日汇总数据
  const info = days.length ? await api('/api/day?date='+days[-1]) : null;
  if (info) {
    const dupCount = {};
    info.routes.forEach(r => dupCount[r] = (dupCount[r]||0)+1);
    $('route-list').innerHTML = info.routes.map((name,i) => {
      const dup = dupCount[name] > 1 ? ' dup' : '';
      return `<div class="route-item${dup}"><span class="idx">${i+1}</span><span class="name">${tagFromRoute(name)}${name}</span><span class="count">${dupCount[name]}</span></div>`;
    }).join('') || '<div class="empty">今日无路线</div>';
  }
  
  // 30 秒刷新状态
  setInterval(async () => {
    const s = await api('/api/status');
    renderStatus(s);
  }, 30000);
  
  window.addEventListener('resize', () => {
    trendChart && trendChart.resize();
    groupsChart && groupsChart.resize();
    itemsChart && itemsChart.resize();
  });
}
init();
</script>
</body>
</html>
'''

if __name__ == '__main__':
    port = int(sys.argv[1]) if len(sys.argv) > 1 else 8765
    run(port)
