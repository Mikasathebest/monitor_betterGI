Get-Process -ErrorAction SilentlyContinue | Where-Object { $_.ProcessName -in @('BetterGI','YuanShen','powershell','conhost') } | Select-Object ProcessName,Id,SessionId,StartTime,Responding,MainWindowTitle,Path | Format-List
Get-ScheduledTask -TaskName 'AgentS1Runner' -ErrorAction SilentlyContinue | Get-ScheduledTaskInfo | Format-List *
