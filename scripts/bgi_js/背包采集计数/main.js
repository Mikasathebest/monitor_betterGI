// 背包采集计数: 调用 BGI 内置 CountInventoryItem 统计收集目标材料数量
// 用法: 收集A组/B组 组头(phase=before)、组尾(phase=after)各挂一条,
//       记录追加到 背包采集计数/inventory_log.jsonl, 由外部脚本差分统计每轮采集量
// 注意: CountInventoryItem 返回 -2 表示找到了但数字识别失败; 找不到的物品不返回键
(async function () {
    // ===== 跟踪物品清单 (与收集组内容对应, 2026-11-09) =====
    const ITEMS = [
        // 特产
        "清水玉", "幽灯蕈", "琉鳞石", "风车菊", "慕风蘑菇",
        // 矿石
        "水晶块", "紫晶块", "虹滴晶", "星银矿石", "白铁块", "铁块",
        // 敌人掉落 (T3)
        "历战的箭簇", "禁咒绘卷", "史莱姆原浆", "隙间之核", "龙冠武士的金哨"
    ];
    const phase = String(settings.phase || "before").trim();
    const LOG_PATH = "背包采集计数/inventory_log.jsonl";

    log.info(`背包采集计数[${phase}]: 开始统计 ${ITEMS.length} 种材料`);

    let raw = {};
    try {
        raw = await dispatcher.runTask(new SoloTask("CountInventoryItem", {
            gridScreenName: "Materials",
            itemNames: ITEMS
        }));
    } catch (e) {
        log.error("CountInventoryItem 执行失败: " + (e && e.message));
    }

    // 按物品名单逐个取值, 避免 .NET 字典序列化问题; 缺失键记 null
    const counts = {};
    for (const n of ITEMS) {
        try {
            const v = raw[n];
            counts[n] = (v === undefined || v === null) ? null : Number(v);
        } catch (e) {
            counts[n] = null;
        }
    }

    const now = new Date();
    const pad = x => String(x).padStart(2, "0");
    const ts = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())} ${pad(now.getHours())}:${pad(now.getMinutes())}:${pad(now.getSeconds())}`;
    const rec = { time: ts, phase: phase, counts: counts };

    let old = "";
    try { old = file.ReadTextSync(LOG_PATH); } catch (e) { /* 首次为空 */ }
    file.WriteTextSync(LOG_PATH, old + JSON.stringify(rec) + "\r\n");

    const got = Object.keys(counts).filter(k => counts[k] !== null).length;
    log.info(`背包采集计数[${phase}] 已记录 ${got}/${ITEMS.length} 种: ${JSON.stringify(counts)}`);
})();
