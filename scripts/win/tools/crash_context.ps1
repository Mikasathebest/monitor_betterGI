# 崩溃前上下文: 昨天日志 00:24 前后 + GPU 信息 + 游戏内画质进程参数
$ErrorActionPreference = 'Continue'
$out = 'C:\Users\djf20\crash_context.txt'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$sb = New-Object System.Text.StringBuilder

# 1. 昨天日志 00:20-00:26 的内容 (游戏死前最后在做什么)
$f = "$base\log\better-genshin-impact20260916.log"
if (Test-Path $f) {
  $fs = New-Object System.IO.FileStream($f, 'Open', 'Read', 'ReadWrite')
  $sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
  $all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
  $lines = $all -split "`r?`n"
  $sb.AppendLine('=== 09-16 日志 00:20-00:26 段 ===') | Out-Null
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\[00:2[0-6]:') {
      $msg = if ($i+1 -lt $lines.Count -and $lines[$i+1] -notmatch '^\[') { $lines[$i+1].Trim() } else { '' }
      $sb.AppendLine("$($lines[$i].Substring(0,14)) $msg") | Out-Null
    }
  }
}

# 2. GPU 型号和驱动日期
$sb.AppendLine('=== GPU ===') | Out-Null
Get-CimInstance Win32_VideoController | ForEach-Object {
  $sb.AppendLine("$($_.Name) | 驱动 $($_.DriverVersion) | $($_.DriverDate)") | Out-Null
}

# 3. 系统运行时长 (排除重启)
$os = Get-CimInstance Win32_OperatingSystem
$sb.AppendLine("系统启动于: $($os.LastBootUpTime)") | Out-Null

# 4. 是否有其他计划任务会碰 YuanShen
$sb.AppendLine('=== 引用 YuanShen 的计划任务 ===') | Out-Null
Get-ScheduledTask | ForEach-Object {
  foreach ($a in $_.Actions) {
    if (($a.Execute + ' ' + $a.Arguments) -match 'YuanShen') { $sb.AppendLine("$($_.TaskName): $($a.Execute) $($a.Arguments)") | Out-Null }
  }
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'CTX_OK'
