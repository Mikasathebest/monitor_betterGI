# 读邀约配置结构
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'
$base = "$src\bin\Release\net8.0-windows10.0.22621.0"

Write-Output '=== HangoutConfig.cs ==='
Get-Content "$src\GameTask\AutoSkip\Assets\HangoutConfig.cs" -Raw -Encoding UTF8

Write-Output '=== hangout.json 结构 (前 80 行) ==='
Get-Content "$src\GameTask\AutoSkip\Assets\hangout.json" -Encoding UTF8 -TotalCount 80

Write-Output '=== autoSkipConfig 当前值 ==='
$c = Get-Content "$base\User\config.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$c.autoSkipConfig | ConvertTo-Json -Depth 5
