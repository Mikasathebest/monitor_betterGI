# 导出 BGI 日志中与材料/路线监控相关的条目 (头行+消息行), 供 Mac 端 scripts/bgilog.py 解析
# 日志可能很大 (曾达 1GB): 流式逐行读 + 共享读 (BGI 持有写锁), 只保留相关条目
# 用法: powershell -NoProfile -File export_log_events.ps1 [-Date yyyyMMdd] [-Out 路径]
param(
  [string]$Date = (Get-Date -Format 'yyyyMMdd'),
  [string]$Out = ''
)
$ErrorActionPreference = 'Stop'
$logDir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
if (-not $Out) { $Out = "C:\Users\djf20\_agent_log_events_$Date.txt" }
$src = Join-Path $logDir "better-genshin-impact$Date.log"
if (-not (Test-Path $src)) { Write-Output "EXPORT_NOLOG $src"; exit 0 }

# 与 bgilog.py 的解析规则保持一致
$keep = [regex]'配置组|开始执行|执行结束|交互或拾取|传送完成|战斗结束|一条龙|未能返回主界面|脱困|卡住|超时|异常'
$header = [regex]'^\[\d{2}:\d{2}:\d{2}'
$errLevel = [regex]'^\[[^\]]+\] \[(ERR|ERROR|FTL|FATAL)\]'

$fs = New-Object System.IO.FileStream($src, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$sw = New-Object System.IO.StreamWriter($Out, $false, (New-Object System.Text.UTF8Encoding($false)))
$buf = New-Object System.Collections.Generic.List[string]
$kept = 0

function Flush-Entry {
  if ($buf.Count -eq 0) { return }
  $text = [string]::Join("`n", $buf)
  if ($keep.IsMatch($text) -or $errLevel.IsMatch($buf[0])) {
    # 异常堆栈只留前 3 行, 控制体积
    $n = [Math]::Min($buf.Count, 3)
    for ($i = 0; $i -lt $n; $i++) { $sw.WriteLine($buf[$i]) }
    $script:kept++
  }
  $buf.Clear()
}

try {
  while ($null -ne ($line = $sr.ReadLine())) {
    if ($header.IsMatch($line)) { Flush-Entry }
    if ($line.Trim() -ne '') { $buf.Add($line) }
  }
  Flush-Entry
} finally {
  $sw.Close(); $sr.Close(); $fs.Close()
}
Write-Output "EXPORT_OK entries=$kept src_bytes=$((Get-Item $src).Length) out_bytes=$((Get-Item $Out).Length) out=$Out"
