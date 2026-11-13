# 定时上线会话 v3 (2026-09-17: 去钓鱼 + 接采矿组):
#   手动游戏保护 → 排程下线 → 杀残留 → BGI+截图器 → 游戏 → 2min安静+隐藏点击器进门 → F9
#   → 等一条龙流程完成标记 (轮询, 上限100min) → UIA 启动"白铁优先"采矿组 → RUNNING
# 关键设计:
#   - 钓鱼已从一条龙任务禁用 (费时间低收益, 用户决策 09-17); 流程=合成/每日/邮件/尘歌壶/地脉花
#   - 完成标记会出现 (~30-60min): 09-17 实测 64min 出现; 旧 v1 的 40min 只是太短, 并非标记不存在
#   - 流程结束后才 UIA 点组 —— 运行中点组会打断健康流程 (09-16 2h 死循环事故)
#   - 等待期间 PHASE 保持 STARTING, 看门狗不干预; 若流程卡死 (静默≥25min) → 置 RUNNING 让看门狗接手
$ErrorActionPreference = 'Continue'
$log = 'C:\Users\djf20\cycle_log.txt'
$base = 'D:\projects\betterGI'
$gameExe = 'E:\YS\miHoYo Launcher\games\Genshin Impact Game\YuanShen.exe'
$stateFile = 'C:\Users\djf20\session_state.txt'
# 每日收集标记 (书签续跑机制):
#   collection_done.txt     = 今日日期 → 今日已启动过收集, 下场从书签续跑
#   collection_finished.txt = 今日日期 → 今日已全部跑完, 下场只跑体力监控
#   collection_started.flag = 本场启动了收集大组 → 下线时据此更新上述标记
$collectDoneFile = 'C:\Users\djf20\collection_done.txt'
$collectFinishedFile = 'C:\Users\djf20\collection_finished.txt'
$collectStartFlag = 'C:\Users\djf20\collection_started.flag'
$groupJson = "$base\User\ScriptGroup\全自动循环.json"
$configJson = "$base\User\config.json"
function Log($msg) { "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $msg" | Out-File $log -Append -Encoding utf8 }

# 读最新日志新增内容的小工具 (按字节偏移, 绕独占锁)
$script:offset = 0
function Read-NewLog {
  $f = Get-ChildItem "$base\log\*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $f) { return '' }
  try {
    $fs = [System.IO.FileStream]::new($f.FullName, 'Open', 'Read', 'ReadWrite')
    $len = $fs.Length
    if ($len -lt $script:offset) { $script:offset = 0 }
    $fs.Seek($script:offset, 'Begin') | Out-Null
    $sr = [System.IO.StreamReader]::new($fs, [Text.Encoding]::UTF8)
    $txt = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
    $script:offset = $len
    return $txt
  } catch { return '' }
}

# 等配置组真正加载完成 (以 BGI 日志的 "配置组 "xxx" 加载完成" 为准), 超时返回 $false
# 11-10 修复: 旧逻辑用 '地图追踪|开始执行|配置组' 匹配, BGI 自己的报错
# "读取配置组配置时失败" 也含"配置组", 组根本没加载也会被判成功
function Wait-GroupLoaded($name, $seconds) {
  $until = (Get-Date).AddSeconds($seconds)
  while ((Get-Date) -lt $until) {
    Start-Sleep -Seconds 15
    if ((Read-NewLog) -match ('配置组\s+"?' + [regex]::Escape($name) + '"?\s+加载完成')) { return $true }
  }
  return $false
}

# 启动截图器并检查返回值 (P0-3, 11-13): 旧代码 4 处调用都不查 $LASTEXITCODE,
# "窗口未找到/启动按钮未找到"被无视继续跑。失败自动重试一次, 仍失败返回 $false。
function Start-CaptureChecked($stage) {
  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
  $capExit = $LASTEXITCODE
  if ($capExit -ne 0) {
    Log "警告: 截图器启动失败 ($stage, exit=$capExit), 5s 后重试一次"
    Start-Sleep -Seconds 5
    & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_capture.ps1
    $capExit = $LASTEXITCODE
  }
  if ($capExit -ne 0) { Log "警告: 截图器启动两次失败 ($stage, exit=$capExit), 需人工检查" }
  return ($capExit -eq 0)
}

