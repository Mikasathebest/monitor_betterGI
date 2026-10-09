# 查月卡/一条龙 (全文件搜, 先看日志时间范围)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$f = Get-ChildItem "$base\log\better-genshin-impact*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fs = [System.IO.FileStream]::new($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = [System.IO.StreamReader]::new($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$rows = $all -split "`r?`n"
Write-Output ("日志: " + $f.Name + " 行数 " + $rows.Count)
Write-Output ("首行: " + $rows[0])
Write-Output ("末行: " + $rows[-2])
Write-Output '=== 月卡/空月/祝福 全文件 ==='
$rows | Select-String '月卡|空月|祝福' | Select-Object -First 10 | ForEach-Object { Write-Output $_.Line }
Write-Output '=== 一条龙 起止 ==='
$rows | Select-String '一条龙|配置组任务结束' | Select-Object -First 12 | ForEach-Object { Write-Output $_.Line }
Write-Output '=== 每日奖励/委托 ==='
$rows | Select-String '每日奖励|委托' | Select-Object -First 12 | ForEach-Object { Write-Output $_.Line }
