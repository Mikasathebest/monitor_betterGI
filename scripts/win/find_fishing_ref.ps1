# 找"钓鱼"配置组的挂载点: 主 config.json + User 目录小文件全扫
$ErrorActionPreference = 'Continue'
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$out = 'C:\Users\djf20\fishing_ref.txt'
$sb = New-Object System.Text.StringBuilder

# 1. 主 config.json 里所有含 钓鱼/组/Group 的行
$cfg = "$base\config.json"
if (Test-Path $cfg) {
  $sb.AppendLine('=== config.json 相关行 ===') | Out-Null
  $raw = [System.IO.File]::ReadAllText($cfg, [Text.Encoding]::UTF8)
  foreach ($ln in ($raw -split "`r?`n")) {
    if ($ln -match '钓鱼|采矿|Group|一条龙') { $sb.AppendLine($ln.Trim()) | Out-Null }
  }
}

# 2. User 目录下 <100KB 的 json 里含 "钓鱼" 的文件 (排除路线文件本身)
$sb.AppendLine('=== User 下引用钓鱼的文件 ===') | Out-Null
Get-ChildItem "$base\User" -Recurse -Filter '*.json' -ErrorAction SilentlyContinue |
  Where-Object { $_.Length -lt 100000 -and $_.FullName -notmatch 'AutoPathing' } |
  Select-String -Pattern '钓鱼' -List -ErrorAction SilentlyContinue |
  ForEach-Object { $sb.AppendLine($_.Path.Replace($base, '')) | Out-Null }
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'REF_OK'
