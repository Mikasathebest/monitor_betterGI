# UIA 启动一条龙 (2026-11-11)
# 背景: 注入了 SendInput 的 F9 无法触发 BGI 的 RegisterHotKey(物理按键正常),
#       所以 F9 无效时改为直接点 BGI 一条龙页的"开始"按钮, 不依赖热键。
# 用法: uia_start_onedragon.ps1 [-DryRun] [-Dump]
#   -DryRun: 只导航到一条龙页并记录按钮名, 不点击
#   -Dump  : 额外把当前页所有 Button 名字写进日志, 便于换版本后校准
param([switch]$DryRun, [switch]$Dump)
$log = 'C:\Users\djf20\cycle_log.txt'
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class WinOpOD {
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
if (-not $proc) { Log "一条龙UIA: BetterGI 未运行"; exit 1 }
$targetPid = $proc.Id
$mainHwnd = [IntPtr]::Zero
$cb = [WinOpOD+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [WinOpOD]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $targetPid) {
    $t = New-Object System.Text.StringBuilder 256
    [WinOpOD]::GetWindowText($h, $t, 256) | Out-Null
    if ([WinOpOD]::IsWindowVisible($h) -and $t.ToString() -match '更好的原神') { $script:mainHwnd = $h }
  }
  return $true
}
[WinOpOD]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
if ($mainHwnd -eq [IntPtr]::Zero) { Log "一条龙UIA: 主窗口未找到"; exit 1 }

# 0. 关 BGI 弹窗 (发现新版本等模态窗会吃掉主窗口点击)
$dlgWins = @()
$cbDlg = [WinOpOD+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [WinOpOD]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $targetPid -and [WinOpOD]::IsWindowVisible($h)) {
    $t = New-Object System.Text.StringBuilder 256
    [WinOpOD]::GetWindowText($h, $t, 256) | Out-Null
    if ($t.ToString().Length -gt 0 -and $t.ToString() -notmatch '更好的原神') { $script:dlgWins += ,@($h, $t.ToString()) }
  }
  return $true
}
[WinOpOD]::EnumWindows($cbDlg, [IntPtr]::Zero) | Out-Null
foreach ($w in $dlgWins) {
  $dh = $w[0]; $dtitle = $w[1]
  Log "一条龙UIA: 发现弹窗 '$dtitle', 关闭中"
  $el = [System.Windows.Automation.AutomationElement]::FromHandle($dh)
  if ($el -ne $null) {
    $btCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
    $btns = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btCond)
    $clicked = $false
    foreach ($b in $btns) {
      if ($b.Current.Name -match '不再提示') {
        try { $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); $clicked = $true; break } catch {}
      }
    }
    if (-not $clicked) {
      foreach ($b in $btns) {
        if ($b.Current.Name -match '取消|关闭|跳过') {
          try { $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); $clicked = $true; break } catch {}
        }
      }
    }
    if (-not $clicked) {
      [WinOpOD]::SetForegroundWindow($dh) | Out-Null
      Start-Sleep -Milliseconds 500
      [WinOpOD]::keybd_event(0x1B, 0, 0, [UIntPtr]::Zero)
      [WinOpOD]::keybd_event(0x1B, 0, 2, [UIntPtr]::Zero)
    }
  }
  Start-Sleep -Seconds 1
}

[WinOpOD]::ForceForeground($mainHwnd)
Start-Sleep -Seconds 2
Log "一条龙UIA: 主窗口=$mainHwnd 当前前景=$([WinOpOD]::GetForegroundWindow())"

function Get-Root { return [System.Windows.Automation.AutomationElement]::FromHandle($mainHwnd) }

function Find-NavItem($name) {
  $r = Get-Root
  if ($r -eq $null) { return $null }
  $nameCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, $name)
  $typeCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::DataItem)
  return $r.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.AndCondition($nameCond, $typeCond)))
}

function Find-Buttons {
  $r = Get-Root
  if ($r -eq $null) { return @() }
  $btCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
  return $r.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btCond)
}

function Click-NavItem($el) {
  # 导航项必须用 Select 才会真的切页 (Invoke 会被支持但无效果)
  try {
    $p = $el.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
    $p.Select()
    return $true
  } catch {}
  $r = $el.Current.BoundingRectangle
  if ($r.Width -le 0 -or $r.Height -le 0) { return $false }
  [WinOpOD]::SetCursorPos([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)) | Out-Null
  Start-Sleep -Milliseconds 200
  [WinOpOD]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 80
  [WinOpOD]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
  return $true
}

