# 定时上线会话 v3 (2026-09-17: 去钓鱼 + 接采矿组):
#   手动游戏保护 → 排程下线 → 杀残留 → BGI+截图器 → 游戏 → 2min安静+隐藏点击器进门 → F9
#   → 等一条龙流程完成标记 (轮询, 上限100min) → UIA 启动"白铁优先"采矿组 → RUNNING
# 关键设计:
#   - 钓鱼已从一条龙任务禁用 (费时间低收益, 用户决策 09-17); 流程=合成/每日/邮件/尘歌壶/地脉花
#   - 完成标记会出现 (~30-60min): 09-17 实测 64min 出现; 旧 v1 的 40min 只是太短, 并非标记不存在
#   - 流程结束后才 UIA 点组 —— 运行中点组会打断健康流程 (09-16 2h 死循环事故)
#   - 等待期间 PHASE 保持 STARTING, 看门狗不干预; 若流程卡死 (静默≥25min) → 置 RUNNING 让看门狗接手
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\cycle_log.txt'
$base = 'D:\projects\betterGI'
$gameExe = 'E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe'
$stateFile = 'C:\Users\djf20\session_state.txt'
# 每日收集标记 (书签续跑机制):
#   collection_done.txt     = 今日日期 → 今日已启动过收集, 下场从书签续跑
#   collection_finished.txt = 今日日期 → 今日已全部跑完, 下场只跑体力监控
#   collection_started.flag = 本场启动了收集大组 → 下线时据此更新上述标记
$collectDoneFile = 'C:\Users\djf20\collection_done.txt'
$collectFinishedFile = 'C:\Users\djf20\collection_finished.txt'
$collectStartFlag = 'C:\Users\djf20\collection_started.flag'
$groupJson = "$base\User\ScriptGroup\全自动循环.json"
$configJson = "$base\User\config.json"
function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

# 读最新日志新增内容的小工具 (按字节偏移, 绕独占锁)
$script:offset = 0
function Read-NewLog {
  $f = Get-ChildItem "$base\log\*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $f) { return '' }
  try {
    $fs = [System.IO.FileStream]::new($f.FullName, 'Open', 'Read', 'ReadWrite')
    $len = $fs.Length
    if ($len -lt $script:offset) { $script:offset = 0 }
    $fs.Seek($script:offset, 'Begin') | Out-Null
    $sr = [System.IO.StreamReader]::new($fs, [Text.Encoding]::UTF8)
    $txt = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
    $script:offset = $len
    return $txt
  } catch { return '' }
}

# 顶号检测: MiHoYoSDK.log 每次进门都会新增一条 "into LoginManager::Login"
# 被顶号→回门→点击器重进→必多一条登录记录; 轮次内新增≥2 = 用户在其他设备手动登录 → 跳过本轮
$sdkLog = "$env:USERPROFILE\AppData\LocalLow\miHoYo\" + [char]0x539F + [char]0x795E + "\logs\MiHoYoSDK.log"
function Count-Logins {
  try { return (Select-String -Path $sdkLog -Pattern 'into LoginManager::Login' -Encoding UTF8 -ErrorAction Stop | Measure-Object).Count }
  catch { return -1 }
}
$script:loginBase = 0
# 顶号判定: delta = 当前登录数 - 基线; 1=自己开局, 之后每+1=被顶号重进一次
# 用户规则: 重复登录(被顶)≥2次 = 用户在手动玩 → 跳过本轮 (即 delta≥3 触发)
function Skip-IfRelogin($stage) {
  if ($script:loginBase -lt 0) { return }
  $now = Count-Logins
  $delta = $now - $script:loginBase
  if ($now -ge 0 -and $delta -ge 3) {
    Log "检测到账号重复登录 $($delta - 1) 次 ($stage), 判定用户手动登录中, 跳过本轮一条龙 → 直接下线"
    & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\cycle_offline.ps1
    exit 0
  }
}

Log "=== 定时上线会话开始 (v3) ==="

# 0.01 实例锁
$me = $PID
$dups = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
  $_.ProcessId -ne $me -and $_.CommandLine -match 'session_online\.ps1' })
if ($dups.Count -gt 0) { Log "已有 session_online 实例 (PID $($dups[0].ProcessId)) 在跑, 本实例退出"; exit }

# 0.02 读旧 PHASE (手动游戏保护判定用, 必须在覆写前读)
$oldPhase = ''
if (Test-Path $stateFile) {
  Get-Content $stateFile -Encoding UTF8 | ForEach-Object { if ($_ -match '^PHASE=(.+)$') { $oldPhase = $Matches[1].Trim() } }
}