# 启动配置组 (P0-2, 11-13): BGI 版本与已验证版本不一致时先 DryRun 校验 UIA 导航链路,
# 导航失效就不再盲跑 (界面文案硬编码, 0.64.2 曾把"执行"改成"运行"导致全线失效)。
function Start-GroupChecked($name, $dryFirst) {
  if ($dryFirst) {
    & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_group_named.ps1 -NameMatch $name -DryRun | Out-Null
    if ($LASTEXITCODE -ne 0) { Log "DryRun 导航校验失败 ($name), 判定 UIA 链路因版本更新失效, 不再盲跑组"; return $false }
    Log "DryRun 导航校验通过 ($name)"
  }
  for ($i = 1; $i -le 2; $i++) {
    & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\uia_start_group_named.ps1 -NameMatch $name
    $uiaExit = $LASTEXITCODE
    if ($uiaExit -eq 0 -and (Wait-GroupLoaded $name 60)) { Log "组已启动 (第 $i 次尝试): $name"; return $true }
    Log "第 $i 次启动组失败 (uiaExit=$uiaExit): $name"
  }
  return $false
}

# 顶号检测: MiHoYoSDK.log 每次进门都会新增一条 "into LoginManager::Login"
# 被顶号→回门→点击器重进→必多一条登录记录; 轮次内新增≥2 = 用户在其他设备手动登录 → 跳过本轮
$sdkLog = "$env:USERPROFILE\AppData\LocalLow\miHoYo\" + [char]0x539F + [char]0x795E + "\logs\MiHoYoSDK.log"
function Count-Logins {
  try { return (Select-String -Path $sdkLog -Pattern 'into LoginManager::Login' -Encoding UTF8 -ErrorAction Stop | Measure-Object).Count }
  catch { return -1 }
}
$script:loginBase = 0
# 顶号判定: delta = 当前登录数 - 基线; 1=自己开局, 之后每+1=被顶号重进一次
# 用户规则: 重复登录(被顶)≥2次 = 用户在手动玩 → 跳过本轮 (即 delta≥3 触发)
function Skip-IfRelogin($stage) {
  if ($script:loginBase -lt 0) { return }
  $now = Count-Logins
  $delta = $now - $script:loginBase
  if ($now -ge 0 -and $delta -ge 3) {
    Log "检测到账号重复登录 $($delta - 1) 次 ($stage), 判定用户手动登录中, 跳过本轮一条龙 → 直接下线"
    & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\cycle_offline.ps1
    exit 0
  }
}

