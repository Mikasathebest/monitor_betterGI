# keybd_event 对照测试: 发 M 键 (旧 API, 与 send_f9.ps1 同路径)
$log = 'C:\Users\djf20\sendkey_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class K2 {
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
}
"@
$g = Get-Process YuanShen -ErrorAction SilentlyContinue
if (-not $g) { Log 'key2: NO_GAME'; exit 1 }
[K2]::SetForegroundWindow($g.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 500
[K2]::keybd_event(0x4D, 0x32, 0, [UIntPtr]::Zero)   # M down (vk, scan)
Start-Sleep -Milliseconds 80
[K2]::keybd_event(0x4D, 0x32, 2, [UIntPtr]::Zero)   # M up
Log "key2: M sent via keybd_event fg=$([K2]::GetForegroundWindow()) game=$($g.MainWindowHandle)"
