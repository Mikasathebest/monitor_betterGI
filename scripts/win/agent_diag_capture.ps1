$ErrorActionPreference='SilentlyContinue'
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'BetterGenshinImpact|YuanShen|ffmpeg|powershell|wscript|capture' } | Select-Object ProcessId,Name,CommandLine | Format-List
