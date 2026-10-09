[Console]::OutputEncoding = [Text.Encoding]::UTF8
Start-Sleep -Seconds 10
$game = @(Get-Process -Name YuanShen -ErrorAction SilentlyContinue)
$bgi = @(Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -match 'BetterGenshinImpact|BetterGI' })
$out = New-Object System.Collections.Generic.List[string]
$out.Add("TIME=$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$out.Add("YUANSHEN_COUNT=$($game.Count)")
$out.Add("BGI_COUNT=$($bgi.Count)")
if (($game.Count -eq 0) -and ($bgi.Count -eq 0)) {
  $state = @(
    'PHASE=OFFLINE'
    'ACTIVE_UNTIL='
  ) -join "`r`n"
  [IO.File]::WriteAllText('C:\Users\djf20\session_state.txt', $state + "`r`n", (New-Object Text.UTF8Encoding($false)))
  $out.Add('STATE_REWRITTEN=YES')
} else {
  $out.Add('STATE_REWRITTEN=NO')
  foreach ($p in ($game + $bgi)) { $out.Add("ALIVE=$($p.ProcessName) PID=$($p.Id)") }
}
$out.Add('---STATE---')
$out.AddRange([string[]](Get-Content 'C:\Users\djf20\session_state.txt' -ErrorAction SilentlyContinue))
[IO.File]::WriteAllLines('C:\Users\djf20\agent_offline_result.txt', $out, (New-Object Text.UTF8Encoding($false)))
$out