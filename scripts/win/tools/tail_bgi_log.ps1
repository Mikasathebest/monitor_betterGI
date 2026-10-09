# 读 BGI 最新日志的关键行 (FileStream+ReadWrite 共享读, 结果写 UTF8 文件供 scp 回 Mac)
# 用法: powershell -File tail_bgi_log.ps1 [-Tail 80] [-Filter 'NAV_RESULT|ERROR_LOG|RESTART']
param([int]$Tail = 80, [string]$Filter = 'NAV_RESULT|ERROR_LOG|RESTART|三角|伺服|采样|上杉|结局|对话开始|导航|卡住|脱困|邀约|执行结束|开始执行|JS')
$ErrorActionPreference = 'Continue'
$logDir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
$out = 'C:\Users\djf20\hangout_tail.txt'

$f = Get-ChildItem $logDir -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $f) { [System.IO.File]::WriteAllText($out, 'NO LOG FILE', (New-Object System.Text.UTF8Encoding($false))); exit 1 }

# FileStream 共享读 (BGI 独占写锁, Get-Content 会失败)
$fs = New-Object System.IO.FileStream($f.FullName, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
$sr = New-Object System.IO.StreamReader($fs, [System.Text.Encoding]::UTF8)
$all = $sr.ReadToEnd()
$sr.Close(); $fs.Close()

$lines = $all -split "`r?`n"
# 只保留最近 10 分钟内的行 (日志行格式 [HH:mm:ss] 或含时间戳), 防止命中上午的旧路径追踪刷屏
$cutoff = (Get-Date).AddMinutes(-10).ToString('HH:mm:ss')
$recent = $lines | Where-Object { $_ -match '\[(\d{2}:\d{2}:\d{2})' -and $Matches[1] -ge $cutoff }
if ($recent.Count -eq 0) { $recent = $lines | Select-Object -Last 200 }
$hits = $recent | Where-Object { $_ -match $Filter } | Select-Object -Last $Tail
$header = "LOG=$($f.Name) SIZE=$($f.Length) TIME=$(Get-Date -Format 'HH:mm:ss') HITS=$($hits.Count)"
[System.IO.File]::WriteAllText($out, ($header + "`n" + ($hits -join "`n")), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'TAIL_OK'
