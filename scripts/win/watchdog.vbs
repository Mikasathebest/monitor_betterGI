' 看门狗隐藏启动器: 避免每 30 分钟弹控制台抢游戏前台 (BGI 会因焦点丢失自动暂停)
Set ws = CreateObject("Wscript.Shell")
ws.Run "powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File C:\Users\djf20\watchdog.ps1", 0, False
