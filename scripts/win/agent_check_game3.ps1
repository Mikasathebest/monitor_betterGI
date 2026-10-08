'NOW='+(Get-Date -Format o)
'GAME='+(@(Get-Process YuanShen -ErrorAction SilentlyContinue).Count)
Get-Content C:\Users\djf20\cycle_log.txt -Tail 5
Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=(Get-Date).AddMinutes(-5)} -ErrorAction SilentlyContinue | Where-Object {$_.LevelDisplayName -eq 'Error'} | Select-Object -First 5 TimeCreated,ProviderName,Id,Message | Format-List