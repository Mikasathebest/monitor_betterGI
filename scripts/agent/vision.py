#!/usr/bin/env python3
"""CV 视觉模型封装: nvidia/qwen/eccn-qwen3.5-122b-a10b (chat completions, 支持图像输入)
给主 Agent 提供"看懂游戏画面"的能力: 游戏状态/卡点/当前队伍/角色识别
"""
import base64
import os
from pathlib import Path

from dotenv import load_dotenv
from openai import OpenAI

ROOT = Path(__file__).resolve().parent.parent.parent
load_dotenv(ROOT / ".env")

# 基准实测 (2026-09-16, 门界面截图×2):
#   gemini-3.5-flash  15.3s 准确详细          ← 选中: 最快且准
#   gpt-5.5           20-41s 准确             ← 备选
#   qwen3.5-122b      35-68s 偶发空回复        ← 太慢且不稳, 弃用
#   qwen3.8-flash-next 129-161s 慢到不可用     ← 弃用
VISION_MODEL = os.environ.get("VISION_MODEL", "us/gcp/google/eccn-gemini-3.5-flash")

_vision_client = None


def _client() -> OpenAI:
    global _vision_client
    if _vision_client is None:
        _vision_client = OpenAI(
            base_url="https://inference-api.nvidia.com/v1",
            api_key=os.environ["INFERENCE_API_KEY"],
            timeout=180.0,
        )
    return _vision_client


def analyze_image(image_path: str, question: str) -> str:
    """把截图喂给 CV 模型, 返回文字分析。question 指明要识别什么"""
    p = Path(image_path)
    b64 = base64.b64encode(p.read_bytes()).decode()
    resp = _client().chat.completions.create(
        model=VISION_MODEL,
        messages=[
            {"role": "system", "content": "你是原神游戏画面分析专家。精确、简洁地回答关于截图的问题, 不确定就说不确定。"},
            {"role": "user", "content": [
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{b64}"}},
                {"type": "text", "text": question},
            ]},
        ],
        max_tokens=2048,
    )
    return resp.choices[0].message.content


if __name__ == "__main__":
    import sys
    img = sys.argv[1]
    q = sys.argv[2] if len(sys.argv) > 2 else "描述这个画面: 游戏当前处于什么状态?"
    print(analyze_image(img, q))
