// 背包采集计数: 调用 BGI 内置 CountInventoryItem 统计收集目标材料数量
// 用法: 收集A组/B组 组头(phase=before)、组尾(phase=after)各挂一条,
//       记录追加到脚本目录下的 inventory_log.jsonl, 由外部脚本差分统计每轮采集量
// 注意: CountInventoryItem 返回 -2 表示找到了但数字识别失败; 找不到的物品不返回键
(async function () {
    // ===== 跟踪物品清单 (与收集组内容对应, 2026-11-19: 移除琉鳞石/慕风蘑菇, 新增小灯草/落落莓/夜泊石; 2026-11-25: 新增特工祭刀) =====
    const ITEMS = [
        // 特产
        "清水玉", "小灯草", "落落莓", "妖精绿艾", "析晶褶伞",
        // 矿石
        "水晶块", "紫晶块", "虹滴晶", "星银矿石", "白铁块", "铁块", "夜泊石",
        // 敌人掉落 (T3: 肌生晶石的妖精 / 先驱秘源统辖阵列; 债务处理人: 特工祭刀)
        "幻造晶鳞石", "无秽的月铁", "特工祭刀"
    ];
    const phase = String(settings.phase || "before").trim();
    // 绝对路径避免 BGI 不同 file 方法解析相对路径基准不一致导致落盘失败
    // 部署位置固定为 D:\projects\betterGI\User\JsScript\背包采集计数\
    const LOG_PATH = "D:/projects/betterGI/User/JsScript/背包采集计数/inventory_log.jsonl";

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

    // AppendAllText 会自动创建文件; 不再先读后写, 避免 ReadTextSync 抛异常污染日志
    try {
        file.AppendAllText(LOG_PATH, JSON.stringify(rec) + "\r\n");
    } catch (e) {
        log.error("写入 inventory_log.jsonl 失败: " + (e && e.message));
    }

    const got = Object.keys(counts).filter(k => counts[k] !== null).length;
    log.info(`背包采集计数[${phase}] 已记录 ${got}/${ITEMS.length} 种: ${JSON.stringify(counts)}`);
})();
