# find_button.ps1 - locate golden confirm button in notice dialog
param([string]$Img = "d:\Projects\genshin_detect\screen_pw.png")
Add-Type -AssemblyName System.Drawing
$bmp = New-Object System.Drawing.Bitmap($Img)
$w = $bmp.Width; $h = $bmp.Height
Write-Output "image: ${w}x${h}"

# golden button: high R, medium-high G, low B (gold ~ #D3BC8E / #ECE5D8 text)
# scan bottom half for bright golden pixels
$minX = $w; $maxX = 0; $minY = $h; $maxY = 0; $count = 0
for ($y = [int]($h*0.5); $y -lt $h; $y += 2) {
  for ($x = 0; $x -lt $w; $x += 2) {
    $c = $bmp.GetPixel($x, $y)
    if ($c.R -gt 180 -and $c.G -gt 150 -and $c.B -lt 160 -and $c.B -gt 80) {
      $count++
      if ($x -lt $minX) { $minX = $x }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}
$bmp.Dispose()
if ($count -gt 50) {
  $ccx = [int](($minX + $maxX) / 2); $ccy = [int](($minY + $maxY) / 2)
  Write-Output "golden region: ($minX,$minY)-($maxX,$maxY) center=($ccx,$ccy) pixels=$count"
  $gx = [int]($ccx * 1920 / $w); $gy = [int]($ccy * 1080 / $h)
  Write-Output "game coords: ($gx, $gy)"
} else {
  Write-Output "no golden button found (pixels=$count)"
}
