# ============================================================
#  CookieGuard - build\New-Icon.ps1
#  Draws the app icon (CookieGuard.ico), the ad blocker icons
#  (adblock\icons\*.png) and a preview strip (build\icon-preview.png).
#
#  Every size is drawn on its own grid instead of being shrunk from
#  256 px: at 16 px a shrunk shield turns into mush. Small sizes get
#  thicker strokes and fewer chocolate chips.
#
#  Frames up to 64 px go into the .ico as classic 32-bit bitmaps,
#  256 px as PNG. That is what Explorer, the taskbar, the tray and
#  System.Drawing.Icon all read without surprises.
# ============================================================

param(
    [string]$OutPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'CookieGuard.ico'),
    [string]$ExtDir = (Join-Path (Split-Path -Parent $PSScriptRoot) 'adblock\icons'),
    [string]$Preview = (Join-Path $PSScriptRoot 'icon-preview.png'),
    [string]$Logo = (Join-Path (Split-Path -Parent $PSScriptRoot) 'docs\assets\logo.png')
)

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

function New-Color([string]$Hex, [int]$A = 255) {
    $c = [System.Drawing.ColorTranslator]::FromHtml($Hex)
    return [System.Drawing.Color]::FromArgb($A, $c.R, $c.G, $c.B)
}

function New-ShieldPath([double]$s) {
    # unit shield on an s×s grid: flat top with soft corners, straight
    # sides, two curves meeting at the point
    $u = { param($v) [single]($v * $s) }
    $p = New-Object System.Drawing.Drawing2D.GraphicsPath
    $l = 0.13; $r = 0.87; $t = 0.08; $k = 0.10
    $p.AddLine((& $u ($l + $k)), (& $u $t), (& $u ($r - $k)), (& $u $t))
    $p.AddBezier((& $u ($r - $k)), (& $u $t), (& $u ($r - 0.02)), (& $u $t), (& $u $r), (& $u ($t + 0.03)), (& $u $r), (& $u ($t + $k)))
    $p.AddLine((& $u $r), (& $u ($t + $k)), (& $u $r), (& $u 0.50))
    $p.AddBezier((& $u $r), (& $u 0.50), (& $u $r), (& $u 0.74), (& $u 0.66), (& $u 0.86), (& $u 0.50), (& $u 0.95))
    $p.AddBezier((& $u 0.50), (& $u 0.95), (& $u 0.34), (& $u 0.86), (& $u $l), (& $u 0.74), (& $u $l), (& $u 0.50))
    $p.AddLine((& $u $l), (& $u 0.50), (& $u $l), (& $u ($t + $k)))
    $p.AddBezier((& $u $l), (& $u ($t + $k)), (& $u $l), (& $u ($t + 0.03)), (& $u ($l + 0.02)), (& $u $t), (& $u ($l + $k)), (& $u $t))
    $p.CloseFigure()
    return $p
}

