'NOW='+(Get-Date -Format o)
'GAME='+(@(Get-Process YuanShen -ErrorAction SilentlyContinue).Count)
'BGI='+(@(Get-Process BetterGI -ErrorAction SilentlyContinue).Count)
Get-Content C:\Users\djf20\cycle_log.txt -Tail 30
Get-WinEvent -FilterHashtable @{LogName='Application';StartTime=(Get-Date).AddMinutes(-10)} -ErrorAction SilentlyContinue | Where-Object {$_.Message -match 'YuanShen|Unity|Genshin'} | Select-Object -First 10 TimeCreated,Id,ProviderName,Message | Format-List