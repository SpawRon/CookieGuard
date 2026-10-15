# ============================================================
#  CookieGuard - build\New-Icon.ps1
#  Рисует значок программы и собирает многоразмерный .ico.
#
#  Формат .ico с PNG внутри (Vista и новее) — поэтому каждый
#  размер кладётся как готовый PNG, а не как сырой битмап с
#  маской. Так проще и так значок остаётся чётким на 256.
# ============================================================

param([string]$OutPath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'CookieGuard.ico'))

Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

function New-ShieldBitmap {
    param([int]$Size)
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.Clear([System.Drawing.Color]::Transparent)

    $s = [double]$Size
    $pad = $s * 0.08
    $w = $s - 2 * $pad
    $h = $s - 2 * $pad

    # контур щита
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $cx = $pad + $w / 2
    $top = $pad
    $shoulder = $pad + $h * 0.26
    $waist = $pad + $h * 0.62
    $bottom = $pad + $h
    $left = $pad
    $right = $pad + $w

    $path.AddLine([single]$cx, [single]$top, [single]$right, [single]$shoulder)
    $path.AddBezier([single]$right, [single]$shoulder, [single]$right, [single]$waist,
                    [single]($cx + $w * 0.30), [single]($bottom - $h * 0.10), [single]$cx, [single]$bottom)
    $path.AddBezier([single]$cx, [single]$bottom, [single]($cx - $w * 0.30), [single]($bottom - $h * 0.10),
                    [single]$left, [single]$waist, [single]$left, [single]$shoulder)
    $path.CloseFigure()

    # заливка градиентом синего — как в окне программы
    $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        (New-Object System.Drawing.PointF([single]0, [single]0)),
        (New-Object System.Drawing.PointF([single]0, [single]$s)),
        [System.Drawing.Color]::FromArgb(255, 76, 141, 255),
        [System.Drawing.Color]::FromArgb(255, 43, 78, 140))
    $g.FillPath($brush, $path)

    $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 200, 220, 255), [single]([Math]::Max(1, $s * 0.035)))
    $g.DrawPath($pen, $path)

    # печенье внутри щита: круг с «крошками» — то, что программа охраняет
    $r = $s * 0.20
    $ccx = $cx
    $ccy = $pad + $h * 0.44
    $cookie = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 245, 222, 179))
    $g.FillEllipse($cookie, [single]($ccx - $r), [single]($ccy - $r), [single]($r * 2), [single]($r * 2))

    $chip = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 92, 58, 28))
    $cr = [Math]::Max(1.0, $s * 0.035)
    foreach ($p in @(@(-0.38, -0.30), @(0.34, -0.12), @(-0.10, 0.34), @(0.12, 0.05), @(-0.42, 0.18))) {
        $px = $ccx + $r * $p[0]
        $py = $ccy + $r * $p[1]
        $g.FillEllipse($chip, [single]($px - $cr), [single]($py - $cr), [single]($cr * 2), [single]($cr * 2))
    }

    $g.Dispose(); $brush.Dispose(); $pen.Dispose(); $cookie.Dispose(); $chip.Dispose(); $path.Dispose()
    return $bmp
}

$sizes = @(16, 24, 32, 48, 64, 128, 256)
$pngs = @()
foreach ($sz in $sizes) {
    $bmp = New-ShieldBitmap -Size $sz
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    $pngs += , @($sz, $ms.ToArray())
    $bmp.Dispose(); $ms.Dispose()
}

# сборка контейнера .ico вручную: заголовок, таблица записей, затем данные
$out = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($out)
$bw.Write([UInt16]0)                 # зарезервировано
$bw.Write([UInt16]1)                 # тип: значок
$bw.Write([UInt16]$pngs.Count)

$offset = 6 + 16 * $pngs.Count
foreach ($p in $pngs) {
    $sz = $p[0]; $bytes = $p[1]
    $bw.Write([Byte]$(if ($sz -ge 256) { 0 } else { $sz }))   # 0 означает 256
    $bw.Write([Byte]$(if ($sz -ge 256) { 0 } else { $sz }))
    $bw.Write([Byte]0)               # палитра не используется
    $bw.Write([Byte]0)               # зарезервировано
    $bw.Write([UInt16]1)             # плоскостей
    $bw.Write([UInt16]32)            # бит на пиксель
    $bw.Write([UInt32]$bytes.Length)
    $bw.Write([UInt32]$offset)
    $offset += $bytes.Length
}
foreach ($p in $pngs) { $bw.Write($p[1]) }
$bw.Flush()

[IO.File]::WriteAllBytes($OutPath, $out.ToArray())
$bw.Dispose(); $out.Dispose()

Write-Host "Значок собран: $OutPath ($([math]::Round((Get-Item $OutPath).Length/1KB,1)) КБ, размеров: $($sizes.Count))" -ForegroundColor Green
