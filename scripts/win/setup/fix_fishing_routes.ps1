# 钓鱼路线补齐: 对照 钓鱼 配置组引用, 把缺失的 json 从 MapPathing 复制进 AutoPathing
# (BGI 0.64.2 实际读 AutoPathing; MapPathing 是遗留目录 —— §16.4 的坑)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$ErrorActionPreference = 'Continue'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$group = Get-Content "$base\User\ScriptGroup\钓鱼.json" -Raw -Encoding UTF8 | ConvertFrom-Json

$missing = @(); $copied = @(); $ok = 0
foreach ($p in $group.projects) {
  if ($p.type -ne 'Pathing') { continue }
  $rel = Join-Path $p.folderName $p.name
  $ap = Join-Path "$base\User\AutoPathing" $rel
  $mp = Join-Path "$base\User\MapPathing" $rel
  if (Test-Path $ap) { $ok++; continue }
  if (Test-Path $mp) {
    New-Item -ItemType Directory -Force -Path (Split-Path $ap) | Out-Null
    Copy-Item $mp $ap -Force
    $copied += $rel
  } else {
    $missing += $rel
  }
}
Write-Output "组内 Pathing 任务: 已存在 $ok 条, 从 MapPathing 补齐 $($copied.Count) 条, 仍缺失 $($missing.Count) 条"
$copied | ForEach-Object { Write-Output "  + $_" }
$missing | ForEach-Object { Write-Output "  ! 缺失: $_" }
