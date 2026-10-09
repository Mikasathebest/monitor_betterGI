$log='C:\Users\djf20\cycle_log.txt'
function Log($m){ "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') AGENT恢复: $m" | Out-File $log -Append -Encoding utf8 }
Log '开始：停止残留点击守护，启动截图器与游戏'
try { Stop-ScheduledTask -TaskName 'BGI_Clickd' -ErrorAction SilentlyContinue } catch {}
Remove-Item 'C:\Users\djf20\click_cmd.txt' -Force -ErrorAction SilentlyContinue
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
Start-Sleep -Seconds 5
if(-not (Get-Process YuanShen -ErrorAction SilentlyContinue)){
 Start-Process 'E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe'
 Log '游戏已启动；按铁律安静等待至少5分钟'
}else{ Log '游戏已存在，不重复启动' }
