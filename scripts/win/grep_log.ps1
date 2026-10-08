# 日志关键字搜索 (FileStream 读, 避开文件锁)
# 用法: powershell -File grep_log.ps1 [-Pattern '一条龙和配置组任务结束'] [-Last 5]
param(
  [string]$Pattern = '一条龙和配置组任务结束',
  [int]$Last = 5,
  [string]$LogName = ''  # 例: 20260914 查指定日; 默认最新
)
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$logDir = 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\log'
if ($LogName) {
  $f = Get-Item "$logDir\better-genshin-impact$LogName.log"
} else {
  $f = Get-ChildItem "$logDir\better-genshin-impact*.log" | Sort-Object LastWriteTime -Descending | Select-Object -First 1
}
Write-Output ("LOGFILE: " + $f.Name)
$fs = [System.IO.FileStream]::new($f.FullName, 'Open', 'Read', 'ReadWrite')
$sr = [System.IO.StreamReader]::new($fs, [Text.Encoding]::UTF8)
$all = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$lines = $all -split "`r?`n"
Write-Output ("总行数: " + $lines.Count)
$hits = $lines | Select-String $Pattern
Write-Output ("匹配数: " + $hits.Count)
$hits | Select-Object -Last $Last | ForEach-Object { Write-Output $_.Line }
