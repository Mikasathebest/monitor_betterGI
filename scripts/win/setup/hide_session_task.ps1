# 把 BGI_Session 的执行方式改为 wscript 隐藏启动 (无控制台窗口: 不抢焦点, 也不会被人手滑关掉)
$ErrorActionPreference = 'Stop'
$task = Get-ScheduledTask -TaskName 'BGI_Session'
$a = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument 'C:\Users\djf20\run_hidden.vbs session_online.ps1'
Set-ScheduledTask -TaskName 'BGI_Session' -Action $a | Out-Null
$check = (Get-ScheduledTask -TaskName 'BGI_Session').Actions[0]
Write-Output ("ACTION_NOW: " + $check.Execute + " " + $check.Arguments)
Write-Output 'HIDE_OK'
