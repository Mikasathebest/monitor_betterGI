# 任务机制测试: 写时间戳 + 光标位置 + 会话ID
$log = 'C:\Users\djf20\tasktest.txt'
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class TT { [DllImport("user32.dll")] public static extern bool GetCursorPos(out POINT p); public struct POINT { public int X; public int Y; } [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
"@
[TT]::SetProcessDPIAware() | Out-Null
$p = New-Object TT+POINT
[TT]::GetCursorPos([ref]$p) | Out-Null
"$(Get-Date -Format 'HH:mm:ss') session=$((Get-Process -Id $PID).SessionId) cursor=($($p.X),$($p.Y))" | Out-File $log -Append -Encoding utf8
