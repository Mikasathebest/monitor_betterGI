' 隐藏运行 PowerShell 脚本 (无控制台窗口, 不抢焦点)
' 用法: wscript run_hidden.vbs <脚本名.ps1>
Set ws = CreateObject("Wscript.Shell")
ws.Run "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -WindowStyle Hidden -File C:\Users\djf20\" & WScript.Arguments(0), 0, False
