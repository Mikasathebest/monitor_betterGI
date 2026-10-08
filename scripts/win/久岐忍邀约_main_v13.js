/**
 * 久岐忍邀约自动导航+全程监督脚本 v13
 *
 * v13 核心升级: 位置伺服导航 (替代 v12 的"等待人走最后70m")
 * - genshin.GetPositionFromMap() 读玩家世界坐标 (与 genshin.Tp 同坐标系)
 * - genshin.GetCameraOrientation() 读相机朝向角 (0-360)
 * - 相机伺服: 复刻 BGI CameraRotateTask.RotateToApproach (moveMouseBy(-ratio*diff*dpi))
 * - 目标角公式: 复刻 Navigation.GetTargetOrientation (acos(dx/len), dy<0 则 2PI-angle)
 * - 上杉坐标: 首次用"任务追踪距离OCR + 两次位移"三角测量解出, 缓存 npc_pos.json 复用
 * - 卡死脱困: 复刻 TrapEscaper (randomAngle 递增绕障 + 跳跃 + 后退)
 *
 * 结果输出:
 *   NAV_RESULT: STARTED  邀约已开始
 *   NAV_RESULT: ENDED    结局已达成
 *   NAV_RESULT: FAILED   彻底失败
 *   RESTART: n           退出重做事件
 *   ERROR_LOG: xxx       错误记录(Python读取)
 */

const MAX_ATTEMPTS = 5;       // 导航重试次数
const MAX_RESTARTS = 10;      // 监督期退出重做次数
const STUCK_CHECK_SEC = 15;   // 卡死检查间隔
const STUCK_THRESHOLD_SEC = 60; // 画面60秒无变化→退出重做
const MIN_SUPERVISE_SEC = 120;  // 最少监督120秒后才检测结局(防止开场误判)
const ENDING_CONFIRM_COUNT = 2; // 结局检测需连续命中2次
const ENDING_CONFIRM_INTERVAL = 5000; // 两次检测间隔5秒
const BASE_W = 1920, BASE_H = 1080;

// 导航参数
const NAV_TIMEOUT_MS = 240000;   // 单次导航上限 4 分钟
const NAV_ARRIVE_DIST = 5.0;     // 到达判定: 距目标 <= 5m (且无追踪距离可读时)
const TRACKER_ARRIVE_M = 8;      // 到达判定: 任务追踪距离 <= 8m (优先用这个)
const WALK_BURST_MS = 800;       // 每次转向后走的时间片
const STUCK_MOVE_M = 0.7;        // 一个时间片位移 < 0.7m 视为卡住

// 稻妻城传送锚点
// 注意BGI坐标系: genshin.Tp(px, py) 中 px=tp.json position[2], py=position[0]
// (GiWorldPosition: X=>Position[2], Y=>Position[0], 轴向与直觉相反, 传反会掉到海里!)
// 久岐忍邀约起始NPC"上杉"在稻妻城天领奉行所门口
const INAZUMA_WAYPOINTS = [
    { name: "稻妻城锚点-近(id306)", x: -4495.035, y: -3218.596 }, // position[-3218.6,265,-4495.0] 距上杉约70m
    { name: "稻妻城锚点-北(id242)", x: -4400.3,   y: -3050.2 }    // position[-3050.2,247,-4400.3]
];

// ===== 错误记录 =====
function logError(step, msg) {
    let ts = new Date().toISOString();
    log.error(`ERROR_LOG: ${step}|${msg}|${ts}`);
    try {
        let lines = [];
        try {
            let old = file.ReadTextSync("AutoHangoutShinobu/errors.json");
            if (old) lines = JSON.parse(old) || [];
        } catch (e) {}
        lines.push({ time: ts, step: step, error: msg });
        if (lines.length > 50) lines = lines.slice(-50);
        file.WriteTextSync("AutoHangoutShinobu/errors.json", JSON.stringify(lines, null, 2));
    } catch (e) {}
}

// ===== 缩放辅助 =====
async function getScale() {
    try {
        let w = genshin.Width, h = genshin.Height;
        if (!w || w <= 0) { w = BASE_W; h = BASE_H; }
        log.info(`游戏画面尺寸: ${w}x${h}`);
        return { sw: w / BASE_W, sh: h / BASE_H };
    } catch (e) {
        log.warn(`获取画面尺寸失败: ${e}, 按1920x1080处理`);
        return { sw: 1, sh: 1 };
    }
}

function makeXY(s, x, y, w, h) {
    return [Math.round(x * s.sw), Math.round(y * s.sh),
            Math.round(w * s.sw), Math.round(h * s.sh)];
}

// ===== OCR 辅助 =====
async function ocrTexts(x, y, w, h) {
    try {
        let ro = RecognitionObject.Ocr(x, y, w, h);
        let region = captureGameRegion();
        let result = region.FindMulti(ro);
        region.dispose();
        let list = [];
        if (result && result.count !== 0) {
            for (let i = 0; i < result.count; i++) {
                list.push(result[i]);
            }
        }
        return list;
    } catch (e) {
        log.warn(`ocrTexts出错 (${x},${y},${w},${h}): ${e}`);
        return [];
    }
}