function New-IconBitmap {
    param([int]$Size, [switch]$Block)
    $s = [double]$Size
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.Clear([System.Drawing.Color]::Transparent)

    $shield = New-ShieldPath $s
    $fill = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF([single]0, [single]0)),
        (New-Object System.Drawing.PointF([single]0, [single]$s)),
        (New-Color '#4F9BFF'), (New-Color '#1D4ED8'))
    $g.FillPath($fill, $shield)
    # dark rim keeps the edge visible on a light taskbar; a light inner
    # rim gives depth on a dark one. The inner rim disappears below 32 px.
    $rimW = [Math]::Max(1.0, $s / 28)
    $rim = New-Object System.Drawing.Pen((New-Color '#0B2A6F'), [single]$rimW)
    $rim.LineJoin = 'Round'
    $g.DrawPath($rim, $shield)
    if ($Size -ge 32) {
        $hi = New-Object System.Drawing.Pen((New-Color '#BFD7FF' 150), [single]($rimW * 0.9))
        $inner = New-ShieldPath ($s * 0.88)
        $m = New-Object System.Drawing.Drawing2D.Matrix
        $m.Translate([single]($s * 0.06), [single]($s * 0.045))
        $inner.Transform($m)
        $g.DrawPath($hi, $inner)
        $hi.Dispose(); $inner.Dispose()
    }

    # cookie with a bite: the bite is painted with the shield's own
    # gradient, so it reads as a hole in the cookie
    $cx = $s * 0.50; $cy = $s * 0.47; $r = $s * 0.235
    if ($Size -le 16) { $r = $s * 0.27 }
    $dough = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF([single]0, [single]($cy - $r))),
        (New-Object System.Drawing.PointF([single]0, [single]($cy + $r))),
        (New-Color '#FBE3B0'), (New-Color '#E9B35F'))
    $g.FillEllipse($dough, [single]($cx - $r), [single]($cy - $r), [single](2 * $r), [single](2 * $r))
    $br = $r * 0.42
    $bx = $cx + $r * 0.78; $by = $cy - $r * 0.72
    $g.FillEllipse($fill, [single]($bx - $br), [single]($by - $br), [single](2 * $br), [single](2 * $br))

    $chip = New-Object System.Drawing.SolidBrush((New-Color '#5A3214'))
    $chips = @(@(-0.38, -0.22, 0.17), @(0.20, 0.30, 0.17), @(-0.12, 0.48, 0.13), @(0.40, -0.02, 0.12), @(-0.50, 0.24, 0.11))
    $n = 5
    if ($Size -le 16) { $n = 2 } elseif ($Size -le 24) { $n = 3 } elseif ($Size -le 32) { $n = 4 }
    for ($i = 0; $i -lt $n; $i++) {
        $c = $chips[$i]
        $cr = [Math]::Max(0.9, $r * $c[2])
        if ($Size -le 24) { $cr = [Math]::Max(1.0, $r * 0.2) }
        $g.FillEllipse($chip, [single]($cx + $r * $c[0] - $cr), [single]($cy + $r * $c[1] - $cr), [single](2 * $cr), [single](2 * $cr))
    }

    if ($Block) {
        # ad blocker: a red "no entry" badge in the lower right corner
        $d = $s * 0.46
        $ox = $s - $d - $s * 0.01; $oy = $s - $d - $s * 0.01
        $gap = [Math]::Max(1.0, $s / 22)
        $cut = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 15, 23, 42))
        $g.FillEllipse($cut, [single]($ox - $gap), [single]($oy - $gap), [single]($d + 2 * $gap), [single]($d + 2 * $gap))
        $red = New-Object System.Drawing.SolidBrush((New-Color '#EF4444'))
        $g.FillEllipse($red, [single]$ox, [single]$oy, [single]$d, [single]$d)
        $bar = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $bh = [Math]::Max(1.6, $d * 0.20)
        $g.FillRectangle($bar, [single]($ox + $d * 0.22), [single]($oy + ($d - $bh) / 2), [single]($d * 0.56), [single]$bh)
        $cut.Dispose(); $red.Dispose(); $bar.Dispose()
    }

    $g.Dispose(); $fill.Dispose(); $rim.Dispose(); $dough.Dispose(); $chip.Dispose(); $shield.Dispose()
    return $bmp
}

# 32-bit DIB frame for the .ico: header, bottom-up BGRA, AND mask
function ConvertTo-IcoDib([System.Drawing.Bitmap]$Bmp) {
    $w = $Bmp.Width; $h = $Bmp.Height
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([UInt32]40); $bw.Write([Int32]$w); $bw.Write([Int32]($h * 2))
    $bw.Write([UInt16]1); $bw.Write([UInt16]32); $bw.Write([UInt32]0)
    $bw.Write([UInt32]0); $bw.Write([Int32]0); $bw.Write([Int32]0); $bw.Write([UInt32]0); $bw.Write([UInt32]0)
    for ($y = $h - 1; $y -ge 0; $y--) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = $Bmp.GetPixel($x, $y)
            $bw.Write([byte]$c.B); $bw.Write([byte]$c.G); $bw.Write([byte]$c.R); $bw.Write([byte]$c.A)
        }
    }
    $stride = [int]([Math]::Ceiling($w / 32.0) * 4)
    for ($y = $h - 1; $y -ge 0; $y--) {
        $row = New-Object byte[] $stride
        for ($x = 0; $x -lt $w; $x++) {
            if ($Bmp.GetPixel($x, $y).A -eq 0) { $row[[int][Math]::Floor($x / 8)] = $row[[int][Math]::Floor($x / 8)] -bor (0x80 -shr ($x % 8)) }
        }
        $bw.Write($row)
    }
    $bw.Flush()
    return , $ms.ToArray()
}

