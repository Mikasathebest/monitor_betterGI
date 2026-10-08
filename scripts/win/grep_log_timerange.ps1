# 抓指定时间段+关键字的日志行 → UTF8 文件
param([string]$Since = '20:26', [int]$MaxLines = 120)
$ErrorActionPreference = 'Continue'
$logDir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
$out = 'C:\Users\djf20\hangout_tail.txt'
$f = Get-ChildItem $logDir -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fs = New-Object System.IO.FileStream($f.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
$sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
$all = $sr.ReadToEnd()
$sr.Close(); $fs.Close()
$lines = $all -split "`r?`n"
# 日志是一条消息两行(头行[时间]+内容行), 把头行+内容行合并输出
$hits = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^\[(20:2[6-9]|20:3\d)' ) {
    $content = ''
    if ($i + 1 -lt $lines.Count -and $lines[$i+1] -notmatch '^\[\d{2}:') { $content = $lines[$i+1] }
    $hits += ($lines[$i] + ' ' + $content).Trim()
  }
}
$hits = $hits | Select-Object -Last $MaxLines
[System.IO.File]::WriteAllText($out, ($hits -join "`n"), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'GREP_OK'
