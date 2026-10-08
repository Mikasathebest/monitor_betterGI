# UIA 按名字启动配置组 v2: ListItem.Name 是类名, 改读子级 Text 元素
param([string]$NameMatch = '伊安珊')
$log = 'C:\Users\djf20\cycle_log.txt'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WinOpN2 {
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowText(IntPtr h, StringBuilder sb, int max);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint a, uint b, bool attach);
  [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
  [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
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
}
"@

$proc = Get-Process BetterGI -ErrorAction SilentlyContinue
if (-not $proc) { Log "BetterGI 未运行"; exit 1 }
$targetPid = $proc.Id
$mainHwnd = [IntPtr]::Zero
$cb = [WinOpN2+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [WinOpN2]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $targetPid) {
    $t = New-Object System.Text.StringBuilder 256
    [WinOpN2]::GetWindowText($h, $t, 256) | Out-Null
    if ([WinOpN2]::IsWindowVisible($h) -and $t.ToString() -match '更好的原神') { $script:mainHwnd = $h }
  }
  return $true
}
[WinOpN2]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($mainHwnd -eq [IntPtr]::Zero) { Log "主窗口未找到"; exit 1 }
[WinOpN2]::ForceForeground($mainHwnd)
Start-Sleep -Seconds 2
$root = [System.Windows.Automation.AutomationElement]::FromHandle($mainHwnd)
if ($root -eq $null) { Log "UIA FromHandle 失败"; exit 1 }

function Click-Nav($root, $name) {
  $nameCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)
  $typeCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::DataItem)
  $nav = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.AndCondition($nameCond, $typeCond)))
  if ($nav -ne $null) {
    $r = $nav.Current.BoundingRectangle
    [WinOpN2]::SetCursorPos([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)) | Out-Null
    Start-Sleep -Milliseconds 200
    [WinOpN2]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 80
    [WinOpN2]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
    return $true
  }
  return $false
}
if (Click-Nav $root '全自动') { Log "已点全自动"; Start-Sleep -Seconds 2 }
if (Click-Nav $root '调度器') { Log "已点调度器"; Start-Sleep -Seconds 3 }

# 找组列表 (ListItem.Name 以 ScriptGroup 结尾的那个 List)
$listCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::List)
$lists = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $listCond)
$groupList = $null
foreach ($lst in $lists) {
  $ic = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)
  $its = $lst.FindAll([System.Windows.Automation.TreeScope]::Children, $ic)
  if ($its.Count -gt 0 -and $its[0].Current.Name -match 'ScriptGroup$') { $groupList = $lst; break }
}
if ($groupList -eq $null) { Log "组列表未找到"; exit 1 }
$ic2 = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)
$items = $groupList.FindAll([System.Windows.Automation.TreeScope]::Children, $ic2)
Log "组列表共 $($items.Count) 项"

# 读每项的子级 Text 拼出显示名
$txtCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
$found = $false
foreach ($it in $items) {
  $texts = $it.FindAll([System.Windows.Automation.TreeScope]::Descendants, $txtCond)
  $disp = ""
  foreach ($t in $texts) { $disp += $t.Current.Name + " " }
  Log "  项显示名: $disp"
  if ($disp -match $NameMatch) {
    $it.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Select()
    Log "已选组: $disp"
    $found = $true
    break
  }
}
if (-not $found) { Log "未找到匹配 $NameMatch 的组"; exit 1 }
Start-Sleep -Seconds 4

$bn = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, '运行')
$bt = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btn = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.AndCondition($bn, $bt)))
if ($btn -eq $null) { Log "运行按钮未找到"; exit 1 }
$br = $btn.Current.BoundingRectangle
[WinOpN2]::SetCursorPos([int]($br.X + $br.Width/2), [int]($br.Y + $br.Height/2)) | Out-Null
Start-Sleep -Milliseconds 250
[WinOpN2]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 80
[WinOpN2]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
Log "已点击运行 — $NameMatch 应已启动"
