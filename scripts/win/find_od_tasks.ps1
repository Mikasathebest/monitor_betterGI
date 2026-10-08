# 在 BGI 源码里找一条龙任务 GUID 对应的任务类型名
$ErrorActionPreference = 'Continue'
$out = 'C:\Users\djf20\od_tasks_map.txt'
$guids = @('5d6fd5b4-4ec7-41ef-b30d-3854e835c491','7b2c7f0c-998b-4b82-8854-e33b84c500c7','26f3b2bf-9b17-4f4a-85b3-3e3aba6fa79a','ff718359-893f-4427-8e11-69842e99d436','a9c9a171-cc96-4404-a925-928641d69038','dab529e9-7ad8-46f2-ac10-d6031b4fa143','f605bbb8-df3d-4c75-9a89-8aa58fd27b9e','32c6e599-c2ce-4dcb-8e3f-c82d1f3cb8c5','8b5546af-93b3-4df0-a2cc-59effadcab9f')
$sb = New-Object System.Text.StringBuilder
foreach ($g in $guids) {
  $hits = Get-ChildItem 'D:\Projects\better-genshin-impact' -Recurse -Include '*.cs','*.json' -ErrorAction SilentlyContinue |
    Select-String -Pattern $g -List -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -notmatch 'bin\\|obj\\|User\\' } |
    Select-Object -First 2
  foreach ($h in $hits) { $sb.AppendLine("$g => $($h.Path.Replace('D:\Projects\better-genshin-impact\','')):$($h.LineNumber): $($h.Line.Trim())") | Out-Null }
  if (-not $hits) { $sb.AppendLine("$g => (源码未找到)") | Out-Null }
}
# 同时找一条龙任务类型注册处 (含"钓鱼"的一条龙任务定义)
$sb.AppendLine('--- 一条龙任务类型定义 ---') | Out-Null
Get-ChildItem 'D:\Projects\better-genshin-impact' -Recurse -Include '*.cs' -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -match 'OneDragon' -and $_.FullName -notmatch 'bin\\|obj\\' } |
  Select-String -Pattern '钓鱼|Fishing|采矿|Mining' -List -ErrorAction SilentlyContinue |
  ForEach-Object { $sb.AppendLine("$($_.Path.Replace('D:\Projects\better-genshin-impact\','')):$($_.LineNumber)") | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'MAP_OK'
