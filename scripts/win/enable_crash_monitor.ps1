# 为 YuanShen.exe 启用 SilentProcessExit 监控: 下次静默退出时自动留 WER 报告+小型转储
# 需要管理员 (HKLM 写入)
$ErrorActionPreference = 'Continue'
$key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\YuanShen.exe'
New-Item -Path $key -Force | Out-Null
# ReportingMode=1: 静默退出时生成 WER 报告
Set-ItemProperty -Path $key -Name 'ReportingMode' -Value 1 -Type DWord
# 退出时留小型转储 (full dump 会有几个 GB, mini 足够定位模块)
Set-ItemProperty -Path $key -Name 'LocalDumpFolder' -Value 'C:\Users\djf20\crash_dumps' -Type ExpandString
Set-ItemProperty -Path $key -Name 'DumpType' -Value 1 -Type DWord
New-Item -Path 'C:\Users\djf20\crash_dumps' -ItemType Directory -Force | Out-Null
Get-ItemProperty -Path $key | Format-List | Out-String | Write-Output
Write-Output 'MONITOR_OK'
