# 杀掉旧版 session_online 实例, 用新版代码重开一场
$ErrorActionPreference = 'Continue'
$killed = 0
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
  Where-Object { $_.CommandLine -match 'session_online\.ps1' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $killed++ }
Write-Output "OLD_KILLED=$killed"
schtasks /run /tn BGI_Session | Out-Null
Write-Output 'V2_STARTED'
