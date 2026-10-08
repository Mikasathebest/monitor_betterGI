# 紧急停会话: 状态置 OFFLINE + 杀 session_online + 杀 BGI (保留游戏) —— 邀约/手动操作时防冲突
[Console]::OutputEncoding = [Text.Encoding]::UTF8
Set-Content 'C:\Users\djf20\session_state.txt' ("PHASE=OFFLINE`nACTIVE_UNTIL=2026-09-15 10:00:00") -Encoding UTF8
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object { $_.CommandLine -match 'session_online' } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
Write-Output ("STOPPED. 游戏存活: " + [bool]$ys + " (PID " + $ys.Id + ")")
