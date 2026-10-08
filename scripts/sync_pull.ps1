# Windows 端一键同步: 拉取最新代码并安装依赖
# 用法: powershell -ExecutionPolicy Bypass -File scripts\sync_pull.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

# 本地若有未提交改动先暂存, 避免 pull 冲突
$dirty = git status --porcelain
if ($dirty) {
    Write-Host "本地有改动, 先 stash..."
    git stash push -m "auto-stash before sync $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
}

git pull --ff-only origin main

if (Test-Path requirements.txt) {
    pip install -r requirements.txt --quiet
}
pip install -e . --quiet

Write-Host "✓ 已同步到最新代码"
if ($dirty) { Write-Host "提示: 之前有本地改动被 stash, 需要时用 'git stash pop' 恢复" }
