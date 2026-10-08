& 'C:\Users\djf20\run_s1.ps1' -ScriptName 'uia_start_capture.ps1'
Start-Sleep -Seconds 10
Get-CimInstance Win32_Process | Where-Object { $_.Name -match 'BetterGI|YuanShen|wscript' -or $_.CommandLine -like '*uia_start_capture*' } | Select-Object ProcessId,Name,SessionId,CreationDate,CommandLine | Format-List
$logDir='D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
Get-ChildItem $logDir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 5 Name,LastWriteTime,Length | Format-Table -AutoSize