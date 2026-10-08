# 在 Session 1 执行 UI 操作: 起截图器 → 按名启动邀约组 (经 BGI_HangoutUI 计划任务调用)
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\hangout_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Log "hangout_ui: 开始 (session $((Get-Process -Id $PID).SessionId))"
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
Start-Sleep -Seconds 5
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_group_named.ps1 -NameMatch '久岐忍邀约'
Log 'hangout_ui: 完成'
