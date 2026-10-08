# Session 1 隐藏执行器: 经 wscript 跑指定 ps1, 全程无控制台窗口 (不抢焦点)
param([string]$ScriptName)
$src = Get-ScheduledTask -TaskName 'BGI_Session'
$a = New-ScheduledTaskAction -Execute 'wscript.exe' -Argument ("C:\Users\djf20\run_hidden.vbs " + $ScriptName)
$t = New-ScheduledTask -Action $a -Principal $src.Principal -Settings $src.Settings
Register-ScheduledTask -TaskName 'BGI_S1Hidden' -InputObject $t -Force | Out-Null
Start-ScheduledTask -TaskName 'BGI_S1Hidden'
Write-Output ("S1_HIDDEN_STARTED " + $ScriptName)
