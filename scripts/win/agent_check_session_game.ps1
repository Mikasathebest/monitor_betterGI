Get-CimInstance Win32_Process | Where-Object {$_.Name -eq 'YuanShen.exe'} | Select-Object Name,ProcessId,SessionId | Format-Table -AutoSize
Get-Content C:\Users\djf20\cycle_log.txt -Tail 4