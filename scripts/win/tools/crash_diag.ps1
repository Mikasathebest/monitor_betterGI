# 原神崩溃取证: 事件查看器 Application Error / Hang + WER 报告
$ErrorActionPreference = 'Continue'
$out = 'C:\Users\djf20\crash_diag.txt'
$sb = New-Object System.Text.StringBuilder

# 1. 最近 2 天的应用程序错误事件 (YuanShen 相关)
$sb.AppendLine('=== Application Error 事件 (YuanShen) ===') | Out-Null
$since = (Get-Date).AddDays(-2)
Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,1001,1002; StartTime=$since} -ErrorAction SilentlyContinue |
  Where-Object { $_.Message -match 'YuanShen' } |
  Select-Object -First 10 |
  ForEach-Object {
    $sb.AppendLine("--- $($_.TimeCreated) (EventID $($_.Id)) ---") | Out-Null
    $sb.AppendLine($_.Message.Substring(0, [Math]::Min(600, $_.Message.Length))) | Out-Null
  }

# 2. 系统日志里的关键崩溃 (nvlddmkm 显卡驱动 / 内存)
$sb.AppendLine('=== System 日志: 显示驱动/关键错误 ===') | Out-Null
Get-WinEvent -FilterHashtable @{LogName='System'; Level=1,2; StartTime=$since} -ErrorAction SilentlyContinue |
  Select-Object -First 8 |
  ForEach-Object { $sb.AppendLine("$($_.TimeCreated) [$($_.Id)] $($_.Message.Substring(0, [Math]::Min(200, $_.Message.Length)))") | Out-Null }

# 3. 内存状况
$os = Get-CimInstance Win32_OperatingSystem
$sb.AppendLine("=== 内存: 总 $([int]($os.TotalVisibleMemorySize/1MB)) GB, 当前可用 $([int]($os.FreePhysicalMemory/1MB)) GB ===") | Out-Null

# 4. 游戏进程历史崩溃时的 WER 报告
$wer = 'C:\ProgramData\Microsoft\Windows\WER\ReportArchive'
if (Test-Path $wer) {
  $reports = Get-ChildItem $wer -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match 'YuanShen' } | Sort-Object LastWriteTime -Descending | Select-Object -First 5
  $sb.AppendLine("=== WER 报告: $($reports.Count) 个 ===") | Out-Null
  foreach ($r in $reports) { $sb.AppendLine("$($r.LastWriteTime) $($r.Name)") | Out-Null }
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'CRASH_OK'
