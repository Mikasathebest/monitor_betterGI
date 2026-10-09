Start-Sleep -Seconds 180
Get-Process YuanShen -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 8
$game = 'E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe'
Start-Process -FilePath $game -WorkingDirectory (Split-Path $game)
"RESTARTED $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File C:\Users\djf20\agent_recover2_status.txt -Encoding utf8
