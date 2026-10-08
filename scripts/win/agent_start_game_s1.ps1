$log='C:\Users\djf20\cycle_log.txt'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') AGENT恢复: $m"|Out-File $log -Append -Encoding utf8}
if(Get-Process YuanShen -ErrorAction SilentlyContinue){Log '游戏已存在'}else{Start-Process -FilePath 'E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe' -WorkingDirectory 'E:\YS\miHoYo Launcher\games\Genshin Impact Game';Log 'Session1 再次启动游戏'}