# UIA 按名字启动配置组 v4 (2026-09-18)
# v4 修复(根因): BGI 启动后弹"发现新版本"模态窗吃掉所有主窗口点击 → 导航全落空 (09-18 04:28 事故)
#   → 导航前先关掉 BGI 所有非主窗口弹窗 (优先点"不再提示"永久关闭, 兜底"取消"/ESC)
# v3: "全自动"是折叠菜单父项, 点击=展开/收起切换 → 找"调度器"子项, 找不到就切换展开再找 (最多4轮)
# -DryRun: 只导航+选组+落日志, 不点"运行" (用于无游戏时验证导航链路)
param([string]$NameMatch = '全自动循环', [switch]$DryRun)
$log = 'C:\Users\djf20\cycle_log.txt'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WinOpN3 {
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
$cb = [WinOpN3+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [WinOpN3]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $targetPid) {
    $t = New-Object System.Text.StringBuilder 256
    [WinOpN3]::GetWindowText($h, $t, 256) | Out-Null
    if ([WinOpN3]::IsWindowVisible($h) -and $t.ToString() -match '更好的原神') { $script:mainHwnd = $h }
  }
  return $true
}
[WinOpN3]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($mainHwnd -eq [IntPtr]::Zero) { Log "主窗口未找到"; exit 1 }

# 0. 先关 BGI 弹窗 (发现新版本等模态窗会吃掉主窗口点击 —— 09-18 事故根因)
$dlgWins = @()
$cbDlg = [WinOpN3+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [WinOpN3]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $targetPid -and [WinOpN3]::IsWindowVisible($h)) {
    $t = New-Object System.Text.StringBuilder 256
    [WinOpN3]::GetWindowText($h, $t, 256) | Out-Null
    if ($t.ToString().Length -gt 0 -and $t.ToString() -notmatch '更好的原神') { $script:dlgWins += ,@($h, $t.ToString()) }
  }
  return $true
}
[WinOpN3]::EnumWindows($cbDlg, [IntPtr]::Zero) | Out-Null
foreach ($w in $dlgWins) {
  $dh = $w[0]; $dtitle = $w[1]
  Log "发现弹窗 '$dtitle', 关闭中"
  $el = [System.Windows.Automation.AutomationElement]::FromHandle($dh)
  if ($el -ne $null) {
    $btCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
    $btns = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btCond)
    $clicked = $false
    foreach ($b in $btns) {
      if ($b.Current.Name -match '不再提示') {
        try { $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); Log "已点 '不再提示'"; $clicked = $true; break } catch {}
      }
    }
    if (-not $clicked) {
      foreach ($b in $btns) {
        if ($b.Current.Name -match '取消|关闭|跳过') {
          try { $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); Log "已点 '$($b.Current.Name)'"; $clicked = $true; break } catch {}
        }
      }
    }
    if (-not $clicked) {
      [WinOpN3]::SetForegroundWindow($dh) | Out-Null
      Start-Sleep -Milliseconds 500
      [WinOpN3]::keybd_event(0x1B, 0, 0, [UIntPtr]::Zero)
      [WinOpN3]::keybd_event(0x1B, 0, 2, [UIntPtr]::Zero)
      Log "已发 ESC 关弹窗"
    }
  }
  Start-Sleep -Seconds 1
}

[WinOpN3]::ForceForeground($mainHwnd)
Start-Sleep -Seconds 2

function Get-Root { return [System.Windows.Automation.AutomationElement]::FromHandle($mainHwnd) }

function Find-NavItem($name) {
  # 导航项在 UIA 里是 DataItem (WPF-UI NavigationViewItem)
  $r = Get-Root
  if ($r -eq $null) { return $null }
  $nameCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)
  $typeCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::DataItem)
  return $r.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.AndCondition($nameCond, $typeCond)))
}

function Click-Element($el) {
  $r = $el.Current.BoundingRectangle
  if ($r.Width -le 0 -or $r.Height -le 0) { return $false }
  [WinOpN3]::SetCursorPos([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)) | Out-Null
  Start-Sleep -Milliseconds 200
  [WinOpN3]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 80
  [WinOpN3]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
  return $true
}

# 1. 导航到调度器页: "调度器"是"全自动"折叠菜单的子项, 找不到就点"全自动"切换展开状态
$navOk = $false
for ($t = 1; $t -le 4; $t++) {
  $nav = Find-NavItem '调度器'
  if ($nav -ne $null) {
    if (Click-Element $nav) { Log "已点调度器 (第 $t 轮)"; $navOk = $true; break }
  }
  $parent = Find-NavItem '全自动'
  if ($parent -ne $null) {
    Click-Element $parent | Out-Null
    Log "已点全自动切换菜单 (第 $t 轮)"
  } else {
    Log "全自动菜单项未找到 (第 $t 轮)"
  }
  Start-Sleep -Seconds 2
}
if (-not $navOk) { Log "调度器导航失败"; exit 1 }
Start-Sleep -Seconds 3

# 2. 找组列表 (ListItem.Name 以 ScriptGroup 结尾的 List), 页面加载慢则重试
$groupList = $null
for ($t = 1; $t -le 5 -and $groupList -eq $null; $t++) {
  $root = Get-Root
  $listCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::List)
  $lists = $root.FindAll([System.Windows.Automation.TreeScope]::Descendants, $listCond)
  foreach ($lst in $lists) {
    $ic = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)
    $its = $lst.FindAll([System.Windows.Automation.TreeScope]::Children, $ic)
    if ($its.Count -gt 0 -and $its[0].Current.Name -match 'ScriptGroup$') { $groupList = $lst; break }
  }
  if ($groupList -eq $null) { Log "第 $t 轮找组列表: 未就绪 (页面共 $($lists.Count) 个List)"; Start-Sleep -Seconds 3 }
}
if ($groupList -eq $null) { Log "组列表未找到"; exit 1 }
$ic2 = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)
$items = $groupList.FindAll([System.Windows.Automation.TreeScope]::Children, $ic2)
Log "组列表共 $($items.Count) 项"

# 3. 读每项的子级 Text 拼出显示名, 按名选组
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

if ($DryRun) { Log "DRYRUN: 已选组 $NameMatch, 跳过点击运行"; exit 0 }

# 4. 点"运行"
$root = Get-Root
$bn = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, '运行')
$bt = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btn = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.AndCondition($bn, $bt)))
if ($btn -eq $null) { Log "运行按钮未找到"; exit 1 }
$br = $btn.Current.BoundingRectangle
[WinOpN3]::SetCursorPos([int]($br.X + $br.Width/2), [int]($br.Y + $br.Height/2)) | Out-Null
Start-Sleep -Milliseconds 250
[WinOpN3]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero)
Start-Sleep -Milliseconds 80
[WinOpN3]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
Log "已点击运行 — $NameMatch 应已启动"
