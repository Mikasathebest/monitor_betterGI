# 在 BGI 源码中查关键配置语义
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact'

Write-Output '=== MinResinToKeep 用法 ==='
Get-ChildItem $src -Recurse -Include *.cs -ErrorAction SilentlyContinue |
  Select-String -Pattern 'MinResinToKeep' -List | Select-Object -First 5 -ExpandProperty Path

Write-Output '=== 鱼饵 bait 相关源码文件 ==='
Get-ChildItem $src -Recurse -Include *.cs -ErrorAction SilentlyContinue |
  Select-String -Pattern '鱼饵|Bait' -List | Select-Object -First 8 -ExpandProperty Path

Write-Output '=== scanDropsAfterReward 用法 ==='
Get-ChildItem $src -Recurse -Include *.cs -ErrorAction SilentlyContinue |
  Select-String -Pattern 'ScanDropsAfterReward' -List | Select-Object -First 5 -ExpandProperty Path
