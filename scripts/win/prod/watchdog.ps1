# 看门狗 v2 (每 30 分钟由 BGI_Watchdog 触发): 状态快照 + 会话内异常自动恢复
# 恢复条件: session_state.txt 为 RUNNING 且未到下线点, 但 游戏/BGI 进程缺失 或 BGI 日志静默 >=25 分钟
# 冷却: 两次恢复间隔 >= 40 分钟, 防止抖动循环
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\watchdog_log.txt'
$stateFile = 'C:\Users\djf20\session_state.txt'
$cooldownFile = 'C:\Users\djf20\watchdog_recover.txt'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
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

$needRecover = $false; $why = ''
if (-not $ys -or -not $bgi) { $needRecover = $true; $why = "进程缺失(game=$ys bgi=$bgi)" }
elseif ($staleMin -ge 25) { $needRecover = $true; $why = "日志静默 ${staleMin} 分钟" }
if (-not $needRecover) { return }

# 流程已完成 ≠ 卡死 (09-17 误报事故: 流程 05:41 跑完空闲, 看门狗 06:24/08:24 两次白重启)
# 判定: 日志最后的任务事件是完成标记 (与 lastTs 相差 <=5 分钟) → 提前下线, 不重启
# 完成标记两种: 一条龙流程结束 / 配置组(采矿等)执行结束
if ($why -match '日志静默' -and $all) {
  $mc = [regex]::Matches($all, '(?m)^\[(\d{2}):(\d{2}):(\d{2})\.\d+\][^\r\n]*\r?\n[^\r\n]*(一条龙.{0,6}任务结束|配置组 .+ 执行结束)')
  if ($mc.Count -gt 0) {
    $gc = $mc[$mc.Count - 1].Groups
    $doneTs = [TimeSpan]::new([int]$gc[1].Value, [int]$gc[2].Value, [int]$gc[3].Value)
    $gapMin = [int](([TimeSpan]::Parse($lastTs)) - $doneTs).TotalMinutes
    if ($gapMin -lt 0) { $gapMin += 1440 }
    if ($gapMin -le 5) {
      Log "流程已于 $($gc[1].Value):$($gc[2].Value) 跑完 (完成标记=最后事件), 提前下线, 不重启"
      & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\cycle_offline.ps1 -Complete $true
      return
    }
  }
}

# 冷却检查 (避免同一故障反复重启)
if (Test-Path $cooldownFile) {
  $age = [int]((Get-Date) - (Get-Item $cooldownFile).LastWriteTime).TotalMinutes
  if ($age -lt 40) { Log "需恢复($why)但冷却中 (距上次 ${age} 分钟), 跳过"; return }
}
Log "触发自动恢复: $why → 重新拉起 BGI_Session"
New-Item $cooldownFile -ItemType File -Force | Out-Null
schtasks /run /tn BGI_Session | Out-Null