Log "=== 定时上线会话开始 (v3) ==="
Set-Content 'C:\Users\djf20\session_start.txt' (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding UTF8

# 0.00 场次时长 (2026-10-12 用户定: 恢复午场; 早 5h / 午 4h / 晚 3h, 每天最长 12h; 跑完由看门狗提前下线)
#   按触发时刻归属: 04-11 点=早场, 12-17 点=午场 (周末跳过), 其余=晚场 (晚场 23:00+3h=02:00, 不压早场)
$h = (Get-Date).Hour
if ($h -ge 4 -and $h -lt 12) { $sessName = '早场'; $sessHours = 5 }
elseif ($h -ge 12 -and $h -lt 18) {
  # 周末不跑午场 (用户周末中午自己上线; 10-12 定)
  if ((Get-Date).DayOfWeek -in 'Saturday', 'Sunday') { Log "周末无午场 (当前 $h 点), 本次触发跳过"; exit 0 }
  $sessName = '午场'; $sessHours = 4
}
else { $sessName = '晚场'; $sessHours = 3 }
Log "场次: $sessName, 窗口 ${sessHours}h"

# 0.00a BGI 版本门禁 (P0-2, 11-13): 托管链对界面文案/窗口标题/日志文案全是硬编码, BGI 升级后
#   任何一处漂移都静默失效。启动时读 FileVersion 写日志; 与已验证版本不一致 → 组启动前先 DryRun。
$bgiVer = ''
try { $bgiVer = (Get-Item "$base\BetterGI.exe").VersionInfo.FileVersion } catch { Log "警告: 读取 BGI 版本失败: $($_.Exception.Message)" }
$verFile = 'C:\Users\djf20\bgi_verified_version.txt'
$dryRunFirst = $false
if ($bgiVer) {
  Log "BGI 版本: $bgiVer"
  if (Test-Path $verFile) {
    $verifiedVer = (Get-Content $verFile -Encoding UTF8 -First 1).Trim()
    if ($verifiedVer -ne $bgiVer) {
      Log "警告: BGI 版本 $bgiVer ≠ 已验证版本 $verifiedVer → 本场组启动前先 DryRun 校验 UIA 导航"
      $dryRunFirst = $true
    }
  } else {
    Set-Content $verFile $bgiVer -Encoding UTF8
    Log "已记录当前 BGI 版本为已验证版本 ($bgiVer)"
  }
}

# 0.00b 领取每日奖励按场次开关 (2026-11-10): 早场 04:15 时当日委托基本都没做完,
#   一条龙只会记 "未完成或者已领取" 并被判成失败项 (白跑一次补跑 F9), 所以早场关掉,
#   午场/晚场再领 (委托完成后才有奖励可领)
$odCfg = "$base\User\OneDragon\默认配置.json"
try {
  $t = [System.IO.File]::ReadAllText($odCfg)
  $want = if ($sessName -eq '早场') { 'false' } else { 'true' }
  $pat = '("7b2c7f0c-998b-4b82-8854-e33b84c500c7"\s*:\s*)(true|false)'
  # 11-13 (P1-2): GUID 正则不命中时 BGI 更新可能改了结构, 静默跳过 = 场次开关失效, 必须报出来
  $mOd = [regex]::Match($t, $pat)
  if (-not $mOd.Success) {
    Log "警告: 一条龙配置未命中领取每日奖励 GUID (7b2c7f0c-…), BGI 更新可能已改配置结构, 场次开关未生效!"
  } elseif ($mOd.Groups[2].Value -ne $want) {
    $t = [regex]::Replace($t, $pat, "`${1}$want")
    [System.IO.File]::WriteAllText($odCfg, $t, (New-Object System.Text.UTF8Encoding($false)))
    Log "一条龙: 领取每日奖励 = $want ($sessName)"
  }
} catch { Log "一条龙配置改写失败: $($_.Exception.Message)" }

# 0.01 实例锁
$me = $PID
$dups = @(Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
  $_.ProcessId -ne $me -and $_.CommandLine -match 'session_online\.ps1' })
if ($dups.Count -gt 0) { Log "已有 session_online 实例 (PID $($dups[0].ProcessId)) 在跑, 本实例退出"; exit }

# 0.02 读旧 PHASE (手动游戏保护判定用, 必须在覆写前读)
$oldPhase = ''
if (Test-Path $stateFile) {
  Get-Content $stateFile -Encoding UTF8 | ForEach-Object { if ($_ -match '^PHASE=(.+)$') { $oldPhase = $Matches[1].Trim() } }
}

# 0.03 手动游戏保护: OFFLINE + 游戏在跑 + BGI 没在跑 = 用户自己开的游戏 → 跳过本场次
$ys0 = Get-Process YuanShen -ErrorAction SilentlyContinue
$bgi0 = Get-Process BetterGI -ErrorAction SilentlyContinue
if ($oldPhase -eq 'OFFLINE' -and $ys0 -and -not $bgi0) {
  Log "检测到手动游戏 (PHASE=OFFLINE, 游戏在跑, BGI 未跑), 跳过本场次, 不杀游戏"
  exit 0
}

# 0.1 代理自愈
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\fix_proxy.ps1 | Out-Null

# 1. 排程 场次时长 后强制下线 (安全网)
# 11-13 (P1-5): 看门狗恢复时写入 session_resume.txt (原 ACTIVE_UNTIL) → 沿用原下线点,
#   不再"恢复时刻+场次时长"把窗口往后推 (旧: 早场 08:54 恢复 → 下线 13:54 与午场重叠)
$off = (Get-Date).AddHours($sessHours)
$resumeFile = 'C:\Users\djf20\session_resume.txt'
if (Test-Path $resumeFile) {
  try {
    $ru = [DateTime]::ParseExact((Get-Content $resumeFile -Encoding UTF8 -First 1).Trim(), 'yyyy-MM-dd HH:mm:ss', $null)
    if ($ru -gt (Get-Date)) { $off = $ru; Log "恢复会话: 沿用原下线时间 $($ru.ToString('MM-dd HH:mm'))" }
    else { Log "恢复标记已过期 ($($ru.ToString('MM-dd HH:mm'))), 按场次重新排程" }
  } catch { Log "恢复标记解析失败, 按场次重新排程" }
  Remove-Item $resumeFile -Force -ErrorAction SilentlyContinue
}
schtasks /create /tn BGI_SessionEnd /tr "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\cycle_offline.ps1" /sc once /st $off.ToString('HH:mm') /sd $off.ToString('dd/MM/yyyy') /rl highest /f | Out-Null
Log "已预排程下线: $($off.ToString('MM-dd HH:mm'))"

