# 读 Navigation.GetTargetOrientation 的世界坐标->相机角度公式
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$f = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\GameTask\AutoPathing\Navigation.cs'
$lines = Get-Content $f -Encoding UTF8
$hits = $lines | Select-String 'GetTargetOrientation|Atan2'
foreach ($h in $hits) { Write-Output ("{0,4}| {1}" -f $h.LineNumber, $h.Line) }
$idx = ($lines | Select-String 'GetTargetOrientation' | Select-Object -First 1).LineNumber
if ($idx) {
  $lo = [Math]::Max(0, $idx - 5); $hi = [Math]::Min($lines.Count - 1, $idx + 25)
  Write-Output "===== GetTargetOrientation 实现 ====="
  for ($i = $lo; $i -le $hi; $i++) { Write-Output ("{0,4}| {1}" -f ($i+1), $lines[$i]) }
}
