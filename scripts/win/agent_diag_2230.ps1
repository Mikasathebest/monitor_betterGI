[Console]::OutputEncoding = [Text.Encoding]::UTF8
$out='C:\Users\djf20\agent_diag_2230.txt'
$lines=New-Object System.Collections.Generic.List[string]
$task=Get-ScheduledTask -TaskName 'BGI_Session'
$lines.Add("STATE=$($task.State)")
$lines.Add("MULTIPLE_INSTANCES=$($task.Settings.MultipleInstances)")
$lines.Add("EXECUTION_TIME_LIMIT=$($task.Settings.ExecutionTimeLimit)")
$lines.Add("ALLOW_HARD_TERMINATE=$($task.Settings.AllowHardTerminate)")
$lines.Add('---TASK EVENTS 22:25-23:50---')
$start=[datetime]'2026-09-15 22:25:00'; $end=[datetime]'2026-09-15 23:50:00'
try {
 $ev=Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-TaskScheduler/Operational';StartTime=$start;EndTime=$end} -ErrorAction Stop | Where-Object {$_.Message -match 'BGI_Session'} | Sort-Object TimeCreated
 foreach($e in $ev){ $msg=($e.Message -replace "`r?`n",' '); $lines.Add("$($e.TimeCreated.ToString('HH:mm:ss')) ID=$($e.Id) $msg") }
} catch { $lines.Add("EVENT_ERROR=$($_.Exception.Message)") }
[IO.File]::WriteAllLines($out,$lines,(New-Object Text.UTF8Encoding($false)))
$lines