# TODO：BGI 更新后运行失败 — 代码排查记录

> 排查日期：2026-11-10，2026-11-12 按 `fa26209`（11-11 的修复）重新核对，行号均对应该提交。
> 范围：`scripts/win/prod/` 生产链路（上线会话 / 看门狗 / 下线 / UIA 启动 / 书签）。
>
> **口径说明**：本次是纯静态代码审查。Mac 本机没有 `.env`，也没有拉回的 `cycle_log.txt` / `watchdog_log.txt` / BGI 日志，
> 所以下面每条都是「代码里确实存在的缺陷」，但**哪一条是更新后失败的真凶尚未用日志证实**。
> 定位真凶需要的证据见文末「下一步取证」。

## 结论

托管链对 BGI 的依赖全部是**隐式硬编码**（界面文案、窗口标题、日志文案、config/组 JSON 结构、热键），
并且多数步骤失败后流程照常往下走。BGI 一更新，任何一个硬编码点漂移，都不会当场报错。

11-10 / 11-11 的两次修复已经补上了一部分（组启动校验、不再杀游戏、切回游戏前台），
但同时引入了一个新问题（P0-0，11-12 已在仓库修复，待部署）。

---

## P0 — 会导致整场/整天失效

### [x] P0-0 下线脚本的「手动游戏保护」判断写错，游戏在跑时永远不下线（11-10 引入，11-12 已修）

- 修复：只取 `PHASE` 一行比较；`STARTING` 也视为自己的会话允许下线。**仓库已改，尚未部署到 Windows**：
  `python3 scripts/win_sync.py push cycle_offline.ps1`。

- 位置：`cycle_offline.ps1:23-30`
- 问题：`$phase` 是把整个 `session_state.txt` 去掉空白后的字符串。会话运行时文件内容是两行
  `PHASE=RUNNING` + `ACTIVE_UNTIL=2026-...`（`session_online.ps1:427`），去空白后是
  `PHASE=RUNNINGACTIVE_UNTIL=2026-...`，与 `'PHASE=RUNNING'` 永远不相等。
  于是只要游戏在跑，`:28` 恒成立 → 记一行「用户手动在玩, 跳过不杀」→ `exit 0`。
- 后果：
  - `BGI_SessionEnd` 到点兜底不生效，看门狗的提前下线（`watchdog.ps1:76`、`:79`）也不生效，游戏和 BGI 一直挂着。
  - 书签不保存，`collection_done.txt` / `collection_finished.txt` 不更新，`set_travel_config.py` 不执行。
  - `PHASE` 一直停在 RUNNING，看门狗每 30 分钟按「日志静默」重复判定。
- 核实方法：`cycle_log.txt` 里 11-10 之后是否每次下线都是「PHASE=PHASE=RUNNINGACTIVE_UNTIL=… 但游戏在跑」。
- 建议：按行解析，只取 `PHASE` 一行：
  ```powershell
  $phase = ''
  Get-Content $stateFile -Encoding UTF8 | ForEach-Object { if ($_ -match '^PHASE=(.+)$') { $phase = $Matches[1].Trim() } }
  if ($ys -and $phase -ne 'RUNNING') { ... }
  ```
  另外 `Skip-IfRelogin`（`session_online.ps1` 顶号检测）是在 `PHASE=STARTING` 时调用下线的，
  需确认那种情况下「不杀游戏」是否符合预期。

### [ ] P0-1 收集组启动失败后，看门狗仍可能把当天标记为「已全部跑完」（11-10 已修一半）

- 位置：`session_online.ps1:352`、`:407-424`、`:427`；`watchdog.ps1:74-76`；`cycle_offline.ps1:87` 起
- 已修：组启动现在检查 UIA 返回值，并用 `Wait-GroupLoaded` 等 `配置组 "x" 加载完成`；
  失败时写「警告: 收集组未启动成功」，不再谎报「运行中」。
- 仍存在：
  1. `:352` 在点「运行」**之前**就写了 `collection_started.flag`，启动失败也不撤销。
  2. 启动失败后仍走到 `:427` 置 `PHASE=RUNNING`，只有一行日志，没有推送，没有非零退出。
  3. 日志静默 25 分钟后，`watchdog.ps1:74` 只要最后一个完成标记是「一条龙…任务结束」就调用
     `cycle_offline.ps1 -Complete`；下线脚本见 flag 存在 + Complete → 写 `collection_finished.txt=今日` 并清书签。
     当天午场、晚场只跑体力监控，**收集全天跳过**。
