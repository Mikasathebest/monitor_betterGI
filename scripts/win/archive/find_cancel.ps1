# 找 BGI 任务取消的触发源: 焦点检查/自动暂停相关代码
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'

Write-Output '=== 含 "不是原神" 的文件 ==='
Get-ChildItem $src -Recurse -Include '*.cs' | Select-String -Pattern '不是原神' -List | Select-Object -ExpandProperty Path

Write-Output '=== TaskControl.cs 焦点/暂停/取消 相关行 ==='
$f = "$src\GameTask\Common\TaskControl.cs"
$lines = Get-Content $f -Encoding UTF8
$lines | Select-String -Pattern '焦点|暂停|Cancel|IsForeground| foreground' | ForEach-Object { Write-Output ("{0,4}| {1}" -f $_.LineNumber, $_.Line.Trim()) } | Select-Object -First 40
