$p1 = Get-Process YuanShen -ErrorAction SilentlyContinue
$p2 = Get-Process BetterGenshinImpact -ErrorAction SilentlyContinue
"GAME_COUNT=$(@($p1).Count)"
"BGI_COUNT=$(@($p2).Count)"
Get-ScheduledTask -TaskName 'BGI_Session' | Select-Object TaskName,State | Format-List