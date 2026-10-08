$log='C:\Users\djf20\cycle_log.txt';function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') AGENT恢复: $m"|Out-File $log -Append -Encoding utf8}
Stop-Process -Name YuanShen -Force -ErrorAction SilentlyContinue
Start-Sleep 10
Start-Process -FilePath 'E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe' -WorkingDirectory 'E:\YS\miHoYo Launcher\games\Genshin Impact Game'
Log '第二次门界面停滞，干净重启游戏，随后安静等待5分钟'