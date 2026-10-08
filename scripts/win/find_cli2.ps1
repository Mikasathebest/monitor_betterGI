# 深挖: GameLoadingTrigger 实现 + App 启动参数
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'

Write-Output '=== GameLoadingTrigger 所在文件 ==='
$f = Get-ChildItem $src -Recurse -Include '*.cs' | Select-String -Pattern 'class GameLoadingTrigger' -List | Select-Object -First 1
if ($f) {
  Write-Output $f.Path
  $lines = Get-Content $f.Path -Encoding UTF8
  $m = ($lines | Select-String 'class GameLoadingTrigger' | Select-Object -First 1).LineNumber
  $hi = [Math]::Min($lines.Count - 1, $m + 90)
  for ($i = $m - 1; $i -le $hi; $i++) { Write-Output ("{0,4}| {1}" -f ($i + 1), $lines[$i]) }
}

Write-Output '=== App.xaml.cs 启动参数处理 ==='
$app = Get-Content "$src\App.xaml.cs" -Encoding UTF8
$m = ($app | Select-String 'args|Startup' | Select-Object -First 3).LineNumber
if ($m) { for ($i = $m[0] - 1; $i -le [Math]::Min($app.Count - 1, $m[0] + 40); $i++) { Write-Output ("{0,4}| {1}" -f ($i + 1), $app[$i]) } }
