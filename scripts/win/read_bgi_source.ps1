# 提取 BGI 源码关键片段
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'

function Show-Match($file, $pattern, $ctx = 6) {
  Write-Output "===== $file :: $pattern ====="
  Get-Content "$src\$file" -Encoding UTF8 | Select-String -Pattern $pattern -Context $ctx | Select-Object -First 4 | ForEach-Object {
    $_.Context.PreContext; $_.Line; $_.Context.PostContext; Write-Output '  ---'
  }
}

Show-Match 'GameTask\Common\Job\GoToCraftingBenchTask.cs' 'MinResinToKeep' 8
Show-Match 'GameTask\AutoLeyLineOutcrop\AutoLeyLineOutcropTask.cs' '浓缩树脂|CondensedResin' 4
Show-Match 'GameTask\AutoLeyLineOutcrop\AutoLeyLineOutcropTask.cs' 'ScanDropsAfterReward' 6
Show-Match 'GameTask\AutoFishing\Behaviours.cs' '鱼饵' 5
