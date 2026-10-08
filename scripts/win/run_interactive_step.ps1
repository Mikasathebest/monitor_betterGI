$src=Get-ScheduledTask -TaskName 'BGI_Session'
$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\enter_door.ps1'
$t=New-ScheduledTask -Action $a -Principal $src.Principal -Settings $src.Settings
Register-ScheduledTask -TaskName 'BGI_AgentStep' -InputObject $t -Force | Out-Null
Start-ScheduledTask -TaskName 'BGI_AgentStep'
Start-Sleep -Seconds 8
$i=Get-ScheduledTaskInfo -TaskName 'BGI_AgentStep'; "LastResult=$($i.LastTaskResult)" | Set-Content C:\Users\djf20\agent_step.txt -Encoding UTF8
