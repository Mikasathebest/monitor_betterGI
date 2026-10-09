$out='C:\Users\djf20\diag_killers.txt'; $x=New-Object System.Collections.Generic.List[string]; function A($s){$x.Add([string]$s)}
A '=== references session_online / Stop-Process powershell / task stop ==='
Get-ChildItem C:\Users\djf20 -File -Include *.ps1,*.py,*.bat,*.cmd,*.vbs -ErrorAction SilentlyContinue | ForEach-Object { try { Select-String -Path $_.FullName -Pattern 'session_online|Stop-Process.+powershell|taskkill.+powershell|schtasks.+/end|Stop-ScheduledTask' -Encoding UTF8 -ErrorAction SilentlyContinue | ForEach-Object { A ("{0}:{1}: {2}" -f $_.Path,$_.LineNumber,$_.Line.Trim()) } } catch{} }
A '=== all scheduled task actions mentioning powershell/scripts ==='
Get-ScheduledTask | ForEach-Object { $t=$_; foreach($a in $t.Actions){ if(($a.Execute+' '+$a.Arguments) -match 'powershell|djf20|BetterGI'){ A ("{0}{1} => {2} {3} State={4}" -f $t.TaskPath,$t.TaskName,$a.Execute,$a.Arguments,$t.State) } } }
A '=== PowerShell Operational events around incidents ==='
$times=@([datetime]'2026-09-15 10:30:00',[datetime]'2026-09-15 22:30:00')
foreach($tt in $times){ try { Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational';StartTime=$tt.AddMinutes(-2);EndTime=$tt.AddMinutes(15)} -ErrorAction Stop | Sort-Object TimeCreated | ForEach-Object { $m=(($_.Message -replace "`r?`n",' ') -replace '\s+',' '); if($m.Length -gt 700){$m=$m.Substring(0,700)}; A ("{0:yyyy-MM-dd HH:mm:ss.fff} ID={1} {2}" -f $_.TimeCreated,$_.Id,$m) } } catch {A "PSLOG ERR $_"} }
A '=== Security process events around incidents ==='
foreach($tt in $times){ try { Get-WinEvent -FilterHashtable @{LogName='Security';Id=4688,4689;StartTime=$tt.AddMinutes(-2);EndTime=$tt.AddMinutes(15)} -ErrorAction Stop | Sort-Object TimeCreated | ForEach-Object { $m=(($_.Message -replace "`r?`n",' ') -replace '\s+',' '); if($m -match 'powershell|schtasks|BetterGI|YuanShen|wscript|cmd.exe'){ A ("{0:yyyy-MM-dd HH:mm:ss.fff} ID={1} {2}" -f $_.TimeCreated,$_.Id,$m) } } } catch {A "SEC ERR $_"} }
$x | Set-Content $out -Encoding UTF8
