param([int]$X = 960, [int]$Y = 540)
Add-Type @"
using System;using System.Runtime.InteropServices;
public class PMClk {
  [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct POINT { public int X; public int Y; }
}
"@
$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
if (-not $ys) { Write-Output "game not running"; exit 1 }
$h = $ys.MainWindowHandle
[PMClk]::SetProcessDPIAware() | Out-Null
[PMClk]::ShowWindow($h, 9) | Out-Null
[PMClk]::SetForegroundWindow($h) | Out-Null
$pt = New-Object PMClk+POINT; $pt.X = $X; $pt.Y = $Y
[PMClk]::ClientToScreen($h, [ref]$pt) | Out-Null
[PMClk]::SetCursorPos($pt.X, $pt.Y) | Out-Null
Start-Sleep -Milliseconds 600
$lp = [IntPtr](($Y -shl 16) -bor $X)
[PMClk]::PostMessage($h, 0x201, [IntPtr]1, $lp) | Out-Null
Start-Sleep -Milliseconds 100
[PMClk]::PostMessage($h, 0x202, [IntPtr]0, $lp) | Out-Null
Write-Output "clicked client ($X,$Y) screen ($($pt.X),$($pt.Y))"