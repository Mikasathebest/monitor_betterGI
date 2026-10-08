# 读取消调用点的上下文
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\ViewModel\Pages'
foreach ($item in @(@('HomePageViewModel.cs', 379), @('HotKeyPageViewModel.cs', 873))) {
  $f = Join-Path $src $item[0]
  $lines = Get-Content $f -Encoding UTF8
  $idx = [int]$item[1]
  $lo = [Math]::Max(0, $idx - 18); $hi = [Math]::Min($lines.Count - 1, $idx + 6)
  Write-Output ("===== " + $item[0] + " around " + $idx + " =====")
  for ($i = $lo; $i -le $hi; $i++) { Write-Output ("{0,4}| {1}" -f ($i+1), $lines[$i]) }
}
