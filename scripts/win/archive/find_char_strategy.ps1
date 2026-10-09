# 搜索 BGI 内置/仓库策略中特定角色的出招数据
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$names = @('桑多涅', '奥黛塔', '阿罗夏', '木偶')

Write-Output '=== Assets 全量递归搜文件名 ==='
Get-ChildItem "$base\Assets" -Recurse -ErrorAction SilentlyContinue |
  Where-Object { $n = $_.Name; ($names | Where-Object { $n -match $_ }) } |
  Select-Object -First 15 -ExpandProperty FullName

Write-Output '=== Assets 文本内容搜角色名 (策略 json/txt) ==='
$hits = Get-ChildItem "$base\Assets" -Recurse -Include *.txt,*.json -ErrorAction SilentlyContinue |
  Select-String -Pattern '桑多涅' -List -ErrorAction SilentlyContinue | Select-Object -First 5 -ExpandProperty Path
$hits

Write-Output '=== User\AutoFight 全量 ==='
Get-ChildItem "$base\User\AutoFight" -Recurse -ErrorAction SilentlyContinue |
  Select-Object FullName, Length

Write-Output '=== 仓库同步目录 Repos 搜策略 ==='
Get-ChildItem "$base\Repos" -Recurse -Include *.txt -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match 'combat|fight|策略' } |
  Select-Object -First 10 -ExpandProperty FullName
