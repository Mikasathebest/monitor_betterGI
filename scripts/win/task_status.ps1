# 输出关键计划任务状态
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$names = @('BGI_Session', 'BGI_Watchdog', 'BGI_SessionEnd', 'BGI_ResumeAtLogon', 'BGI_HangoutUI')
foreach ($n in $names) {
  $t = Get-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue
  if ($t) {
    $info = $t | Get-ScheduledTaskInfo
    Write-Output ("{0,-20} {1,-10} NextRun={2}" -f $n, $t.State, $info.NextRunTime)
  } else {
    Write-Output ("{0,-20} MISSING" -f $n)
  }
}
