# 按键原语 v4: PostMessage 直发游戏窗口消息队列 (BGI JS keyPress 同款路径, 免前台/免聚焦/反作弊不拦)
# 用法: powershell -File send_key.ps1 -Key M
# 背景: SendInput/keybd_event 对该游戏窗口全部无效 (09-15 实测), 唯 PostMessage 有效 (BGI 实证)
param([string]$Key = 'M')
$ErrorActionPreference = 'Stop'
$log = 'C:\Users\djf20\sendkey_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class PM {
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
}
"@
$vkMap = @{ 'J'=0x4A; 'ESC'=0x1B; 'F9'=0x78; 'ENTER'=0x0D; 'M'=0x4D; 'B'=0x42; 'F'=0x46; 'L'=0x4C; 'SPACE'=0x20 }
$vk = $vkMap[$Key.ToUpper()]
if (-not $vk) { $vk = [byte][char]$Key.ToUpper()[0] }
$g = Get-Process YuanShen -ErrorAction SilentlyContinue
if (-not $g -or $g.MainWindowHandle -eq 0) { Write-Output 'NO_GAME'; Log 'NO_GAME'; exit 1 }
$h = $g.MainWindowHandle
# BGI KeyPressBackground 配方: KEYDOWN + CHAR + KEYUP, lParam 固定 0x1e0001 / 0xc01e0001
[PM]::PostMessage($h, 0x100, [IntPtr]$vk, [IntPtr]0x1e0001) | Out-Null
[PM]::PostMessage($h, 0x102, [IntPtr]$vk, [IntPtr]0x1e0001) | Out-Null
[PM]::PostMessage($h, 0x101, [IntPtr]$vk, [IntPtr]0xc01e0001) | Out-Null
$msg = "KEY $Key vk=0x$('{0:X2}' -f $vk) posted to $h"
Write-Output $msg; Log $msg