# 0.03 手动游戏保护: OFFLINE + 游戏在跑 + BGI 没在跑 = 用户自己开的游戏 → 跳过本场次
$ys0 = Get-Process YuanShen -ErrorAction SilentlyContinue
$bgi0 = Get-Process BetterGI -ErrorAction SilentlyContinue
if ($oldPhase -eq 'OFFLINE' -and $ys0 -and -not $bgi0) {
  Log "检测到手动游戏 (PHASE=OFFLINE, 游戏在跑, BGI 未跑), 跳过本场次, 不杀游戏"
  exit 0
}

# 0.1 代理自愈
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\fix_proxy.ps1 | Out-Null

# 1. 排程 3h 后强制下线 (安全网)
$off = (Get-Date).AddHours(3)
schtasks /create /tn BGI_SessionEnd /tr "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\cycle_offline.ps1" /sc once /st $off.ToString('HH:mm') /sd $off.ToString('dd/MM/yyyy') /rl highest /f | Out-Null
Log "已预排程下线: $($off.ToString('MM-dd HH:mm'))"

# 2. PHASE=STARTING
Set-Content $stateFile ("PHASE=STARTING`nACTIVE_UNTIL=" + $off.ToString('yyyy-MM-dd HH:mm:ss')) -Encoding UTF8

# 3. 杀残留 (能走到这说明: 无游戏, 或是我们自己会话的残留)
Stop-Process -Name YuanShen -Force -ErrorAction SilentlyContinue
Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# 4. 起 BGI + 截图器
schtasks /run /tn BetterGI_Run | Out-Null
Log "BGI 经 BetterGI_Run 启动, 等 75s"
Start-Sleep -Seconds 75
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
Start-Sleep -Seconds 5

# 5. 起游戏, 安静等 120s
$script:loginBase = Count-Logins   # 顶号检测基线 (游戏未起, 此刻计数为历史值)
Log "顶号检测基线: SDK登录历史 $script:loginBase 次"
if (-not (Get-Process YuanShen -ErrorAction SilentlyContinue)) {
  Start-Process $gameExe
  Log "游戏已直起"
}
Log "安静等待 120s (不点不碰)..."
Start-Sleep -Seconds 120

# 6. 隐藏点击器进门 (6s/次 × 180s, wscript 隐藏不抢焦点)
& wscript.exe C:\Users\djf20\run_hidden.vbs door_clicker2.ps1
Log "隐藏点击器已启动 (6s/次), 180s 后停止"
Start-Sleep -Seconds 180
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -match 'door_clicker2' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Log "点击器已停止"
Skip-IfRelogin '进门阶段'

# 7. 重启截图器 (关键: 必须进门后再起 —— 游戏窗口不存在时起截图器会静默失败, F9 随后落空; 09-17 16:10 事故)
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
Start-Sleep -Seconds 10

# 8. F9 一条龙 + 快速验证 (180s 内日志无增长 = F9 没落上, 补一次)
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\send_f9.ps1
Log "F9 已触发"
Read-NewLog | Out-Null   # 锚定偏移: 之后只读新增
Start-Sleep -Seconds 180
$probe = Read-NewLog
if ($probe.Trim().Length -lt 200) {
  Log "警告: F9 后 180s 日志静默, 补截图器 + 重发 F9"
  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
  Start-Sleep -Seconds 10
  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\send_f9.ps1
  Start-Sleep -Seconds 120
  Read-NewLog | Out-Null
}

