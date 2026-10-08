# 提取地脉花树脂选择完整方法
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$f = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\GameTask\AutoLeyLineOutcrop\AutoLeyLineOutcropTask.cs'
$lines = Get-Content $f -Encoding UTF8
# 找 candidates 相关方法的起止
$startIdx = ($lines | Select-String 'candidates' | Select-Object -First 1).LineNumber
$lo = [Math]::Max(0, $startIdx - 60)
$hi = [Math]::Min($lines.Count - 1, $startIdx + 60)
for ($i = $lo; $i -le $hi; $i++) { Write-Output ("{0,4}| {1}" -f ($i + 1), $lines[$i]) }
