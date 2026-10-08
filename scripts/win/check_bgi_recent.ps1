Start-Sleep -Seconds 10
Write-Output 'PROCESSES:'
Get-Process BetterGI,YuanShen -ErrorAction SilentlyContinue | ForEach-Object { Write-Output ($_.ProcessName + ' PID=' + $_.Id + ' START=' + $_.StartTime.ToString('yyyy-MM-dd HH:mm:ss')) }
$dir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
Write-Output 'LOGFILES:'
$files = Get-ChildItem -LiteralPath $dir -File | Sort-Object LastWriteTime -Descending | Select-Object -First 3
foreach ($f in $files) {
 Write-Output ('FILE=' + $f.FullName + ' WRITE=' + $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss'))
 try {
  $fs = New-Object System.IO.FileStream($f.FullName,[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::ReadWrite)
  $sr = New-Object System.IO.StreamReader($fs,[System.Text.Encoding]::UTF8,$true)
  $txt = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
  $lines = $txt -split "`r?`n"
  $lines | Select-Object -Last 30 | ForEach-Object { Write-Output $_ }
 } catch { Write-Output ('READERR ' + $_.Exception.Message) }
}
