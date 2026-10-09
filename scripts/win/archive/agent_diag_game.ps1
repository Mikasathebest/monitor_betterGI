'NOW='+(Get-Date -Format o)
Get-CimInstance Win32_Process | Where-Object {$_.Name -match 'YuanShen|Genshin|mhyp|launcher'} | Select-Object Name,ProcessId,SessionId,CommandLine | Format-List
Get-Content C:\Users\djf20\cycle_log.txt -Tail 8