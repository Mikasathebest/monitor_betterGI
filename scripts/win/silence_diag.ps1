# 诊断静默期: 找 05:41 和 07:40 静默前的最后日志内容
$ErrorActionPreference = 'Continue'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$out = 'C:\Users\djf20\silence_diag.txt'
$f = Get-ChildItem "$base\log\better-genshin-impact*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fs = New-Object System.IO.FileStream($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$lines = $all -split "`r?`n"

$sb = New-Object System.Text.StringBuilder
foreach ($target in @('05:3', '05:4', '07:3', '07:4')) {
  $sb.AppendLine("=== 最后出现 $target 的 8 行 ===") | Out-Null
  $hits = $lines | Select-String -Pattern ("^\[" + $target) | Select-Object -Last 8
  foreach ($h in $hits) {
    $sb.AppendLine($h.Line.Trim()) | Out-Null
    # 消息在下一行, 一并带上
    $next = $lines[$h.LineNumber]
    if ($next -and $next -notmatch '^\[') { $sb.AppendLine("    " + $next.Trim()) | Out-Null }
  }
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'DIAG_OK'
