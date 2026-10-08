# Windows Update 加固 v3: 托管期直接停用更新服务 (AUOptions=2 之上再加一层)
# 恢复方法(回来后): sc.exe config wuauserv start= demand; sc.exe config UsoSvc start= demand; 删 AUOptions
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
foreach ($svc in 'wuauserv', 'UsoSvc') {
  Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
  & sc.exe config $svc start= disabled | Out-Null
  $s = Get-Service $svc
  Write-Output "$svc : $($s.Status) / starttype 已设 disabled"
}
# WaaSMedicSvc (更新医生, 会复活 wuauserv) 受保护, 尝试注册表禁用
$wm = 'HKLM:\SYSTEM\CurrentControlSet\Services\WaaSMedicSvc'
try {
  $old = (Get-ItemProperty $wm -Name Start).Start
  Set-ItemProperty $wm -Name Start -Value 4 -ErrorAction Stop
  Write-Output "WaaSMedicSvc Start: $old -> 4 (disabled)"
} catch { Write-Output 'WaaSMedicSvc 受保护改不动(可接受, AUOptions=2 已兜底)' }
Write-Output 'UPDATE_HARDENED_V3'
