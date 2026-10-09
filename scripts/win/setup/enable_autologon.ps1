# 开启 Windows 自动登录 (防重启后无人登录 Session 1 → 计划任务全瘫)
# 用法: 在 Windows 机上【右键→使用 PowerShell 以管理员运行】, 按提示输入开机密码
# 密码写入 HKLM Winlogon\DefaultPassword (明文, 仅本机管理员可读; 家庭游戏机可接受)
#Requires -RunAsAdministrator
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'

$pw = Read-Host '请输入 djf20 的开机密码' -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($pw))
if ([string]::IsNullOrEmpty($plain)) { Write-Output '密码为空, 取消'; exit 1 }

Set-ItemProperty -Path $key -Name 'AutoAdminLogon' -Value '1'
Set-ItemProperty -Path $key -Name 'DefaultUserName' -Value 'djf20'
Set-ItemProperty -Path $key -Name 'DefaultDomainName' -Value 'HARRY-WIN11'
Set-ItemProperty -Path $key -Name 'DefaultPassword' -Value $plain
$plain = $null; $pw = $null

$v = Get-ItemProperty -Path $key
Write-Output ('AutoAdminLogon = ' + $v.AutoAdminLogon)
Write-Output ('DefaultUserName = ' + $v.DefaultUserName)
Write-Output ('DefaultPassword 已写入 = ' + [bool]$v.DefaultPassword)
Write-Output '完成。下次重启将自动登录 djf20 进桌面, BGI_ResumeAtLogon 会自动拉起上线流程。'
Read-Host '按回车关闭'
