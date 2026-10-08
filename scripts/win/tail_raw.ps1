# 原始tail: BGI 最新日志最后 N 行 → UTF8 文件 (供 scp 回 Mac)
param([int]$Tail = 40)
$ErrorActionPreference = 'Continue'
$logDir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
$out = 'C:\Users\djf20\hangout_tail.txt'
$f = Get-ChildItem $logDir -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $f) { [System.IO.File]::WriteAllText($out, 'NO LOG FILE', (New-Object System.Text.UTF8Encoding($false))); exit 1 }
$fs = New-Object System.IO.FileStream($f.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
$sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
$all = $sr.ReadToEnd()
$sr.Close(); $fs.Close()
$lines = $all -split "`r?`n" | Where-Object { $_.Trim() -ne '' }
$tailLines = $lines | Select-Object -Last $Tail
$header = "LOG=$($f.Name) SIZE=$($f.Length) TIME=$(Get-Date -Format 'HH:mm:ss') TOTAL=$($lines.Count)"
[System.IO.File]::WriteAllText($out, ($header + "`n" + ($tailLines -join "`n")), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'TAIL_OK'
