# 找 JS 脚本取消源: ScriptService/ScriptGroupProject/ScriptProject 中的 Cancel/超时
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'

foreach ($rel in @('Service\ScriptService.cs', 'Core\Script\Group\ScriptGroupProject.cs', 'Core\Script\Project\ScriptProject.cs', 'Core\Script\CancellationContext.cs')) {
  $f = Join-Path $src $rel
  Write-Output ("===== " + $rel + " =====")
  $lines = Get-Content $f -Encoding UTF8
  $lines | Select-String -Pattern 'Cancel|TimeSpan|Timeout|cts|Cts' | ForEach-Object { Write-Output ("{0,4}| {1}" -f $_.LineNumber, $_.Line.Trim()) } | Select-Object -First 25
}