async function findAndClick(keywords, x, y, w, h, maxLen = 0) {
    let results = await ocrTexts(x, y, w, h);
    for (let r of results) {
        if (!r.text) continue;
        if (maxLen > 0 && r.text.length > maxLen) continue;
        for (let kw of keywords) {
            if (r.text.includes(kw)) {
                log.info(`>>> 点击 "${r.text}" (匹配:${kw}) at (${r.x},${r.y})`);
                r.click();
                await sleep(800);
                return true;
            }
        }
    }
    return false;
}

async function dumpOcr(label, x, y, w, h) {
    try {
        log.info(`--- ${label} OCR ---`);
        let results = await ocrTexts(x, y, w, h);
        if (results.length === 0) log.info("  (无文字)");
        for (let r of results) {
            log.info(`  '${r.text}' at (${r.x},${r.y})`);
        }
    } catch (e) {
        log.warn(`dumpOcr出错: ${e}`);
    }
}

// ===== 状态检测 =====

async function isPaimonMenuOpen(s) {
    let [x, y, w, h] = makeXY(s, 100, 400, 700, 400);
    let results = await ocrTexts(x, y, w, h);
    for (let r of results) {
        if (r.text && r.text.includes("任务")) return true;
    }
    return false;
}

async function ensurePaimonMenu(s, maxPress = 10) {
    try {
        log.info("调用 genshin.ReturnMainUi() 返回主界面");
        await genshin.ReturnMainUi();
        await sleep(1000);
    } catch (e) {
        log.warn(`ReturnMainUi失败: ${e}, 改用ESC方式`);
        for (let i = 0; i < 6; i++) {
            keyPress("Escape");
            await sleep(1500);
        }
    }

    for (let i = 0; i < maxPress; i++) {
        if (await isPaimonMenuOpen(s)) return true;
        log.info(`按ESC打开派蒙菜单 (${i + 1}/${maxPress})`);
        keyPress("Escape");
        await sleep(1600);
        if (i > 0 && i % 3 === 0) {
            let [cx, cy] = makeXY(s, 960, 600);
            log.info(`尝试点击屏幕中央 (${cx},${cy}) 跳过登录界面`);
            click(cx, cy);
            await sleep(2000);
        }
    }
    let ok = await isPaimonMenuOpen(s);
    if (!ok) logError("ensurePaimonMenu", "无法回到派蒙菜单");
    return ok;
}

async function isQuestPanelOpen(s) {
    let [x, y, w, h] = makeXY(s, 0, 0, 1920, 200);
    let results = await ocrTexts(x, y, w, h);
    let all = results.map(r => r.text).join("");
    return all.includes("进行中");
}

// 严格判断流程图: 只认"已完成的剧情节点"或"旅程记录"
async function isInFlowChart(s) {
    let [x, y, w, h] = makeXY(s, 0, 0, 1920, 1080);
    let results = await ocrTexts(x, y, w, h);
    let all = results.map(r => r.text).join("");
    return all.includes("已完成的剧情节点") || all.includes("旅程记录");
}

// ===== 导航步骤 =====

async function openQuestPanel(s) {
    log.info("步骤1: 点击'任务'打开任务面板");
    let [x, y, w, h] = makeXY(s, 100, 600, 700, 200);
    let ok = await findAndClick(["任务"], x, y, w, h);
    if (!ok) {
        [x, y, w, h] = makeXY(s, 0, 0, 800, 1080);
        ok = await findAndClick(["任务"], x, y, w, h);
    }
    if (!ok) {
        logError("openQuestPanel", "找不到'任务'按钮");
        return false;
    }

    for (let i = 0; i < 5; i++) {
        await sleep(1000);
        if (await isQuestPanelOpen(s)) {
            log.info("任务面板已打开");
            return true;
        }
    }
    logError("openQuestPanel", "点击任务后面板未打开");
    return false;
}

async function openHangoutFlow(s) {
    log.info("步骤2: 在任务列表查找'邀约事件·久岐忍'");
    for (let scroll = 0; scroll < 6; scroll++) {
        let [x, y, w, h] = makeXY(s, 100, 80, 420, 900);
        if (await findAndClick(["邀约事件", "久岐忍"], x, y, w, h)) {
            await sleep(2500);
            return true;
        }
        log.info(`列表未找到, 向下滚动 (${scroll + 1}/6)`);
        let [cx, cy] = makeXY(s, 300, 540);
        wheel(cx, cy, -300);
        await sleep(1200);
    }
    logError("openHangoutFlow", "任务列表中未找到邀约事件条目");
    return false;
}

async function handleConfirmDialog(s) {
    await sleep(1500);
    let [x, y, w, h] = makeXY(s, 400, 400, 1120, 400);
    let clicked = await findAndClick(["确认", "确定"], x, y, w, h);
    if (clicked) log.info("已点击确认弹窗");
}

