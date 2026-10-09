$log='C:\Users\djf20\game_launch_monitor.txt'
function Log($m){"$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $m"|Out-File $log -Append -Encoding utf8}
$exe='E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe'
Stop-Process -Name YuanShen -Force -ErrorAction SilentlyContinue
Start-Sleep 10
try{$p=Start-Process -FilePath $exe -WorkingDirectory (Split-Path $exe) -PassThru;Log "START pid=$($p.Id)"}catch{Log "START_ERROR $($_.Exception.Message)";exit 1}
for($i=1;$i -le 60;$i++){Start-Sleep 5;$q=Get-Process -Id $p.Id -ErrorAction SilentlyContinue;if(-not $q){Log "EXIT after=$($i*5)s";exit 2};if(($i%6)-eq 0){Log "ALIVE after=$($i*5)s responding=$($q.Responding) cpu=$($q.CPU)"}}
Log 'ALIVE_300S'