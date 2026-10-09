# 置前游戏窗口并发送 F9 (触发 BetterGI 一条龙: 合成树脂+领取每日奖励)
# 游戏只认 SendInput (raw input); 40 字节 INPUT 对齐是 PS 5.1 下的关键
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class F9Op {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int c);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool at);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte s, uint f, UIntPtr e);
  [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
  [StructLayout(LayoutKind.Explicit, Size=32)] public struct INPUTUNION { [FieldOffset(0)] public KEYBDINPUT ki; }
  [StructLayout(LayoutKind.Sequential)] public struct INPUT { public uint type; public INPUTUNION u; }
  [DllImport("user32.dll", SetLastError=true)] public static extern uint SendInput(uint n, INPUT[] p, int cb);
  public static void ForceForeground(IntPtr h) {
    IntPtr fg = GetForegroundWindow();
    if (fg == h) return;
    uint dummy;
    uint fgT = fg == IntPtr.Zero ? 0 : GetWindowThreadProcessId(fg, out dummy);
    uint myT = GetCurrentThreadId();
    keybd_event(0x12, 0, 0, UIntPtr.Zero);
    if (fgT != 0) AttachThreadInput(myT, fgT, true);
    ShowWindow(h, 9);
    SetForegroundWindow(h);
    if (fgT != 0) AttachThreadInput(myT, fgT, false);
    keybd_event(0x12, 0, 2, UIntPtr.Zero);
  }
  public static void TapF9() {
    int sz = Marshal.SizeOf(typeof(INPUT));
    var down = new INPUT { type = 1, u = new INPUTUNION { ki = new KEYBDINPUT { wVk = 0x78, wScan = 0x43, dwFlags = 0x8, time = 0, dwExtraInfo = IntPtr.Zero } } };
    var up   = new INPUT { type = 1, u = new INPUTUNION { ki = new KEYBDINPUT { wVk = 0x78, wScan = 0x43, dwFlags = 0x8 | 0x2, time = 0, dwExtraInfo = IntPtr.Zero } } };
    SendInput(1, new INPUT[] { down }, sz);
    System.Threading.Thread.Sleep(60);
    SendInput(1, new INPUT[] { up }, sz);
  }
}
"@

$proc = Get-Process YuanShen -ErrorAction SilentlyContinue
if (-not $proc) { Log "F9: 游戏未运行, 跳过"; exit 1 }
$hwnd = [IntPtr]::Zero
$targetPid = $proc.Id
$cb = [F9Op+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [F9Op]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $targetPid -and [F9Op]::IsWindowVisible($h)) { $script:hwnd = $h }
  return $true
}
[F9Op]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($hwnd -eq [IntPtr]::Zero) { Log "F9: 游戏窗口未找到"; exit 1 }

[F9Op]::ForceForeground($hwnd)
Start-Sleep -Seconds 2
[F9Op]::TapF9()
Log "F9 已发送 (游戏已置前)"
