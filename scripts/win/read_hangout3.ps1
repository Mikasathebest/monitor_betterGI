# 读 hangout.json 结构 + HangoutConfig.cs + 找世界坐标->相机角度的换算函数
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'

Write-Output '===== HangoutConfig.cs ====='
Get-Content "$src\GameTask\AutoSkip\Assets\HangoutConfig.cs" -Raw -Encoding UTF8

Write-Output '===== hangout.json 前 60 行 ====='
Get-Content "$src\GameTask\AutoSkip\Assets\hangout.json" -Encoding UTF8 -TotalCount 60

Write-Output '===== hangout.json 角色列表 ====='
$j = Get-Content "$src\GameTask\AutoSkip\Assets\hangout.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$j.PSObject.Properties.Name

Write-Output '===== 世界坐标->相机角度 换算 (RotateToApproach 调用点) ====='
Get-ChildItem $src -Recurse -Include '*.cs' | Select-String -Pattern 'RotateToApproach|GetTargetOrientation|Math.Atan2' -List | Select-Object -ExpandProperty Path
