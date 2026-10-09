# 读 GlobalMethod.cs 键名解析逻辑 (35-150 行)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$f = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\Core\Script\Dependence\GlobalMethod.cs'
$lines = Get-Content $f -Encoding UTF8
for ($i = 34; $i -lt 150 -and $i -lt $lines.Count; $i++) { Write-Output ("{0,4}| {1}" -f ($i+1), $lines[$i]) }
