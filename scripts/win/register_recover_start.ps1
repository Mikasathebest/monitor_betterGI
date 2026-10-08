wevtutil.exe set-log Microsoft-Windows-TaskScheduler/Operational /enabled:true
$src=Get-ScheduledTask -TaskName 'BGI_Session'
$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\agent_recover_start.ps1'
$t=New-ScheduledTask -Action $a -Principal $src.Principal -Settings $src.Settings
Register-ScheduledTask -TaskName 'BGI_AgentRecoverStart' -InputObject $t -Force | Out-Null
Start-ScheduledTask -TaskName 'BGI_AgentRecoverStart'
Start-Sleep -Seconds 12
$i=Get-ScheduledTaskInfo -TaskName 'BGI_AgentRecoverStart'; "LastResult=$($i.LastTaskResult)" | Set-Content C:\Users\djf20\agent_step.txt -Encoding UTF8
