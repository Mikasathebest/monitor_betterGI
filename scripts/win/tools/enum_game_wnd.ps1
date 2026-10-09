# 枚举原神进程所有窗口 (写文件, 任务里跑)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$out = 'C:\Users\djf20\enum_wnd.txt'
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  public struct RECT { public int Left, Top, Right, Bottom; }
}
"@
[W]::SetProcessDPIAware() | Out-Null
$sb = New-Object Text.StringBuilder
$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
if (-not $ys) { 'NO_GAME' | Out-File $out -Encoding utf8; exit 1 }
[void]$sb.AppendLine("游戏 PID: $($ys.Id)  MainWindowHandle: $($ys.MainWindowHandle)  时间: $(Get-Date -Format 'HH:mm:ss')")
$cb = [W+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [W]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $ys.Id) {
    $cls = New-Object Text.StringBuilder 256; [W]::GetClassName($h, $cls, 256) | Out-Null
    $ttl = New-Object Text.StringBuilder 256; [W]::GetWindowText($h, $ttl, 256) | Out-Null
    $vis = [W]::IsWindowVisible($h)
    $r = New-Object W+RECT; [W]::GetWindowRect($h, [ref]$r) | Out-Null
    [void]$sb.AppendLine(("hwnd={0} vis={1} class='{2}' title='{3}' rect=({4},{5})-({6},{7})" -f $h, $vis, $cls, $ttl, $r.Left, $r.Top, $r.Right, $r.Bottom))
  }
  return $true
}
[W]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
$fg = [W]::GetForegroundWindow()
$fgCls = New-Object Text.StringBuilder 256; [W]::GetClassName($fg, $fgCls, 256) | Out-Null
$fgPid = 0; [W]::GetWindowThreadProcessId($fg, [ref]$fgPid) | Out-Null
[void]$sb.AppendLine("前台窗口: $fg class='$fgCls' pid=$fgPid")
$sb.ToString() | Out-File $out -Encoding utf8
