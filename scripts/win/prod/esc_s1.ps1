# Session 1: 激活游戏窗口按 ESC 关掉队伍配置界面, 然后截图
$ErrorActionPreference = 'Continue'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Fg {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int s);
}
"@
$p = Get-Process YuanShen -ErrorAction SilentlyContinue
if ($p) {
  [Fg]::ShowWindow($p.MainWindowHandle, 9) | Out-Null
  [Fg]::SetForegroundWindow($p.MainWindowHandle) | Out-Null
  Start-Sleep -Milliseconds 800
  $ws = New-Object -ComObject WScript.Shell
  $ws.SendKeys('{ESC}')
  Start-Sleep -Seconds 2
  Write-Output 'ESC_SENT'
} else { Write-Output 'NO_GAME' }
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\screen.ps1
Write-Output 'SHOT_DONE'
