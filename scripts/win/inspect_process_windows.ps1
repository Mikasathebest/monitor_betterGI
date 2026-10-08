$out = @()
Get-Process | Where-Object { $_.MainWindowHandle -ne 0 } | ForEach-Object {
  $out += ($_.Id.ToString() + '|' + $_.ProcessName + '|' + $_.MainWindowHandle.ToString() + '|' + $_.MainWindowTitle)
}
$out | Set-Content -LiteralPath 'C:\Users\djf20\visible_windows.txt' -Encoding UTF8
$out
