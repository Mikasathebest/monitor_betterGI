# 大组监控 v2: 合并"时间戳头行+消息行"为条目后再统计
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$logDir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
$out = 'C:\Users\djf20\mon_now.txt'
$f = Get-ChildItem $logDir -Filter *.log | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fs = New-Object System.IO.FileStream($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$rawLines = $all -split "`r?`n"

# 合并: 消息行挂到前一个时间戳条目
$entries = New-Object System.Collections.ArrayList
foreach ($ln in $rawLines) {
  if ($ln -match '^\[(\d{2}:\d{2}:\d{2})') {
    [void]$entries.Add([PSCustomObject]@{ Ts = $Matches[1]; Msg = $ln })
  } elseif ($entries.Count -gt 0 -and $ln.Trim() -ne '') {
    $entries[$entries.Count - 1].Msg += ' ' + $ln.Trim()
  }
}

$sb = New-Object System.Text.StringBuilder
$sb.AppendLine("TIME=$(Get-Date -Format 'HH:mm:ss') LOGSIZE=$($f.Length) ENTRIES=$($entries.Count)") | Out-Null

$cur = ($entries | Where-Object { $_.Msg -match '开始执行' } | Select-Object -Last 1)
$sb.AppendLine("CURRENT: [$($cur.Ts)] $($cur.Msg -replace '.*ScriptService\s*', '')") | Out-Null
$sb.AppendLine("LASTTS: $($entries[$entries.Count-1].Ts)") | Out-Null

# 近 10 分钟异常
$cutoff = (Get-Date).AddMinutes(-10).ToString('HH:mm:ss')
$bad = $entries | Where-Object { $_.Ts -ge $cutoff -and $_.Msg -match '脱困|卡住|失败|错误|异常|超时|放弃|无法|掉线|重连' } | Select-Object -Last 12
$sb.AppendLine("--- 异常(近10min, $($bad.Count)条) ---") | Out-Null
foreach ($b in $bad) { $m = $b.Msg; if ($m.Length -gt 160) { $m = $m.Substring($m.Length - 160) }; $sb.AppendLine("[$($b.Ts)] $m") | Out-Null }

# 自 20:36 起统计
$since = $entries | Where-Object { $_.Ts -ge '20:36:00' }
$pick = ($since | Where-Object { $_.Msg -match '交互或拾取|拾取' }).Count
$fightEnd = ($since | Where-Object { $_.Msg -match '战斗结束' }).Count
$tp = ($since | Where-Object { $_.Msg -match '传送完成' }).Count
$doneNames = @($since | Where-Object { $_.Msg -match '执行结束: "([^"]+)"' } | ForEach-Object { if ($_.Msg -match '执行结束: "([^"]+)"') { $Matches[1] } })
$sb.AppendLine("--- 统计(自20:36): 拾取=$pick 战斗结束=$fightEnd 传送=$tp 任务完成=$($doneNames.Count) ---") | Out-Null
$sb.AppendLine("--- 最近完成: " + (($doneNames | Select-Object -Last 10) -join ' | ') + " ---") | Out-Null

[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'MON_OK'
