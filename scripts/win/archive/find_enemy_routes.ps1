# 找 AutoPathing/MapPathing 里的敌人路线: 遗迹守卫/遗迹猎者/盗宝团
$ErrorActionPreference = 'Continue'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$out = 'C:\Users\djf20\enemy_routes.txt'
$sb = New-Object System.Text.StringBuilder
foreach ($kw in @('遗迹守卫','遗迹猎者','盗宝团')) {
  $files = Get-ChildItem "$base\User\AutoPathing" -Recurse -Filter "*$kw*" -ErrorAction SilentlyContinue
  $files += Get-ChildItem "$base\User\MapPathing" -Recurse -Filter "*$kw*" -ErrorAction SilentlyContinue
  $sb.AppendLine("=== $kw : $($files.Count) 个 ===") | Out-Null
  foreach ($f in $files | Select-Object -First 40) { $sb.AppendLine($f.FullName.Replace("$base\User\", '')) | Out-Null }
}
# 顺便列出 AutoPathing 顶层目录 (看有哪些路线包)
$sb.AppendLine('=== AutoPathing 顶层目录 ===') | Out-Null
Get-ChildItem "$base\User\AutoPathing" -Directory -ErrorAction SilentlyContinue | ForEach-Object { $sb.AppendLine($_.Name) | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'ENEMY_OK'
