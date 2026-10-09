Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like '*door_clicker2.ps1*' -and $_.ProcessId -ne $PID } | ForEach-Object { "STOP_DOOR_PID=$($_.ProcessId)"; Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
$dir='D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
Get-ChildItem $dir -Filter '*.exe' | Select-Object Name,FullName | Format-Table -AutoSize
Get-CimInstance Win32_Process | Where-Object { $_.ExecutablePath -like "$dir*" } | Select-Object ProcessId,Name,SessionId,ExecutablePath,CommandLine | Format-List