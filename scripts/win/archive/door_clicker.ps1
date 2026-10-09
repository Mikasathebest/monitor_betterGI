# 快速进门: 每 10s 盲点游戏窗口中心, 直到进入世界 (加载中点击无害, 在门=进门, 在世界=一次普攻无害)
# 停止条件: 检测到游戏窗口标题栏消失(全屏化) 或 达到上限 8 分钟
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Log 'door_clicker: 开始 10s 循环盲点'
for ($i = 0; $i -lt 48; $i++) {
  $g = Get-Process YuanShen -ErrorAction SilentlyContinue
  if (-not $g) { Log 'door_clicker: 游戏进程没了, 退出'; exit 1 }
  $out = & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\enter_door.ps1
  Log "door_clicker: 第 $($i+1) 次点击 $out"
  Start-Sleep -Seconds 10
}
Log 'door_clicker: 达到上限退出'
