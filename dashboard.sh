#!/usr/bin/env bash
# BetterGI Dashboard 启动器 — 用本项目 venv 的 python 执行 dashboard.py
# 用法: ./dashboard.sh [端口]   (默认 8765)
set -e
cd "$(dirname "$0")"

PORT="${1:-8765}"

# venv 不存在则创建 (纯标准库, 无需 pip 安装)
if [ ! -x ".venv/Scripts/python.exe" ] && [ ! -x ".venv/bin/python" ]; then
    PY="${PYTHON:-python}"
    command -v "$PY" >/dev/null 2>&1 || PY=py
    echo "[dashboard] 创建虚拟环境 .venv ..."
    "$PY" -m venv .venv
fi

# Windows / Linux venv 路径兼容
if [ -x ".venv/Scripts/python.exe" ]; then
    VPY=".venv/Scripts/python.exe"
else
    VPY=".venv/bin/python"
fi

echo "[dashboard] http://localhost:${PORT}  ($VPY)"
exec "$VPY" scripts/agent/dashboard.py "$PORT"
