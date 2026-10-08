# 系统代理自愈: Clash(FlyintPro) 没跑而系统代理指着 127.0.0.1:7890 → 原神断网登不上
# 逻辑: 代理开 + 7890 无监听 → 关代理(直连); 代理开 + 7890 在听 → VPN 正常, 不动; 代理关 → 不动
# 调用: session_online.ps1 起游戏前; 也可手动单跑
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$proxyOn = (Get-ItemProperty -Path $key -Name ProxyEnable -ErrorAction SilentlyContinue).ProxyEnable
$proxyServer = (Get-ItemProperty -Path $key -Name ProxyServer -ErrorAction SilentlyContinue).ProxyServer

# 测 7890 是否有监听 (1.5s 超时)
$alive = $false
try {
  $tcp = New-Object System.Net.Sockets.TcpClient
  $iar = $tcp.BeginConnect('127.0.0.1', 7890, $null, $null)
  $alive = $iar.AsyncWaitHandle.WaitOne(1500) -and $tcp.Connected
  $tcp.Close()
} catch { $alive = $false }

if ($proxyOn -eq 1 -and -not $alive) {
  Set-ItemProperty -Path $key -Name ProxyEnable -Value 0
  Log "代理自愈: 系统代理开($proxyServer)但 7890 无监听(Clash 未运行) → 已关代理, 走直连"
  Write-Output 'PROXY_DISABLED (was on, vpn dead)'
} elseif ($proxyOn -eq 1 -and $alive) {
  Write-Output 'PROXY_OK (vpn alive)'
} else {
  Write-Output 'PROXY_OFF (direct)'
}
