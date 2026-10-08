# 调研 BGI 自动邀约: 源码结构 + 配置 + 触发方式
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'
$base = "$src\bin\Release\net8.0-windows10.0.22621.0"

Write-Output '=== AutoHangout 源码文件 ==='
Get-ChildItem $src -Recurse -Filter '*Hangout*' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName

Write-Output '=== 邀约配置 (config.json 相关键) ==='
$c = Get-Content "$base\User\config.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$c.PSObject.Properties | Where-Object { $_.Name -match 'hangout|邀约' } | ForEach-Object { Write-Output ($_.Name + ' = ' + ($_.Value | ConvertTo-Json -Compress -Depth 4)) }

Write-Output '=== JS API 有无邀约 ==='
Get-ChildItem "$src" -Recurse -Include '*.cs' -ErrorAction SilentlyContinue | Select-String -Pattern 'Hangout' -List | Where-Object { $_.Path -match 'Script|Js' } | Select-Object -First 5 -ExpandProperty Path
