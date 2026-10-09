# UIA 设置 BGI 自动邀约目标结局 (免重启 BGI)
# 用法: powershell -File hangout_set_ending.ps1 -Ending '久岐忍结局1:xxx'
param([string]$Ending = '')
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$log = 'C:\Users\djf20\hangout_log.txt'
function Log($msg) { "$(Get-Date -Format 'HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

# 1. 找 BGI 主窗口 (最小化则恢复)
$bgi = Get-Process BetterGI -ErrorAction SilentlyContinue
if (-not $bgi) { Log 'BGI 未运行'; exit 1 }
$root = [System.Windows.Automation.AutomationElement]::RootElement
$cond = New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ProcessIdProperty, $bgi.Id)
$win = $root.FindFirst([System.Windows.Automation.TreeScope]::Children, $cond)
if (-not $win) { Log '找不到 BGI 窗口'; exit 1 }
try { $win.SetFocus() } catch {}

# 2. 导航到 触发器 设置页: 左侧导航找 "触发器" 项
Start-Sleep -Milliseconds 800
$navItems = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)))
$navHit = $null
foreach ($it in $navItems) {
  $txt = ''
  foreach ($t in $it.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::Text)))) { $txt += $t.Current.Name }
  if ($txt -match '触发器') { $navHit = $it; break }
}
if (-not $navHit) { Log '导航找不到触发器项'; exit 1 }
$sel = $navHit.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
$sel.Select()
Log '已进入触发器页'
Start-Sleep -Milliseconds 1200

# 3. 找邀约分支 ComboBox (页面上有多个下拉; 邀约分支的下拉项含"结局")
$combos = $win.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ComboBox)))
$target = $null
foreach ($cb in $combos) {
  try {
    $exp = $cb.GetCurrentPattern([System.Windows.Automation.ExpandCollapsePattern]::Pattern)
    $exp.Expand(); Start-Sleep -Milliseconds 500
    $items = $cb.FindAll([System.Windows.Automation.TreeScope]::Descendants, (New-Object System.Windows.Automation.PropertyCondition([System.Windows.Automation.AutomationElement]::ControlTypeProperty, [System.Windows.Automation.ControlType]::ListItem)))
    $names = ($items | Select-Object -First 3 | ForEach-Object { $_.Current.Name }) -join '|'
    if (($items.Count -gt 10) -or ($names -match '结局')) { $target = $cb; $items0 = $items; break }
    $exp.Collapse(); Start-Sleep -Milliseconds 200
  } catch { }
}
if (-not $target) { Log '找不到邀约分支下拉框'; exit 1 }

# 4. 选中目标结局项
$hit = $null
foreach ($it in $items0) { if ($it.Current.Name -eq $Ending) { $hit = $it; break } }
if (-not $hit) {
  # 模糊匹配 (前缀)
  foreach ($it in $items0) { if ($it.Current.Name -like "$Ending*") { $hit = $it; break } }
}
if (-not $hit) { Log ("下拉项里没有: " + $Ending); exit 1 }
$si = $hit.GetCurrentPattern([System.Windows.Automation.SelectionItemPattern]::Pattern)
$si.Select()
Start-Sleep -Milliseconds 300
Log ("结局已设置: " + $hit.Current.Name)
Write-Output 'ENDING_SET_OK'
