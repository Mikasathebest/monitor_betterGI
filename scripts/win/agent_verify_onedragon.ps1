[Console]::OutputEncoding = [Text.Encoding]::UTF8
$logDir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
$out = 'C:\Users\djf20\agent_verify_onedragon.txt'
$f = Get-ChildItem $logDir -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fs = New-Object System.IO.FileStream($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$lines = $all -split "`r?`n"
$tail = $lines | Select-Object -Last 120
$matched = $lines | Where-Object { $_ -match '一条龙和配置组任务结束|今日奖励已领取|一条龙|奖励' } | Select-Object -Last 30
$text = "FILE=$($f.FullName)`r`nLASTWRITE=$($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))`r`n---MATCHED---`r`n" + ($matched -join "`r`n") + "`r`n---TAIL120---`r`n" + ($tail -join "`r`n")
[IO.File]::WriteAllText($out, $text, (New-Object Text.UTF8Encoding($false)))
Write-Output $out