async function clickStartBtn(results) {
    for (let r of results) {
        if (!r.text) continue;
        if (r.text.length <= 6 && (r.text.includes("开始体验") || r.text.includes("开始游玩") ||
            r.text.includes("开始") || r.text.includes("继续体验") || r.text.includes("继续游玩") ||
            r.text.includes("继续") || r.text.includes("追踪"))) {
            log.info(`>>> 点击 "${r.text}" at (${r.x},${r.y})`);
            r.click();
            await sleep(1200);
            return true;
        }
    }
    return false;
}

async function startFromFlowChart(s) {
    log.info("步骤4: 在流程图点击开始");
    let [fx, fy, fw, fh] = makeXY(s, 0, 0, 1920, 1080);

    await sleep(4000);
    await dumpOcr("流程图", fx, fy, fw, fh);

    // 1) 先直接找开始按钮
    let results = await ocrTexts(fx, fy, fw, fh);
    if (await clickStartBtn(results)) {
        await handleConfirmDialog(s);
        return true;
    }

    // 2) "事件进行中"状态: 邀约已开始, 点击右上角X关闭流程图
    if (results.some(r => r.text && r.text.includes("事件进行中"))) {
        log.info("检测到'事件进行中'状态, 点右上角X关闭流程图");
        let [xx, xy] = makeXY(s, 1850, 50);
        log.info(`点击右上角X (${xx},${xy})`);
        click(xx, xy);
        await sleep(2500);
        if (await isInFlowChart(s)) {
            click(xx, xy);
            await sleep(2000);
        }
        log.info("邀约已在进行中, 进入监督模式");
        return true;
    }

    // 3) 网格扫描流程图节点
    let ys = [660, 580, 500, 420];
    for (let y of ys) {
        for (let x = 280; x <= 1420; x += 140) {
            let [cx, cy] = makeXY(s, x, y);
            log.info(`扫描节点 (${cx},${cy})`);
            click(cx, cy);
            await sleep(1500);
            let re = await ocrTexts(fx, fy, fw, fh);
            if (await clickStartBtn(re)) {
                await handleConfirmDialog(s);
                return true;
            }
        }
    }

    // 4) 兜底: 右下角
    let [rx, ry] = makeXY(s, 1700, 950);
    log.info(`OCR未找到按钮, 点击右下角 (${rx},${ry})`);
    click(rx, ry);
    await sleep(1500);
    let re2 = await ocrTexts(fx, fy, fw, fh);
    if (await clickStartBtn(re2)) {
        await handleConfirmDialog(s);
        return true;
    }

    logError("startFromFlowChart", "流程图中未找到开始按钮");
    return false;
}

// ===== 导航主流程 =====
async function navigateAndStart(s) {
    for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt++) {
        log.info(`───── 导航尝试 ${attempt}/${MAX_ATTEMPTS} ─────`);

        if (!await ensurePaimonMenu(s)) {
            logError("navigate.0", `尝试${attempt}: 无法回到派蒙菜单`);
            continue;
        }

        if (!await openQuestPanel(s)) {
            logError("navigate.1", `尝试${attempt}: 无法打开任务面板`);
            continue;
        }

        if (!await openHangoutFlow(s)) {
            logError("navigate.2", `尝试${attempt}: 无法找到邀约事件条目`);
            continue;
        }

        // 右侧详情面板: 找继续/前往/追踪按钮
        {
            let [dx, dy, dw, dh] = makeXY(s, 1100, 100, 820, 900);
            let results = await ocrTexts(dx, dy, dw, dh);
            if (await clickStartBtn(results)) {
                await handleConfirmDialog(s);
                for (let i = 0; i < 6; i++) {
                    await sleep(2000);
                    if (!(await isInFlowChart(s)) && !(await isQuestPanelOpen(s))) {
                        log.info("详情面板按钮触发, 邀约已开始/恢复");
                        return true;
                    }
                }
            }
        }

        // 点击"查看旅途"打开流程图
        if (!(await isInFlowChart(s))) {
            log.info("步骤3: 查找'查看旅途'按钮打开流程图");
            let [vx, vy, vw, vh] = makeXY(s, 1200, 100, 720, 300);
            let opened = await findAndClick(["查看旅途", "旅途"], vx, vy, vw, vh);
            if (!opened) {
                let [fx, fy, fw, fh] = makeXY(s, 0, 0, 1920, 1080);
                opened = await findAndClick(["查看旅途"], fx, fy, fw, fh);
            }
            if (opened) {
                log.info("已点击查看旅途, 等待流程图加载");
                await sleep(3000);
            } else {
                logError("navigate.3", `尝试${attempt}: 未找到查看旅途按钮`);
                await dumpOcr("找不到查看旅途时的画面", 0, 0, 1920, 1080);
            }
        }

        if (!(await isInFlowChart(s))) {
            log.info("流程图未打开, 再点一次邀约条目+查看旅途");
            let [x, y, w, h] = makeXY(s, 100, 80, 420, 900);
            await findAndClick(["邀约事件", "久岐忍"], x, y, w, h);
            await sleep(2000);
            let [vx, vy, vw, vh] = makeXY(s, 1200, 100, 720, 300);
            await findAndClick(["查看旅途", "旅途"], vx, vy, vw, vh);
            await sleep(3000);
        }

        if (!(await isInFlowChart(s))) {
            await dumpOcr("导航失败画面", 0, 0, 1920, 1080);
            logError("navigate.flow", `尝试${attempt}: 未进入邀约流程图`);
            continue;
        }
        log.info("已进入邀约流程图");

        if (await startFromFlowChart(s)) {
            await sleep(2000);
            if (!(await isInFlowChart(s))) {
                log.info("邀约已开始(流程图已关闭)");
                return true;
            }
            log.info("流程图可能未完全关闭, 但邀约已开始/进行中");
            return true;
        } else {
            logError("navigate.4", `尝试${attempt}: 流程图中未找到开始按钮`);
        }
    }
    return false;
}

