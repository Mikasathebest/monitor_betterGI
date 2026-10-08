$log='C:\Users\djf20\cycle_log.txt'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') AGENT恢复: $m"|Out-File $log -Append -Encoding utf8}
Stop-Process -Name YuanShen -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 5
Start-Process 'E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe'
Log '门界面未进入且白屏，已杀游戏重开；开始安静等待'
