$out='C:\Users\djf20\diag_session_kill.txt'
$lines = New-Object System.Collections.Generic.List[string]
function Add($s){ $lines.Add([string]$s) }
Add '=== NOW ==='
Add (Get-Date -Format o)
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'powershell|wscript|BetterGI|YuanShen' } | Sort-Object ProcessId | ForEach-Object { Add ("PID={0} PPID={1} NAME={2} CMD={3}" -f $_.ProcessId,$_.ParentProcessId,$_.Name,$_.CommandLine) }
Add '=== TASK INFO ==='
$names='BGI_Session','BGI_SessionEnd','BGI_Watchdog','BetterGI_Run','BGI_ResumeAtLogon'
foreach($n in $names){
  try { $t=Get-ScheduledTask -TaskName $n -ErrorAction Stop; $i=Get-ScheduledTaskInfo -TaskName $n; Add ("TASK {0} State={1} LastRun={2:o} LastResult={3} NextRun={4:o}" -f $n,$t.State,$i.LastRunTime,$i.LastTaskResult,$i.NextRunTime); Add (' Actions='+ (($t.Actions|ForEach-Object{"$($_.Execute) $($_.Arguments)"}) -join ' | ')); Add (' Triggers='+ (($t.Triggers|ForEach-Object{"Start=$($_.StartBoundary) End=$($_.EndBoundary) Enabled=$($_.Enabled) Repeat=$($_.Repetition.Interval)"}) -join ' | ')); Add (" Settings MultipleInstances={0} ExecutionTimeLimit={1} StopAtDurationEnd={2}" -f $t.Settings.MultipleInstances,$t.Settings.ExecutionTimeLimit,$t.Settings.StopAtDurationEnd) } catch { Add "TASK $n ERR $_" }
}
Add '=== TASK SCHEDULER EVENTS (last 36h, BGI) ==='
$start=(Get-Date).AddHours(-36)
try {
 Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational';StartTime=$start} -ErrorAction Stop | Where-Object { $_.Message -match 'BGI_|BetterGI' } | Sort-Object TimeCreated | ForEach-Object { $m=($_.Message -replace "`r?`n",' '); Add ("{0:yyyy-MM-dd HH:mm:ss.fff} ID={1} {2}" -f $_.TimeCreated,$_.Id,$m) }
} catch { Add "TASKLOG ERR $_" }
Add '=== SYSTEM/APPLICATION around incidents ==='
foreach($logn in 'System','Application'){
 try { Get-WinEvent -FilterHashtable @{LogName=$logn;StartTime=$start} -ErrorAction Stop | Where-Object { ($_.TimeCreated.Hour -eq 10 -and $_.TimeCreated.Minute -ge 20 -and $_.TimeCreated.Minute -le 50) -or ($_.TimeCreated.Hour -eq 22 -and $_.TimeCreated.Minute -ge 20 -and $_.TimeCreated.Minute -le 50) } | Where-Object { $_.LevelDisplayName -in 'Critical','Error','Warning' -or $_.ProviderName -match 'TaskScheduler|Power|Kernel|Application Error|Windows Error' } | Sort-Object TimeCreated | ForEach-Object { Add ("{0:yyyy-MM-dd HH:mm:ss.fff} LOG={1} ID={2} PROVIDER={3} LEVEL={4} MSG={5}" -f $_.TimeCreated,$logn,$_.Id,$_.ProviderName,$_.LevelDisplayName,(($_.Message -replace "`r?`n",' ') -replace '\s+',' ')) }
 } catch { Add "$logn ERR $_" }
}
Add '=== CYCLE RELEVANT ==='
if(Test-Path 'C:\Users\djf20\cycle_log.txt'){ Get-Content 'C:\Users\djf20\cycle_log.txt' -Encoding UTF8 | Where-Object { $_ -match '^2026-09-15 (10|11|22|23):|^2026-09-16 0[0-2]:' } | ForEach-Object { Add $_ } }
$lines | Set-Content $out -Encoding UTF8