// ===== 退出邀约 =====
async function exitHangout(s) {
    log.info("步骤: 退出邀约");

    // 方式1: ESC菜单中的"退出邀约"
    for (let i = 0; i < 4; i++) {
        let [fx, fy, fw, fh] = makeXY(s, 0, 0, 1920, 1080);
        if (await findAndClick(["退出邀约"], fx, fy, fw, fh, 8)) {
            await sleep(1200);
            await handleConfirmDialog(s);
            await sleep(2500);
            log.info("已退出邀约(ESC菜单)");
            return true;
        }
        keyPress("Escape");
        await sleep(1600);
    }

    // 方式2: 任务面板放弃事件
    log.info("ESC菜单未找到退出邀约, 尝试任务面板放弃事件");
    try { await genshin.ReturnMainUi(); } catch (e) {}
    await sleep(1500);

    if (await ensurePaimonMenu(s)) {
        if (await openQuestPanel(s)) {
            let [x, y, w, h] = makeXY(s, 100, 80, 420, 900);
            await findAndClick(["邀约事件", "久岐忍"], x, y, w, h);
            await sleep(2000);

            let [dx, dy, dw, dh] = makeXY(s, 1100, 100, 820, 900);
            if (await findAndClick(["放弃事件", "放弃", "结束邀约", "退出"], dx, dy, dw, dh, 8)) {
                await sleep(1500);
                await handleConfirmDialog(s);
                await sleep(2500);
                log.info("已退出邀约(任务面板放弃)");
                return true;
            }
            await dumpOcr("放弃按钮搜索区", dx, dy, dw, dh);
            logError("exitHangout.放弃", "任务面板未找到放弃事件按钮");
        }
    }

    log.warn("无法退出邀约, 尝试ReturnMainUi兜底");
    try { await genshin.ReturnMainUi(); } catch (e) {}
    return false;
}

// ===== 传送到稻妻城 =====
async function teleportInazuma(s) {
    try { await genshin.ReturnMainUi(); } catch (e) {}
    await sleep(2000);
    for (let wp of INAZUMA_WAYPOINTS) {
        try {
            log.info(`准备传送 ${wp.name}: genshin.Tp(${wp.x}, ${wp.y})`);
            await genshin.Tp(wp.x, wp.y);
            log.info("传送指令已发送, 等待加载...");
            await sleep(11000);
            if (await isInFlowChart(s) || await isQuestPanelOpen(s)) {
                keyPress("Escape");
                await sleep(2000);
            }
            log.info(`已传送到 ${wp.name}`);
            return true;
        } catch (e) {
            logError("teleportInazuma", `${wp.name} 传送异常: ${e}`);
            await sleep(2000);
        }
    }
    return false;
}

// 检测是否已进入剧情对话: 底部台词区出现成句中文
async function detectDialog(s) {
    let [dx, dy, dw, dh] = makeXY(s, 300, 830, 1300, 180);
    let dlg = await ocrTexts(dx, dy, dw, dh);
    let bad = ["进行中", "传说任务", "邀约事件", "世界任务", "委托", "地图", "背包", "成就", "冒险等阶"];
    let good = dlg.filter(r => r.text && r.text.length >= 6 && !bad.some(b => r.text.includes(b)));
    if (good.length > 0) {
        log.info(`检测到剧情台词: "${good[0].text}"`);
        return true;
    }
    return false;
}

// ============================================================
// v13 新增: 位置伺服导航
// ============================================================

// 读玩家世界坐标 (与 genshin.Tp 同坐标系); 非主界面/识别失败返回 null
function getPos() {
    try {
        let p = genshin.GetPositionFromMap();
        if (p) return { x: p.X, y: p.Y };
    } catch (e) { /* 不在主界面等, 静默 */ }
    return null;
}

// 相机朝向角; 失败返回 null
function getCam() {
    try { return genshin.GetCameraOrientation(); } catch (e) { return null; }
}

