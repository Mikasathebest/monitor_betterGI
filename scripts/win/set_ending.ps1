# 设置邀约目标结局: 杀 BGI → 改 config.json → 起 BGI → 起截图器 (确定性流程, 替代易碎的 UIA)
# 用法: powershell -File set_ending.ps1 -Ending '凯亚结局1:问题'
param([string]$Ending = '')
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$log = 'C:\Users\djf20\hangout_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }
$cfgPath = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\User\config.json'

if (-not $Ending) { Log 'set_ending: 未指定结局'; exit 1 }
Log "set_ending: 目标 [$Ending]"

# 1. 杀 BGI (防止退出时覆写配置)
Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# 2. 改配置
$json = Get-Content $cfgPath -Raw -Encoding UTF8 | ConvertFrom-Json
$json.autoSkipConfig.autoHangoutEndChoose = $Ending
$json.autoSkipConfig.autoHangoutEventEnabled = $true
$json.autoSkipConfig.enabled = $true
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($cfgPath, ($json | ConvertTo-Json -Depth 10 -Compress), $utf8NoBom)
Log "set_ending: config.json 已写入 autoHangoutEndChoose=$Ending"

# 3. 起 BGI (经交互任务进 Session 1)
schtasks /run /tn BetterGI_Run | Out-Null
Log 'set_ending: BGI 启动中, 等 25s'
Start-Sleep -Seconds 25

# 4. 起截图器 (按钮不存在=已在跑, 正常)
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
Start-Sleep -Seconds 5
Log 'set_ending: 完成'
Write-Output 'ENDING_SET_OK'
