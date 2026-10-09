# 枚举 BetterGI 进程全部窗口 (标题/句柄/可见性/矩形) → UTF8 文件
$ErrorActionPreference = 'Continue'
$out = 'C:\Users\djf20\enum_bgi.txt'
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WndEnum {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassName(IntPtr h, StringBuilder sb, int max);
}
"@
$p = Get-Process BetterGI -ErrorAction SilentlyContinue
if (-not $p) { [System.IO.File]::WriteAllText($out, 'BGI NOT RUNNING', (New-Object System.Text.UTF8Encoding($false))); exit 1 }
$targetPid = $p.Id
$sb = New-Object System.Text.StringBuilder
$sb.AppendLine("BGI pid=$targetPid MainWindowHandle=0x$($p.MainWindowHandle.ToString('X')) MainWindowTitle=[$($p.MainWindowTitle)]") | Out-Null
$cb = [WndEnum+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [WndEnum]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $targetPid) {
    $t = New-Object System.Text.StringBuilder 512
    $c = New-Object System.Text.StringBuilder 256
    [WndEnum]::GetWindowText($h, $t, 512) | Out-Null
    [WndEnum]::GetClassName($h, $c, 256) | Out-Null
    $vis = [WndEnum]::IsWindowVisible($h)
    $ico = [WndEnum]::IsIconic($h)
    $sb.AppendLine(("0x{0:X} vis={1} iconic={2} class=[{3}] title=[{4}]" -f $h.ToInt64(), $vis, $ico, $c.ToString(), $t.ToString())) | Out-Null
  }
  return $true
}
[WndEnum]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($false)))
Write-Output 'ENUM_OK'
