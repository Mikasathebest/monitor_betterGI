# 排雷: 杀掉所有 Agent 遗留的脚本进程 (Session 1, agent_*/door_clicker/enter_door 等), 报告游戏状态
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($m) { "$(Get-Date -Format 'HH:mm:ss') $m" | Out-File $log -Append -Encoding utf8 }

$sb = New-Object System.Text.StringBuilder
$mine = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
  $_.CommandLine -match 'agent_|door_clicker|enter_door|run_s1|clean_desktop'
}
foreach ($p in $mine) {
  $sb.AppendLine("KILL PID=$($p.ProcessId) SID=$($p.SessionId) CMD=$($p.CommandLine.Substring(0, [Math]::Min(120, $p.CommandLine.Length)))") | Out-Null
  Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue
}
$sb.AppendLine("共杀 $($mine.Count) 个") | Out-Null
Log "排雷: 杀掉 $($mine.Count) 个遗留脚本进程"

# 清理一次性计划任务
foreach ($tn in @('BGI_S1Run', 'BGI_S1Hidden', 'BGI_AgentStep', 'BGI_Shot')) {
  Unregister-ScheduledTask -TaskName $tn -Confirm:$false -ErrorAction SilentlyContinue
}

$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
$bgi = Get-Process BetterGI -ErrorAction SilentlyContinue
$sb.AppendLine("YuanShen: $(if ($ys) { 'PID=' + $ys.Id + ' Start=' + $ys.StartTime } else { '不存在' })") | Out-Null
$sb.AppendLine("BetterGI: $(if ($bgi) { 'PID=' + $bgi.Id } else { '不存在' })") | Out-Null
[System.IO.File]::WriteAllText('C:\Users\djf20\landmine.txt', $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'MINE_OK'
