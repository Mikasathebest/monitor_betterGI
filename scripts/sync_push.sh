#!/usr/bin/env bash
# Mac 端一键同步: 提交全部改动并推送到 GitHub (Windows 端随后 sync_pull.ps1)
# 用法: scripts/sync_push.sh ["提交信息"]
set -euo pipefail
cd "$(dirname "$0")/.."

msg="${1:-sync from mac: $(date '+%Y-%m-%d %H:%M:%S')}"

git add -A
if git diff --cached --quiet; then
    echo "没有改动, 无需同步"
    exit 0
fi

git commit -m "$msg"
git push origin main
echo "✓ 已推送到 GitHub, 到 Windows 上运行 scripts\\sync_pull.ps1"
