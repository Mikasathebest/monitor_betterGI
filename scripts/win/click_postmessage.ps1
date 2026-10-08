# click_postmessage.ps1 - click via PostMessage (bypass input queue)
param(
  [int]$GameX = 1640,
  [int]$GameY = 928
)
$csharp = @'
using System;
using System.Runtime.InteropServices;
public class PMC {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  public const uint WM_LBUTTONDOWN = 0x0201;
  public const uint WM_LBUTTONUP = 0x0202;
  public const uint WM_MOUSEMOVE = 0x0200;
  public static void ClickClient(IntPtr h, int x, int y) {
    IntPtr l = (IntPtr)((y << 16) | (x & 0xFFFF));
    PostMessage(h, WM_MOUSEMOVE, IntPtr.Zero, l);
    System.Threading.Thread.Sleep(100);
    PostMessage(h, WM_LBUTTONDOWN, (IntPtr)1, l);
    System.Threading.Thread.Sleep(80);
    PostMessage(h, WM_LBUTTONUP, IntPtr.Zero, l);
  }
}
'@
if (-not ("PMC" -as [type])) { Add-Type -TypeDefinition $csharp }
$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
if (-not $ys) { Write-Output "game not running"; exit 1 }
[PMC]::ShowWindow($ys.MainWindowHandle, 9) | Out-Null
[PMC]::SetForegroundWindow($ys.MainWindowHandle) | Out-Null
Start-Sleep 1
$r = New-Object PMC+RECT
[PMC]::GetClientRect($ys.MainWindowHandle, [ref]$r) | Out-Null
$cx = [int]($GameX * $r.Right / 1920)
$cy = [int]($GameY * $r.Bottom / 1080)
Write-Output "PostMessage click client: ($cx, $cy)"
[PMC]::ClickClient($ys.MainWindowHandle, $cx, $cy)
Write-Output "done"
