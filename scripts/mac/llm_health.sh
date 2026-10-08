#!/bin/bash
# MacBook 上 LLM API 链路健康检查（在 MacBook 上执行；从 Windows 用:
#   ssh harryd@100.101.217.73 'bash -s' < scripts/mac/llm_health.sh）
set -u

echo "=== NV Inference Hub 连通性 (401=网络通但key过期; 000/超时=网络/VPN问题) ==="
KEY=$(grep -E '^NV_INFERENCE_HUB_API_KEY' "$HOME/.hermes/.env" 2>/dev/null | cut -d= -f2)
curl -s -o /dev/null -w "HTTP %{http_code}  %{time_total}s\n" \
  -H "Authorization: Bearer $KEY" --connect-timeout 8 -m 12 \
  https://api.nvcf.nvidia.com/v2/nvcf/health/status 2>&1

echo "=== Hermes / agent 最近错误 ==="
tail -200 "$HOME/.hermes/logs/agent.log" 2>/dev/null |
  grep -i -E 'error|fail|timeout' | tail -5

echo "=== llmproxy 9002 ==="
lsof -nP -iTCP:9002 -sTCP:LISTEN 2>/dev/null | tail -1 || echo "llmproxy 未运行"