# ============================================================
#  CookieGuard - Ui.Theme.ps1
#  Один набор стилей на все окна программы.
#
#  Зачем отдельный файл. Окон у программы три: главное, окно
#  проверки файлов и диалоги. Если бы каждое несло свою копию
#  стилей, они разъехались бы на второй правке — а разъехавшийся
#  интерфейс читается как собранный на коленке, и доверия к
#  тому, что он показывает, не прибавляет.
#
#  Вид «Монолит» (2.0). Окно — одна плита, а не россыпь
#  карточек: области делят волосяные линии в один пиксель,
#  углы у областей прямые, у кнопок — едва скруглённые. Карточки
#  с тенями и скруглением просили глаз собирать страницу из
#  кусков; линии на одном фоне читаются как таблица приборов,
#  где у каждого показания своё место.
#
#  ПОЧЕМУ БЕЗ СТОРОННИХ БИБЛИОТЕК. Готовый набор тем (WPF-UI,
#  ModernWpf) дал бы похожий вид быстрее, но это чужие .dll
#  рядом с программой в Program Files, которые грузятся в
#  процесс с правами администратора. Для инструмента, который
#  сам ищет неподписанные файлы в чужом автозапуске, это
#  двойные стандарты. Всё ниже — обычный XAML и шрифты, уже
#  имеющиеся в Windows 10: Bahnschrift, Segoe UI, Consolas.
#
#  ТРИ ТОНА ЧЁРНОГО. Столбец разделов и рамка окна темнее
#  страницы, кнопки и выбранная строка — светлее. Глубину дают
#  тона и линии, а не тени: тень на тёмном фоне почти не видна
#  и только размывает край.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml -ErrorAction SilentlyContinue

# Шрифт текста: на Windows 11 есть Segoe UI Variable, на 10 — нет.
# WPF сам возьмёт первый существующий из списка.
# Bahnschrift — для заголовков и чисел: узкий, техничный, есть
# в Windows 10 с 2017 года. Моноширинный — для путей, времени и
# кодов важности: в нём столбцы цифр стоят ровно.
$script:CgFont     = 'Segoe UI Variable Text, Segoe UI'
$script:CgFontHead = 'Bahnschrift, Segoe UI'

$script:CgThemeXaml = Read-CgText 'ui\Theme.xaml'

# ------------------------------------------------------------
#  Сборка окна из разметки
#
#  Разметка каждого окна содержит метку <!--THEME-->, вместо
#  которой подставляются общие стили. Replace, а не -replace:
#  в стилях есть знаки, которые регулярное выражение съело бы.
# ------------------------------------------------------------
#
# Значок. Окно живёт в процессе powershell.exe, и без своего значка
# Windows рисует на панели задач значок PowerShell — даже у
# установленной программы, запущенной через CookieGuard.exe.
$script:CgIconPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'CookieGuard.ico'
$script:CgIconImage = $null

function Get-CgIconImage {
    if ($script:CgIconImage) { return $script:CgIconImage }
    if (-not (Test-Path -LiteralPath $script:CgIconPath)) { return $null }
    try {
        $dec = New-Object System.Windows.Media.Imaging.IconBitmapDecoder(
            (New-Object Uri $script:CgIconPath), [System.Windows.Media.Imaging.BitmapCreateOptions]::None,
            [System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad)
        # самый крупный кадр: из него Windows сама уменьшит до панели задач
        $script:CgIconImage = @($dec.Frames | Sort-Object { $_.PixelWidth } -Descending)[0]
    } catch { }
    return $script:CgIconImage
}

function New-CgWindow {
    param([string]$Xaml)
    $full = $Xaml.Replace('<!--THEME-->', $script:CgThemeXaml)
    $doc = [xml]$full
    Convert-CgXamlLang $doc
    $reader = New-Object System.Xml.XmlNodeReader $doc
    $w = [Windows.Markup.XamlReader]::Load($reader)
    Add-CgLangToGrids $w
    $ico = Get-CgIconImage
    if ($ico -and $w -is [System.Windows.Window]) { $w.Icon = $ico }
    return $w
}

function Get-CgUiMap {
    param($Window, [string[]]$Names)
    $m = @{}
    foreach ($n in $Names) { $m[$n] = $Window.FindName($n) }
    return $m
}

# Появление окна. Диалог, возникающий мгновенно, читается как
# сбой отрисовки — особенно поверх тёмного окна. Полутораста
# миллисекунд достаточно, чтобы глаз понял: это новое окно, а не
# моргнуло старое. Работает только при AllowsTransparency="True",
# то есть у диалогов; у главного окна своя рамка и свой путь.
function Add-CgWindowFadeIn {
    param($Window, [int]$Ms = 140)
    if (-not $Window) { return }
    $Window.Opacity = 0
    $Window.Add_ContentRendered({
        $a = New-Object System.Windows.Media.Animation.DoubleAnimation
        $a.To = 1
        $a.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($Ms))
        $Window.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $a)
    }.GetNewClosure())
}

# Перетаскивание окна за собственный заголовок: своя рамка —
# значит, и это теперь наша забота.
function Add-CgWindowDrag {
    param($Window, $DragArea, $MaxButton = $null)
    $DragArea.Add_MouseLeftButtonDown({
        param($s, $e)
        if ($e.ClickCount -eq 2) {
            if ($Window.ResizeMode -ne 'NoResize') {
                if ($Window.WindowState -eq 'Maximized') { $Window.WindowState = 'Normal' } else { $Window.WindowState = 'Maximized' }
            }
            return
        }
        try { $Window.DragMove() } catch { }
    }.GetNewClosure())
}
