Add-Type @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class WInspect {
 public delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
}
$lines = New-Object System.Collections.Generic.List[string]
$cb = [WInspect+EnumWindowsProc]{ param($h,$lp)
 if ([WInspect]::IsWindowVisible($h)) {
  $t=New-Object Text.StringBuilder 512; $c=New-Object Text.StringBuilder 256
  [void][WInspect]::GetWindowText($h,$t,512); [void][WInspect]::GetClassName($h,$c,256)
  [uint32]$pid=0; [void][WInspect]::GetWindowThreadProcessId($h,[ref]$pid)
  try {$pn=(Get-Process -Id $pid -ErrorAction Stop).ProcessName} catch {$pn='?'}
  $lines.Add(("{0}|{1}|{2}|{3}" -f $pid,$pn,$c.ToString(),$t.ToString()))
 }
 return $true
}
[void][WInspect]::EnumWindows($cb,[IntPtr]::Zero)
$lines | Set-Content -LiteralPath C:\Users\djf20\visible_windows.txt -Encoding UTF8
