# 日志 1GB 卡死修复: 杀 BGI → 删巨日志 → 重启 BGI (游戏不动, 已在大世界)
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\cycle_log.txt'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# 删掉 >=500MB 的今日日志 (截图失败 spam 灌出来的, 无分析价值)
$today = "$base\log\better-genshin-impact$(Get-Date -Format yyyyMMdd).log"
$sz = 0
if (Test-Path $today) { $sz = (Get-Item $today).Length }
if ($sz -ge 500MB) {
  Remove-Item $today -Force -ErrorAction SilentlyContinue
  Log "已删除巨型日志 ($([int]($sz/1MB)) MB)"
} else {
  Log "今日日志 $([int]($sz/1MB)) MB, 未达删除阈值"
}

schtasks /run /tn BetterGI_Run | Out-Null
Log "BGI 重启中, 等 75s"
Start-Sleep -Seconds 75
$bgi = Get-Process BetterGI -ErrorAction SilentlyContinue
if ($bgi) { Log "BGI 已起 (PID $($bgi.Id))" } else { Log "警告: BGI 未起来" }
Write-Output 'FIXLOG_OK'
