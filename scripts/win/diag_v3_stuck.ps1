# 诊断 v3 卡点: 进程状态 + session_online/uia 进程 + BGI 窗口
$ErrorActionPreference = 'Continue'
$out = 'C:\Users\djf20\diag_v3.txt'
$sb = New-Object System.Text.StringBuilder
$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
$bgi = Get-Process BetterGI -ErrorAction SilentlyContinue
$sb.AppendLine("YuanShen: $(if ($ys) { 'PID=' + $ys.Id + ' Start=' + $ys.StartTime } else { '不存在' })") | Out-Null
$sb.AppendLine("BetterGI: $(if ($bgi) { 'PID=' + $bgi.Id + ' Start=' + $bgi.StartTime } else { '不存在' })") | Out-Null
$sb.AppendLine('--- 相关 powershell 进程 ---') | Out-Null
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
  $_.CommandLine -match 'session_online|uia_start_capture|door_clicker|send_f9'
} | ForEach-Object { $sb.AppendLine("PID=$($_.ProcessId) Created=$($_.CreationDate) CMD=$($_.CommandLine.Substring(0, [Math]::Min(100, $_.CommandLine.Length)))") | Out-Null }
$sb.AppendLine('--- BetterGI_Run 任务状态 ---') | Out-Null
$t = Get-ScheduledTask -TaskName 'BetterGI_Run' -ErrorAction SilentlyContinue
if ($t) { $sb.AppendLine("State=$($t.State)") | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'DIAG_OK'
