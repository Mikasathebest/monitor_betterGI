# 导出 hangout.json 中 6 个目标角色的结局名+选项关键词 (UTF8 落盘, 避免 SSH 控制台乱码)
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\GameTask\AutoSkip\Assets\hangout.json'
$j = Get-Content $src -Raw -Encoding UTF8 | ConvertFrom-Json
$chars = @('久岐忍', '琳妮特', '凯亚', '鹿野院平藏', '凝光', '云堇')
$out = @{}
foreach ($c in $chars) {
  $entries = @{}
  foreach ($p in $j.PSObject.Properties) {
    if ($p.Name -like "$c*") { $entries[$p.Name] = $p.Value }
  }
  $out[$c] = $entries
}
$json = $out | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText('C:\Users\djf20\hangout_endings.json', $json, (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'DUMPED'