- 不确定点：第 3 步要求完成标记与日志最后一行相差 ≤5 分钟（`watchdog.ps1:68`）。一条龙之后 BGI 会被重启，
  重启日志可能把间隔撑过 5 分钟；那样走的是「重拉整个会话」分支（现在每日上限 4 次）。
  （P0-0 修复前，这条链会被 P0-0 挡住，表现为不下线。）
- 建议：
  - flag 改到 `$groupStarted = $true` 之后再写。
  - 启动失败时截图存证 + 飞书推送 + `exit 1`。
  - `watchdog.ps1:74` 的「一条龙结束 = Complete」只在 flag 不存在时成立；
    flag 存在而没有任何 `配置组…执行结束`，应判为「收集没起来」并报警。

### [ ] P0-2 UIA 导航全靠界面文案硬编码，没有版本感知

- 位置：`uia_start_group_named.ps1:57`、`:137`、`:141`、`:162`、`:193`；`uia_start_capture.ps1:30`、`:41`
- 硬编码清单（任何一项在新版本改名/改结构即全线失效）：

  | 硬编码 | 用途 | 位置 |
  |---|---|---|
  | 窗口标题含 `更好的原神` | 找主窗口 | group:57, capture:30 |
  | DataItem 名 `调度器` / `全自动` | 侧栏导航 | group:137, 141 |
  | ListItem.Name 以 `ScriptGroup` 结尾 | 认组列表（实际是 C# 类名 ToString） | group:162 |
  | Button 名 `运行` | 启动组 | group:193 |
  | Button 名 `启动` | 启动截图器 | capture:41 |
  | 弹窗按钮 `不再提示` / `取消\|关闭\|跳过` | 关更新弹窗 | group:87, 93 |

- 已有前科：`操作复盘与错误.md:163` 记录过 0.64.2-alpha.3 把「执行」改成了「运行」。
- 另外：BGI 若在更新后把界面语言重置成非简中，上表全部失效。
- 建议：
  - 上线第一步读 `BetterGI.exe` 的 FileVersion 写进 `cycle_log.txt`，与「已验证版本」文件比对；
    不一致时先跑 `uia_start_group_named.ps1 -DryRun`，失败就报警并停在一条龙，不再盲跑。
  - 能用 AutomationId 的控件改用 AutomationId（用 `tools/inspect_windows.ps1` 在新版本上导出一次对照）。
  - 把上表抽成一个 `bgi_ui_names.ps1` 配置文件，更新后只改一处。

### [ ] P0-3 启动截图器不关弹窗、不等窗口、不查返回值

- 位置：`session_online.ps1:144-145`、`:170`、`:211`、`:393-396`；`uia_start_capture.ps1:21`、`:35`、`:44`
- 问题：
  - `session_online.ps1:144`、`:393` 固定 `Start-Sleep 75`，不确认 BGI 主窗口已出现。
    更新后首次启动（迁移配置、下载资源、更新日志页）很可能超过 75 秒。
  - 关弹窗逻辑只在 `uia_start_group_named.ps1:64-107`，而 `uia_start_capture.ps1` 先执行且**完全没有**这段。
    更新后弹出的模态窗会挡住首页「启动」。
  - `uia_start_capture.ps1:21` `(Get-Process BetterGI).Id` 没有 `-ErrorAction`，BGI 没起来时直接报错继续跑。
  - 四处调用 `uia_start_capture.ps1` 都不检查 `$LASTEXITCODE`（11-10 只给组启动加了检查），
    「窗口未找到」「启动按钮未找到」被无视，流程继续发 F9。
- 建议：
  - 把「等主窗口出现（轮询，上限 3 分钟）」和「关弹窗」抽成公共函数，两个 UIA 脚本都先调用。
  - 调用截图器后同样检查 `$LASTEXITCODE`，失败重试一次，仍失败则报警退出。

### [ ] P0-4 `PHASE=STARTING` 阶段没有任何超时保护

- 位置：`session_online.ps1:134`（置 STARTING）；`watchdog.ps1:41`（非 RUNNING 一律不干预）
- 问题：会话在 STARTING 期间同步调用多个子脚本（UIA、F9、python），任一个挂住，会话永久停在 STARTING，
  看门狗不管，只能等 `BGI_SessionEnd` 到点兜底，整场作废。
  `logs/2026-09-16_Agent_结论.md:32` 就是这个形态（停在「等 75s」之后，状态残留 STARTING）。
