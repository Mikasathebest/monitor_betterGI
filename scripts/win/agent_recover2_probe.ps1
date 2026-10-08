$names = @('BetterGI','BetterGenshinImpact','YuanShen')
Get-Process -ErrorAction SilentlyContinue | Where-Object { $names -contains $_.ProcessName -or $_.ProcessName -match 'capture|screenshot' } | Select-Object ProcessName,Id,SessionId,StartTime | Format-Table -AutoSize
