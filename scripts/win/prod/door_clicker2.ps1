# 进门点击器 v2: 每 6s 盲点游戏窗口中心, 设计上由 wscript 隐藏运行 (不抢焦点)
# 由 Agent 外部控制生死: CV 确认进大世界后杀掉本进程; 上限 10 分钟自保退出
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }
Log 'door_clicker2: 开始 6s 隐藏循环盲点'
for ($i = 0; $i -lt 100; $i++) {
  $g = Get-Process YuanShen -ErrorAction SilentlyContinue
  if (-not $g) { Log 'door_clicker2: 游戏进程没了, 退出'; exit 1 }
  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Users\djf20\enter_door.ps1
  Log "door_clicker2: 第 $($i+1) 次点击"
  Start-Sleep -Seconds 6
}
Log 'door_clicker2: 达到上限退出'
