# UIA Invoke 主页"启动"按钮 (启动截图器)
# 11-13 重写 (P0-3): 旧版四个缺陷 —
#   1) BGI 未起时 (Get-Process BetterGI).Id 裸报错后继续跑 → 现在缺失直接 exit 1
#   2) 固定等 75s 后就找窗口, 更新后首次启动 (迁移配置/下载资源) 超过 75s 就失败
#      → 现在轮询等主窗口, 上限 3 分钟
#   3) 完全没有关弹窗逻辑, "发现新版本"模态窗会挡住首页"启动" → 现在启动前先关
#      (与 uia_start_group_named 同款: 优先"不再提示", 兜底"取消/关闭/跳过")
#   4) 截图器已在运行时按钮变"停止", 旧版报"启动按钮未找到"被当成失败
#      (11-11 下午日志误报) → 现在检测到"停止"直接成功返回
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
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint f, uint dx, uint dy, uint d, IntPtr e);
}
"@

$proc = Get-Process BetterGI -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { Log "截图器UIA: BetterGI 未运行"; exit 1 }
$targetPid = $proc.Id

# 等主窗口出现 (轮询, 上限 3 分钟); 多个候选时取面积最大的 (P2-2: 枚举最后一个可能是浮窗)
$hwnd = [IntPtr]::Zero
$deadline = (Get-Date).AddMinutes(3)
while ((Get-Date) -lt $deadline) {
  $cands = @()
  $cb = [CapWnd+EnumProc]{
    param($h, $l)
    $pid2 = 0
    [CapWnd]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
    if ($pid2 -eq $targetPid -and [CapWnd]::IsWindowVisible($h)) {
      $t = New-Object System.Text.StringBuilder 256
      [CapWnd]::GetWindowText($h, $t, 256) | Out-Null
      if ($t.ToString() -match '更好的原神') { $script:cands += $h }
    }
    return $true
  }
  [CapWnd]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
  $best = [IntPtr]::Zero; $bestArea = 0
  foreach ($h in $cands) {
    $r = New-Object CapWnd+RECT
    if ([CapWnd]::GetWindowRect($h, [ref]$r)) {
      $a = ($r.Right - $r.Left) * ($r.Bottom - $r.Top)
      if ($a -gt $bestArea) { $bestArea = $a; $best = $h }
    }
  }
  if ($best -ne [IntPtr]::Zero) { $hwnd = $best; break }
  Start-Sleep -Seconds 3
}
if ($hwnd -eq [IntPtr]::Zero) { Log "截图器UIA: 3 分钟内主窗口未出现 (BGI 可能未启动完成)"; exit 1 }
[CapWnd]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 800

# 关 BGI 弹窗: 遍历 BGI 进程其它带标题的可见顶层窗口 (模态弹窗), 挡住首页"启动"就全空跑
$dlgWins = @()
$cbDlg = [CapWnd+EnumProc]{
  param($h, $l)
  $pid2 = 0
  [CapWnd]::GetWindowThreadProcessId($h, [ref]$pid2) | Out-Null
  if ($pid2 -eq $targetPid -and [CapWnd]::IsWindowVisible($h)) {
    $t = New-Object System.Text.StringBuilder 256
    [CapWnd]::GetWindowText($h, $t, 256) | Out-Null
    if ($t.ToString().Length -gt 0 -and $t.ToString() -notmatch '更好的原神') { $script:dlgWins += $h }
  }
  return $true
}
[CapWnd]::EnumWindows($cbDlg, [IntPtr]::Zero) | Out-Null
foreach ($dh in $dlgWins) {
  $el = [System.Windows.Automation.AutomationElement]::FromHandle($dh)
  if ($el -eq $null) { continue }
  $btCond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
  $btns = $el.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btCond)
  $clicked = $false
  foreach ($b in $btns) {
    if ($b.Current.Name -match '不再提示') {
      try { $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); Log "截图器UIA: 已点弹窗'不再提示'"; $clicked = $true; break } catch {}
    }
  }
  if (-not $clicked) {
    foreach ($b in $btns) {
      if ($b.Current.Name -match '取消|关闭|跳过') {
        try { $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke(); Log "截图器UIA: 已点弹窗'$($b.Current.Name)'"; $clicked = $true; break } catch {}
      }
    }
  }
  Start-Sleep -Seconds 1
}

$root = [System.Windows.Automation.AutomationElement]::FromHandle($hwnd)
# 找 name=启动 的 Button (截图器启动按钮)
$bn = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, '启动')
$bt = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Button)
$btn = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.AndCondition($bn, $bt)))
if ($btn -eq $null) {
  # 截图器已在运行时按钮变"停止" — 不是失败 (P0-3)
  $sn = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::NameProperty, '停止')
  $stopBtn = $root.FindFirst([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.AndCondition($sn, $bt)))
  if ($stopBtn -ne $null) { Log "截图器UIA: 已在运行 (按钮=停止), 无需启动"; exit 0 }
  Log "截图器UIA: 启动按钮未找到"; exit 1
}
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
exit 0