// 世界坐标->目标朝向角 (复刻 Navigation.GetTargetOrientation)
function targetOrientation(tx, ty, px, py) {
    let dx = tx - px, dy = ty - py;
    let len = Math.sqrt(dx * dx + dy * dy);
    if (len === 0) return 0;
    let ang = Math.acos(dx / len);
    if (dy < 0) ang = 2 * Math.PI - ang;
    return ang * 180 / Math.PI;
}

// 相机伺服转向 (复刻 CameraRotateTask.RotateToApproach 迭代逼近)
async function rotateTo(target, maxDiff = 4, maxTry = 60) {
    let dpi = 1;
    try { dpi = genshin.ScreenDpiScale || 1; } catch (e) {}
    for (let i = 0; i < maxTry; i++) {
        let cao = getCam();
        if (cao === null) { await sleep(200); continue; }
        let diff = ((cao - target + 180) % 360) - 180;
        if (diff < -180) diff += 360;
        if (Math.abs(diff) <= maxDiff) return true;
        let ad = Math.abs(diff);
        let ratio = 1;
        if (ad > 90) ratio = 4; else if (ad > 30) ratio = 3; else if (ad > 5) ratio = 2;
        moveMouseBy(Math.round(-ratio * diff * dpi), 0);
        await sleep(70);
    }
    return false;
}

function pressJump() {
    try { keyPress("Space"); } catch (e) {
        try { keyPress("VK_SPACE"); } catch (e2) {}
    }
}

// 读左上角任务追踪距离 (米); 读不到返回 null
async function readTrackerDistance(s) {
    let [x, y, w, h] = makeXY(s, 0, 80, 520, 300);
    let results = await ocrTexts(x, y, w, h);
    for (let r of results) {
        if (!r.text) continue;
        let m = r.text.match(/(\d+(?:\.\d+)?)\s*(km|千米|公里)/i);
        if (m) return parseFloat(m[1]) * 1000;
        m = r.text.match(/(\d+(?:\.\d+)?)\s*(m|米)(?![a-z])/i);
        if (m) return parseFloat(m[1]);
    }
    return null;
}

// 两圆相交 (三角测量目标位置)
function circleIntersect(p1, d1, p2, d2) {
    let dx = p2.x - p1.x, dy = p2.y - p1.y;
    let d = Math.sqrt(dx * dx + dy * dy);
    if (d < 1) return [];
    let a = (d1 * d1 - d2 * d2 + d * d) / (2 * d);
    let h2 = d1 * d1 - a * a;
    if (h2 < 0) h2 = 0;
    let h = Math.sqrt(h2);
    let mx = p1.x + a * dx / d, my = p1.y + a * dy / d;
    // 法线方向 (-dy, dx)/d
    return [
        { x: mx + h * (-dy / d), y: my + h * (dx / d) },
        { x: mx - h * (-dy / d), y: my - h * (dx / d) }
    ];
}

// 三角测量上杉位置: 采样 (位置, 追踪距离) x2~3 解圆交点
async function triangulateTarget(s) {
    log.info("=== 三角测量目标位置 ===");
    let p1 = getPos();
    let d1 = await readTrackerDistance(s);
    if (!p1 || d1 === null) {
        log.warn(`三角测量采样1失败: pos=${p1 ? 'ok' : 'null'} dist=${d1}`);
        return null;
    }
    log.info(`采样1: pos(${p1.x.toFixed(1)},${p1.y.toFixed(1)}) dist=${d1}m`);

    // 向当前朝向的垂直方向走 ~3 秒制造基线
    let cam = getCam() || 0;
    await rotateTo(cam + 90);
    keyDown("W");
    await sleep(3000);
    keyUp("W");
    await sleep(600);

    let p2 = getPos();
    let d2 = await readTrackerDistance(s);
    if (!p2 || d2 === null) {
        log.warn(`三角测量采样2失败: pos=${p2 ? 'ok' : 'null'} dist=${d2}`);
        return null;
    }
    log.info(`采样2: pos(${p2.x.toFixed(1)},${p2.y.toFixed(1)}) dist=${d2}m`);

    if (Math.hypot(p2.x - p1.x, p2.y - p1.y) < 4) {
        log.warn("基线太短(位移<4m), 三角测量放弃");
        return null;
    }

    let cands = circleIntersect(p1, d1, p2, d2);
    if (cands.length === 0) return null;

    // 第三采样点消歧
    await rotateTo(cam - 90);
    keyDown("W");
    await sleep(2000);
    keyUp("W");
    await sleep(600);
    let p3 = getPos();
    let d3 = await readTrackerDistance(s);

    let best = cands[0];
    if (p3 && d3 !== null && cands.length > 1) {
        log.info(`采样3: pos(${p3.x.toFixed(1)},${p3.y.toFixed(1)}) dist=${d3}m`);
        let err0 = Math.abs(Math.hypot(cands[0].x - p3.x, cands[0].y - p3.y) - d3);
        let err1 = Math.abs(Math.hypot(cands[1].x - p3.x, cands[1].y - p3.y) - d3);
        best = err1 < err0 ? cands[1] : cands[0];
        log.info(`消歧: cand0误差${err0.toFixed(1)}m cand1误差${err1.toFixed(1)}m`);
    }
    log.info(`>>> 三角测量结果: 目标约 (${best.x.toFixed(1)}, ${best.y.toFixed(1)})`);
    return best;
}

