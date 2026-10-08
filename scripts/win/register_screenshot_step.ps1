$src=Get-ScheduledTask -TaskName 'BGI_Session'
$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\screen.ps1'
$t=New-ScheduledTask -Action $a -Principal $src.Principal -Settings $src.Settings
Register-ScheduledTask -TaskName 'BGI_AgentShot' -InputObject $t -Force | Out-Null
Start-ScheduledTask -TaskName 'BGI_AgentShot'; Start-Sleep -Seconds 8
