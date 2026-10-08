[Console]::OutputEncoding = [Text.Encoding]::UTF8
$task = Get-ScheduledTask -TaskName 'BGI_Session' -ErrorAction Stop
$info = Get-ScheduledTaskInfo -TaskName 'BGI_Session' -ErrorAction Stop
$lines = @(
  "TASK=$($task.TaskName)"
  "STATE=$($task.State)"
  "LAST_RUN=$($info.LastRunTime.ToString('yyyy-MM-dd HH:mm:ss'))"
  "LAST_RESULT=$('{0:X8}' -f ([uint32]$info.LastTaskResult))"
  "NEXT_RUN=$($info.NextRunTime.ToString('yyyy-MM-dd HH:mm:ss'))"
)
[IO.File]::WriteAllLines('C:\Users\djf20\agent_schedule_result.txt', $lines, (New-Object Text.UTF8Encoding($false)))
$lines