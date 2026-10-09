# 查 BGI 命令行参数支持 + GameLoadingTrigger 进门日志标记
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'

Write-Output '=== Program.cs / App 命令行解析 ==='
Get-ChildItem $src -Include 'Program.cs','App.xaml.cs' -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
  $c = Get-Content $_.FullName -Raw -Encoding UTF8
  if ($c -match 'args|CommandLine') { Write-Output ("FILE: " + $_.FullName.Replace($src,'')); ($c -split "`n") | Select-String 'args\[|CommandLine|"--' | Select-Object -First 15 | ForEach-Object { Write-Output $_.Line.Trim() } }
}

Write-Output '=== GameLoadingTrigger 进门点击与日志 ==='
$f = "$src\GameTask\GameLoading\GameLoadingTrigger.cs"
if (Test-Path $f) {
  $lines = Get-Content $f -Encoding UTF8
  $m = $lines | Select-String 'EnterGame|点击进入|LogInformation|LogWarning' | Select-Object -First 8
  foreach ($x in $m) { Write-Output ("{0,4}| {1}" -f $x.LineNumber, $lines[$x.LineNumber-1].Trim()) }
}
