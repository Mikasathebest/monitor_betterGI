$procs = Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'"
$matches = @($procs | Where-Object { $_.CommandLine -match 'door_clicker2' -and $_.CommandLine -notmatch 'agent_stop_clicker2' })
foreach ($p in $matches) {
  try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; Write-Output ("STOPPED door_clicker2 PID=" + $p.ProcessId) }
  catch { Write-Output ("FAILED PID=" + $p.ProcessId + " " + $_.Exception.Message) }
}
if ($matches.Count -eq 0) { Write-Output 'NO door_clicker2 process found' }
Write-Output 'POWERSHELL PROCESSES:'
Get-CimInstance Win32_Process -Filter "Name='powershell.exe' OR Name='pwsh.exe'" | ForEach-Object { Write-Output (($_.ProcessId.ToString()) + " | " + $_.CommandLine) }
