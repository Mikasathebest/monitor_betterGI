#!/usr/bin/env python3
"""视觉模型基准: 同图同题测 延迟+准确率, 为 Agent 选 CV 模型
用法: .venv/bin/python scripts/agent/vision_bench.py <图片路径> [更多图片...]
"""
import base64
import os
import sys
import time
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

ROOT = Path(__file__).resolve().parent.parent.parent
load_dotenv(ROOT / ".env")

MODELS = [
    "us/gcp/google/eccn-gemini-3.5-flash",
    "nvidia/qwen/eccn-qwen3.8-flash-next",
    "us/azure/openai/eccn-gpt-5.5",
    "nvidia/qwen/eccn-qwen3.5-122b-a10b",  # 现役, 作对照
]

QUESTION = (
    "这是 Windows 桌面截图, 其中有原神游戏窗口。请判断: "
    "1) 原神当前处于什么状态 (登录门-点击进入 / 大世界 / 队伍配置 / 地图 / 已退出不可见)? "
    "2) 你看到了什么关键 UI 元素证明你的判断? 3) 一句话结论开头, 格式: 状态=XXX"
)

client = OpenAI(
    base_url="https://inference-api.nvidia.com/v1",
    api_key=os.environ["INFERENCE_API_KEY"],
    timeout=180.0,
)


def test(model: str, img_path: str) -> dict:
    b64 = base64.b64encode(Path(img_path).read_bytes()).decode()
    t0 = time.time()
    try:
        resp = client.chat.completions.create(
            model=model,
            messages=[
                {"role": "system", "content": "你是原神游戏画面分析专家。精确简洁, 不确定就说不确定。"},
                {"role": "user", "content": [
                    {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
                    {"type": "text", "text": QUESTION},
                ]},
            ],
            max_tokens=1024,
        )
        dt = time.time() - t0
        text = resp.choices[0].message.content or "(空回复 — 可能不支持图像输入)"
        return {"ok": True, "latency": dt, "text": text}
    except Exception as e:
        return {"ok": False, "latency": time.time() - t0, "text": str(e)[:300]}


def main():
    images = sys.argv[1:] or ["/tmp/door_now_small.png"]
    results = []
    for img in images:
        print(f"\n########## 图片: {img} ##########")
        for m in MODELS:
            r = test(m, img)
            status = f"{r['latency']:.1f}s" if r["ok"] else f"FAIL {r['latency']:.1f}s"
            print(f"\n===== {m}  [{status}] =====")
            print(r["text"][:600])
            results.append({"model": m, "image": img, **r})
    print("\n\n########## 延迟汇总 ##########")
    for r in results:
        print(f"{'OK ' if r['ok'] else 'FAIL'} {r['latency']:6.1f}s  {r['model']}  {Path(r['image']).name}")


if __name__ == "__main__":
    main()
