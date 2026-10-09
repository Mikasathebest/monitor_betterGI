# 鼠标原语 v3: 移动光标到屏幕物理像素坐标 (与 screen.ps1 截图 1:1) 并点击
# 用法: powershell -File mouse.ps1 -X 1280 -Y 800 [-Right] [-MoveOnly]
# 铁律1: SetProcessDPIAware —— 否则坐标被缩放点歪
# 铁律2: INPUT 显式 40 字节 —— 否则 SendInput 静默失败
# 铁律3: 点击前用 Alt+AttachThreadInput 把目标窗口置前台 —— 原神 raw input 只收前台窗口的输入 (09-15 实证)
# 铁律4: down/up 分两次 SendInput 间隔 120ms —— 瞬时 down+up 游戏可能不识别
param([int]$X = 0, [int]$Y = 0, [switch]$Right, [switch]$MoveOnly)
$ErrorActionPreference = 'Stop'
$log = 'C:\Users\djf20\mouse_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class M {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size=40)] public struct INPUTUNION { [FieldOffset(0)] public MOUSEINPUT mi; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION u; }
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
  [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p);
  [DllImport("user32.dll")] public static extern IntPtr WindowFromPoint(POINT p);
  [DllImport("user32.dll")] public static extern IntPtr GetAncestor(IntPtr h, uint flags);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] p, int cb);
  public static void Foreground(IntPtr h) {
    uint dummy;
    uint fgT = GetWindowThreadProcessId(GetForegroundWindow(), out dummy);
    uint myT = GetCurrentThreadId();
    keybd_event(0x12, 0, 0, UIntPtr.Zero);   // Alt 满足前台锁
    AttachThreadInput(myT, fgT, true);
    ShowWindow(h, 9);                         // SW_RESTORE
    SetForegroundWindow(h);
    AttachThreadInput(myT, fgT, false);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
  }
}
"@
[M]::SetProcessDPIAware() | Out-Null
# 1. 找到目标坐标下的窗口并置前台
$pt = New-Object M+POINT; $pt.X = $X; $pt.Y = $Y
$hw = [M]::WindowFromPoint($pt)
if ($hw -ne [IntPtr]::Zero) {
  $root = [M]::GetAncestor($hw, 2)   # GA_ROOT
  [M]::Foreground($root)
  Start-Sleep -Milliseconds 600
}
# 2. 移动光标并验证
[M]::SetCursorPos($X, $Y) | Out-Null
Start-Sleep -Milliseconds 200
$p = New-Object M+POINT
[M]::GetCursorPos([ref]$p) | Out-Null
if ($p.X -ne $X -or $p.Y -ne $Y) { $m = "MOVE_FAIL want($X,$Y) got($($p.X),$($p.Y))"; Write-Output $m; Log $m; exit 1 }
if ($MoveOnly) { Write-Output "MOVED ($X,$Y)"; Log "MOVED ($X,$Y)"; exit 0 }
# 3. 点击 (down/up 分开, 间隔 120ms)
$flagDown = 0x2; $flagUp = 0x4
if ($Right) { $flagDown = 0x8; $flagUp = 0x10 }
$sz = [Runtime.InteropServices.Marshal]::SizeOf([type][M+INPUT])
$down = New-Object M+INPUT; $down.type = 0; $down.u.mi.dwFlags = $flagDown
$up = New-Object M+INPUT; $up.type = 0; $up.u.mi.dwFlags = $flagUp
$s1 = [M]::SendInput(1, @($down), $sz)
Start-Sleep -Milliseconds 120
$s2 = [M]::SendInput(1, @($up), $sz)
$fg = [M]::GetForegroundWindow()
$m = "CLICKED ($X,$Y)$(if($Right){' right'}) sent=$s1/$s2 size=$sz fg=$fg targetRoot=$root"
Write-Output $m; Log $m
