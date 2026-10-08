# UIA Invoke 主页"启动"按钮 (启动截图器)
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class CapWnd {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
}
"@
$targetPid = (Get-Process BetterGI).Id
$hwnd = [IntPtr]::Zero
$cb = [CapWnd+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [CapWnd]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $targetPid -and [CapWnd]::IsWindowVisible($h)) {
    $t = New-Object System.Text.StringBuilder 256
    [CapWnd]::GetWindowText($h, $t, 256) | Out-Null
    if ($t.ToString() -match '更好的原神') { $script:hwnd = $h }
  }
  return $true
}
[CapWnd]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($hwnd -eq [IntPtr]::Zero) { Log "窗口未找到"; exit 1 }
[CapWnd]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 800

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
# 找 name=启动 的 Button (截图器启动按钮)
$bn = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, '启动')
$bt = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btn = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.AndCondition($bn, $bt)))
if ($btn -eq $null) { Log "启动按钮未找到"; exit 1 }
$r = $btn.Current.BoundingRectangle
Log "启动按钮 rect=($([int]$r.X),$([int]$r.Y),$([int]$r.Width)x$([int]$r.Height))"

# 先试 InvokePattern
$invoked = $false
try {
  $ip = $btn.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
  $ip.Invoke()
  $invoked = $true
  Log "InvokePattern 已调用"
} catch { Log "InvokePattern 失败: $($_.Exception.Message)" }

if (-not $invoked) {
  # 鼠标点中心
  [CapWnd]::SetCursorPos([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)) | Out-Null
  Start-Sleep -Milliseconds 300
  [CapWnd]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 100
  [CapWnd]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
  Log "鼠标点击 ($([int]($r.X + $r.Width/2)),$([int]($r.Y + $r.Height/2)))"
}
