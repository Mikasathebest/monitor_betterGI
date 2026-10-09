# 当前组进度: 今天 16:50 后的路线执行情况
$ErrorActionPreference = 'Continue'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$out = 'C:\Users\djf20\group_progress.txt'
$f = Get-ChildItem "$base\log\better-genshin-impact$(Get-Date -Format yyyyMMdd).log" -ErrorAction SilentlyContinue
$fs = New-Object System.IO.FileStream($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = New-Object System.IO.StreamReader($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$lines = $all -split "`r?`n"
$sb = New-Object System.Text.StringBuilder
# 组启动/结束事件 + 路线开始事件 (16:50 之后)
for ($i = 0; $i -lt $lines.Count; $i++) {
  $l = $lines[$i]
  if ($l -match '^\[(1[6-9]:[0-9]{2}:[0-9]{2})' -and $l.Substring(1,8) -ge '16:50:00') {
    $next = if ($i+1 -lt $lines.Count) { $lines[$i+1] } else { '' }
    if ($next -match '配置组|开始执行地图追踪任务|执行结束|任务结束') {
      $sb.AppendLine("$($l.Substring(0,12)) $($next.Trim())") | Out-Null
    }
  }
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'PROG_OK'
