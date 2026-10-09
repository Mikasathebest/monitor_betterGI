# BetterGI 久岐忍邀约任务 - 5结局自动切换脚本
# 用法: 以管理员身份运行 PowerShell，执行此脚本
# 参数: -Ending 1|2|3|4|5 (选择第几个结局), 或 -All (依次跑全部5个)

param(
    [int]$Ending = 0,
    [switch]$All
)

$BgiPath = "D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0"
$ConfigPath = "$BgiPath\User\config.json"
$ExePath = "$BgiPath\BetterGI.exe"

$Endings = @(
    @{ Name = "久岐忍结局1:期待之外的工资";        Dialog = @("快步上前袒护", "道歉要紧", "姑且顺从她的意思吧") },
    @{ Name = "久岐忍结局2:接下来是商务密谈";        Dialog = @("快步上前袒护", "道歉要紧", "千万不能被她带着走") },
    @{ Name = "久岐忍结局3:法度执行";                Dialog = @("快步上前袒护", "让我来代劳", "还是跟我走吧") },
    @{ Name = "久岐忍结局4:是祸躲不过";              Dialog = @("快步上前袒护", "让我来代劳", "我帮你藏好吧") },
    @{ Name = "久岐忍结局5:荒泷派町街服务记录";      Dialog = @("默默退后半步") }
)

function Set-HangoutEnding {
    param([string]$EndingName)
    Write-Host "切换邀约结局: $EndingName" -ForegroundColor Cyan

    # 读取配置
    $config = Get-Content $ConfigPath -Raw | ConvertFrom-Json
    $config.autoSkipConfig.autoHangoutEndChoose = $EndingName
    $config.autoSkipConfig.autoHangoutEventEnabled = $true

    # 保存配置
    $config | ConvertTo-Json -Depth 100 | Set-Content $ConfigPath -Encoding UTF8
    Write-Host "  配置已保存" -ForegroundColor Green
}

function Restart-BetterGI {
    Write-Host "重启 BetterGI..." -ForegroundColor Yellow
    $proc = Get-Process -Name "BetterGI" -ErrorAction SilentlyContinue
    if ($proc) {
        Stop-Process -Id $proc.Id -Force
        Start-Sleep -Seconds 3
    }
    Start-Process $ExePath
    Start-Sleep -Seconds 5
    $proc = Get-Process -Name "BetterGI" -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Host "  BetterGI 已启动 (PID: $($proc.Id))" -ForegroundColor Green
    } else {
        Write-Host "  BetterGI 启动失败!" -ForegroundColor Red
    }
}

if ($All) {
    Write-Host "=== 久岐忍邀约任务 - 全5结局自动切换 ===" -ForegroundColor Magenta
    Write-Host ""
    Write-Host "注意: 每个结局完成后，需要手动在游戏内重新开始邀约任务" -ForegroundColor Yellow
    Write-Host "      然后按回车继续下一个结局" -ForegroundColor Yellow
    Write-Host ""

    for ($i = 0; $i -lt 5; $i++) {
        $ending = $Endings[$i]
        Write-Host ""
        Write-Host "--- 结局 $($i+1)/5: $($ending.Name) ---" -ForegroundColor Cyan
        Write-Host "    选项路径: $($ending.Dialog -join ' -> ')" -ForegroundColor Gray

        Set-HangoutEnding -EndingName $ending.Name
        Restart-BetterGI

        Write-Host ""
        Write-Host "现在请在原神内开启久岐忍的邀约任务" -ForegroundColor Yellow
        Write-Host "BetterGI 会自动选择对话选项，完成此结局后按回车继续..." -ForegroundColor Yellow
        Read-Host "按回车键继续到下一个结局"
    }

    Write-Host ""
    Write-Host "=== 全部5个结局已完成! ===" -ForegroundColor Magenta
}
elseif ($Ending -ge 1 -and $Ending -le 5) {
    $ending = $Endings[$Ending - 1]
    Write-Host "=== 久岐忍结局${Ending}: $($ending.Name) ===" -ForegroundColor Cyan
    Write-Host "选项路径: $($ending.Dialog -join ' -> ')" -ForegroundColor Gray
    Write-Host ""

    Set-HangoutEnding -EndingName $ending.Name
    Restart-BetterGI

    Write-Host ""
    Write-Host "配置已就绪，请在原神内开启久岐忍的邀约任务" -ForegroundColor Green
    Write-Host "BetterGI 会自动选择以下选项:" -ForegroundColor Green
    for ($i = 0; $i -lt $ending.Dialog.Count; $i++) {
        Write-Host "  $($i+1). $($ending.Dialog[$i])" -ForegroundColor White
    }
}
else {
    Write-Host "BetterGI 久岐忍邀约任务辅助脚本" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "用法:" -ForegroundColor Yellow
    Write-Host "  .\bgi_hangout_shinobu.ps1 -Ending 1   # 切换到结局1并重启BetterGI"
    Write-Host "  .\bgi_hangout_shinobu.ps1 -Ending 2   # 切换到结局2"
    Write-Host "  .\bgi_hangout_shinobu.ps1 -All         # 依次跑全部5个结局"
    Write-Host ""
    Write-Host "5个结局:" -ForegroundColor Yellow
    for ($i = 0; $i -lt 5; $i++) {
        Write-Host "  $($i+1). $($Endings[$i].Name)"
        Write-Host "     路径: $($Endings[$i].Dialog -join ' -> ')" -ForegroundColor Gray
    }
}
