# 在 User 目录全量找 GUID 映射 + 日志里的一条龙任务名
$ErrorActionPreference = 'Continue'
$out = 'C:\Users\djf20\guid_map.txt'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$sb = New-Object System.Text.StringBuilder
$g = 'dab529e9-7ad8-46f2-ac10-d6031b4fa143'
$hits = Get-ChildItem "$base\User" -Recurse -Filter '*.json' -ErrorAction SilentlyContinue |
  Select-String -Pattern $g -List -ErrorAction SilentlyContinue
foreach ($h in $hits) { $sb.AppendLine("GUID在: $($h.Path.Replace($base,''))") | Out-Null }

# 日志里 F9 启动后的任务名 (一条龙任务执行 前后的行)
$f = Get-ChildItem "$base\log\better-genshin-impact*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fs = New-Object System.IO.FileStream($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$lines = $all -split "`r?`n"
$sb.AppendLine('--- 日志中 一条龙任务执行 上下文 ---') | Out-Null
$idxs = @()
for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '一条龙任务执行|启用一条龙任务') { $idxs += $i } }
foreach ($i in ($idxs | Select-Object -Last 12)) {
  $sb.AppendLine($lines[$i].Trim()) | Out-Null
  if ($lines[$i+1] -and $lines[$i+1] -notmatch '^\[') { $sb.AppendLine('    ' + $lines[$i+1].Trim()) | Out-Null }
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'GUID_OK'