function Click-Element($el) {
  # 优先用 UIA Invoke/Select: 不受窗口前后台影响 (鼠标点击在窗口被遮挡时会打偏)
  try {
    $p = $el.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern)
    $p.Invoke()
    return $true
  } catch {}
  try {
    $p = $el.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
    $p.Select()
    return $true
  } catch {}
  $r = $el.Current.BoundingRectangle
  if ($r.Width -le 0 -or $r.Height -le 0) { return $false }
  [WinOpOD]::SetCursorPos([int]($r.X + $r.Width/2), [int]($r.Y + $r.Height/2)) | Out-Null
  Start-Sleep -Milliseconds 200
  [WinOpOD]::mouse_event(0x2, 0, 0, 0, [IntPtr]::Zero)
  Start-Sleep -Milliseconds 80
  [WinOpOD]::mouse_event(0x4, 0, 0, 0, [IntPtr]::Zero)
  return $true
}

# 1. 导航到"一条龙"页 (可能挂在"全自动"折叠菜单下)
$navOk = $false
for ($t = 1; $t -le 4; $t++) {
  $nav = Find-NavItem '一条龙'
  if ($nav -ne $null) {
    if (Click-NavItem $nav) { Log "一条龙UIA: 已选导航'一条龙' (第 $t 轮)"; $navOk = $true; break }
  }
  $parent = Find-NavItem '全自动'
  if ($parent -ne $null) {
    Click-NavItem $parent | Out-Null
    Log "一条龙UIA: 已点'全自动'切换菜单 (第 $t 轮)"
  } else {
    Log "一条龙UIA: '一条龙'/'全自动' 导航项都未找到 (第 $t 轮)"
  }
  Start-Sleep -Seconds 2
}
if (-not $navOk) { Log "一条龙UIA: 导航'一条龙'失败"; exit 1 }
Start-Sleep -Seconds 3

# 2. 找开始/停止按钮
$btnNames = @()
$startBtn = $null
$stopBtn = $null
for ($t = 1; $t -le 5; $t++) {
  $btns = Find-Buttons
  $btnNames = @()
  foreach ($b in $btns) {
    $n = $b.Current.Name
    if ($Dump) {
      $r = $b.Current.BoundingRectangle
      $childTxt = ''
      try {
        $tc = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
        $cts = $b.FindAll([System.Windows.Automation.TreeScope]::Descendants, $tc)
        $acc = @(); foreach ($c in $cts) { if ($c.Current.Name) { $acc += $c.Current.Name } }
        $childTxt = ($acc | Select-Object -First 3) -join '/'
      } catch {}
      $btnNames += ("[{0}] id={1} cls={2} @({3},{4}) {5}x{6} E={7} txt={8}" -f $n, $b.Current.AutomationId, $b.Current.ClassName, [int]$r.X, [int]$r.Y, [int]$r.Width, [int]$r.Height, $b.Current.IsEnabled, $childTxt)
    }
    elseif ($n) { $btnNames += $n }
    if (-not $stopBtn -and $n -match '^停止') { $stopBtn = $b }
    if (-not $startBtn -and $n -match '^(启动|开始|开始执行|开始一条龙|启动一条龙)$') { $startBtn = $b }
  }
  if ($startBtn -or $stopBtn) { break }
  Log "一条龙UIA: 第 $t 轮未找到开始/停止按钮 (按钮数 $($btns.Count))"
  Start-Sleep -Seconds 3
}

if ($Dump) {
  Log "一条龙UIA: 当前按钮 = $($btnNames -join ' | ')"
  $rootD = Get-Root
  if ($rootD -ne $null) {
    $diCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::DataItem)
    $dis = $rootD.FindAll([System.Windows.Automation.TreeScope]::Descendants, $diCond)
    $dinfo = @()
    foreach ($d in $dis) {
      $dr = $d.Current.BoundingRectangle
      $sel = ''
      try { $sel = $d.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern).Current.IsSelected } catch { $sel = 'n/a' }
      $dinfo += ("[{0}] @({1},{2}) {3}x{4} sel={5} off={6}" -f $d.Current.Name, [int]$dr.X, [int]$dr.Y, [int]$dr.Width, [int]$dr.Height, $sel, $d.Current.IsOffscreen)
    }
    Log "一条龙UIA: 导航项 = $($dinfo -join ' | ')"
    $txtCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)
    $texts = $rootD.FindAll([System.Windows.Automation.TreeScope]::Descendants, $txtCond)
    $tnames = @()
    foreach ($x in $texts) { if ($x.Current.Name) { $tnames += $x.Current.Name } }
    Log "一条龙UIA: 页面文本 = $((($tnames | Select-Object -First 25) -join ' | '))"
  }
}

if ($stopBtn -ne $null) { Log "一条龙UIA: 已是运行中状态 (存在'$($stopBtn.Current.Name)'), 无需启动"; exit 0 }
if ($startBtn -eq $null) {
  Log "一条龙UIA: 未找到开始按钮, 现有按钮 = $($btnNames -join ' | ')"
  exit 1
}
if ($DryRun) { Log "一条龙UIA: DRYRUN 找到开始按钮 '$($startBtn.Current.Name)', 不点击"; exit 0 }

if (-not (Click-Element $startBtn)) { Log "一条龙UIA: 点击开始按钮失败 (rect 空)"; exit 1 }
Log "一条龙UIA: 已点击'$($startBtn.Current.Name)'"
exit 0
