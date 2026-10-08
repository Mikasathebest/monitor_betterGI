# 点击守护进程: 常驻 Session 1, 监视 C:\Users\djf20\click_cmd.txt (内容 "X,Y" 或 "X,Y,right"), 收到即点
# 结果写 C:\Users\djf20\mouse_log.txt; 用 screen.ps1 截图可看到光标落点
# 启动: schtasks /run /tn BGI_Clickd; 停止: echo quit > click_cmd.txt
# 铁律: INPUT 构造必须在 C# 里完成 —— PowerShell 嵌套 struct 赋值静默无效, 会发全零结构 (09-15 事故)
$ErrorActionPreference = 'Continue'
$cmdFile = 'C:\Users\djf20\click_cmd.txt'
$log = 'C:\Users\djf20\mouse_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Threading;
public class M {
  [StructLayout(LayoutKind.Sequential)] public struct POINT { public int X; public int Y; }
  [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx; public int dy; public uint mouseData; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  // INPUT = type(4) + 对齐(4) + MOUSEINPUT(32) = 40 字节; 不能再套 Size=40 的 union (会变 48 → error 87)
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public MOUSEINPUT mi; }
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
    keybd_event(0x12, 0, 0, UIntPtr.Zero);
    AttachThreadInput(myT, fgT, true);
    ShowWindow(h, 9);
    SetForegroundWindow(h);
    AttachThreadInput(myT, fgT, false);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
  }
  // 完整点击: 移光标 → 验证 → down/up 分两次发 (全在 C#, PS 只传坐标)
  public static string ClickAt(int x, int y, bool right) {
    SetCursorPos(x, y);
    Thread.Sleep(200);
    POINT p; GetCursorPos(out p);
    if (p.X != x || p.Y != y) return "MOVE_FAIL got(" + p.X + "," + p.Y + ")";
    INPUT down = new INPUT(); down.type = 0; down.mi.dwFlags = right ? 0x8u : 0x2u;
    INPUT up = new INPUT(); up.type = 0; up.mi.dwFlags = right ? 0x10u : 0x4u;
    int sz = Marshal.SizeOf(typeof(INPUT));
    uint s1 = SendInput(1, new INPUT[] { down }, sz);
    int e1 = Marshal.GetLastWin32Error();
    Thread.Sleep(120);
    uint s2 = SendInput(1, new INPUT[] { up }, sz);
    int e2 = Marshal.GetLastWin32Error();
    return "sent=" + s1 + "/" + s2 + " err=" + e1 + "/" + e2;
  }
}
"@
[M]::SetProcessDPIAware() | Out-Null
Log "clickd 启动 (PID $PID, session $((Get-Process -Id $PID).SessionId))"
while ($true) {
  try {
    if (Test-Path $cmdFile) {
      $cmd = (Get-Content $cmdFile -Raw -Encoding UTF8).Trim()
      Remove-Item $cmdFile -Force -ErrorAction SilentlyContinue
      if ($cmd -eq 'quit') { Log 'clickd 收到 quit, 退出'; break }
      $parts = $cmd -split ','
      $X = [int]$parts[0]; $Y = [int]$parts[1]
      $right = ($parts.Count -gt 2 -and $parts[2] -eq 'right')
      # 置前台目标坐标下的窗口
      $pt = New-Object M+POINT; $pt.X = $X; $pt.Y = $Y
      $hw = [M]::WindowFromPoint($pt)
      if ($hw -ne [IntPtr]::Zero) { [M]::Foreground([M]::GetAncestor($hw, 2)); Start-Sleep -Milliseconds 500 }
      $r = [M]::ClickAt($X, $Y, $right)
      Log "CLICK ($X,$Y)$(if($right){' right'}) $r"
    }
  } catch { Log "ERR: $_" }
  Start-Sleep -Milliseconds 400
}