# 9. 等一条龙流程完成 (标记: 一条龙.*任务结束; 每 2min 轮询, 上限 100min)
$done = ($probe -match '一条龙.{0,6}任务结束'); $stuck = $false  # 修复09-18: probe 可能已吞完成标记(一条龙跑得快时)
$sw = [Diagnostics.Stopwatch]::StartNew()
$silentMin = 0
while (-not $done -and $sw.Elapsed.TotalMinutes -lt 100) {
  Start-Sleep -Seconds 120
  Skip-IfRelogin '一条龙等待'
  $new = Read-NewLog
  if ($new -match '一条龙.{0,6}任务结束') { $done = $true; break }
  if ($new.Trim().Length -gt 0) { $silentMin = 0 } else { $silentMin += 2 }
  if ($silentMin -ge 25) { $stuck = $true; break }   # 流程卡死: 交给看门狗恢复
}
if ($done) { Log "一条龙流程已完成 (耗时 $([int]$sw.Elapsed.TotalMinutes) 分钟), 启动采矿组" }
elseif ($stuck) {
  Log "警告: 等待期间日志静默 ≥25 分钟, 流程疑似卡死 → 置 RUNNING 让看门狗恢复, 本场不启动采矿"
  Set-Content $stateFile ("PHASE=RUNNING`nACTIVE_UNTIL=" + $off.ToString('yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
  exit 1
}
else { Log "警告: 等完成标记超时 (100 分钟), 仍尝试启动采矿组" }

# 10. 启动收集大组 (书签续跑) 或体力监控组
#     - 今日已全部跑完 (collection_finished.txt=今日) → 只跑体力监控
#     - 今日已启动过但未跑完 → 启动全自动循环, BGI 自动从 config.json 的 nextScheduledTask 书签续跑
#     - 今日首场 → 清空书签从头启动全自动循环
$today = (Get-Date).ToString('yyyy-MM-dd')

# 读组总任务数 & 书签 (nextScheduledTask[0].Item2 是 1-based index)
$groupObj = Get-Content $groupJson -Raw -Encoding UTF8 | ConvertFrom-Json
$totalTasks = $groupObj.projects.Count
$cfgObj = Get-Content $configJson -Raw -Encoding UTF8 | ConvertFrom-Json
$bookmarkIdx = 0
if ($cfgObj.nextScheduledTask -and $cfgObj.nextScheduledTask.Count -gt 0) {
  $bookmarkIdx = [int]$cfgObj.nextScheduledTask[0].Item2
}

# 今日是否已全部跑完
$finishedToday = $false
if (Test-Path $collectFinishedFile) {
  $finDate = (Get-Content $collectFinishedFile -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
  if ($finDate -eq $today) { $finishedToday = $true }
}

if ($finishedToday) {
  Log "今日收集已全部跑完, 跳过收集大组, 本场仅 F9 一条龙 + 体力监控组"
  for ($i = 1; $i -le 2; $i++) {
    & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_group_named.ps1 -NameMatch '体力监控'
    Start-Sleep -Seconds 20
    $new = Read-NewLog
    if ($new -match '树脂监控|配置组') { Log "体力监控组已启动 (第 $i 次尝试)"; break }
    Log "第 $i 次启动体力监控组未见日志活动, 重试"
  }
  $tailMsg = '本场跳过收集大组 (仅日常+体力)'
} else {
  # 今日首场: 清空书签从头跑; 续跑场: 保留书签让 BGI 从断点继续
  $startedBefore = $false
  if (Test-Path $collectDoneFile) {
    $doneDate = (Get-Content $collectDoneFile -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
    if ($doneDate -eq $today) { $startedBefore = $true }
  }
  if ($startedBefore -and $bookmarkIdx -gt 0 -and $bookmarkIdx -lt $totalTasks) {
    Log "今日收集续跑: 从书签 idx $bookmarkIdx / $totalTasks 继续 (全自动循环大组)"
  } elseif ($startedBefore -and $bookmarkIdx -eq 0) {
    # 今日已启动过但书签为空: 看门狗恢复或 BetterGI_Run 中途重开场次, 从今日日志推导断点
    # (10-09 教训: 13:00 场次重启后从头重跑, 重复收集松珀香/云岩裂叶/敌人约 1 小时)
    Log "今日收集恢复: 书签为空, 从今日日志推导断点 (避免从头重复收集)"
    $bkOut = & python 'C:\Users\djf20\set_bookmark.py' 2>&1
    $bkOut | ForEach-Object { Log "bookmark: $_" }
  } else {
    Log "今日收集从头开始 (全自动循环大组, 共 $totalTasks 条, 含松珀香/云岩裂叶)"
    & python 'C:\Users\djf20\set_bookmark.py' CLEAR 2>&1 | ForEach-Object { Log "bookmark: $_" }
  }
  Set-Content $collectStartFlag $today -Encoding UTF8   # 标记本场启动了收集, 下线时据此更新标记
  for ($i = 1; $i -le 2; $i++) {
    & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_group_named.ps1 -NameMatch '全自动循环'
    Start-Sleep -Seconds 30
    $new = Read-NewLog
    if ($new -match '地图追踪|开始执行|配置组') { Log "农场组已启动 (第 $i 次尝试)"; break }
    Log "第 $i 次启动农场组未见日志活动, 重试"
  }
  $tailMsg = '全自动循环收集大组运行中 (书签续跑)'
}

# 11. PHASE=RUNNING: 看门狗开始监护
Set-Content $stateFile ("PHASE=RUNNING`nACTIVE_UNTIL=" + $off.ToString('yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
Log "=== 上线会话部署完毕 (v3), $tailMsg (下线由 BGI_SessionEnd 兜底) ==="
