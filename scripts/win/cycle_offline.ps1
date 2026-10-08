# 会话下线: 保存进度书签 → 杀游戏+BGI (不自我续链; 下次上线由 BGI_Session 每日定时触发)
# -Complete:$true = 大组跑完(清空书签, 下轮从头); 默认 = 到点下线(保存书签续跑)
param([bool]$Complete = $false)
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Log "=== 会话下线 (Complete=$Complete) ==="

# 0. 已离线则直接跳过 (防止大组提前跑完触发 -Complete 后, 兜底任务二次触发误写书签)
$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
$bgi = Get-Process BetterGI -ErrorAction SilentlyContinue
if (-not $ys -and -not $bgi) { Log "已处于离线状态, 跳过"; exit 0 }

# 0.5 先置状态 OFFLINE (看门狗据此停止恢复尝试); 并清理可能挂死的 session_online 残留进程
Set-Content 'C:\Users\djf20\session_state.txt' "PHASE=OFFLINE" -Encoding UTF8
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -match 'session_online\.ps1' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }

# 1. 杀游戏 + BGI (先杀, 防止 config 被回写)
Stop-Process -Name YuanShen -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
Log "游戏与 BGI 已关闭"

# 1.5 大组刚跑完? (09-15 07:30 竞速实证: SessionEnd 比组完成标记早 2 秒, 误写书签 idx 79)
# 日志尾 3 分钟内出现 "配置组 ... 执行结束" → 视为跑完, 走 Complete 清书签
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
if (-not $Complete) {
  try {
    $f = Get-ChildItem "$base\log\better-genshin-impact*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if ($f) {
      $fs = [System.IO.FileStream]::new($f.FullName, 'Open', 'Read', 'ReadWrite')
      $sr = [System.IO.StreamReader]::new($fs, [Text.Encoding]::UTF8)
      $all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
      foreach ($ln in (($all -split "`r?`n") | Select-Object -Last 15)) {
        if ($ln -match '^\[(\d\d:\d\d:\d\d).+配置组.*执行结束') {
          $t = [DateTime]::ParseExact($Matches[1], 'HH:mm:ss', $null)
          $age = (Get-Date) - (Get-Date -Hour $t.Hour -Minute $t.Minute -Second $t.Second)
          if ($age.TotalMinutes -ge 0 -and $age.TotalMinutes -lt 3) { $Complete = $true; Log "检测到组刚完成 ($($Matches[1])), 按 Complete 处理"; break }
        }
      }
    }
  } catch { }
}

# 2. Python 写书签 (从日志找最后路线 → 写 nextScheduledTask 进 config.json)
$arg = if ($Complete) { 'CLEAR' } else { '' }
$out = & python 'C:\Users\djf20\set_bookmark.py' $arg 2>&1
$out | ForEach-Object { Log "bookmark: $_" }

Log "=== 下线完成 (下次上线: BGI_Session 定时触发) ==="
