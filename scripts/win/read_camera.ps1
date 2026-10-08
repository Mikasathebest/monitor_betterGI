# 读相机朝向/旋转实现: CameraOrientation.cs + CameraRotateTask.cs
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\GameTask'

Write-Output '===== CameraOrientation.cs (全文) ====='
Get-Content "$base\Common\Map\CameraOrientation.cs" -Raw -Encoding UTF8

Write-Output ''
Write-Output '===== CameraRotateTask.cs (全文) ====='
Get-Content "$base\AutoPathing\CameraRotateTask.cs" -Raw -Encoding UTF8
