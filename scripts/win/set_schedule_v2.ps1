# 场次改一天 3 场: 早 04:15 / 午 13:00 / 夜 23:00 (去掉晚场 16:30; 每场 3h 由 session_online 自排下线)
$ErrorActionPreference = 'Stop'
$t = @(
  New-ScheduledTaskTrigger -Daily -At '04:15'
  New-ScheduledTaskTrigger -Daily -At '13:00'
  New-ScheduledTaskTrigger -Daily -At '23:00'
)
Set-ScheduledTask -TaskName 'BGI_Session' -Trigger $t | Out-Null
$task = Get-ScheduledTask -TaskName 'BGI_Session'
foreach ($tr in $task.Triggers) { Write-Output ("TRIGGER: " + $tr.StartBoundary) }
Write-Output 'SCHEDULE_OK'
