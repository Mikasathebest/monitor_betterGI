# 列出 BGI 战斗策略相关目录与文件
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
Write-Output '=== User 目录 ==='
Get-ChildItem "$base\User" -Directory | Select-Object -ExpandProperty Name
Write-Output '=== User\AutoFight (自定义策略) ==='
Get-ChildItem "$base\User\AutoFight" -ErrorAction SilentlyContinue | Select-Object Name, Length, LastWriteTime
Write-Output '=== 内置策略 Assets ==='
Get-ChildItem "$base\Assets" -Recurse -Include *.txt,*.json -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'Strategy|Fight|Combat' } | Select-Object -First 20 FullName
