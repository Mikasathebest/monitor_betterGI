# 查 JS 脚本设置持久化方式 + 大组钓鱼段起始索引
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'

Write-Output '=== 树脂监控 文件夹内容 (看设置存哪) ==='
Get-ChildItem "$base\User\JsScript\树脂监控" | Select-Object Name, Length
Write-Output '--- 其 settings.json 内容 ---'
Get-Content "$base\User\JsScript\树脂监控\settings.json" -Raw -Encoding UTF8

Write-Output '=== 全自动循环.json: 树脂监控条目 schema + 钓鱼段位置 ==='
$g = Get-Content "$base\User\ScriptGroup\全自动循环.json" -Raw -Encoding UTF8 | ConvertFrom-Json
Write-Output ('总任务数: ' + $g.projects.Count)
for ($i = 0; $i -lt $g.projects.Count; $i++) {
  $p = $g.projects[$i]
  if ($p.type -eq 'Javascript' -and $i -lt 20) {
    Write-Output ("JS 条目示例 idx ${i}: " + ($p | ConvertTo-Json -Compress -Depth 3))
  }
  if ($p.name -match '钓鱼' -and $p.type -eq 'Pathing') {
    Write-Output ("首条钓鱼路线 idx: $i = $($p.folderName)\$($p.name)")
    break
  }
}
