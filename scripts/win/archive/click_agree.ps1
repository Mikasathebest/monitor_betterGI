# click_agree.ps1 - click the agree button on Genshin privacy popup
param(
  [int]$GameX = 1327,
  [int]$GameY = 792
)
$csharp = @'
using System;
using System.Runtime.InteropServices;
public class Door2 {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size=40)] public struct INPUTUNION { [FieldOffset(0)] public MOUSEINPUT mi; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION u; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] p, int cb);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public static void Click(int x, int y) {
    SetCursorPos(x, y);
    System.Threading.Thread.Sleep(300);
    int sz = Marshal.SizeOf(typeof(INPUT));
    INPUT down = new INPUT(); down.type = 0; down.u.mi.dwFlags = 0x2;
    INPUT up   = new INPUT(); up.type = 0;   up.u.mi.dwFlags = 0x4;
    SendInput(1, new INPUT[] { down }, sz);
    System.Threading.Thread.Sleep(120);
    SendInput(1, new INPUT[] { up }, sz);
  }
}
'@
if (-not ("Door2" -as [type])) { Add-Type -TypeDefinition $csharp }
[Door2]::SetProcessDPIAware() | Out-Null
$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
if (-not $ys) { Write-Output "game not running"; exit 1 }
[Door2]::ShowWindow($ys.MainWindowHandle, 9) | Out-Null
[Door2]::SetForegroundWindow($ys.MainWindowHandle) | Out-Null
Start-Sleep 2
$r = New-Object Door2+RECT
[Door2]::GetClientRect($ys.MainWindowHandle, [ref]$r) | Out-Null
$origin = New-Object Door2+RECT
[Door2]::ClientToScreen($ys.MainWindowHandle, [ref]$origin) | Out-Null
Write-Output "client: $($r.Right)x$($r.Bottom) origin: ($($origin.Left),$($origin.Top))"
$cx = $origin.Left + [int]($GameX * $r.Right / 1920)
$cy = $origin.Top + [int]($GameY * $r.Bottom / 1080)
Write-Output "click: ($cx, $cy)"
[Door2]::Click($cx, $cy)
Write-Output "clicked"
