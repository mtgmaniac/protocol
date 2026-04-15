$ErrorActionPreference = "Stop"
$assets = "C:\Users\Kev\.cursor\projects\c-Users-Kev-overload-protocol\assets"
$outDir = "C:\Users\Kev\overload-protocol\public\enemies"
$tw = 240
$th = 317
$ar = $tw / $th

New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Add-Type -AssemblyName System.Drawing

function Resize-Portrait {
    param([string]$Src, [string]$Dst)
    $img = [System.Drawing.Image]::FromFile($Src)
    try {
        $iw = $img.Width
        $ih = $img.Height
        $srcAr = $iw / $ih
        if ($srcAr -gt $ar) {
            $ch = $ih
            $cw = [int]($ih * $ar)
            $sx = [int](($iw - $cw) / 2)
            $sy = 0
        } else {
            $cw = $iw
            $ch = [int]($iw / $ar)
            $sx = 0
            $sy = [int](($ih - $ch) / 2)
        }
        $bmp = New-Object System.Drawing.Bitmap $tw, $th
        $bmp.SetResolution(96, 96)
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
        $g.DrawImage(
            $img,
            [System.Drawing.Rectangle]::new(0, 0, $tw, $th),
            [System.Drawing.Rectangle]::new($sx, $sy, $cw, $ch),
            [System.Drawing.GraphicsUnit]::Pixel
        )
        $g.Dispose()
        $bmp.Save($Dst, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
        Write-Host "OK $Dst"
    } finally {
        $img.Dispose()
    }
}

$map = @{
    "enemy-scrap-raw.png"  = "scrap-portrait.png"
    "enemy-rust-raw.png"  = "rust-portrait.png"
    "enemy-patrol-raw.png" = "patrol-portrait.png"
    "enemy-guard-raw.png"  = "guard-portrait.png"
    "enemy-warden-raw.png" = "warden-portrait.png"
    "enemy-volt-raw.png"   = "volt-portrait.png"
    "enemy-boss-raw.png"   = "boss-portrait.png"
}

foreach ($e in $map.GetEnumerator()) {
    $src = Join-Path $assets $e.Key
    $dst = Join-Path $outDir $e.Value
    if (-not (Test-Path $src)) { throw "Missing: $src" }
    Resize-Portrait -Src $src -Dst $dst
}
