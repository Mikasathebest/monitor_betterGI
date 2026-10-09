# 第二批源码/日志调查
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'
$base = "$src\bin\Release\net8.0-windows10.0.22621.0"

Write-Output '=== AutoLeyLineOutcropParam 全部属性 ==='
Get-Content "$src\GameTask\AutoLeyLineOutcrop\AutoLeyLineOutcropParam.cs" -Encoding UTF8 |
  Select-String -Pattern 'public .+ \{ get' | ForEach-Object { $_.Line.Trim() }

Write-Output '=== 地脉花树脂耗尽模式逻辑 (IsResinExhaustionMode 上下文) ==='
Get-Content "$src\GameTask\AutoLeyLineOutcrop\AutoLeyLineOutcropTask.cs" -Encoding UTF8 |
  Select-String -Pattern 'IsResinExhaustionMode|UseCondensedResin|hasCondensed' -Context 2 | Select-Object -First 6 | ForEach-Object { $_.Line.Trim() }

Write-Output '=== 今日日志鱼饵相关 ==='
$log = Get-ChildItem "$base\log\better-genshin-impact*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fs = [System.IO.FileStream]::new($log.FullName, 'Open', 'Read', 'ReadWrite')
$sr = [System.IO.StreamReader]::new($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
($all -split "`r?`n") | Select-String '鱼饵|饵料|没有饵' | Select-Object -Last 8 | ForEach-Object { Write-Output $_.Line }

Write-Output '=== JsScript 目录 ==='
Get-ChildItem "$base\User\JsScript" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
