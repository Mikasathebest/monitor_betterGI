# 一次性加固 (需管理员): 禁止 Windows Update 在有登录会话时自动重启
# Session 1 常开 → 此键生效后更新只下载安装不重启, 避免半个月无人期间重启后无人登录导致全线停摆
$ErrorActionPreference = 'Stop'
$key = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1 -Type DWord
$v = Get-ItemProperty -Path $key -Name 'NoAutoRebootWithLoggedOnUsers'
"RESULT: NoAutoRebootWithLoggedOnUsers = $($v.NoAutoRebootWithLoggedOnUsers)"
