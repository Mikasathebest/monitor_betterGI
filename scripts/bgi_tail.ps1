# 读取 BGI 最新日志 (共享读, 绕开独占锁)
# 默认: 最近 N 条 INF/ERR 消息(含消息体); -Raw: 最近 N 行原文
param([int]$N = 25, [switch]$Raw)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$f = Get-ChildItem "$base\log\*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
Write-Output ("LOGFILE: " + $f.Name)
$fs = [System.IO.FileStream]::new($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = [System.IO.StreamReader]::new($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd()
$sr.Close(); $fs.Close()
$lines = $all -split "`r?`n" | Where-Object { $_ -ne '' }
if ($Raw) { $lines | Select-Object -Last $N; return }
# 条目 = 头行([时间] [级别] [来源]) + 后续消息行; 从后往前收集 N 个条目
$out = @()
for ($i = $lines.Count - 1; $i -ge 0 -and $out.Count -lt $N; $i--) {
  if ($lines[$i] -match '^\[\d{2}:\d{2}:\d{2}') {
    $entry = $lines[$i]
    if ($i + 1 -lt $lines.Count -and $lines[$i+1] -notmatch '^\[\d{2}:\d{2}:\d{2}') { $entry += ' | ' + $lines[$i+1] }
    if ($entry -notmatch 'ONNX|GpuAuto') { $out += $entry }
  }
}
[array]::Reverse($out)
$out