// 读缓存的 NPC 坐标
function loadNpcPos() {
    try {
        let txt = file.ReadTextSync("AutoHangoutShinobu/npc_pos.json");
        if (txt && txt.length > 2) {
            let o = JSON.parse(txt);
            if (o && typeof o.x === 'number' && typeof o.y === 'number') {
                log.info(`使用缓存NPC坐标 (${o.x.toFixed(1)}, ${o.y.toFixed(1)})`);
                return o;
            }
        }
    } catch (e) {}
    return null;
}

function saveNpcPos(p) {
    try {
        file.WriteTextSync("AutoHangoutShinobu/npc_pos.json",
            JSON.stringify({ x: p.x, y: p.y, time: new Date().toISOString() }, null, 2));
        log.info(`NPC坐标已缓存 (${p.x.toFixed(1)}, ${p.y.toFixed(1)})`);
    } catch (e) {}
}

// 伺服走到目标点 (复刻 TrapEscaper 的绕障思路)
// 到达判定优先用任务追踪距离(<=TRACKER_ARRIVE_M), 其次用坐标距离(<=NAV_ARRIVE_DIST)
async function navigateTo(s, tx, ty) {
    log.info(`=== 伺服导航至 (${tx.toFixed(1)}, ${ty.toFixed(1)}) ===`);
    let start = Date.now();
    let randomAngle = 0;
    let randomSign = 1;
    let lastPos = getPos();
    let lastStuckCheck = Date.now();
    let stuckCount = 0;

    keyDown("W");
    try {
        while (Date.now() - start < NAV_TIMEOUT_MS) {
            // 0. 已进入对话? (导航成功的终极判定)
            if (await detectDialog(s)) { log.info("导航中检测到对话开始"); return true; }

            // 1. 追踪距离到达判定 (地面真值)
            let td = await readTrackerDistance(s);
            if (td !== null && td <= TRACKER_ARRIVE_M) {
                log.info(`追踪距离 ${td}m <= ${TRACKER_ARRIVE_M}m, 判定到达`);
                return true;
            }

            // 2. 坐标到达判定
            let p = getPos();
            if (p) {
                let dist = Math.hypot(tx - p.x, ty - p.y);
                if (dist <= NAV_ARRIVE_DIST) {
                    log.info(`坐标距离 ${dist.toFixed(1)}m <= ${NAV_ARRIVE_DIST}m, 判定到达`);
                    return true;
                }

                // 3. 卡死检测 (每 ~2.4s 检查一次位移)
                let now = Date.now();
                if (lastPos && now - lastStuckCheck > 2400) {
                    let moved = Math.hypot(p.x - lastPos.x, p.y - lastPos.y);
                    if (moved < STUCK_MOVE_M) {
                        stuckCount++;
                        randomSign = -randomSign;
                        randomAngle += randomSign * (30 + Math.floor(Math.random() * 15));
                        randomAngle %= 360;
                        log.warn(`卡住(#${stuckCount}): ${moved.toFixed(2)}m 位移, randomAngle=${randomAngle}, 跳跃+转向`);
                        pressJump();
                        if (stuckCount % 4 === 0) {
                            // 连续卡住: 后退+大跳 (TrapEscaper RotateAndMove 思路)
                            log.warn("连续卡住, 后退脱困");
                            keyUp("W");
                            keyDown("S");
                            await sleep(700);
                            pressJump();
                            await sleep(500);
                            keyUp("S");
                            keyDown("W");
                        }
                    } else {
                        // 移动正常: 缓慢消除随机偏角
                        if (randomAngle !== 0 && stuckCount === 0) randomAngle = 0;
                        stuckCount = Math.max(0, stuckCount - 1);
                    }
                    lastPos = p;
                    lastStuckCheck = now;
                }

                // 4. 朝目标转向 (带绕障偏角)
                let to = targetOrientation(tx, ty, p.x, p.y) + randomAngle;
                await rotateTo(to);
            } else {
                // 位置读不到(可能不在主界面): 稍等重试
                await sleep(500);
            }

            await sleep(WALK_BURST_MS);
        }
    } finally {
        keyUp("W");
    }
    log.warn("伺服导航超时");
    return false;
}

// 扫描"上杉"交互并按F
async function tryInteractNpc(s) {
    let [fx, fy, fw, fh] = makeXY(s, 0, 0, 1920, 1080);
    let scan = await ocrTexts(fx, fy, fw, fh);
    let nearNpc = scan.filter(r => r.text && r.text.includes("上杉") && r.x >= 500);
    if (nearNpc.length > 0) {
        log.info(`发现上杉交互提示(${nearNpc[0].x},${nearNpc[0].y}), 按F对话`);
        try { keyPress("F"); } catch (e) {}
        await sleep(3500);
        if (await detectDialog(s)) { log.info("与上杉对话已开始"); return true; }
    }
    return false;
}

