# 鱼饵脚本部署 step1: 解压到 JsScript (组文件修改交给 python, PS 5.1 大 JSON 不可靠)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$base = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
$dst = "$base\User\JsScript\AutoFishingTeyvat-Bait"
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
tar -xzf 'C:\Users\djf20\bait_pack.tar.gz' -C "$base\User\JsScript"
if (-not (Test-Path "$dst\main.js")) { throw 'main.js 未就位' }
$fc = (Get-ChildItem $dst -Recurse -File).Count
Write-Output "脚本就位: $dst ($fc 个文件)"
