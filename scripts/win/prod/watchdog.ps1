# 看门狗 v2 (每 30 分钟由 BGI_Watchdog 触发): 状态快照 + 会话内异常自动恢复
# 恢复条件: session_state.txt 为 RUNNING 且未到下线点, 但 游戏/BGI 进程缺失 或 BGI 日志静默 >=25 分钟
# 限次: 每日最多恢复 2 次, 间隔 >= 10 分钟, 防止误判(如用户手动玩时关 BGI)反复拉起
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\watchdog_log.txt'
$stateFile = 'C:\Users\djf20\session_state.txt'
$cooldownFile = 'C:\Users\djf20\watchdog_recover.txt'
$base = 'D:\projects\betterGI'
function Log($msg) { "$(Get-Date -Format 'MM-dd HH:mm') $msg" | Out-File $log -Append -Encoding utf8 }

$ys = [bool](Get-Process YuanShen -ErrorAction SilentlyContinue)
$bgi = [bool](Get-Process BetterGI -ErrorAction SilentlyContinue)
$lock = [bool](Get-Process LogonUI -ErrorAction SilentlyContinue)

# BGI 日志最后时间戳 (FileStream 共享读绕独占锁; 不信 LastWriteTime 元数据, 它会滞后)
$lastTs = 'none'; $staleMin = -1
$f = Get-ChildItem "$base\log\*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($f) {
  try {
    $fs = [System.IO.FileStream]::new($f.FullName, 'Open', 'Read', 'ReadWrite')
    $sr = [System.IO.StreamReader]::new($fs, [Text.Encoding]::UTF8)
    $all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
    $m = [regex]::Matches($all, '(?m)^\[(\d{2}):(\d{2}):(\d{2})')
    if ($m.Count -gt 0) {
      $g = $m[$m.Count - 1].Groups
      $lastTs = "$($g[1].Value):$($g[2].Value):$($g[3].Value)"
      $ts = [TimeSpan]::new([int]$g[1].Value, [int]$g[2].Value, [int]$g[3].Value)
      $staleMin = [int]((Get-Date).TimeOfDay - $ts).TotalMinutes
      if ($staleMin -lt 0) { $staleMin += 1440 }  # 跨午夜回绕
    }
  } catch { $lastTs = 'read_err' }
}

Log "game=$ys bgi=$bgi lock=$lock lastLog=$lastTs stale=${staleMin}min"
if ($lock) { Log '警告: 检测到锁屏! 自动化全线瘫痪, 需现场解锁 (锁屏已注册表禁用, 此为异常)' }

# --- 自动恢复判定 ---
if (-not (Test-Path $stateFile)) { return }
$st = @{}
Get-Content $stateFile -Encoding UTF8 | ForEach-Object { $kv = $_ -split '=', 2; if ($kv.Count -eq 2) { $st[$kv[0]] = $kv[1] } }
if ($st['PHASE'] -ne 'RUNNING') { return }                       # 非运行期(离线/启动中)不干预
$until = [DateTime]::ParseExact($st['ACTIVE_UNTIL'], 'yyyy-MM-dd HH:mm:ss', $null)
if ((Get-Date) -ge $until) { return }                            # 已过下线点, 交给 BGI_SessionEnd

# 启动保护期 (10-17 修复): session_online 启动 BGI 需 ~75s, 若恰在启动间隙检测会误判"进程缺失"
# 导致 23:24 重复拉起 BGI_Session, 前 5 条路线重复跑两遍. 保护期内不恢复.
$startFile = 'C:\Users\djf20\session_start.txt'
if (Test-Path $startFile) {
  $startAge = [int]((Get-Date) - (Get-Item $startFile).LastWriteTime).TotalMinutes
  if ($startAge -lt 15) { Log "启动保护期 (${startAge}min<15min), 跳过恢复检测"; return }
}

