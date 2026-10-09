"""bgilog 解析器测试。运行: python3 -m unittest discover tests"""
import json
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
import bgilog  # noqa: E402

SVC = "BetterGenshinImpact.Service.ScriptService"

# 真实 BGI 两行格式: 头行带类名, 消息在下一行
TWO_LINE = f"""[20:38:00.100] [INF] {SVC}
配置组 "全自动循环" 加载完成，共3个脚本，开始执行
[20:38:01.000] [INF] {SVC}
开始执行地图追踪任务: "09-柔灯铃"
[20:38:20.000] [INF] BetterGenshinImpact.GameTask.TpTask
传送完成
[20:38:40.000] [INF] BetterGenshinImpact.GameTask.AutoPick
交互或拾取："柔灯铃"
[20:38:45.000] [INF] BetterGenshinImpact.GameTask.AutoPick
交互或拾取："柔灯铃"
[20:38:46.000] [INF] BetterGenshinImpact.GameTask.AutoPick
交互或拾取："调查"
[20:39:30.000] [INF] {SVC}
执行结束: "09-柔灯铃"
[20:39:31.000] [INF] {SVC}
开始执行地图追踪任务: "不存在的路线"
[20:39:31.003] [ERR] {SVC}
路径文件不存在
[20:39:31.500] [INF] {SVC}
执行结束: "不存在的路线"
[20:39:32.000] [INF] {SVC}
开始执行地图追踪任务: "弹窗卡住"
[20:39:35.000] [ERR] BetterGenshinImpact.GameTask.Common
未能返回主界面
[20:39:41.000] [INF] {SVC}
执行结束: "弹窗卡住"
[20:39:42.000] [INF] {SVC}
配置组 "全自动循环" 执行结束
"""

# CanLiang 测试用的单行格式
ONE_LINE = """[12:00:00.000] [INFO] [TestClass] 配置组 "测试组" 加载完成，共1个脚本，开始执行
[12:01:00.000] [INFO] [TestClass] 交互或拾取："测试物品"
[12:02:00.000] [INFO] [TestClass] 配置组 "测试组" 执行结束"""


class ParseTest(unittest.TestCase):
    def test_two_line_format(self):
        r = bgilog.analyze(TWO_LINE)
        self.assertEqual(r["items_total"], {"柔灯铃": 2})  # 调查 被过滤
        self.assertEqual(r["items_by_group"], {"全自动循环": {"柔灯铃": 2}})
        self.assertEqual(r["groups"][0]["end"], "20:39:42")
        verdicts = {t["name"]: t["verdict"] for t in r["tasks"]}
        self.assertEqual(verdicts, {"09-柔灯铃": "ok", "不存在的路线": "missing", "弹窗卡住": "fake"})
        rou = r["tasks"][0]
        self.assertEqual((rou["duration"], rou["teleports"], rou["pickups"]), (89, 1, {"柔灯铃": 2}))
        self.assertTrue(any("未能返回主界面" in k for k in r["top_errors"]))

    def test_one_line_format(self):
        r = bgilog.analyze(ONE_LINE)
        self.assertEqual(r["items_by_group"], {"测试组": {"测试物品": 1}})

    def test_since_filter(self):
        r = bgilog.analyze(TWO_LINE, since="20:39")
        self.assertEqual(r["items_total"], {})
        self.assertEqual(len(r["tasks"]), 2)

    def test_midnight_wrap_and_unfinished_task(self):
        text = f"""[23:59:50.000] [INF] {SVC}
开始执行地图追踪任务: "跨午夜"
[00:00:30.000] [INF] X
交互或拾取："水晶块"
"""
        r = bgilog.analyze(text)
        t = r["tasks"][0]
        self.assertEqual((t["verdict"], t["pickups"]), ("running", {"水晶块": 1}))
        self.assertEqual(r["active_seconds"], 40)

    def test_active_seconds_gap_split(self):
        # 0-60 一段, 隔 10 分钟, 660-700 一段
        self.assertEqual(bgilog.active_seconds([0, 30, 60, 660, 700]), 100)


class BaselineTest(unittest.TestCase):
    def test_regression_detected(self):
        with tempfile.TemporaryDirectory() as d:
            old = bgilog.STATS_DIR
            bgilog.STATS_DIR = Path(d)
            try:
                for day, n in [("2026-10-01", 8), ("2026-10-02", 9), ("2026-10-03", 7)]:
                    task = {"name": "09-柔灯铃", "verdict": "ok", "pickups": {"柔灯铃": n}}
                    (Path(d) / f"{day}.json").write_text(json.dumps({"tasks": [task]}), encoding="utf-8")
                today = TWO_LINE.replace('交互或拾取："柔灯铃"', '交互或拾取："调查"')
                report, md = bgilog.build_report(today, "2026-10-04", save=True)
                self.assertIn("比历史基线明显变少", md)
                self.assertIn("历史中位 8", md)
                self.assertTrue((Path(d) / "2026-10-04.json").exists())
            finally:
                bgilog.STATS_DIR = old


if __name__ == "__main__":
    unittest.main()