# 2. PHASE=STARTING
Set-Content $stateFile ("PHASE=STARTING`nACTIVE_UNTIL=" + $off.ToString('yyyy-MM-dd HH:mm:ss')) -Encoding UTF8

# 3. 杀残留 (能走到这说明: 无游戏, 或是我们自己会话的残留)
Stop-Process -Name YuanShen -Force -ErrorAction SilentlyContinue
Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# 4. 起 BGI + 截图器 (P0-3: 调用检查返回值; 失败则一场全废, 直接中止)
schtasks /run /tn BetterGI_Run | Out-Null
Log "BGI 经 BetterGI_Run 启动, 等 75s"
Start-Sleep -Seconds 75
if (-not (Start-CaptureChecked '初始启动')) {
  Log "警告: 截图器无法启动, F9/一条龙必然落空 → 中止本场 (保持 STARTING, 看门狗超时规则接管)"
  exit 1
}
Start-Sleep -Seconds 5

# 5. 起游戏, 安静等 30s (10-12 用户要求缩短: 本机加载快; 截图器已开时 BGI 联动起游戏,
#    其 GameLoading 触发器在截图器启动后 5 分钟内自动点"点击进入"+空月祝福+原石, 点击器只是兜底)
$script:loginBase = Count-Logins   # 顶号检测基线 (游戏未起, 此刻计数为历史值)
Log "顶号检测基线: SDK登录历史 $script:loginBase 次"
if (-not (Get-Process YuanShen -ErrorAction SilentlyContinue)) {
  Start-Process $gameExe
  Log "游戏已直起"
}
Log "安静等待 30s (不点不碰)..."
Start-Sleep -Seconds 30

# 6. 隐藏点击器进门 (6s/次 × 180s, wscript 隐藏不抢焦点)
& wscript.exe C:\Users\djf20\run_hidden.vbs door_clicker2.ps1
Log "隐藏点击器已启动 (6s/次), 180s 后停止"
Start-Sleep -Seconds 180
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
  Where-Object { $_.CommandLine -match 'door_clicker2' } |
  ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Log "点击器已停止"
Skip-IfRelogin '进门阶段'

# 7. 重启截图器 (关键: 必须进门后再起 —— 游戏窗口不存在时起截图器会静默失败, F9 随后落空; 09-17 16:10 事故)
#    P0-3: 已在运行时新 capture 脚本会返回"已在运行" (exit 0), 不再误报
Start-CaptureChecked '进门后重启' | Out-Null
Start-Sleep -Seconds 10

# 7.5 分辨率守卫 (11-08: 游戏被调成全屏 2560x1600(16:10) → BGI 只支持 16:9,
#     一条龙与地图追踪全部秒失败, 白跑一整场。开局前校验, 非 16:9 直接中止本场)
try {
  if (-not ('BgiGameWin' -as [type])) {
    Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public class BgiGameWin { [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left; public int Top; public int Right; public int Bottom; } [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr hWnd, out RECT lpRect); }'
  }
  $gw = Get-Process YuanShen -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne 0 } | Select-Object -First 1
  if ($gw) {
    $rect = New-Object BgiGameWin+RECT
    if ([BgiGameWin]::GetClientRect($gw.MainWindowHandle, [ref]$rect)) {
      $gwW = $rect.Right - $rect.Left
      $gwH = $rect.Bottom - $rect.Top
      if ($gwH -gt 0) {
        $ratio = $gwW / $gwH
        if ([math]::Abs($ratio - (16.0 / 9.0)) -gt 0.05) {
          Log "警告: 游戏分辨率 ${gwW}x${gwH} (比例 $([math]::Round($ratio, 2))) 非 16:9 → BGI 无法执行任何任务, 本场中止 (请改回 2560x1440 或 1920x1080)"
          Set-Content 'C:\Users\djf20\resolution_warning.txt' "游戏分辨率 ${gwW}x${gwH} 非 16:9, $(Get-Date -Format 'yyyy-MM-dd HH:mm') 跳过了本场" -Encoding UTF8
          Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
          Stop-Process -Name YuanShen -Force -ErrorAction SilentlyContinue
          schtasks /delete /tn BGI_SessionEnd /f 2>&1 | Out-Null
          Set-Content $stateFile "PHASE=OFFLINE`nACTIVE_UNTIL=" -Encoding UTF8
          Log "=== 本场因分辨率非 16:9 中止 (未执行任何任务) ==="
          exit 2
        }
        Log "分辨率校验通过: ${gwW}x${gwH} (16:9)"
      }
    }
  } else { Log "警告: 未取到游戏窗口句柄, 跳过分辨率校验" }
} catch { Log "分辨率校验异常 (忽略): $($_.Exception.Message)" }

