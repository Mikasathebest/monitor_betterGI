$ErrorActionPreference='SilentlyContinue'
'=== PID ==='
Get-CimInstance Win32_Process | Where-Object { $_.ProcessId -eq 36388 -or $_.Name -match 'Better|Genshin|YuanShen' } | Select-Object ProcessId,ParentProcessId,SessionId,Name,CommandLine | Format-List
'=== WINDOWS ==='
Get-Process | Where-Object { $_.MainWindowTitle -ne '' } | Select-Object Id,ProcessName,SessionId,MainWindowTitle | Format-Table -AutoSize
'=== TASKS ==='
schtasks /Query /FO LIST /V | Select-String -Pattern 'Capture|BGI|uia' -Context 1,2
