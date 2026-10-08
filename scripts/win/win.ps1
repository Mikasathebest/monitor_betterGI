# 窗口管理原语: 按进程名最小化/置前窗口
# 用法: powershell -File win.ps1 -Name BetterGI -Minimize   或   -Name YuanShen -Foreground
param([string]$Name = 'BetterGI', [switch]$Minimize, [switch]$Foreground)
$ErrorActionPreference = 'Continue'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WN {
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  public static void ForegroundIt(IntPtr h) {
    uint dummy;
    uint fgT = GetWindowThreadProcessId(GetForegroundWindow(), out dummy);
    uint myT = GetCurrentThreadId();
    keybd_event(0x12, 0, 0, UIntPtr.Zero);
    AttachThreadInput(myT, fgT, true);
    ShowWindow(h, 9);
    SetForegroundWindow(h);
    AttachThreadInput(myT, fgT, false);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
  }
}
"@
$p = Get-Process -Name $Name -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
if (-not $p) { Write-Output "NO_WINDOW $Name"; exit 1 }
if ($Minimize) { [WN]::ShowWindow($p.MainWindowHandle, 6) | Out-Null; Write-Output "MINIMIZED $Name ($($p.MainWindowHandle))" }
if ($Foreground) { [WN]::ForegroundIt($p.MainWindowHandle); Write-Output "FOREGROUNDED $Name ($($p.MainWindowHandle))" }
