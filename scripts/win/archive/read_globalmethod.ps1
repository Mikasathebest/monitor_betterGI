# 读 GlobalMethod.cs 的 JS 全局函数 (keyDown/keyUp/moveMouseBy 键名约定)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$f = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\Core\Script\Dependence\GlobalMethod.cs'
$lines = Get-Content $f -Encoding UTF8
Write-Output "总行数: $($lines.Count)"
$hits = $lines | Select-String 'public|VirtualKey|Keys\.|Parse'
foreach ($h in $hits) { Write-Output ("{0,4}| {1}" -f $h.LineNumber, $h.Line.Trim()) }
