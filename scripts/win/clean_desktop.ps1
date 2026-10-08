# 清理 Session 1 残留控制台窗口 (之前 Agent 可见任务留下的) + 游戏置前台 + 截图
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [Text.Encoding]::UTF8
$log = 'C:\Users\djf20\cycle_log.txt'
function Log($m) { "$(Get-Date -Format 'HH:mm:ss') $m" | Out-File $log -Append -Encoding utf8 }

# 1. 杀 Session 1 里跑我们脚本的 powershell 控制台 (不动 Session 0 的 sshd 进程)
$killed = 0
Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" | Where-Object {
  $_.SessionId -eq 1 -and $_.CommandLine -match 'djf20\\(door_clicker|enter_door|uia_|mon_|agent_|run_|check_|diag_|read_|tail_|grep_|esc_|shot_)'
} | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; $killed++ }
Log "清理控制台: 杀掉 $killed 个残留 powershell (Session 1)"

# 2. 游戏置前台
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Fg2 {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int s);
}
"@
$ys = Get-Process YuanShen -ErrorAction SilentlyContinue
if ($ys -and $ys.MainWindowHandle -ne 0) {
  [Fg2]::ShowWindow($ys.MainWindowHandle, 9) | Out-Null
  [Fg2]::SetForegroundWindow($ys.MainWindowHandle) | Out-Null
  Log "游戏已置前台"
} else { Log "游戏进程或窗口句柄不存在" }
Start-Sleep -Seconds 2
& powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\screen.ps1
Write-Output 'CLEAN_OK'
