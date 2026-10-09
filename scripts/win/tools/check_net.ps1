# 检查代理与网络: Clash 进程 / 系统代理 / 原神服务器连通性
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$out = 'C:\Users\djf20\check_net.txt'
$sb = New-Object System.Text.StringBuilder

$proxy = Get-Process | Where-Object { $_.Name -match 'clash|verge|mihomo|v2ray|sing' } | Select-Object -First 3
if ($proxy) { foreach ($p in $proxy) { $sb.AppendLine("代理进程: $($p.Name) PID=$($p.Id)") | Out-Null } }
else { $sb.AppendLine('代理进程: 无 (Clash 未运行)') | Out-Null }

$rk = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$sb.AppendLine("系统代理: ProxyEnable=$($rk.ProxyEnable) ProxyServer=$($rk.ProxyServer)") | Out-Null

# 原神国服登录服务器连通性 (走系统代理 vs 直连对比)
foreach ($url in @('https://sdk-static.mihoyo.com', 'https://passport-api.mihoyo.com')) {
  try {
    $t = Measure-Command { $r = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 8 }
    $sb.AppendLine("$url => $($r.StatusCode) ($([int]$t.TotalMilliseconds)ms)") | Out-Null
  } catch { $sb.AppendLine("$url => FAIL: $($_.Exception.Message)") | Out-Null }
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'NET_OK'
