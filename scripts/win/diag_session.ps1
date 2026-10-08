# 诊断 22:30 场次为何中断 + 10:30 场次情况
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$out = 'C:\Users\djf20\diag_session.txt'
$sb = New-Object System.Text.StringBuilder

# 1. session_online 是否还在跑
$alive = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'session_online' })
$sb.AppendLine("session_online 存活实例: $($alive.Count)") | Out-Null

# 2. BGI_Session 任务最近运行结果
$info = Get-ScheduledTask -TaskName 'BGI_Session' | Get-ScheduledTaskInfo
$sb.AppendLine("BGI_Session LastRunTime=$($info.LastRunTime) LastTaskResult=$($info.LastTaskResult) NextRun=$($info.NextRunTime)") | Out-Null
$info2 = Get-ScheduledTask -TaskName 'BGI_SessionEnd' | Get-ScheduledTaskInfo
$sb.AppendLine("BGI_SessionEnd LastRun=$($info2.LastRunTime) Result=$($info2.LastTaskResult) NextRun=$($info2.NextRunTime)") | Out-Null

# 3. cycle_log 里 10:30 和 22:30 场次的完整段落
$log = Get-Content 'C:\Users\djf20\cycle_log.txt' -Encoding UTF8
$sb.AppendLine('=== cycle_log 10:00-11:00 段 ===') | Out-Null
$log | Where-Object { $_ -match '2026-09-15 (10|11):' } | Select-Object -First 25 | ForEach-Object { $sb.AppendLine($_) | Out-Null }
$sb.AppendLine('=== cycle_log 22:30 起全部 ===') | Out-Null
$log | Where-Object { $_ -match '2026-09-15 2[23]:' } | Select-Object -First 25 | ForEach-Object { $sb.AppendLine($_) | Out-Null }

# 4. BGI 日志 22:30 之后的关键行 (合并条目)
$logDir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
$f = Get-ChildItem $logDir -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fs = New-Object System.IO.FileStream($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$entries = New-Object System.Collections.ArrayList
foreach ($ln in ($all -split "`r?`n")) {
  if ($ln -match '^\[(\d{2}:\d{2}:\d{2})') { [void]$entries.Add([PSCustomObject]@{ Ts = $Matches[1]; Msg = $ln }) }
  elseif ($entries.Count -gt 0 -and $ln.Trim() -ne '') { $entries[$entries.Count - 1].Msg += ' ' + $ln.Trim() }
}
$sb.AppendLine('=== BGI 日志 22:29 后关键行 ===') | Out-Null
$night = $entries | Where-Object { $_.Ts -ge '22:29:00' -and $_.Msg -match '截图|捕获|启动|错误|失败|异常|一条龙|配置组|执行|窗口|游戏|未找到|取消' } | Select-Object -First 40
foreach ($e in $night) { $m = $e.Msg; if ($m.Length -gt 150) { $m = $m.Substring(0, 150) }; $sb.AppendLine("[$($e.Ts)] $m") | Out-Null }
$sb.AppendLine("BGI 日志最后时间: $($entries[$entries.Count-1].Ts)  当前: $(Get-Date -Format 'HH:mm:ss')") | Out-Null

# 5. 游戏进程
$g = Get-Process YuanShen -ErrorAction SilentlyContinue
$sb.AppendLine("YuanShen 进程: $(if ($g) { '存活 PID=' + $g.Id } else { '不存在' })") | Out-Null

[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'DIAG_OK'
