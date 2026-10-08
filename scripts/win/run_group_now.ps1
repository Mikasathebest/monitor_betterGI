# 立即跑大组(全自动循环, 大世界队伍): 重启 BGI 加载新配置 → 截图器 → 启动大组
# 必须在 Session 1 运行 (计划任务 InteractiveToken); 不动游戏进程, 避免卡门风险
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\run_now_log.txt'
function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

Log "=== 立即跑大组开始 ==="

# 1. 重启 BGI (加载 partyName=大世界 的新组配置); 游戏不动
Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3
schtasks /run /tn BetterGI_Run | Out-Null
Log "BGI 经 BetterGI_Run 重启, 等 75s"
Start-Sleep -Seconds 75

# 2. 截图器 (按钮不存在=已在跑, 正常继续)
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
Log "截图器已触发"
Start-Sleep -Seconds 5

# 3. 启动大组 (书签续跑; 组配置 partyName=大世界 → 开局自动切队)
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_group_named.ps1 -NameMatch '全自动循环'
Log "大组启动指令已发 (全自动循环)"
Log "=== 部署完毕 ==="
