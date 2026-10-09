# 找遗迹猎者: 锄地-精英400 等混合路线包 + 全 User 目录文件名
$ErrorActionPreference = 'Continue'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$out = 'C:\Users\djf20\hunter_routes.txt'
$sb = New-Object System.Text.StringBuilder
$sb.AppendLine('=== 全 User 文件名含 猎者 ===') | Out-Null
Get-ChildItem "$base\User" -Recurse -Filter '*猎者*' -ErrorAction SilentlyContinue |
  ForEach-Object { $sb.AppendLine($_.FullName.Replace("$base\User\", '')) | Out-Null }
$sb.AppendLine('=== 锄地-精英400 文件列表 ===') | Out-Null
Get-ChildItem "$base\User\AutoPathing\锄地-精英400" -Recurse -ErrorAction SilentlyContinue |
  ForEach-Object { $sb.AppendLine($_.Name) | Out-Null }
$sb.AppendLine('=== 白铁块-富集 文件数 ===') | Out-Null
$wt = Get-ChildItem "$base\User\AutoPathing\白铁块-富集" -Recurse -Filter '*.json' -ErrorAction SilentlyContinue
$sb.AppendLine("白铁块-富集: $($wt.Count) 个") | Out-Null
foreach ($f in $wt | Select-Object -First 8) { $sb.AppendLine('  ' + $f.Name) | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'HUNTER_OK'
