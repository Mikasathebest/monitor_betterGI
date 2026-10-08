# 找队伍配置: 星扩散/大世界 出现在哪些文件 (Select-String UTF8 安全) + 一条龙配置文件位置
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\User'
$out = 'C:\Users\djf20\party_find.txt'
$sb = New-Object System.Text.StringBuilder

$files = Get-ChildItem $base -Recurse -Include '*.json', '*.txt' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch 'AutoPathing|MapPathing|log\\' -and $_.Length -lt 2MB }
foreach ($f in $files) {
  try {
    $hits = Select-String -Path $f.FullName -Pattern '星扩散', '大世界' -Encoding UTF8 -ErrorAction SilentlyContinue
    foreach ($h in $hits) {
      $sb.AppendLine($f.FullName.Replace($base, '') + ':' + $h.LineNumber + ': ' + $h.Line.Trim().Substring(0, [Math]::Min(150, $h.Line.Trim().Length))) | Out-Null
    }
  } catch {}
}
$sb.AppendLine('=== User 顶层目录 ===') | Out-Null
Get-ChildItem $base -Directory | ForEach-Object { $sb.AppendLine('DIR ' + $_.Name) | Out-Null }
Get-ChildItem $base -Filter '*.json' | ForEach-Object { $sb.AppendLine('FILE ' + $_.Name) | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'FIND_OK'