function ConvertTo-Png([System.Drawing.Bitmap]$Bmp) {
    $ms = New-Object System.IO.MemoryStream
    $Bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    return , $ms.ToArray()
}

# ---- CookieGuard.ico ----
$sizes = @(16, 20, 24, 32, 40, 48, 64, 256)
$frames = @()
foreach ($sz in $sizes) {
    $bmp = New-IconBitmap -Size $sz
    if ($sz -ge 256) { [byte[]]$bytes = ConvertTo-Png $bmp } else { [byte[]]$bytes = ConvertTo-IcoDib $bmp }
    $frames += , @($sz, $bytes)
    $bmp.Dispose()
}
$out = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($out)
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$frames.Count)
$offset = 6 + 16 * $frames.Count
foreach ($f in $frames) {
    $sz = $f[0]; $bytes = $f[1]
    $bw.Write([Byte]$(if ($sz -ge 256) { 0 } else { $sz }))
    $bw.Write([Byte]$(if ($sz -ge 256) { 0 } else { $sz }))
    $bw.Write([Byte]0); $bw.Write([Byte]0)
    $bw.Write([UInt16]1); $bw.Write([UInt16]32)
    $bw.Write([UInt32]$bytes.Length); $bw.Write([UInt32]$offset)
    $offset += $bytes.Length
}
foreach ($f in $frames) { $bw.Write([byte[]]$f[1]) }
$bw.Flush()
[IO.File]::WriteAllBytes($OutPath, $out.ToArray())
$bw.Dispose(); $out.Dispose()
Write-Host "Icon: $OutPath ($($sizes -join ', ') px)" -ForegroundColor Green

# ---- ad blocker icons ----
if ($ExtDir -and (Test-Path -LiteralPath $ExtDir)) {
    foreach ($sz in @(16, 32, 48, 128)) {
        $bmp = New-IconBitmap -Size $sz -Block
        $bmp.Save((Join-Path $ExtDir "$sz.png"), [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    }
    Write-Host "Extension icons: $ExtDir" -ForegroundColor Green
}

# ---- logo for the README ----
if ($Logo -and (Test-Path -LiteralPath (Split-Path -Parent $Logo))) {
    $bmp = New-IconBitmap -Size 256
    $bmp.Save($Logo, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

# ---- preview strip ----
if ($Preview) {
    $pw = 780; $ph = 300
    $pv = New-Object System.Drawing.Bitmap($pw, $ph)
    $g = [System.Drawing.Graphics]::FromImage($pv)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $g.Clear((New-Color '#15181D'))
    $light = New-Object System.Drawing.SolidBrush((New-Color '#F3F4F6'))
    $g.FillRectangle($light, 0, 150, $pw, 150)
    foreach ($row in @(@(0, $false), @(150, $true))) {
        $x = 24
        foreach ($sz in @(128, 64, 48, 32, 24, 16)) {
            $b = New-IconBitmap -Size $sz -Block:$row[1]
            $g.DrawImage($b, $x, $row[0] + (150 - $sz) / 2, $sz, $sz)
            $x += $sz + 28
            $b.Dispose()
        }
        foreach ($sz in @(16, 32)) {
            $b = New-IconBitmap -Size $sz -Block:$row[1]
            $g.DrawImage($b, $x, $row[0] + 43, 64, 64)
            $x += 92
            $b.Dispose()
        }
    }
    $g.Dispose(); $light.Dispose()
    $pv.Save($Preview, [System.Drawing.Imaging.ImageFormat]::Png)
    $pv.Dispose()
}
