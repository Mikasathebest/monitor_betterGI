Stop-ScheduledTask -TaskName 'BGI_S1Run' -ErrorAction SilentlyContinue
Set-Content C:\Users\djf20\session_state.txt 'PHASE=OFFLINE' -Encoding UTF8
Stop-Process -Name YuanShen -Force -ErrorAction SilentlyContinue
Start-Sleep 3
Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') AGENT恢复: 登录门界面多轮重试仍点击无效，安全下线，未触发F9" | Out-File C:\Users\djf20\cycle_log.txt -Append -Encoding utf8