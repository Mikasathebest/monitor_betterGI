$target = 'C:\Users\djf20\agent_launch_game_s1.ps1'
$body = @'
$game = 'E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe'
if (-not (Get-Process YuanShen -ErrorAction SilentlyContinue)) {
    Start-Process -FilePath $game -WorkingDirectory (Split-Path $game)
}
'@
[IO.File]::WriteAllText($target, $body, [Text.Encoding]::Unicode)
& 'C:\Users\djf20\run_s1.ps1' -ScriptName 'agent_launch_game_s1.ps1'