- 建议：看门狗增加一条规则——`session_start.txt` 超过 150 分钟仍是 STARTING，或 `cycle_log.txt` 超过 30 分钟
  没有新行 → 判定会话卡死，杀掉 `session_online` 后按恢复流程处理。

---

## P1 — 特定条件下出错或重复跑

### [ ] P1-1 F9 是否生效的判定太弱

- 位置：`session_online.ps1:206-216`
- 问题：判据是「180 秒内日志新增 ≥200 字符」。截图器启动、GameLoading 触发器、月卡识别都会写日志，
  F9 实际没生效也会通过，然后空等到 25 分钟静默才发现。更新后若一条龙热键被重置，就是这个表现。
- 建议：改成匹配一条龙开始的具体文案；上线前读 `config.json` 确认一条龙热键仍是 F9。

### [ ] P1-2 在 BGI 运行期间重写 BGI 的配置文件

- 位置：`session_online.ps1:328`、`:333`、`:338`、`:342`（此时 BGI 已启动）；`set_bookmark.py:38-43`、`:103-104`；
  `session_online.ps1:93-103`（一条龙 `默认配置.json`）
- 问题：
  - `set_bookmark.py` 用 `json.load` + `json.dump` 重写整个 `config.json`。文件带 BOM、BGI 正在写、
    或新版本改了格式时会直接抛异常，书签和续跑组都不会生成。
  - 脚本自己的注释（`set_bookmark.py:3-6`）已说明 BGI 读不出 `nextScheduledTask`，续跑实际靠「续跑收集组」文件。
    也就是说写 `config.json` 没有收益，只有风险。
  - 11-10 新增的「领取每日奖励按场次开关」靠一个写死的任务 GUID（`:97`）做正则替换。
    更新后若该 GUID 或文件结构变化，正则不命中时既不报错也不写日志，开关静默失效。
- 建议：书签改存自己的文件（如 `C:\Users\djf20\bookmark.json`），不再碰 `config.json`；
  GUID 正则不命中时写一行警告。

### [ ] P1-3 续跑组 JSON 是手工拼的，会丢掉新版本字段

- 位置：`set_bookmark.py:30`
- 问题：`sub = {"index": 99, "name": ..., "config": ..., "projects": []}` 只保留了四个顶层字段。
  新版本组文件若新增顶层字段，续跑组会缺字段，BGI 可能加载失败或在列表里不显示。
  （`Wait-GroupLoaded` 的注释提到过「读取配置组配置时失败」这类报错，值得对照。）
- 建议：`sub = dict(projs_group)` 整体复制后只覆盖 `index` / `name` / `projects`。

### [ ] P1-4 书签按路线名匹配第一条，重名或不在组内时从头跑

- 位置：`set_bookmark.py:72-76`、`:84-101`
- 问题：
  - 只比较 `name`，不比较 `folderName`。不同文件夹下的同名路线会命中靠前的那条，书签回退、重复收集。
  - 日志最后一条路线若来自别的组（体力监控、一条龙地脉等），输出「路线不在组内, 从头开始」，
    书签为空 → 从 A/B 组头重跑。
  - 最后一条正好是组尾时也会打印「路线不在组内」（`:100`），日志误导。
- 建议：只统计 `配置组 "收集A组|收集B组|续跑收集组|全自动循环"` 区间内的路线；匹配时带上 `folderName`；
  区分「组尾完成」和「未找到」两种日志。

### [ ] P1-5 看门狗恢复会重置场次窗口

- 位置：`watchdog.ps1:95-102` → `session_online.ps1:81-87`、`:129-130`
- 问题：恢复是重跑整个 `BGI_Session`，下线时间被重排为「恢复时刻 + 场次时长」。
  早场 08:54 恢复 → 下线变成 13:54，与 13:00 午场重叠；「每天最长 12h」的约束也被突破。
  11-10 把恢复上限从 2 次放宽到 4 次后，这个窗口漂移更容易发生。
- 建议：恢复时写一个标记文件，`session_online.ps1` 读到后沿用原 `ACTIVE_UNTIL`，不重新排程。
  （不要用 `-File X.ps1 -Param $true` 传参，10-19 已踩过绑定失败的坑。）

### [x] ~~P1-6 收集前的 BGI 重启把游戏也杀了~~（11-10 `d70a308` 已修）

- 现在只重启 BGI、补点截图器、游戏缺失时直起，组启动改为等「加载完成」60 秒。
- 遗留：`session_online.ps1:396` 的截图器调用仍不检查返回值（归入 P0-3）。

---

## P2 — 死代码 / 隐患

