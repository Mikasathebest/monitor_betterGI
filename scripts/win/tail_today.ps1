# 读今天 BGI 日志的最后 N 行 (FileStream 共享读, 绕独占锁)
$ErrorActionPreference = 'Continue'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$f = Get-ChildItem "$base\log\better-genshin-impact$(Get-Date -Format yyyyMMdd).log" -ErrorAction SilentlyContinue
$out = 'C:\Users\djf20\tail_today.txt'
if (-not $f) { [System.IO.File]::WriteAllText($out, 'NO_TODAY_LOG', (New-Object System.Text.UTF8Encoding($false))); Write-Output 'NO_TODAY_LOG'; exit }
$fs = New-Object System.IO.FileStream($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$lines = $all -split "`r?`n"
$tail = $lines | Select-Object -Last 40
[System.IO.File]::WriteAllText($out, ("SIZE=$($f.Length) LINES=$($lines.Count)`n" + ($tail -join "`n")), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'TAIL_OK'
