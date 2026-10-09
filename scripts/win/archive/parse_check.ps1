# 解析检查: 用 PSParser 报告 ps1 的真实语法错误 (不执行)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$files = @('C:\Users\djf20\watchdog.ps1', 'C:\Users\djf20\session_online.ps1', 'C:\Users\djf20\cycle_offline.ps1', 'C:\Users\djf20\enter_door.ps1')
foreach ($f in $files) {
  $errs = $null
  $tokens = [System.Management.Automation.PSParser]::Tokenize((Get-Content $f -Raw -Encoding UTF8), [ref]$errs)
  $size = (Get-Item $f).Length
  if ($errs -and $errs.Count -gt 0) {
    Write-Output ("FAIL " + $f + " (" + $size + "B)")
    $errs | Select-Object -First 3 | ForEach-Object { Write-Output ("  行" + $_.Token.StartLine + ": " + $_.Message) }
  } else {
    Write-Output ("OK   " + $f + " (" + $size + "B, tokens=" + $tokens.Count + ")")
  }
}
