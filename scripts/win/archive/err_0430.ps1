# 提取 04:30 场次 ERR 条目样本 (合并条目后)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$out = 'C:\Users\djf20\err_0430.txt'
$f = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log\better-genshin-impact20260916.log'
$fs = New-Object System.IO.FileStream($f, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$entries = New-Object System.Collections.ArrayList
foreach ($ln in ($all -split "`r?`n")) {
  if ($ln -match '^\[(\d{2}:\d{2}:\d{2})') { [void]$entries.Add([PSCustomObject]@{ Ts = $Matches[1]; Msg = $ln }) }
  elseif ($entries.Count -gt 0 -and $ln.Trim() -ne '') { $entries[$entries.Count - 1].Msg += ' ' + $ln.Trim() }
}
$errs = $entries | Where-Object { $_.Ts -ge '04:30:00' -and $_.Ts -le '06:35:00' -and $_.Msg -match '\[ERR\]' }
$sb = New-Object System.Text.StringBuilder
$sb.AppendLine("ERR 总数: $($errs.Count)") | Out-Null
# 按消息内容分组计数 (取消息尾部 100 字符做 key)
$groups = @{}
foreach ($e in $errs) {
  $m = $e.Msg; if ($m.Length -gt 100) { $m = $m.Substring($m.Length - 100) }
  if (-not $groups.ContainsKey($m)) { $groups[$m] = 0 }
  $groups[$m]++
}
$sb.AppendLine('=== ERR 分组计数 ===') | Out-Null
foreach ($k in $groups.Keys) { $sb.AppendLine("x$($groups[$k])  $k") | Out-Null }
$sb.AppendLine('=== 前 6 条完整 ERR ===') | Out-Null
$errs | Select-Object -First 6 | ForEach-Object { $m = $_.Msg; if ($m.Length -gt 400) { $m = $m.Substring(0, 400) }; $sb.AppendLine("[$($_.Ts)] $m`n") | Out-Null }
# 一条路线任务期间的完整上下文 (找 01-柔灯铃 开始后的 30 条)
$sb.AppendLine('=== 01-柔灯铃 任务上下文 ===') | Out-Null
$idx = -1
for ($i = 0; $i -lt $entries.Count; $i++) { if ($entries[$i].Ts -ge '04:43:00' -and $entries[$i].Msg -match '01-柔灯铃') { $idx = $i; break } }
if ($idx -ge 0) {
  for ($j = $idx; $j -lt [Math]::Min($idx + 30, $entries.Count); $j++) {
    $m = $entries[$j].Msg; if ($m.Length -gt 200) { $m = $m.Substring(0, 200) }
    $sb.AppendLine("[$($entries[$j].Ts)] $m") | Out-Null
  }
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'ERR_OK'
