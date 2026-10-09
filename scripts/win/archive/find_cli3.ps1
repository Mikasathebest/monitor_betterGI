# 查 GameLoadingTrigger 的日志标记 + 当前 AutoEnterGameEnabled 配置
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'
$base = "$src\bin\Release\net8.0-windows10.0.22621.0"

Write-Output '=== GameLoading.cs 日志与点击逻辑 ==='
$lines = Get-Content "$src\GameTask\GameLoading\GameLoading.cs" -Encoding UTF8
$m = ($lines | Select-String 'LogInformation|LogWarning|PosClick|同意|EnterGame' | Select-Object -First 20)
foreach ($x in $m) { Write-Output ("{0,4}| {1}" -f $x.LineNumber, $lines[$x.LineNumber-1].Trim()) }

Write-Output '=== 当前配置 genshinStartConfig ==='
$c = Get-Content "$base\User\config.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$c.genshinStartConfig | ConvertTo-Json -Depth 3
