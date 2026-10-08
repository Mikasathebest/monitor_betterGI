# 查 AutoHangoutEndChoose 的匹配语义与结局处理
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'
$hits = Get-ChildItem $src -Recurse -Include '*.cs' -ErrorAction SilentlyContinue | Select-String -Pattern 'AutoHangoutEndChoose|HangoutOptionsTitle' -List
foreach ($h in $hits) {
  Write-Output ("===== " + $h.Path.Replace($src, '') + " =====")
  $lines = Get-Content $h.Path -Encoding UTF8
  $idx = ($lines | Select-String 'AutoHangoutEndChoose|HangoutOptionsTitle' | Select-Object -First 1).LineNumber
  $lo = [Math]::Max(0, $idx - 15); $hi = [Math]::Min($lines.Count - 1, $idx + 35)
  for ($i = $lo; $i -le $hi; $i++) { Write-Output ("{0,4}| {1}" -f ($i + 1), $lines[$i]) }
}
