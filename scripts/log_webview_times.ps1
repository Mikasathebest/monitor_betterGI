# Print timestamp + instance + page of each webview URL line in the Unity player log.
# Authkey is NOT printed (sensitive). Pure ASCII; game dir resolved via wildcard.
$log = Get-ChildItem "$env:USERPROFILE\AppData\LocalLow\miHoYo\*\output_log.txt" |
       Select-Object -First 1 -ExpandProperty FullName
Select-String -Path $log -Pattern 'web: \d+ url:' | ForEach-Object {
    $line = $_.Line
    $ts   = $line.Substring(1, 23)
    $inst = ([regex]::Match($line, 'web: \d+')).Value
    $page = ([regex]::Match($line, 'event/[^/]+/')).Value
    $init = ([regex]::Match($line, 'init_type=\d+')).Value
    "$ts  $inst  $page  $init"
}
