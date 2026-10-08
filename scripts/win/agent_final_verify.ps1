'STATE='+(Get-Content C:\Users\djf20\session_state.txt -Raw).Trim()
'GAME='+(@(Get-Process YuanShen -ErrorAction SilentlyContinue).Count)
'BGI='+(@(Get-Process BetterGI -ErrorAction SilentlyContinue).Count)
'BOOKMARK='+(Select-String -Path 'D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0\config.json' -Pattern 'nextScheduledTask' -SimpleMatch -ErrorAction SilentlyContinue | Select-Object -First 1).Line