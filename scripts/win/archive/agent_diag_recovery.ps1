$base='D:\Projects\better-genshin-impact\BetterGenshinImpact\bin\Release\net8.0-windows10.0.22621.0'
'NOW='+(Get-Date -Format o)
'BGI='+(@(Get-Process BetterGI -ErrorAction SilentlyContinue).Count)
'GAME='+(@(Get-Process YuanShen -ErrorAction SilentlyContinue).Count)
'TASK='+(Get-ScheduledTaskInfo -TaskName 'BGI_S1Run' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty LastTaskResult)
$f=Get-ChildItem "$base\log\better-genshin-impact*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if($f){'LOG='+$f.FullName;'LOGTIME='+$f.LastWriteTime.ToString('o');$fs=[IO.FileStream]::new($f.FullName,'Open','Read','ReadWrite');$sr=[IO.StreamReader]::new($fs,[Text.Encoding]::UTF8);$all=$sr.ReadToEnd();$sr.Close();$fs.Close();($all -split "`r?`n" | Select-Object -Last 15)}