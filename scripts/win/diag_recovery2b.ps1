Get-Process YuanShen -ErrorAction SilentlyContinue | Select-Object Id,SessionId,StartTime,MainWindowTitle,Responding | Format-List
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'BetterGenshin|YuanShen|wscript|powershell' } | Select-Object ProcessId,Name,SessionId,CreationDate,CommandLine | Format-List
Get-Date -Format 'yyyy-MM-dd HH:mm:ss'