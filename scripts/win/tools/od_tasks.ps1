# 列出一条龙默认配置的任务清单 (看有没有挖矿/地图追踪)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$p = 'D:\projects\betterGI\User\OneDragon\默认配置.json'
$j = Get-Content $p -Raw -Encoding UTF8 | ConvertFrom-Json
$out = 'C:\Users\djf20\od_tasks.txt'
$sb = New-Object System.Text.StringBuilder
# 任务列表字段名探测
$j.PSObject.Properties | ForEach-Object {
  $v = $_.Value
  if ($v -is [array]) { $desc = 'array[' + $v.Count + ']' } else { $desc = [string]$v }
  $sb.AppendLine('FIELD: ' + $_.Name + ' = ' + $desc) | Out-Null
}
if ($j.TaskList) { foreach ($t in $j.TaskList) { $sb.AppendLine('TASK: ' + ($t | ConvertTo-Json -Compress -Depth 3)) | Out-Null } }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'OD_OK'
