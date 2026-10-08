# 通用 Session 1 执行器: run_s1.ps1 -ScriptName xxx.ps1 → 注册一次性任务跑指定脚本
param([string]$ScriptName)
$src = Get-ScheduledTask -TaskName 'BGI_Session'
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument ("-NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\" + $ScriptName)
$t = New-ScheduledTask -Action $a -Principal $src.Principal -Settings $src.Settings
Register-ScheduledTask -TaskName 'BGI_S1Run' -InputObject $t -Force | Out-Null
Start-ScheduledTask -TaskName 'BGI_S1Run'
Write-Output ("S1_STARTED " + $ScriptName)
