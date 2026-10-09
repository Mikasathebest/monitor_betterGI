# 原神自身日志取证: Unity Player.log + 崩溃转储目录
$ErrorActionPreference = 'Continue'
$out = 'C:\Users\djf20\game_log_diag.txt'
$sb = New-Object System.Text.StringBuilder

# 1. Unity 日志目录
$dirs = @(
  "$env:USERPROFILE\AppData\LocalLow\miHoYo",
  'E:\YS\miHoYo Launcher\games\Genshin Impact Game'
)
foreach ($d in $dirs) {
  if (Test-Path $d) {
    $sb.AppendLine("=== $d ===") | Out-Null
    Get-ChildItem $d -Recurse -Include 'Player*.log','*.dmp','crash*' -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending | Select-Object -First 10 |
      ForEach-Object { $sb.AppendLine("$($_.LastWriteTime)  $([int]($_.Length/1KB)) KB  $($_.FullName)") | Out-Null }
  }
}

# 2. Player.log 最后 30 行 (看退出方式)
$pl = Get-ChildItem "$env:USERPROFILE\AppData\LocalLow\miHoYo" -Recurse -Filter 'Player.log' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($pl) {
  $sb.AppendLine("=== Player.log ($($pl.LastWriteTime)) 末尾 ===") | Out-Null
  $tail = Get-Content $pl.FullName -Tail 30 -ErrorAction SilentlyContinue
  foreach ($l in $tail) { $sb.AppendLine($l) | Out-Null }
}

# 3. 崩溃时间点附近 (00:24 / 14:24-14:54 / 15:14) 谁杀了游戏: 查安全日志进程终止 (如启用) —— 大概率没启用, 改查 cycle_log 对应时段
$sb.AppendLine('=== cycle_log 中 00:2x / 14:2x-14:5x / 15:1x 时段记录 ===') | Out-Null
$cl = 'C:\Users\djf20\cycle_log.txt'
if (Test-Path $cl) {
  Get-Content $cl -Encoding UTF8 -ErrorAction SilentlyContinue |
    Where-Object { $_ -match '2026-09-17 00:2|2026-09-17 14:[2-5]|2026-09-17 15:1' } |
    Select-Object -First 25 |
    ForEach-Object { $sb.AppendLine($_) | Out-Null }
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'GLOG_OK'
