# 查 BGI 自动进入游戏的实现与触发条件
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'
$hits = Get-ChildItem $src -Recurse -Include '*.cs' -ErrorAction SilentlyContinue | Select-String -Pattern 'AutoEnterGame|自动进入|点击进入' -List | Select-Object -First 6
foreach ($h in $hits) {
  Write-Output ("===== " + $h.Path.Replace($src, '') + " =====")
  $lines = Get-Content $h.Path -Encoding UTF8
  $m = $lines | Select-String 'AutoEnterGame|点击进入' | Select-Object -First 1
  if ($m) {
    $lo = [Math]::Max(0, $m.LineNumber - 10); $hi = [Math]::Min($lines.Count - 1, $m.LineNumber + 30)
    for ($i = $lo; $i -le $hi; $i++) { Write-Output ("{0,4}| {1}" -f ($i + 1), $lines[$i]) }
  }
}
