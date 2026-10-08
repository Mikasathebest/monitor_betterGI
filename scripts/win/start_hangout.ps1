# 启动邀约: 起 BGI (BetterGI_Run 交互任务) → 等 25s → 起截图器 → 按名启动邀约组
# 前提: config.json/target.json 已由 Mac 端写好, BGI 已杀
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\hangout_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Log 'start_hangout: 起 BGI'
schtasks /run /tn BetterGI_Run | Out-Null
Start-Sleep -Seconds 25

$bgi = Get-Process BetterGI -ErrorAction SilentlyContinue
if (-not $bgi) { Log 'start_hangout: BGI 未能启动'; exit 1 }
Log "start_hangout: BGI pid=$($bgi.Id), 起截图器"
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
Start-Sleep -Seconds 5

Log 'start_hangout: 按名启动组 久岐忍邀约'
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File D:\Projects\genshin_detect\scripts\win\uia_start_group_named.ps1 -NameMatch '久岐忍邀约'
Log 'start_hangout: 完成'
Write-Output 'HANGOUT_STARTED'
