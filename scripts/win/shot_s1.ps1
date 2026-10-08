# Session 1 截图: 注册一次性任务跑 screen.ps1 (SSH 直跑 CopyFromScreen 会失败)
$src = Get-ScheduledTask -TaskName 'BGI_Session'
$a = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\screen.ps1'
$t = New-ScheduledTask -Action $a -Principal $src.Principal -Settings $src.Settings
Register-ScheduledTask -TaskName 'BGI_Shot' -InputObject $t -Force | Out-Null
Start-ScheduledTask -TaskName 'BGI_Shot'
Start-Sleep -Seconds 6
$f = Get-Item 'C:\Users\djf20\screen.png' -ErrorAction SilentlyContinue
if ($f) { Write-Output ("SHOT_OK " + $f.Length + " " + $f.LastWriteTime) } else { Write-Output 'SHOT_FAIL' }
