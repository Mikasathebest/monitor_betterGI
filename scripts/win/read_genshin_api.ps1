# 读 Genshin.cs 关键 API 实现 (GetCameraOrientation / GetPositionFromMap / Tp)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$f = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\Core\Script\Dependence\Genshin.cs'
$lines = Get-Content $f -Encoding UTF8
Write-Output '===== Genshin.cs 230-310 ====='
for ($i = 229; $i -lt 310 -and $i -lt $lines.Count; $i++) { Write-Output ("{0,4}| {1}" -f ($i+1), $lines[$i]) }

# 找 GetCameraOrientation 的真正实现 (CameraOrientation 计算)
Write-Output '===== CameraOrientation 相关源码位置 ====='
Get-ChildItem 'D:\Projects\better-genshin-impact\BetterGenshinImpact' -Recurse -Include '*.cs' |
  Select-String -Pattern 'CameraOrientation' -List | Select-Object -ExpandProperty Path