# 8. F9 一条龙 + 快速验证 (P1-1, 11-13): 旧判据 "180s 日志新增 ≥200 字符" 太弱 —
#    截图器/GameLoading/月卡日志都能凑够 200 字符, F9 没落上也判通过 (11-10 下午 6 次"已发送"0 次生效)。
#    改为匹配一条龙启动的具体文案; 发送前先校验 config.json 的 onedragonHotkey 仍是 F9。
$odHotkey = ''
try {
  $hkObj = Get-Content $configJson -Raw -Encoding UTF8 | ConvertFrom-Json
  $odHotkey = $hkObj.onedragonHotkey
} catch { Log "警告: 读取 onedragonHotkey 失败: $($_.Exception.Message)" }
if ($odHotkey -and $odHotkey -ne 'F9') { Log "警告: config.json onedragonHotkey=$odHotkey (≠F9), 发送的 F9 不会触发一条龙!" }
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\send_f9.ps1
Log "F9 已触发"
Read-NewLog | Out-Null   # 锚定偏移: 之后只读新增
Start-Sleep -Seconds 180
$probe = Read-NewLog
if ($probe -notmatch '启用一条龙配置|一条龙任务执行') {
  Log "警告: F9 后 180s 无一条龙启动记录 (日志 $($probe.Trim().Length) 字符), 补截图器 + 重发 F9"
  Start-CaptureChecked 'F9补发前' | Out-Null
  Start-Sleep -Seconds 10
  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\send_f9.ps1
  Start-Sleep -Seconds 120
  Read-NewLog | Out-Null
}

# 9. 等一条龙流程完成 (标记: 一条龙.*任务结束; 每 2min 轮询, 上限 100min)
$done = ($probe -match '一条龙.{0,6}任务结束'); $stuck = $false  # 修复09-18: probe 可能已吞完成标记(一条龙跑得快时)
$odText = $probe   # 累积本轮一条龙日志, 完成后判断是否失败 (10-12: 补跑逻辑用)
$sw = [Diagnostics.Stopwatch]::StartNew()
$silentMin = 0
while (-not $done -and $sw.Elapsed.TotalMinutes -lt 100) {
  Start-Sleep -Seconds 120
  Skip-IfRelogin '一条龙等待'
  $new = Read-NewLog
  $odText += $new
  if ($new -match '一条龙.{0,6}任务结束') { $done = $true; break }
  if ($new.Trim().Length -gt 0) { $silentMin = 0 } else { $silentMin += 2 }
  if ($silentMin -ge 25) { $stuck = $true; break }   # 流程卡死: 交给看门狗恢复
}
if ($done) { Log "一条龙流程已完成 (耗时 $([int]$sw.Elapsed.TotalMinutes) 分钟), 启动采矿组" }

