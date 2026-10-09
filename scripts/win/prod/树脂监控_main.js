// 树脂监控: 读取当前原粹树脂, 达到阈值自动刷地脉花 (摩拉/经验书)
// 原理: 打开地图 → 模板匹配树脂图标 → OCR 右侧 "xxx/200" → 超阈值则调用 BGI 内置地脉任务
(async function () {
    // ===== 设置 =====
    const threshold = parseInt(settings.threshold || "150");
    const flower = (settings.flower || "藏金之花(摩拉)").includes("启示") ? "启示之花" : "藏金之花";
    const country = settings.country || "枫丹";

    log.info(`树脂监控: 阈值=${threshold}, 花=${flower}, 国家=${country}`);

    // ===== 1. 回主界面 → 顺手领月卡 → 开地图 =====
    await genshin.returnMainUi();
    await sleep(1200);

    // 月卡(空月祝福): 弹窗在则点击领取, 不在则跳过 (幂等; 本脚本每session跑多次=每日必领)
    // 背景: 2026-09-15 一条龙 returnMainUi 的 Esc 没能领到月卡, 用户手动补领
    try {
        await genshin.blessingOfTheWelkinMoon();
        log.info("月卡(空月祝福)检查/领取完成");
    } catch (e) {
        log.warn("月卡领取跳过: " + (e && e.message));
    }
    await sleep(500);

    keyPress("M");
    await sleep(2200);

    // ===== 2. 模板匹配树脂图标 =====
    const iconRo = RecognitionObject.TemplateMatch(file.ReadImageMatSync("assets/original_resin.png"));
    const capture = captureGameRegion();
    const iconRes = capture.find(iconRo);
    if (iconRes.isEmpty()) {
        log.error("未找到树脂图标, 可能地图未打开");
        await genshin.returnMainUi();
        return;
    }

    // ===== 3. OCR 图标右侧的 "xxx/200" =====
    const ocrRo = RecognitionObject.ocr(iconRes.x, iconRes.y, 200, 40);
    const ocrRes = capture.find(ocrRo);
    const text = ocrRes.text || "";
    await genshin.returnMainUi();

    const m = /(\d{1,3})\s*\/\s*\d+/.exec(text);
    if (!m) {
        log.error(`树脂 OCR 失败, 原文: "${text}"`);
        return;
    }
    const resin = parseInt(m[1]);
    log.info(`当前原粹树脂: ${resin} / 阈值: ${threshold}`);

    // ===== 4. 达到阈值 → 刷地脉 =====
    if (resin < threshold) {
        log.info("未达阈值, 继续队列");
        return;
    }

    log.warn(`树脂 ${resin} >= ${threshold}, 开始刷 ${flower} (${country})`);
    const param = new AutoLeyLineOutcropParam(1, country, flower);
    param.isResinExhaustionMode = true;   // 耗尽模式: 打到树脂不够领奖励为止
    param.isGoToSynthesizer = false;      // 不合成浓缩, 只直接烧计数器里的原粹树脂
    param.useFragileResin = false;        // 不动用脆弱树脂 (库存道具)
    param.useTransientResin = false;      // 不动用须臾树脂 (库存道具)
    await dispatcher.runAutoLeyLineOutcropTask(param);
    log.warn("地脉刷取结束, 继续队列");
})();