// v13 reachNpc: 传送 → (缓存坐标 | 三角测量) → 伺服导航 → 按F → 对话
async function reachNpc(s, waitMs = 120000) {
    log.info("=== v13: 传送稻妻城 + 伺服导航到上杉 ===");
    if (!(await teleportInazuma(s))) {
        logError("reachNpc.tp", "无法传送到稻妻城");
        return false;
    }
    await sleep(1500);

    // 1. 拿到目标坐标 (缓存优先, 否则三角测量)
    let target = loadNpcPos();
    if (!target) {
        target = await triangulateTarget(s);
        if (target) saveNpcPos(target);
    }

    // 2. 伺服导航 (有坐标) — 失败则退化到等待模式
    if (target) {
        let arrived = await navigateTo(s, target.x, target.y);
        if (arrived) {
            // 到达附近: 找上杉按F
            for (let i = 0; i < 10; i++) {
                if (await detectDialog(s)) return true;
                if (await tryInteractNpc(s)) return true;
                // 找不到交互提示就小步逼近/转圈找
                pressJump();
                try { keyPress("F"); } catch (e) {}
                await sleep(2000);
            }
            log.warn("已到目标附近但未触发对话, 进入等待模式兜底");
        } else {
            logError("reachNpc.nav", "伺服导航未到达, 退化等待模式");
        }
    } else {
        logError("reachNpc.tri", "无目标坐标(三角测量失败), 退化等待模式");
    }

    // 3. 等待模式兜底 (v12 行为): 原地等交互出现
    log.warn("等待模式: 原地扫描上杉交互, 周期性按F");
    let start = Date.now();
    let lastF = 0;
    while (Date.now() - start < waitMs) {
        if (await detectDialog(s)) { log.info("已进入剧情对话"); return true; }
        if (await tryInteractNpc(s)) return true;
        if (Date.now() - lastF > 8000) {
            try { keyPress("F"); } catch (e) {}
            lastF = Date.now();
        }
        await sleep(2500);
    }
    logError("reachNpc", "导航+等待后仍未触发上杉对话");
    return false;
}

// ===== 监督辅助 =====

function loadTarget() {
    try {
        let paths = ["target.json", "AutoHangoutShinobu/target.json"];
        for (let p of paths) {
            try {
                let txt = file.ReadTextSync(p);
                if (txt && txt.length > 2) {
                    let obj = JSON.parse(txt);
                    if (obj && obj.options && obj.options.length > 0) {
                        log.info(`目标结局: ${obj.endName} (选项关键词${obj.options.length}个)`);
                        return obj;
                    }
                }
            } catch (e2) {}
        }
    } catch (e) {}
    log.warn("target.json不可用, 对话选项交给BetterGI自动剧情触发器");
    return null;
}

async function clickSkipButton(s) {
    let [x, y, w, h] = makeXY(s, 1450, 900, 470, 180);
    return await findAndClick(["跳过"], x, y, w, h, 4);
}

async function chooseOption(s, target, allowFallback) {
    let [x, y, w, h] = makeXY(s, 960, 250, 960, 650);
    let results = await ocrTexts(x, y, w, h);

    if (target && target.options) {
        for (let r of results) {
            if (!r.text || r.text.length > 40) continue;
            for (let kw of target.options) {
                if (r.text.includes(kw)) {
                    log.info(`>>> 选中目标选项 "${r.text}" (关键词:${kw})`);
                    r.click();
                    await sleep(1000);
                    return true;
                }
            }
        }
    }
    if (allowFallback) {
        let cand = results.filter(r => r.text && r.text.length >= 2 && r.text.length <= 40 && r.y > 100);
        if (cand.length > 0) {
            log.warn(`>>> 无关键词命中, 兜底点击第一个选项 "${cand[0].text}"`);
            cand[0].click();
            await sleep(1000);
            return true;
        }
    }
    return false;
}