# 9.5 一条龙失败补跑 (10-12 排查: 09-25~10-12 有 6 天一次"今日奖励已领取"都没有;
#     失败场次的共同特征 = F9 时游戏不在主界面 (队伍识别全"未知角色" / 打开大地图失败)
#     → 合成树脂/委托奖励/尘歌壶 全部空跑。BGI 重跑一条龙会跳过已完成项, 只补失败的)
$odFail = '打开大地图失败|合成树脂执行异常|未能返回主界面|未知角色,未知角色'
# 11-11 修复: 早场已禁用"领取每日奖励", 但 BGI 内置的奖励检查照样打 "结果：未领取" →
#   宽匹配把它当失败项, 早场每次白跑一轮补跑 F9。只在午场/晚场(该任务启用)时才计入。
if ($sessName -ne '早场') { $odFail += '|结果："未领取"' }
if ($done -and $odText -match $odFail) {
  Log "一条龙有失败项 (匹配: $($Matches[0])), 点 3 下中心 + 关弹窗 + 截图存证 + 补跑 F9 一次"
  # 早场必有月卡: 空月祝福/原石界面只认点击不认 ESC (BGI 自带的月卡任务只在 03:55~04:05 生效)
  for ($k = 0; $k -lt 3; $k++) {
    & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\enter_door.ps1 | Out-Null
    Start-Sleep -Seconds 4
  }
  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\esc_s1.ps1 | Out-Null
  $shot = 'C:\Users\djf20\screen.png'
  if (Test-Path $shot) { Copy-Item $shot ("C:\Users\djf20\od_fail_" + (Get-Date -Format 'yyyyMMdd_HHmm') + '.png') -Force }
  Start-Sleep -Seconds 15
  Read-NewLog | Out-Null
  & powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\send_f9.ps1
  $retryText = ''; $retryDone = $false
  $sw2 = [Diagnostics.Stopwatch]::StartNew()
  while ($sw2.Elapsed.TotalMinutes -lt 30) {
    Start-Sleep -Seconds 60
    $new = Read-NewLog
    $retryText += $new
    if ($new -match '一条龙.{0,6}任务结束') { $retryDone = $true; break }
  }
  if (-not $retryDone) { Log "警告: 补跑一条龙 30 分钟未结束, 继续启动采矿组" }
  elseif ($retryText -match $odFail) { Log "警告: 补跑后仍有失败项 (匹配: $($Matches[0])), 需人工检查 (截图 od_fail_*.png)" }
  else { Log "补跑一条龙成功 (耗时 $([int]$sw2.Elapsed.TotalMinutes) 分钟)" }
}
elseif ($stuck) {
  Log "警告: 等待期间日志静默 ≥25 分钟, 流程疑似卡死 → 置 RUNNING 让看门狗恢复, 本场不启动采矿"
  Set-Content $stateFile ("PHASE=RUNNING`nACTIVE_UNTIL=" + $off.ToString('yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
  exit 1
}
elseif (-not $done) { Log "警告: 等完成标记超时 (100 分钟), 仍尝试启动采矿组" }

# 10. 启动收集大组 (书签续跑) 或体力监控组
#     - 今日已全部跑完 (collection_finished.txt=今日) → 只跑体力监控
#     - 今日已启动过但未跑完 → 启动全自动循环, BGI 自动从 config.json 的 nextScheduledTask 书签续跑
#     - 今日首场 → 清空书签从头启动全自动循环
# 采集日: 以凌晨4点(游戏刷新)为界, 00:00-03:59 属于前一天 — 保证跨午夜场次(如 00:30)不误判为新的一天而全量重跑
$nowDt = Get-Date
$today = if ($nowDt.Hour -lt 4) { $nowDt.AddDays(-1).ToString('yyyy-MM-dd') } else { $nowDt.ToString('yyyy-MM-dd') }

# 手动补跑覆盖 (11-08): force_group.txt 写好组名 → 本场强制启动该收集组 (读后即删, 一次性)
$forceFile = 'C:\Users\djf20\force_group.txt'
$forceGroup = ''
if (Test-Path $forceFile) {
  $forceGroup = (Get-Content $forceFile -Encoding UTF8 -Raw).Trim()
  Remove-Item $forceFile -Force -ErrorAction SilentlyContinue
  if ($forceGroup) { Log "手动覆盖: 本场强制启动收集组 [$forceGroup]" }
}

# 读组总任务数 & 书签 (11-13 P1-2: 进度改存 C:\Users\djf20\bookmark.json, item2 为 0-based
# 由 set_bookmark.py 写入; 旧口径读 config.json nextScheduledTask 的注释 "1-based" 是错的, 一并纠正)
$groupObj = Get-Content $groupJson -Raw -Encoding UTF8 | ConvertFrom-Json
$totalTasks = $groupObj.projects.Count
$bookmarkIdx = 0
try {
  $bmObj = Get-Content 'C:\Users\djf20\bookmark.json' -Raw -Encoding UTF8 | ConvertFrom-Json
  if ($bmObj.item2) { $bookmarkIdx = [int]$bmObj.item2 }
} catch { }

# 今日是否已全部跑完
$finishedToday = $false
if (Test-Path $collectFinishedFile) {
  $finDate = (Get-Content $collectFinishedFile -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
  if ($finDate -eq $today) { $finishedToday = $true }
}

if ($finishedToday) {
  Log "今日收集已全部跑完, 跳过收集大组, 本场仅 F9 一条龙 + 体力监控组"
  if (Start-GroupChecked '体力监控' $dryRunFirst) {
    $tailMsg = '本场跳过收集大组 (仅日常+体力)'
  } else {
    Log "警告: 体力监控组未启动成功, 需人工检查"
    $tailMsg = '体力监控组启动失败 (需人工检查)'
  }
} else {
  # 今日首场判定 (10-15 修复): collection_started.flag 由本场部署时写入(下方),
  # 会话崩溃未走下线时 collection_done.txt 仍是昨日 → 旧逻辑只查 done 文件,
  # 误判"今日首场" → 清书签从头重跑 (10-15 早场 08:17 崩溃后 08:24 恢复 + 13:00 午场 三重从头跑的根因)
  $startedBefore = $false
  foreach ($mf in @($collectDoneFile, $collectStartFlag)) {
    if (Test-Path $mf) {
      $md = (Get-Content $mf -Encoding UTF8 -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
      if ($md -eq $today) { $startedBefore = $true; break }
    }
  }
  if ($forceGroup) {
    Log "手动覆盖: 清空书签, 从组头启动 [$forceGroup]"
    & python 'C:\Users\djf20\set_bookmark.py' CLEAR 2>&1 | ForEach-Object { Log "bookmark: $_" }
  } elseif ($startedBefore) {
    # 今日已启动过收集 (续跑/看门狗恢复/崩溃重开): 从日志校准断点, 绝不清书签重跑
    # (10-09 教训: 13:00 场次重启后从头重跑, 重复收集约 1 小时)
    Log "今日收集续跑: 书签 idx $bookmarkIdx, 从今日日志校准断点 (避免从头重复收集)"
    $bkOut = & python 'C:\Users\djf20\set_bookmark.py' 2>&1
    $bkOut | ForEach-Object { Log "bookmark: $_" }
  } elseif ($sessName -eq '午场') {
    # 早场整场未跑收集 (手动保护/跳过): 优先尾部稀缺材料, 从头启动 B 组
    Log "午场: 今日收集未启动, 清书签从头启动 收集B组"
    & python 'C:\Users\djf20\set_bookmark.py' CLEAR 2>&1 | ForEach-Object { Log "bookmark: $_" }
  } elseif ($sessName -eq '早场') {
    # 早场今日首场: 清书签从头
    Log "早场今日收集首场, 清空书签从头开始"
    & python 'C:\Users\djf20\set_bookmark.py' CLEAR 2>&1 | ForEach-Object { Log "bookmark: $_" }
  } else {
    # 10-21 修复: 晚场 + 今日未启动过收集 → 跳过收集, 只跑一条龙
    # (之前误判晚场为"今日首场"清书签, 又 fallback 到全自动循环 103 条全组重跑
    #  — 跨午夜看门狗恢复 session 时凌晨跑一遍 00:05→02:54, 午场续跑又跑一遍)
    Log "晚场 + 今日未启动过收集 → 跳过收集大组, 本场仅日常一条龙 (不启动任何组)"
    Set-Content $stateFile ("PHASE=RUNNING`nACTIVE_UNTIL=" + $off.ToString('yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
    Log "=== 上线会话部署完毕 (v3), 本场仅日常一条龙 (下线由 BGI_SessionEnd 兜底) ==="
    exit 0
  }
  # P0-1 (11-13): 收集标记只在组真正启动成功后才写 (旧代码在这就写, 启动失败也不撤销 →
  #   看门狗见 flag 存在 + 一条龙结束 → 误判 -Complete → 当天收集被跳过)
  # 选启动组 (10-15 分组: 主组104条 = 收集A组50(早场) + 收集B组54(午场)):
  #   书签>0 且续跑组文件存在 → "续跑收集组" (BGI nextScheduledTask 反序列化 bug 规避);
  #   否则按场次: 早场=收集A组, 午场=收集B组, 晚场跳过 (10-21 修复)
  $groupMatch = ''
  $resumeGroupFile = 'D:\projects\betterGI\User\ScriptGroup\续跑收集组.json'
  $bk = 0
  try {
    $bmNow = Get-Content 'C:\Users\djf20\bookmark.json' -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($bmNow.item2) { $bk = [int]$bmNow.item2 }
  } catch { Log "读取 bookmark.json 失败: $($_.Exception.Message)" }
  if ($forceGroup) {
    $groupMatch = $forceGroup
    Log "手动覆盖生效, 本场启动组: $groupMatch"
  } elseif ($bk -gt 0 -and (Test-Path $resumeGroupFile)) {
    $groupMatch = '续跑收集组'
    Log "续跑组文件存在 (书签 idx $bk), 将启动子组: 续跑收集组"
  } elseif ($sessName -eq '早场') {
    $groupMatch = '收集A组'
    Log "无续跑组 (书签 idx $bk), 将启动早场专属组: 收集A组"
  } elseif ($sessName -eq '午场') {
    $groupMatch = '收集B组'
    Log "无续跑组 (书签 idx $bk), 将启动午场专属组: 收集B组"
  } else {
    # 10-21 修复: 晚场无续跑组 → 跳过收集 (不是全自动循环!)
    Log "晚场无续跑组 (书签 idx $bk), 跳过收集大组, 本场仅日常一条龙"
    Set-Content $stateFile ("PHASE=RUNNING`nACTIVE_UNTIL=" + $off.ToString('yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
    Log "=== 上线会话部署完毕 (v3), 本场仅日常一条龙 (下线由 BGI_SessionEnd 兜底) ==="
    exit 0
  }
  # BGI 已在跑时其内存书签是启动时加载的旧值, config.json 新写的书签不生效
  # (10-13 午场教训: 早场未正常下线 → BGI 未重启 → 午场无视书签从组头重跑 85 条)
  # → 启动收集组前若 BGI 在跑, 重启 BGI 让它重新加载 config.json
  $bgiProc = Get-Process BetterGI -ErrorAction SilentlyContinue
  if ($bgiProc) {
    Log "BGI 已在运行 (PID $($bgiProc.Id -join ',')), 重启以加载最新书签"
    Stop-Process -Name BetterGI -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 6
    schtasks /run /tn BetterGI_Run | Out-Null
    Log "BGI 经 BetterGI_Run 重启, 等 75s"
    Start-Sleep -Seconds 75
    # 11-10 修复: 重启 BGI 只为重读书签, 不要杀游戏 (旧代码连 YuanShen 一起 Stop → 游戏再也没起来);
    # 截图器随 BGI 进程消失, 必须补点"启动", 否则 BGI 不联动拉起游戏, 组点了也跑不了
    Start-CaptureChecked '重启BGI后' | Out-Null
    Start-Sleep -Seconds 10
    if (-not (Get-Process YuanShen -ErrorAction SilentlyContinue)) {
      Start-Process $gameExe
      Log "重启 BGI 后游戏缺失, 已直起游戏"
      Start-Sleep -Seconds 30
    }
    if (-not (Get-Process YuanShen -ErrorAction SilentlyContinue)) {
      Log "警告: 重启 BGI 后游戏仍未运行, 收集组无法执行"
    }
  }
  $groupStarted = Start-GroupChecked $groupMatch $dryRunFirst
  if ($groupStarted) {
    # P0-1: 组真正启动成功才写收集标记 (下线时据此更新 done/finished)
    Set-Content $collectStartFlag $today -Encoding UTF8
    $tailMsg = "收集大组运行中 ($groupMatch, 书签续跑)"
  } else {
    Log "警告: 收集组 [$groupMatch] 未启动成功 (游戏在跑=$([bool](Get-Process YuanShen -ErrorAction SilentlyContinue))), 本场收集未运行"
    $shot = 'C:\Users\djf20\screen.png'
    if (Test-Path $shot) { Copy-Item $shot ("C:\Users\djf20\collect_fail_" + (Get-Date -Format 'yyyyMMdd_HHmm') + '.png') -Force }
    Log "警告: 收集组启动失败 → 不写收集标记/不置 RUNNING, 保持 STARTING 退出 (看门狗 STARTING 超时规则接管重试)"
    exit 1
  }
}

# 11. PHASE=RUNNING: 看门狗开始监护
Set-Content $stateFile ("PHASE=RUNNING`nACTIVE_UNTIL=" + $off.ToString('yyyy-MM-dd HH:mm:ss')) -Encoding UTF8
Log "=== 上线会话部署完毕 (v3), $tailMsg (下线由 BGI_SessionEnd 兜底) ==="
