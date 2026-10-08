# 抓取原神窗口画面(PrintWindow, 独占全屏也能抓)
# 用法: powershell -ExecutionPolicy Bypass -File grab_game.ps1 [-Out path.png]
param(
    [string]$Out = "d:\Projects\genshin_detect\screen_pw.png"
)
Add-Type -AssemblyName System.Drawing
if (-not ("PW_Grab" -as [type])) {
Add-Type @"
using System;using System.Runtime.InteropServices;using System.Drawing;
public class PW_Grab {
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdcBlt, uint flags);
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  public struct RECT{public int l;public int t;public int r;public int b;}
  public static Bitmap Grab(IntPtr h){
    RECT rc; GetClientRect(h, out rc);
    int w=rc.r-rc.l, ht=rc.b-rc.t;
    if(w<=0)w=1920; if(ht<=0)ht=1080;
    Bitmap bmp=new Bitmap(w,ht);
    using(Graphics g=Graphics.FromImage(bmp)){
      IntPtr hdc=g.GetHdc();
      PrintWindow(h,hdc,3);
      g.ReleaseHdc(hdc);
    }
    return bmp;
  }
}
"@ -ReferencedAssemblies System.Drawing
}
$g = Get-Process YuanShen -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $g) { Write-Output "YuanShen not running"; exit 1 }
$bmp = [PW_Grab]::Grab($g.MainWindowHandle)
$bmp.Save($Out)
$bmp.Dispose()
Write-Output "saved $Out"
