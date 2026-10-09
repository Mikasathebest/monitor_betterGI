# 全屏截图 (物理像素, 含光标) —— 两大原语之一
# 输出: C:\Users\djf20\screen.png, 尺寸 = 虚拟屏幕物理像素, 与 mouse.ps1 坐标 1:1
# 教训: 必须先 SetProcessDPIAware 再用 GetSystemMetrics 取虚拟屏幕;
#       用 SystemInformation.VirtualScreen 且不感知 DPI → 只拍到左上 2/3 (09-15 事故)
$ErrorActionPreference = 'Stop'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Cap {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int n);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetCursor();
  [DllImport("user32.dll")] public static extern bool DrawIcon(IntPtr hdc, int x, int y, IntPtr hIcon);
  public struct POINT { public int X; public int Y; }
}
"@
Add-Type -AssemblyName System.Drawing
[Cap]::SetProcessDPIAware() | Out-Null
# 虚拟屏幕原点与尺寸 (多显示器时原点可为负; 单显示器 = 0,0,2560,1600)
$vx = [Cap]::GetSystemMetrics(76); $vy = [Cap]::GetSystemMetrics(77)
$vw = [Cap]::GetSystemMetrics(78); $vh = [Cap]::GetSystemMetrics(79)
$bmp = New-Object System.Drawing.Bitmap $vw, $vh
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($vx, $vy, 0, 0, $bmp.Size)
# 画上光标 (截图里能看到鼠标在哪, 便于验证点击落点)
$p = New-Object Cap+POINT
[Cap]::GetCursorPos([ref]$p) | Out-Null
$hdc = $g.GetHdc()
[Cap]::DrawIcon($hdc, ($p.X - $vx), ($p.Y - $vy), [Cap]::GetCursor()) | Out-Null
$g.ReleaseHdc($hdc); $g.Dispose()
$bmp.Save('C:\Users\djf20\screen.png', [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "SHOT ${vw}x${vh} origin($vx,$vy) cursor($($p.X),$($p.Y))"
