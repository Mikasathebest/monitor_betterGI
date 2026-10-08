Start-Sleep -Seconds 15
$dir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
$f = Get-ChildItem -LiteralPath $dir -File -Filter '*.log' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if (-not $f) { Write-Output 'NO_LOG'; exit }
Write-Output ('FILE=' + $f.FullName)
Write-Output ('WRITE=' + $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
$fs = New-Object System.IO.FileStream($f.FullName,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
$sr = New-Object System.IO.StreamReader($fs,[System.Text.Encoding]::UTF8,$true)
$txt=$sr.ReadToEnd(); $sr.Close(); $fs.Close()
$lines=$txt -split "`r?`n"
Write-Output 'MATCHES:'
$lines | Where-Object { $_ -match '一条龙|合成台|树脂|树脂|OneDragon|commission|Resin|Craft' } | Select-Object -Last 30
Write-Output 'TAIL:'
$lines | Select-Object -Last 80