// ===== 全程监督 =====
async function supervise(s, target) {
    log.info("=== 进入全程监督模式 ===");
    let restarts = 0;
    let lastSig = "";
    let superviseStart = Date.now();
    let endingHits = 0;
    let lastEndingHit = 0;
    let noChangeCount = 0;

    await sleep(8000);

    while (true) {
        await sleep(STUCK_CHECK_SEC * 1000);
        let now = Date.now();
        let elapsed = (now - superviseStart) / 1000;

        let [fx, fy, fw, fh] = makeXY(s, 0, 0, 1920, 1080);
        let texts = (await ocrTexts(fx, fy, fw, fh)).map(r => (r.text || "").trim()).filter(t => t);
        let all = texts.join("|");

        // 1) 结局达成判定 (严格)
        if (elapsed >= MIN_SUPERVISE_SEC) {
            let isEnding = all.includes("达成结局") || all.includes("邀约结局") || all.includes("结局达成");
            if (isEnding) {
                if (now - lastEndingHit < ENDING_CONFIRM_INTERVAL + STUCK_CHECK_SEC * 1000) {
                    endingHits++;
                } else {
                    endingHits = 1;
                }
                lastEndingHit = now;
                log.info(`[监督] 检测到结局文字 (连续${endingHits}/${ENDING_CONFIRM_COUNT})`);
                if (endingHits >= ENDING_CONFIRM_COUNT) {
                    log.info("结局确认达成!");
                    await sleep(4000);
                    log.info("NAV_RESULT: ENDED");
                    return true;
                }
                continue;
            } else {
                endingHits = 0;
            }
        }

        // 2) ESC菜单误开则关闭
        if (all.includes("退出邀约") && !all.includes("达成结局")) {
            log.info("检测到ESC菜单打开, 关闭");
            keyPress("Escape");
            await sleep(1500);
            noChangeCount = 0;
            lastSig = "";
            continue;
        }

        // 2.5) 流程图还开着 → 点右上角X关闭
        if (all.includes("事件进行中") || all.includes("已完成的剧情节点")) {
            log.info("[监督] 流程图仍开着, 点右上角X关闭");
            let [xx, xy] = makeXY(s, 1850, 50);
            click(xx, xy);
            await sleep(2500);
            noChangeCount = 0;
            lastSig = "";
            continue;
        }

        // 3) 卡死检测: 用粗粒度签名
        let sig = texts.length + ":" + all.length;
        if (sig !== lastSig) {
            lastSig = sig;
            noChangeCount = 0;
            continue;
        }

        noChangeCount++;
        let stuckSec = noChangeCount * STUCK_CHECK_SEC;
        log.info(`[监督] 画面无变化 (连续${noChangeCount}次, 约${stuckSec}s)`);

        // 4) 连续4次无变化(约60秒) → 退出重做
        if (noChangeCount >= 4) {
            restarts++;
            if (restarts > MAX_RESTARTS) {
                logError("supervise", `退出重做已达上限(${MAX_RESTARTS}次), 放弃`);
                log.error("NAV_RESULT: FAILED");
                return false;
            }
            if (restarts <= 2) {
                log.warn(`[监督] 画面${stuckSec}s无变化 → 重新传送寻找上杉 ${restarts}/${MAX_RESTARTS}`);
                logError("supervise.reTp", `第${restarts}次: 重新传送稻妻城, OCR摘要: ${all.substring(0, 100)}`);
                await reachNpc(s);
            } else {
                log.warn(`[监督] 画面${stuckSec}s无变化 → 退出邀约重开 ${restarts}/${MAX_RESTARTS}`);
                log.info(`RESTART: ${restarts}`);
                logError("supervise.stuck", `第${restarts}次重做(退出重进): 画面${stuckSec}s无变化, OCR摘要: ${all.substring(0, 100)}`);

                await exitHangout(s);
                let ok = await navigateAndStart(s);
                if (ok) {
                    log.info("邀约已重新接取, 传送稻妻城找NPC");
                    await reachNpc(s);
                    superviseStart = Date.now();
                    endingHits = 0;
                } else {
                    logError("supervise.restart", `第${restarts}次重做导航失败`);
                }
            }
            noChangeCount = 0;
            lastSig = "";
            await sleep(6000);
            continue;
        }

        // 5) 画面无变化但未到退出阈值 → 尝试推进
        if (await clickSkipButton(s)) {
            log.info("点击了跳过按钮");
        } else if (await chooseOption(s, target, noChangeCount >= 2)) {
            // 连续2次无变化才允许兜底点第一个选项
        } else {
            log.info("按F尝试与NPC交互");
            try { keyPress("F"); } catch (e) {}
            await sleep(2000);
            let [ax, ay] = makeXY(s, 960, 900);
            click(ax, ay);
            log.info(`点击推进对话 (${ax},${ay})`);
            await sleep(1200);
        }
    }
}

// ===== 主流程 =====
async function main() {
    log.info("=== 久岐忍邀约导航+全程监督 v13 (位置伺服导航) ===");
    let s = await getScale();
    let target = loadTarget();

    log.info("阶段1: 传送稻妻城 + 伺服导航找上杉");
    let reached = await reachNpc(s);

    if (!reached) {
        log.warn("直接传送未触发对话, 阶段2: 走任务面板完整导航");
        let started = await navigateAndStart(s);
        if (started) {
            reached = await reachNpc(s);
        } else {
            let [dx, dy, dw, dh] = makeXY(s, 0, 0, 1920, 1080);
            await dumpOcr("最终画面", dx, dy, dw, dh);
        }
    }

    if (!reached) {
        logError("main", "传送+导航后仍无法触发上杉对话");
        log.error("NAV_RESULT: FAILED");
        return;
    }
    log.info("NAV_RESULT: STARTED");

    let ended = await supervise(s, target);
    if (ended) {
        log.info(`>>> 结局达成: ${target ? target.endName : "未知"}`);
    } else {
        logError("main", `结局未达成: ${target ? target.endName : "未知"}`);
        log.error(`>>> 结局未达成: ${target ? target.endName : "未知"}`);
    }
}

(async () => { await main(); })();
