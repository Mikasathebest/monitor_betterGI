# 读 PathExecutor/TrapEscaper 中 世界坐标->相机角度 的换算与卡死脱困逻辑
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\GameTask\AutoPathing'

$f1 = "$base\PathExecutor.cs"
$lines = Get-Content $f1 -Encoding UTF8
$idx = ($lines | Select-String 'Atan2' | Select-Object -First 1).LineNumber
if ($idx) {
  $lo = [Math]::Max(0, $idx - 20); $hi = [Math]::Min($lines.Count - 1, $idx + 15)
  Write-Output "===== PathExecutor.cs Atan2 附近 ($lo-$hi) ====="
  for ($i = $lo; $i -le $hi; $i++) { Write-Output ("{0,4}| {1}" -f ($i+1), $lines[$i]) }
}

Write-Output ''
Write-Output '===== TrapEscaper.cs 全文 ====='
Get-Content "$base\TrapEscaper.cs" -Raw -Encoding UTF8
