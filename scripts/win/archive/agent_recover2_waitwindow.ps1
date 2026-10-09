Start-Sleep -Seconds 90
$p=Get-Process YuanShen -ErrorAction SilentlyContinue
if($p){$p.Refresh(); $p | Select-Object Id,SessionId,StartTime,Responding,MainWindowHandle,MainWindowTitle,CPU,WorkingSet64 | Format-List}else{'NO_GAME'}
