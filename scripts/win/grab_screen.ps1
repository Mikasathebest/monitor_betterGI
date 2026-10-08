param([string]$Out = "d:\Projects\genshin_detect\screen_real.png")
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;using System.Runtime.InteropServices;
public class ScrCapR {
  [DllImport("user32.dll")] public static extern int GetSystemMetrics(int i);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[ScrCapR]::SetProcessDPIAware() | Out-Null
$w = [ScrCapR]::GetSystemMetrics(78); $h = [ScrCapR]::GetSystemMetrics(79)
$x = [ScrCapR]::GetSystemMetrics(76); $y = [ScrCapR]::GetSystemMetrics(77)
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($x, $y, 0, 0, (New-Object System.Drawing.Size($w, $h)))
$bmp.Save($Out)
$g.Dispose(); $bmp.Dispose()
Write-Output "saved $Out"