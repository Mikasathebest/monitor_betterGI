# 只起游戏(不起 BGI, 不排程下线) —— 邀约专用会话
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }
$gameExe = 'E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe'

Log '=== 邀约会话: 起游戏 ==='
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\fix_proxy.ps1 | Out-Null
Start-Process $gameExe
Log '游戏进程已启动, 等 240s 加载'
Start-Sleep -Seconds 240
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\enter_door.ps1
Log '进门点击完成'
