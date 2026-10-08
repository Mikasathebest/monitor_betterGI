$src=Get-ScheduledTask -TaskName 'BGI_Session'
$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\send_f9.ps1'
$t=New-ScheduledTask -Action $a -Principal $src.Principal -Settings $src.Settings
Register-ScheduledTask -TaskName 'BGI_AgentStep' -InputObject $t -Force | Out-Null
Start-ScheduledTask -TaskName 'BGI_AgentStep'; Start-Sleep -Seconds 8
"$(Get-Date -Format o) F9 requested" | Add-Content C:\Users\djf20\cycle_log.txt -Encoding UTF8
