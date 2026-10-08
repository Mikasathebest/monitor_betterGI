# Remote-control the Windows capture process (called from Mac over SSH, or run locally).
# Usage:
#   powershell -NoProfile -File scripts\remote_capture.ps1 -Action start [-Name live01] [-Duration 1800]
#   powershell -NoProfile -File scripts\remote_capture.ps1 -Action status [-Name live01]
#   powershell -NoProfile -File scripts\remote_capture.ps1 -Action stop  [-Name live01]
# Notes: Start-Process detaches from the SSH session; stop uses taskkill /T (process tree).
# Requires admin rights (Npcap); otherwise scapy errors land in <Name>.err.log.
# IMPORTANT: keep this file pure ASCII - Windows PowerShell 5.1 misreads UTF-8-no-BOM as GBK.
param(
    [Parameter(Mandatory=$true)][ValidateSet("start","stop","status")] [string]$Action,
    [string]$Name = "live01",
    [int]$Duration = 1800
)

$repo = "D:\Projects\genshin_detect"
$exe  = Join-Path $repo ".venv\Scripts\genshin-detect.exe"
$dir  = Join-Path $repo "captures"
$out  = Join-Path $dir "$Name.jsonl"
$pidfile = Join-Path $dir "$Name.pid"
New-Item -ItemType Directory -Force $dir | Out-Null

switch ($Action) {
    "start" {
        if (Test-Path $pidfile) { "ERROR: $pidfile exists, run -Action stop first"; exit 1 }
        if (-not (Test-Path $exe)) { "ERROR: $exe not found (venv missing?)"; exit 1 }
        $p = Start-Process -FilePath $exe `
            -ArgumentList @("sniff","-o",$out,"--duration",$Duration) `
            -WorkingDirectory $repo -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput (Join-Path $dir "$Name.out.log") `
            -RedirectStandardError  (Join-Path $dir "$Name.err.log")
        $p.Id | Out-File -Encoding ascii $pidfile
        "STARTED pid=$($p.Id) out=$out duration=${Duration}s"
    }
    "status" {
        if (-not (Test-Path $pidfile)) { "NOT RUNNING (no pid file)"; exit 0 }
        $procId = [int](Get-Content $pidfile)
        $proc = Get-Process -Id $procId -ErrorAction SilentlyContinue
        if ($proc) {
            $size = 0
            if (Test-Path $out) { $size = (Get-Item $out).Length }
            "RUNNING pid=$procId out=${size}B"
        } else { "DEAD pid=$procId (see $Name.err.log)" }
    }
    "stop" {
        if (-not (Test-Path $pidfile)) { "NOT RUNNING"; exit 0 }
        $procId = [int](Get-Content $pidfile)
        taskkill /PID $procId /T /F 2>&1 | Out-String
        Remove-Item $pidfile -Force
        "STOPPED pid=$procId"
    }
}
