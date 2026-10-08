# 久岐忍 5结局全自动邀约脚本
# 集成: BetterGI配置切换 + 鼠标/键盘自动化 + 截图检测 + 日志监控
# 需以管理员身份运行

using namespace System.Drawing
using namespace System.Runtime.InteropServices

param(
    [int]$StartEnding = 1,      # 从第几个结局开始(1-5)
    [int]$EndEnding = 5,        # 到第几个结局结束(1-5)
    [string]$GameTitle = "原神"
)

# ===== WinAPI 定义 =====
Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Drawing;

public class Win32 {
    [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
    [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);
    [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, uint dwExtraInfo);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll", CharSet = CharSet.Auto)] public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    
    public const uint MOUSEEVENTF_LEFTDOWN = 0x02;
    public const uint MOUSEEVENTF_LEFTUP = 0x04;
    public const uint KEYEVENTF_KEYDOWN = 0x00;
    public const uint KEYEVENTF_KEYUP = 0x02;
    
    public const byte VK_ESCAPE = 0x1B;
    public const byte VK_RETURN = 0x0D;
    public const byte VK_SPACE = 0x20;
    public const byte VK_F = 0x46;
    
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms

# ===== 配置 =====
$BgiDir = "D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0"
$ConfigPath = "$BgiDir\User\config.json"
$ExePath = "$BgiDir\BetterGI.exe"
$LogDir = "$BgiDir\log"

$Endings = @(
    @{ Name = "久岐忍结局1:期待之外的工资"; Branch = 0; Dialog = @("快步上前袒护","道歉要紧","姑且顺从她的意思吧") }
    @{ Name = "久岐忍结局2:接下来是商务密谈"; Branch = 3; Dialog = @("快步上前袒护","道歉要紧","千万不能被她带着走") }
    @{ Name = "久岐忍结局3:法度执行"; Branch = 2; Dialog = @("快步上前袒护","让我来代劳","还是跟我走吧") }
    @{ Name = "久岐忍结局4:是祸躲不过"; Branch = 3; Dialog = @("快步上前袒护","让我来代劳","我帮你藏好吧") }
    @{ Name = "久岐忍结局5:荒泷派町街服务记录"; Branch = 1; Dialog = @("默默退后半步") }
)

# ===== 辅助函数 =====

function Get-GameWindow {
    $hwnd = [Win32]::FindWindow($null, $GameTitle)
    if ($hwnd -eq [IntPtr]::Zero) { return $null }
    $rect = New-Object Win32+RECT
    [Win32]::GetWindowRect($hwnd, [ref]$rect) | Out-Null
    return @{ Hwnd=$hwnd; Left=$rect.Left; Top=$rect.Top; Right=$rect.Right; Bottom=$rect.Bottom; W=($rect.Right-$rect.Left); H=($rect.Bottom-$rect.Top) }
}

function Focus-Game {
    $win = Get-GameWindow
    if ($win) { [Win32]::SetForegroundWindow($win.Hwnd) | Out-Null; Start-Sleep -Milliseconds 500 }
}

function Click-At {
    param([int]$X, [int]$Y, [int]$Delay = 300)
    [Win32]::SetCursorPos($X, $Y) | Out-Null
    Start-Sleep -Milliseconds 100
    [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds 50
    [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds $Delay
}

function Press-Key {
    param([byte]$Key, [int]$Delay = 500)
    [Win32]::keybd_event($Key, 0, [Win32]::KEYEVENTF_KEYDOWN, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds 50
    [Win32]::keybd_event($Key, 0, [Win32]::KEYEVENTF_KEYUP, [IntPtr]::Zero) | Out-Null
    Start-Sleep -Milliseconds $Delay
}

function Take-Screenshot {
    $win = Get-GameWindow
    if (-not $win) { return $null }
    $w = $win.W; $h = $win.H
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($win.Left, $win.Top, 0, 0, (New-Object System.Drawing.Size($w, $h)))
    $g.Dispose()
    return $bmp
}

function Get-PixelColor {
    param([int]$X, [int]$Y)
    $win = Get-GameWindow
    if (-not $win) { return $null }
    $bmp = New-Object System.Drawing.Bitmap(1, 1)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CopyFromScreen($win.Left + $X, $win.Top + $Y, 0, 0, (New-Object System.Drawing.Size(1, 1)))
    $g.Dispose()
    $c = $bmp.GetPixel(0, 0)
    $bmp.Dispose()
    return $c
}

function Save-Screenshot {
    param([string]$Path)
    $bmp = Take-Screenshot
    if ($bmp) { $bmp.Save($Path); $bmp.Dispose() }
}

function Set-HangoutConfig {
    param([string]$EndingName)
    Write-Host "  修改配置 → $EndingName" -ForegroundColor Cyan
    $json = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $json.autoSkipConfig.autoHangoutEndChoose = $EndingName
    $json.autoSkipConfig.autoHangoutEventEnabled = $true
    $json | ConvertTo-Json -Depth 100 | Set-Content $ConfigPath -Encoding UTF8
}

function Restart-BetterGI {
    Write-Host "  重启 BetterGI..." -ForegroundColor Yellow
    Get-Process -Name "BetterGI" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3
    Start-Process $ExePath
    Start-Sleep -Seconds 5
    $proc = Get-Process -Name "BetterGI" -ErrorAction SilentlyContinue
    if ($proc) { Write-Host "  BetterGI PID: $($proc.Id)" -ForegroundColor Green }
    else { Write-Host "  BetterGI 启动失败!" -ForegroundColor Red; exit 1 }
}

function Get-LatestLog {
    $logFile = Get-ChildItem $LogDir -Filter "*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $logFile) { return @{ File=$null; Lines=@(); Length=0 } }
    return @{ File=$logFile.FullName; Lines=(Get-Content $logFile.FullName -Tail 100 -ErrorAction SilentlyContinue); Length=$logFile.Length }
}

function Wait-HangoutComplete {
    param([int]$TimeoutSeconds = 600)
    Write-Host "  等待邀约完成(最多${TimeoutSeconds}秒)..." -ForegroundColor Yellow
    $startTime = Get-Date
    $lastLogLen = 0
    $noActivityCount = 0
    $checkInterval = 5  # 每5秒检查一次

    while (((Get-Date) - $startTime).TotalSeconds -lt $TimeoutSeconds) {
        Start-Sleep -Seconds $checkInterval
        $log = Get-LatestLog
        if (-not $log.File) { continue }

        $currentLen = $log.Length
        $newLines = $log.Lines | Where-Object { $_ -match "邀约|hangout|Hangout|跳过|对话选项|结局" }

        if ($currentLen -eq $lastLogLen) {
            $noActivityCount++
        } else {
            $noActivityCount = 0
            $lastLogLen = $currentLen
            if ($newLines) {
                foreach ($line in $newLines | Select-Object -Last 3) {
                    Write-Host "  [LOG] $line" -ForegroundColor Gray
                }
            }
        }

        # 如果30秒没有BetterGI日志活动，可能邀约已结束
        if ($noActivityCount -ge 6) {
            Write-Host "  BetterGI 30秒无活动，检测游戏状态..." -ForegroundColor Yellow
            # 检查是否有结局画面（屏幕变暗、特定文字）
            $centerColor = Get-PixelColor -X 640 -Y 360
            Write-Host "  屏幕中心颜色: $($centerColor.ToString())" -ForegroundColor Gray

            # 如果BetterGI确实在选择邀约选项了很长时间然后停止了，很可能结束了
            if ($newLines -and ($newLines | Select-String "邀约分支|Hangout")) {
                Write-Host "  检测到邀约日志活动，确认可能已完成" -ForegroundColor Green
                return $true
            }
            # 即使没检测到明确信号，30秒无活动也认为可能完成了
            return $true
        }

        # 显示进度
        $elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds)
        Write-Host "  已等待 ${elapsed}s..." -NoNewline -ForegroundColor Gray
        Write-Host "`r" -NoNewline
    }

    Write-Host "  超时!" -ForegroundColor Red
    return $false
}

function Dismiss-EndingScreen {
    Write-Host "  处理结局画面..." -ForegroundColor Yellow
    Focus-Game
    Start-Sleep -Milliseconds 500

    # 结局达成后通常有多个需要点击/按键才能继续的画面
    for ($i = 0; $i -lt 5; $i++) {
        # 按空格/回车确认
        Press-Key ([Win32]::VK_SPACE) -Delay 500
        Press-Key ([Win32]::VK_RETURN) -Delay 800
        # 也可以点击屏幕中心
        $win = Get-GameWindow
        if ($win) {
            Click-At ($win.Left + 640) ($win.Top + 400) -Delay 800
        }
    }
    Start-Sleep -Seconds 2
}

function Navigate-ToHangout {
    Write-Host "  导航到邀约事件..." -ForegroundColor Yellow
    Focus-Game
    Start-Sleep -Milliseconds 500

    # ESC 打开派蒙菜单
    Press-Key ([Win32]::VK_ESCAPE) -Delay 1000

    $win = Get-GameWindow
    if (-not $win) { return $false }

    # 在1280x720分辨率下，派蒙菜单左侧图标大致位置
    # 邀约事件图标位置（根据实际游戏版本可能需要调整）
    # 左侧图标列大约在 x=100, y从180开始
    $iconX = $win.Left + 100

    # 尝试点击邀约事件图标（可能是第4-5个图标）
    $hangoutIconY = $win.Top + 360
    Click-At $iconX $hangoutIconY -Delay 1000

    # 如果邀约事件界面没打开，尝试其他位置
    Start-Sleep -Seconds 1
    # 点击邀约角色 久岐忍
    # 在邀约列表中找久岐忍
    $charY = $win.Top + 200
    Click-At ($win.Left + 400) $charY -Delay 1000

    return $true
}

function Start-HangoutFresh {
    Write-Host "  开始新的邀约..." -ForegroundColor Yellow
    $win = Get-GameWindow
    if (-not $win) { return $false }

    # 点击"开始体验"按钮（通常在右下角）
    Click-At ($win.Left + 900) ($win.Top + 600) -Delay 2000
    Start-Sleep -Seconds 3
    return $true
}

function Select-BranchPoint {
    param([int]$BranchIndex)
    Write-Host "  选择分支点 $BranchIndex ..." -ForegroundColor Yellow
    $win = Get-GameWindow
    if (-not $win) { return $false }

    # 在邀约事件树中，分支点按顺序排列
    # BranchIndex 0=从开始, 1=第一个分支, 2=第二个分支, 3=第三个分支
    if ($BranchIndex -eq 0) {
        # 从头开始 - 点击最左边的节点
        Click-At ($win.Left + 200) ($win.Top + 360) -Delay 1000
    } elseif ($BranchIndex -eq 1) {
        # 第一个分支点
        Click-At ($win.Left + 400) ($win.Top + 360) -Delay 1000
    } elseif ($BranchIndex -eq 2) {
        # 第二个分支点
        Click-At ($win.Left + 600) ($win.Top + 360) -Delay 1000
    } elseif ($BranchIndex -eq 3) {
        # 第三个分支点
        Click-At ($win.Left + 800) ($win.Top + 360) -Delay 1000
    }

    # 点击"重新体验"按钮
    Start-Sleep -Seconds 1
    Click-At ($win.Left + 900) ($win.Top + 600) -Delay 2000
    Start-Sleep -Seconds 3
    return $true
}

# ===== 主流程 =====

Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  久岐忍 5结局全自动邀约任务" -ForegroundColor Magenta
Write-Host "========================================`n" -ForegroundColor Magenta

# 检查游戏和BetterGI状态
$gameWin = Get-GameWindow
if (-not $gameWin) {
    Write-Host "原神未运行! 请先启动原神。" -ForegroundColor Red
    exit 1
}
Write-Host "原神窗口: $($gameWin.W)x$($gameWin.H) at ($($gameWin.Left), $($gameWin.Top))" -ForegroundColor Green

$bgiProc = Get-Process -Name "BetterGI" -ErrorAction SilentlyContinue
if (-not $bgiProc) {
    Write-Host "BetterGI未运行，正在启动..." -ForegroundColor Yellow
    Start-Process $ExePath
    Start-Sleep -Seconds 5
}

Write-Host "`n5个结局:" -ForegroundColor Cyan
for ($i = 0; $i -lt 5; $i++) {
    $e = $Endings[$i]
    Write-Host "  $($i+1). $($e.Name)" -ForegroundColor White
    Write-Host "     路径: $($e.Dialog -join ' → ')" -ForegroundColor Gray
    Write-Host "     分支起点: $($e.Branch)" -ForegroundColor Gray
}
Write-Host ""

# 截图保存目录
$ssDir = "$LogDir\screenshots"
if (-not (Test-Path $ssDir)) { New-Item -ItemType Directory -Path $ssDir | Out-Null }

for ($i = $StartEnding - 1; $i -lt $EndEnding; $i++) {
    $ending = $Endings[$i]
    $endingNum = $i + 1

    Write-Host "`n----------------------------------------" -ForegroundColor Cyan
    Write-Host "  结局 $endingNum/5: $($ending.Name)" -ForegroundColor Cyan
    Write-Host "----------------------------------------" -ForegroundColor Cyan
    Write-Host "  选项: $($ending.Dialog -join ' → ')" -ForegroundColor Gray
    Write-Host "  分支: $($ending.Branch)" -ForegroundColor Gray

    # 1. 停止 BetterGI
    Write-Host "`n[1/4] 停止 BetterGI" -ForegroundColor Yellow
    Get-Process -Name "BetterGI" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 3

    # 2. 修改配置
    Write-Host "[2/4] 修改配置" -ForegroundColor Yellow
    Set-HangoutConfig -EndingName $ending.Name
    # 验证
    $verify = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    Write-Host "  验证: autoHangoutEndChoose = $($verify.autoSkipConfig.autoHangoutEndChoose)" -ForegroundColor Gray
    Write-Host "  验证: autoHangoutEventEnabled = $($verify.autoSkipConfig.autoHangoutEventEnabled)" -ForegroundColor Gray

    # 3. 启动 BetterGI
    Write-Host "[3/4] 启动 BetterGI" -ForegroundColor Yellow
    Start-Process $ExePath
    Start-Sleep -Seconds 5

    # 4. 导航到邀约事件并开始
    Write-Host "[4/4] 导航到邀约事件" -ForegroundColor Yellow
    Focus-Game
    Start-Sleep -Milliseconds 500

    if ($i -eq 0 -or $ending.Branch -eq 0) {
        # 第一个结局或从头开始
        # 如果是第一次，可能需要先打开邀约事件菜单
        if ($i -eq 0) {
            Write-Host "  首次运行，打开邀约事件..." -ForegroundColor Gray
            # 截图当前画面
            Save-Screenshot "$ssDir\before_ending_$endingNum.png"
            # 尝试导航到邀约事件
            Navigate-ToHangout | Out-Null
            Start-HangoutFresh | Out-Null
        } else {
            # 从头开始（选择第一个分支点）
            Navigate-ToHangout | Out-Null
            Select-BranchPoint -BranchIndex 0 | Out-Null
        }
    } else {
        # 后续结局：处理上一个结局的收尾画面，然后在树中选择分支点
        Dismiss-EndingScreen
        Start-Sleep -Seconds 2
        Save-Screenshot "$ssDir\after_ending_$endingNum.png"

        # 在邀约事件树中选择分支点
        Select-BranchPoint -BranchIndex $ending.Branch | Out-Null
    }

    # 等待BetterGI自动完成邀约
    Write-Host "`n  BetterGI 开始自动处理对话..." -ForegroundColor Green
    Write-Host "  脚本将监控日志，等待完成..." -ForegroundColor Green
    Save-Screenshot "$ssDir\during_ending_$endingNum.png"

    $completed = Wait-HangoutComplete -TimeoutSeconds 600

    if ($completed) {
        Write-Host "`n  结局 $endingNum 可能已完成!" -ForegroundColor Green
        Save-Screenshot "$ssDir\complete_ending_$endingNum.png"
    } else {
        Write-Host "`n  结局 $endingNum 超时，继续下一个..." -ForegroundColor Yellow
        Save-Screenshot "$ssDir\timeout_ending_$endingNum.png"
    }

    # 更新进度
    Write-Host "`n  进度: $endingNum/$EndEnding 完成" -ForegroundColor Cyan
}

# 收尾
Write-Host "`n========================================" -ForegroundColor Magenta
Write-Host "  全部 $EndEnding 个结局流程执行完毕!" -ForegroundColor Magenta
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "`n截图保存在: $ssDir" -ForegroundColor Gray
Write-Host "BetterGI 日志: $LogDir" -ForegroundColor Gray
Write-Host "`n注意: 某些结局可能需要手动确认是否正确完成。" -ForegroundColor Yellow
Write-Host "如果某个结局未正确达成，可以重新运行此脚本指定单个结局:" -ForegroundColor Yellow
Write-Host "  .\auto_hangout_shinobu.ps1 -StartEnding 3 -EndEnding 3" -ForegroundColor Gray
