# 游戏内点击: 以 1920x1080 客户区逻辑坐标点击 (自动按当前窗口矩形映射)
# 用法: powershell -File game_click.ps1 -X 960 -Y 540 [-Right]
param([double]$X = 960, [double]$Y = 540, [switch]$Right)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class GC {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte s, uint f, UIntPtr e);
  [DllImport("user32.dll")] public static extern bool SendInput(uint n, INPUT[] i, int cb);
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X, Y; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public MOUSEINPUT mi; }
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr ex; }
}
"@ -ReferencedAssemblies System.Drawing | Out-Null

$g = Get-Process YuanShen -ErrorAction SilentlyContinue
if (-not $g) { Write-Output 'GAME_NOT_RUNNING'; exit 1 }
$h = $g.MainWindowHandle
if ($h -eq 0) { Write-Output 'NO_WINDOW'; exit 1 }

[GC]::SetProcessDPIAware() | Out-Null
[GC]::SetForegroundWindow($h) | Out-Null
Start-Sleep -Milliseconds 400

$cr = New-Object GC+RECT
[GC]::GetClientRect($h, [ref]$cr) | Out-Null
$cw = $cr.Right - $cr.Left; $ch = $cr.Bottom - $cr.Top
# 逻辑 1920x1080 → 客户区像素
$cx = [int]($X / 1920.0 * $cw); $cy = [int]($Y / 1080.0 * $ch)
$pt = New-Object GC+POINT; $pt.X = $cx; $pt.Y = $cy
[GC]::ClientToScreen($h, [ref]$pt) | Out-Null

# SendInput 绝对坐标点击 (0-65535 归一化到主屏物理像素)
$sw = [GC]::GetSystemMetrics(0); $sh = [GC]::GetSystemMetrics(1)
$down = New-Object GC+INPUT; $up = New-Object GC+INPUT
$flagDown = 0x0002; $flagUp = 0x0004   # LEFTDOWN/UP
if ($Right) { $flagDown = 0x0008; $flagUp = 0x0010 }
$down.type = 0; $down.mi.dx = [int]($pt.X * 65535 / $sw); $down.mi.dy = [int]($pt.Y * 65535 / $sh); $down.mi.dwFlags = 0x8000 -bor $flagDown
$up.type = 0; $up.mi.dx = $down.mi.dx; $up.mi.dy = $down.mi.dy; $up.mi.dwFlags = 0x8000 -bor $flagUp
[GC]::SendInput(2, @($down, $up), [Runtime.InteropServices.Marshal]::SizeOf([type][GC+INPUT])) | Out-Null
Write-Output ("CLICKED client($cx,$cy) screen($($pt.X),$($pt.Y)) clientRect ${cw}x${ch}")
