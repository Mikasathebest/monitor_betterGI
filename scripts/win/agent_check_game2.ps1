'NOW='+(Get-Date -Format o)
'GAME='+(@(Get-Process YuanShen -ErrorAction SilentlyContinue).Count)
Get-Content C:\Users\djf20\cycle_log.txt -Tail 5