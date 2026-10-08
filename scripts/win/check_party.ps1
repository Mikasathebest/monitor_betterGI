# 列出所有 ScriptGroup 的 partyName + 游戏内当前队伍相关配置
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\User'
$out = 'C:\Users\djf20\party_list.txt'
$sb = New-Object System.Text.StringBuilder
foreach ($f in Get-ChildItem "$base\ScriptGroup" -Filter *.json) {
  try {
    $j = Get-Content $f.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
    $pn = $j.config.pathingConfig.partyName
    $sb.AppendLine($f.Name + '  partyName=[' + $pn + ']  tasks=' + $j.projects.Count) | Out-Null
  } catch { $sb.AppendLine($f.Name + '  PARSE_FAIL') | Out-Null }
}
# 一条龙配置的队伍字段
$sb.AppendLine('=== OneDragon 默认配置 ===') | Out-Null
$od = Get-Content "$base\OneDragon\默认配置.json" -Raw -Encoding UTF8 | ConvertFrom-Json
$od.PSObject.Properties | Where-Object { $_.Name -match 'Party' } | ForEach-Object { $sb.AppendLine($_.Name + ' = ' + $_.Value) | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'LIST_OK'