### [ ] P2-1 下线脚本的「大组刚跑完」检测永远不命中

- 位置：`cycle_offline.ps1:59-60`
- 问题：正则要求时间戳和 `配置组 … 执行结束` 在**同一行**，而 BGI 真实日志是两行格式
  （头行 + 消息行，见 `tests/test_bgilog.py` 的 `TWO_LINE`；`watchdog.ps1:62` 的正则是按两行写的）。
  这段逻辑是死代码，外层 `catch { }` 又把一切异常吞了。
- 建议：复用看门狗那条两行正则，或抽成公共函数。

### [ ] P2-2 主窗口识别有歧义，关弹窗可能误伤

- 位置：`uia_start_group_named.ps1:47-48`、`:57`、`:73`、`:99-103`
- 问题：
  - 多个可见窗口标题都含 `更好的原神` 时取枚举到的最后一个，可能不是主窗口。
  - 存在多个 `BetterGI` 进程时 `$proc.Id` 是数组，PID 比较失效。
  - 关弹窗会遍历 BGI 进程所有带标题的可见窗口（包括遮罩/日志浮窗）。兜底的 ESC 是发给前台窗口的，
    前台若是游戏，会把游戏切到派蒙菜单。
- 建议：主窗口按类名 + 尺寸筛选；弹窗只处理 owner 是主窗口的；ESC 前确认前台确实是该弹窗。

### [x] ~~P2-3 一条龙补跑条件包含「未领取」~~（11-11 `fa26209` 已修：早场不计入）

### [ ] P2-4 其它

- `session_online.ps1:290` 注释写书签是 1-based，`set_bookmark.py:93` 写的是 0-based，注释互相矛盾。
- `D:\projects\betterGI`、`C:\Users\djf20` 在十几个脚本里各写一遍，BGI 换目录安装时要逐个改。
- PowerShell 生产脚本没有任何自动化测试，`tests/` 只覆盖 `bgilog.py`。P0-0 这类字符串比较错误，
  一个针对状态文件解析的小测试就能拦住。

---

## 建议：BGI 更新 SOP

更新前：

1. 备份 `D:\projects\betterGI\User\` 整个目录（`config.json` + `ScriptGroup\` + `OneDragon\`）。
2. 记下当前版本号，更新安排在两场之间，先跑 `stop_session.ps1`。

更新后、下一场之前逐项确认：

1. 手动开一次 BGI，把首次启动的弹窗全部关掉（新版本提示、更新日志、协议等），界面语言仍是简体中文。
2. `config.json`：一条龙热键仍是 F9；联动启动游戏、GameLoading 自动进门仍开启；截图模式未变。
3. 调度器里 `收集A组` / `收集B组` / `体力监控` 仍在，名字未变。
4. 经 Session 1 跑一次 `uia_start_group_named.ps1 -NameMatch 收集A组 -DryRun`，`cycle_log.txt` 出现「DRYRUN: 已选组」。
5. 看一眼新版本 BGI 日志，确认这几条文案没变：`一条龙…任务结束`、`配置组 "x" 加载完成`、
   `配置组 "x" 执行结束`、`开始执行地图追踪任务: "x"`，以及时间戳头行格式 `[HH:mm:ss.fff] [INF] 类名`。
6. `User\OneDragon\默认配置.json` 里「领取每日奖励」的任务 GUID 仍是 `7b2c7f0c-…`（`session_online.ps1:97`）。
7. `树脂监控_main.js` 用到的 API（`genshin.blessingOfTheWelkinMoon`、`AutoLeyLineOutcropParam`、
   `dispatcher.runAutoLeyLineOutcropTask`）在新版本仍存在。
8. 关闭 BGI 的自动检查更新，托管期间锁定版本，只在人在场时手动升级。

## 下一步取证

要确认真凶，需要失败那天的三份文件（都在 Windows 上）：

- `C:\Users\djf20\cycle_log.txt`：
  - 「但游戏在跑 → 用户手动在玩, 跳过不杀」反复出现 → P0-0。
  - 「窗口未找到 / 启动按钮未找到 / 调度器导航失败 / 组列表未找到 / 未找到匹配 / 运行按钮未找到 /
    收集组未启动成功」→ P0-2 / P0-3 的对应项。
- `C:\Users\djf20\watchdog_log.txt`：有「提前下线 (今日完成)」但当天其实没跑收集 → P0-1。
- `D:\projects\betterGI\log\better-genshin-impact<日期>.log`：核对上面 SOP 第 5 条的文案是否变了。
