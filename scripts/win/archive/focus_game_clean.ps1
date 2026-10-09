$shell = New-Object -ComObject Shell.Application
$shell.MinimizeAll()
Start-Sleep -Seconds 1
$g = Get-Process YuanShen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($g) {
  $ws = New-Object -ComObject WScript.Shell
  [void]$ws.AppActivate($g.Id)
}
