# 查看: 一条龙配置的续跑配置组 + 各 ScriptGroup 的任务清单 (找钓鱼/采矿/白铁块)
$ErrorActionPreference = 'Continue'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$out = 'C:\Users\djf20\groups_inspect.txt'
$sb = New-Object System.Text.StringBuilder

# 1. 一条龙配置 (找配置组相关字段)
$sb.AppendLine('=== 一条龙配置文件 ===') | Out-Null
Get-ChildItem "$base\User" -Recurse -Filter '*.json' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match 'OneDragon|一条龙' } |
  ForEach-Object { $sb.AppendLine("FILE: $($_.FullName)") | Out-Null }

# 2. ScriptGroup 列表及任务
$sb.AppendLine('=== ScriptGroup 清单 ===') | Out-Null
$sgDir = "$base\User\ScriptGroup"
Get-ChildItem $sgDir -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
  $sb.AppendLine("GROUP FILE: $($_.Name) ($($_.Length) bytes)") | Out-Null
}

# 3. 每个组的名字和任务名 (正则提取, 避免大 JSON 解析卡死)
Get-ChildItem $sgDir -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object {
  $raw = [System.IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
  $name = [regex]::Match($raw, '"Name"\s*:\s*"([^"]+)"').Groups[1].Value
  $sb.AppendLine("--- 组: $name ($($_.Name)) ---") | Out-Null
  $tasks = [regex]::Matches($raw, '"Name"\s*:\s*"([^"]+\.json)"')
  $sb.AppendLine("任务数: $($tasks.Count)") | Out-Null
  $fish = @($tasks | Where-Object { $_.Groups[1].Value -match '钓鱼' })
  $mine = @($tasks | Where-Object { $_.Groups[1].Value -match '矿|白铁|水晶|魔晶|星银|紫晶' })
  $sb.AppendLine("钓鱼任务: $($fish.Count), 采矿任务: $($mine.Count)") | Out-Null
  foreach ($m in $mine | Select-Object -First 30) { $sb.AppendLine("  矿: $($m.Groups[1].Value)") | Out-Null }
}

# 4. 一条龙配置里续跑哪个组
$od = Get-ChildItem "$base\User" -Recurse -Filter '*.json' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -match 'OneDragon' }
foreach ($f in $od) {
  $raw = [System.IO.File]::ReadAllText($f.FullName, [Text.Encoding]::UTF8)
  $m = [regex]::Matches($raw, '"(CompletionAction|GroupName|ScriptGroupName|ConfigGroupName|AfterGroupName)"\s*:\s*"([^"]*)"')
  $sb.AppendLine("--- OneDragon $($f.Name) 关键字段 ---") | Out-Null
  foreach ($x in $m) { $sb.AppendLine("  $($x.Groups[1].Value) = $($x.Groups[2].Value)") | Out-Null }
}
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'INSPECT_OK'
