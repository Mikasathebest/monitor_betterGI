# 进门: 游戏置前台 + ClientToScreen 测客户区中心 + SetCursorPos 移真实光标 + PostMessage 点击
# 2026-09-26 改版: 7.1 门场景下 SendInput 两次点击无效(窗口已前台仍不开门), PostMessage 一次即成
# Unity 按真实光标位置命中 UI, 故 PostMessage 前必须 SetCursorPos 到目标点
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Door {
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  [DllImport("user32.dll")] public static extern IntPtr PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref POINT p);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
if (-not $ys) { Log "进门: 游戏未运行"; exit 1 }
[Door]::SetProcessDPIAware() | Out-Null
$hwnd = $ys.MainWindowHandle
if ($hwnd -eq 0) { Log "进门: MainWindowHandle=0, 放弃"; exit 1 }
[Door]::ShowWindow($hwnd, 9) | Out-Null
[Door]::SetForegroundWindow($hwnd) | Out-Null
$rc = New-Object Door+RECT
[Door]::GetClientRect($hwnd, [ref]$rc) | Out-Null
$cx = [int](($rc.Right - $rc.Left) / 2); $cy = [int](($rc.Bottom - $rc.Top) / 2)
$pt = New-Object Door+POINT; $pt.X = $cx; $pt.Y = $cy
[Door]::ClientToScreen($hwnd, [ref]$pt) | Out-Null
[Door]::SetCursorPos($pt.X, $pt.Y) | Out-Null
Start-Sleep -Milliseconds 500
$lp = [IntPtr](($cy -shl 16) -bor $cx)
[Door]::PostMessage($hwnd, 0x201, [IntPtr]1, $lp) | Out-Null
Start-Sleep -Milliseconds 100
[Door]::PostMessage($hwnd, 0x202, [IntPtr]0, $lp) | Out-Null
Log "进门: 已PostMessage点击客户区中心($cx,$cy) 屏幕($($pt.X),$($pt.Y))"