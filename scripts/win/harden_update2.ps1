# Windows Update 加固 v2: 托管期间彻底禁止自动安装/重启
# 背景: NoAutoRebootWithLoggedOnUsers=1 挡不住"更新截止期限"强制重启 (09-15 04:14 实证)
# 恢复方法: AUOptions 删回默认 + 启用 Reboot 任务 (见 bgi_autopilot.md)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
if (-not (Test-Path $au)) { New-Item -Path $au -Force | Out-Null }
# AUOptions: 2=仅通知不自动下载安装 (托管期最稳); 原值备份
$old = (Get-ItemProperty -Path $au -Name AUOptions -ErrorAction SilentlyContinue).AUOptions
Set-ItemProperty -Path $au -Name 'AUOptions' -Value 2 -Type DWord
Set-ItemProperty -Path $au -Name 'NoAutoRebootWithLoggedOnUsers' -Value 1 -Type DWord
Set-ItemProperty -Path $au -Name 'NoAutoUpdate' -Value 0 -Type DWord
Write-Output "AUOptions: $old -> 2 (仅通知)"
# 禁用 UpdateOrchestrator 的重启任务 (双保险)
$t = Get-ScheduledTask -TaskPath '\Microsoft\Windows\UpdateOrchestrator\' -TaskName 'Reboot' -ErrorAction SilentlyContinue
if ($t) { Disable-ScheduledTask -TaskPath '\Microsoft\Windows\UpdateOrchestrator\' -TaskName 'Reboot' | Out-Null; Write-Output 'Reboot 任务已禁用' }
else { Write-Output 'Reboot 任务不存在(可能已禁)' }
Write-Output 'UPDATE_HARDENED_V2'
