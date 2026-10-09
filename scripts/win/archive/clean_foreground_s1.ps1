Add-Type @'
using System;
using System.Runtime.InteropServices;
public class Win32Agent {
 [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lp);
 public delegate bool EnumWindowsProc(IntPtr h, IntPtr lp);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
 [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
}
'@
$cb = [Win32Agent+EnumWindowsProc]{ param($h,$lp)
  if ([Win32Agent]::IsWindowVisible($h)) {
    $s = New-Object System.Text.StringBuilder 256
    [void][Win32Agent]::GetClassName($h,$s,256)
    if ($s.ToString() -eq 'ConsoleWindowClass') { [void][Win32Agent]::ShowWindow($h,6) }
  }
  return $true
}
[void][Win32Agent]::EnumWindows($cb,[IntPtr]::Zero)
Start-Sleep -Milliseconds 500
$g = Get-Process YuanShen -ErrorAction SilentlyContinue | Select-Object -First 1
if ($g -and $g.MainWindowHandle -ne 0) {
  [void][Win32Agent]::ShowWindow($g.MainWindowHandle,9)
  [void][Win32Agent]::SetForegroundWindow($g.MainWindowHandle)
}
