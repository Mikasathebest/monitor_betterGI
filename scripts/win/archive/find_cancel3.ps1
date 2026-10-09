# 找 CancellationContext.Cancel/ManualCancel 的全部调用点
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$src = 'D:\Projects\better-genshin-impact\BetterGenshinImpact'
Get-ChildItem $src -Recurse -Include '*.cs' | Select-String -Pattern 'CancellationContext\.Instance\.(ManualCancel|Cancel)\(\)' | ForEach-Object {
  Write-Output ($_.Path.Replace($src, '') + ':' + $_.LineNumber + ': ' + $_.Line.Trim())
}