$needRecover = $false; $why = ''
if (-not $ys -or -not $bgi) { $needRecover = $true; $why = "进程缺失(game=$ys bgi=$bgi)" }
elseif ($staleMin -ge 25) { $needRecover = $true; $why = "日志静默 ${staleMin} 分钟" }
if (-not $needRecover) { return }

# 流程已完成 ≠ 卡死 (09-17 误报事故: 流程 05:41 跑完空闲, 看门狗 06:24/08:24 两次白重启)
# 判定: 日志最后的任务事件是完成标记 (与 lastTs 相差 <=5 分钟) → 提前下线, 不重启
# 完成标记两种: 一条龙流程结束 / 配置组(采矿等)执行结束
if ($why -match '日志静默' -and $all) {
  $mc = [regex]::Matches($all, '(?m)^\[(\d{2}):(\d{2}):(\d{2})\.\d+\][^\r\n]*\r?\n[^\r\n]*(一条龙.{0,6}任务结束|配置组\s+"?([^"\r\n]+?)"?\s+执行结束)')
  if ($mc.Count -gt 0) {
    $gc = $mc[$mc.Count - 1].Groups
    $doneTs = [TimeSpan]::new([int]$gc[1].Value, [int]$gc[2].Value, [int]$gc[3].Value)
    $gapMin = [int](([TimeSpan]::Parse($lastTs)) - $doneTs).TotalMinutes
    if ($gapMin -lt 0) { $gapMin += 1440 }
    if ($gapMin -le 5) {
      # 10-19 双修复:
      #  a) 旧写法 `-Complete $true` 经 & powershell -File 传参时 [bool] 绑定失败 → 子进程无日志静默死亡
      #     (08:24/08:54 两次提前下线空转, 游戏挂机到 09:15 兜底) → cycle_offline 已改 [switch], 裸传 -Complete
      #  b) 只有日收尾组 (B组/续跑组/主组) 完成才标 Complete; A组完成仅早场收尾 → 保存书签, 晚场续跑B组
      $grp = $gc[5].Value
      if ($gc[4].Value -match '一条龙' -or $grp -match '^(收集B组|续跑收集组|全自动循环)$') {
        Log "流程已于 $($gc[1].Value):$($gc[2].Value) 跑完 (完成标记=最后事件, 组=$grp), 提前下线 (今日完成)"
        & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\cycle_offline.ps1 -Complete
      } else {
        Log "流程已于 $($gc[1].Value):$($gc[2].Value) 跑完 (完成标记=最后事件, 组=$grp), 提前下线 (保存书签续跑)"
        & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\cycle_offline.ps1
      }
      return
    }
  }
}

# 恢复限次 (10-21 改): 每日最多 2 次, 间隔 >=10 分钟
# 背景: 用户手动玩时关掉 BGI, 看门狗误判"进程缺失"每 30min 拉起一次 (10-21 一天拉了 5 次)
# 文件格式: 每行一条恢复时间戳 yyyy-MM-dd HH:mm:ss, 只统计当日行
$todayStr = (Get-Date).ToString('yyyy-MM-dd')
$recTimes = @()
if (Test-Path $cooldownFile) {
  $recTimes = @(Get-Content $cooldownFile -Encoding UTF8 | Where-Object { $_ -match "^$todayStr (\d{2}):(\d{2}):(\d{2})" } | ForEach-Object { [DateTime]::ParseExact($_, 'yyyy-MM-dd HH:mm:ss', $null) })
}
if ($recTimes.Count -ge 2) { Log "需恢复($why)但今日已恢复 $($recTimes.Count) 次 (上限2), 跳过"; return }
if ($recTimes.Count -gt 0) {
  $gap = [int]((Get-Date) - $recTimes[-1]).TotalMinutes
  if ($gap -lt 10) { Log "需恢复($why)但距上次仅 ${gap} 分钟 (<10), 跳过"; return }
}
Log "触发自动恢复 (今日第 $($recTimes.Count + 1)/2 次): $why → 重新拉起 BGI_Session"
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $cooldownFile -Append -Encoding utf8
schtasks /run /tn BGI_Session | Out-Null
