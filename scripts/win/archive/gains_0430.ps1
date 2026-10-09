# 统计 04:30 场次收益: 04:30-06:35 窗口内的路线/拾取/战斗/树脂
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$out = 'C:\Users\djf20\gains_0430.txt'
$f = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log\better-genshin-impact20260916.log'
$fs = New-Object System.IO.FileStream($f, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()

# 合并 时间戳头行+消息行
$entries = New-Object System.Collections.ArrayList
foreach ($ln in ($all -split "`r?`n")) {
  if ($ln -match '^\[(\d{2}:\d{2}:\d{2})') { [void]$entries.Add([PSCustomObject]@{ Ts = $Matches[1]; Msg = $ln }) }
  elseif ($entries.Count -gt 0 -and $ln.Trim() -ne '') { $entries[$entries.Count - 1].Msg += ' ' + $ln.Trim() }
}
$w = $entries | Where-Object { $_.Ts -ge '04:30:00' -and $_.Ts -le '06:35:00' }

$sb = New-Object System.Text.StringBuilder
$sb.AppendLine("窗口条目数: $($w.Count)") | Out-Null

# 一条龙关键事件
$sb.AppendLine('=== 一条龙 ===') | Out-Null
$w | Where-Object { $_.Msg -match '一条龙|树脂|每日奖励|邮件|尘歌壶|地脉|合成' -and $_.Msg -match 'INF|WRN' } |
  Where-Object { $_.Msg -match '结束|完成|领取|使用|购买|合成|消耗|奖励' } |
  Select-Object -First 25 | ForEach-Object { $m = $_.Msg; if ($m.Length -gt 130) { $m = $m.Substring($m.Length - 130) }; $sb.AppendLine("[$($_.Ts)] $m") | Out-Null }

# 大组路线完成清单
$done = @($w | Where-Object { $_.Msg -match '执行结束: "([^"]+)"' } | ForEach-Object { if ($_.Msg -match '执行结束: "([^"]+)", 耗时: (\S+)') { $Matches[1] + ' (' + $Matches[2] + ')' } })
$sb.AppendLine("=== 大组完成任务数: $($done.Count) ===") | Out-Null
foreach ($d in $done) { $sb.AppendLine($d) | Out-Null }

# 拾取/战斗/传送/卡死统计
$pick = ($w | Where-Object { $_.Msg -match '交互或拾取|拾取' }).Count
$fight = ($w | Where-Object { $_.Msg -match '战斗结束' }).Count
$fightFail = ($w | Where-Object { $_.Msg -match '战斗失败' }).Count
$tp = ($w | Where-Object { $_.Msg -match '传送完成' }).Count
$stuck = ($w | Where-Object { $_.Msg -match '卡死|脱困' }).Count
$err = ($w | Where-Object { $_.Msg -match '\[ERR\]' }).Count
$sb.AppendLine("=== 统计: 拾取=$pick 战斗结束=$fight 战斗失败=$fightFail 传送=$tp 卡死脱困=$stuck ERR=$err ===") | Out-Null

# 钓鱼统计
$fish = ($w | Where-Object { $_.Msg -match '钓鱼' -and $_.Msg -match '成功|完成|结束' }).Count
$sb.AppendLine("钓鱼相关完成事件: $fish") | Out-Null

[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'GAINS_OK'
