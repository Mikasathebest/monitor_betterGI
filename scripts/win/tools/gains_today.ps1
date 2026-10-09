# 今日 (04:30 起) 收益与异常统计 → UTF8 文件供 scp 回 Mac
$ErrorActionPreference = 'Continue'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$out = 'C:\Users\djf20\gains_today.txt'
$f = Get-ChildItem "$base\log\better-genshin-impact*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$fs = New-Object System.IO.FileStream($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$lines = $all -split "`r?`n"

# 只统计 04:30 之后的内容: 找第一条 >=04:30 的时间戳行, 取其后的**全部行** (含无时间戳的消息行)
$startIdx = -1
for ($i = $lines.Count - 1; $i -ge 0; $i--) {
  if ($lines[$i] -match '^\[(\d{2}):(\d{2})') {
    $mins = [int]$Matches[1] * 60 + [int]$Matches[2]
    if ($mins -ge 270) { $startIdx = $i } else { break }
  }
}
if ($startIdx -lt 0) { $startIdx = 0 }
$after = $lines[$startIdx..($lines.Count - 1)]

$sb = New-Object System.Text.StringBuilder
$sb.AppendLine("日志文件: $($f.Name), 04:30 后行数: $(@($after).Count)") | Out-Null
$sb.AppendLine("传送次数: $(@($after | Select-String '开始传送').Count)") | Out-Null
$sb.AppendLine("拾取次数: $(@($after | Select-String '拾取').Count)") | Out-Null
$sb.AppendLine("战斗相关: $(@($after | Select-String '元素战技|元素爆发').Count)") | Out-Null
$sb.AppendLine("地脉花: $(@($after | Select-String '地脉').Count)") | Out-Null
$sb.AppendLine("合成台: $(@($after | Select-String '合成').Count)") | Out-Null
$sb.AppendLine("每日奖励/委托: $(@($after | Select-String '每日奖励|委托').Count)") | Out-Null
$sb.AppendLine("'已领取': $(@($after | Select-String '已领取').Count)") | Out-Null
$sb.AppendLine("ERR 未能返回主界面: $(@($after | Select-String '未能返回主界面').Count)") | Out-Null
$sb.AppendLine("配置组执行结束: $(@($after | Select-String '配置组.*执行结束').Count)") | Out-Null
$sb.AppendLine("一条龙完成标记: $(@($after | Select-String '一条龙和配置组任务结束').Count)") | Out-Null
$sb.AppendLine("任务执行结束(路线): $(@($after | Select-String '执行结束').Count)") | Out-Null
$sb.AppendLine('--- 关键事件 (领取/完成/异常) ---') | Out-Null
$after | Select-String '已领取|一条龙|执行结束|未能返回|恢复|卡住|脱困' | Select-Object -Last 30 | ForEach-Object { $sb.AppendLine($_.Line.Trim()) | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'GAINS_OK'
