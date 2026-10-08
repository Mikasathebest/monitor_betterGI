# List miHoYo local files modified within the last N minutes (default 15).
# Pure ASCII only - PS 5.1 misreads UTF-8-no-BOM as GBK.
param([int]$Minutes = 15)
$roots = @(
    "$env:USERPROFILE\AppData\LocalLow\miHoYo",
    "$env:USERPROFILE\AppData\Local\miHoYo",
    "$env:USERPROFILE\AppData\Roaming\miHoYo"
)
$cutoff = (Get-Date).AddMinutes(-$Minutes)
foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    Get-ChildItem -Recurse -File $root -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $cutoff } |
        ForEach-Object { "{0:HH:mm:ss}  {1,10}  {2}" -f $_.LastWriteTime, $_.Length, $_.FullName }
}
