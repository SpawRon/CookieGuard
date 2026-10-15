# ============================================================
#  CookieGuard - Ui.Actions.ps1
#  Меню по правой кнопке и действия над выбранной строкой.
#
#  Зачем отдельно. Одни и те же действия нужны и в главном окне,
#  и в окне проверки файлов. Если бы каждое окно держало свою
#  копию, «Доверять» в одном месте работало бы иначе, чем в
#  другом, — а доверие и так уже один раз подвело.
#
#  Правая кнопка здесь не украшение: действие над строкой
#  естественно искать на самой строке, а не в полосе кнопок
#  внизу окна, куда ещё надо отвести глаза.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

# ------------------------------------------------------------
#  Меню по правой кнопке для любой таблицы
#
#  $Build получает объект строки и возвращает список пунктов:
#     @{ Text = 'Доверять'; Glyph = 0xE8FB; Action = { param($r) ... } }
#     @{ Separator = $true }
#     @{ ...; Enabled = $false }   — пункт виден, но недоступен
# ------------------------------------------------------------
function Add-CgRowMenu {
    param($Grid, [scriptblock]$Build)

    $Grid.Add_MouseRightButtonUp({
        param($s, $e)

        # Поднимаемся от того, по чему щёлкнули, до строки таблицы.
        # Щелчок почти всегда приходит по TextBlock внутри ячейки,
        # поэтому без подъёма по дереву строки не найти.
        $node = $e.OriginalSource
        while ($node -and -not ($node -is [System.Windows.Controls.DataGridRow])) {
            if (-not ($node -is [System.Windows.DependencyObject])) { break }
            $node = [System.Windows.Media.VisualTreeHelper]::GetParent($node)
        }
        if (-not ($node -is [System.Windows.Controls.DataGridRow])) { return }

        $node.IsSelected = $true
        $row = $node.Item
        if (-not $row) { return }

        $menu = New-Object System.Windows.Controls.ContextMenu
        foreach ($d in @(& $Build $row)) {
            if ($d.Separator) {
                $null = $menu.Items.Add((New-Object System.Windows.Controls.Separator))
                continue
            }
            $mi = New-Object System.Windows.Controls.MenuItem
            $mi.Header = $d.Text
            if ($d.Glyph) { $mi.Tag = [string][char][int]$d.Glyph }
            if ($d.ContainsKey('Enabled') -and -not $d.Enabled) { $mi.IsEnabled = $false }
            $act = $d.Action
            $mi.Add_Click({ & $act $row }.GetNewClosure())
            $null = $menu.Items.Add($mi)
        }
        if (-not $menu.Items.Count) { return }

        $menu.PlacementTarget = $Grid
        $menu.Placement = 'MousePoint'
        $menu.IsOpen = $true
        $e.Handled = $true
    }.GetNewClosure())
}

# ------------------------------------------------------------
#  Путь и отпечаток выбранной строки
# ------------------------------------------------------------
function Get-CgRowPath {
    param($Row)
    if ($Row -and $Row.PSObject.Properties['Path']) { return [string]$Row.Path }
    return ''
}
function Get-CgRowHash {
    param($Row)
    if ($Row -and $Row.PSObject.Properties['Hash']) { return [string]$Row.Hash }
    return ''
}

# ------------------------------------------------------------
#  Доверять выбранной строке
#
#  Возвращает запись доверия или $null, если человек отказался.
#  Обновление таблиц — забота вызывающего окна: только оно знает,
#  что у него открыто.
# ------------------------------------------------------------
function Invoke-CgTrustRow {
    param($Row)
    if (-not $Row) { return $null }

    # расширение браузера — у него нет файла, доверяем по номеру
    if ($Row.PSObject.Properties['Id'] -and "$($Row.Id)" -match '^[a-p]{32}$' -and $Row.PSObject.Properties['Browser']) {
        $label = "$($Row.Browser): $($Row.Name)"
        $note = Show-CgPrompt -Title 'Больше про это не спрашивать' `
            -Text 'Расширение перестанет попадать в находки. Напишите себе на будущее, почему вы его оставляете.' `
            -Subject $label -Default 'поставил сам, пользуюсь' -OkText 'Доверять'
        if ($null -eq $note) { return $null }
        return (Add-CgTrust -Type 'extension' -Key "$($Row.Browser)|$($Row.Id)" -Label $label -Note $note)
    }

    # корневой сертификат — доверяем по отпечатку: имя у самодельного
    # сертификата может совпасть с чужим, отпечаток — нет
    if ($Row.PSObject.Properties['Target'] -and $Row.Target -and "$($Row.Target.Kind)" -eq 'cert') {
        $label = "$($Row.Target.Name)"
        $note = Show-CgPrompt -Title 'Больше про это не спрашивать' `
            -Text 'Сертификат перестанет попадать в находки. Если его когда-нибудь подменят, у подмены будет другой отпечаток — и она попадёт.' `
            -Subject "$label  ($($Row.Target.Thumbprint))" -Default 'знаю, чей он' -OkText 'Доверять'
        if ($null -eq $note) { return $null }
        return (Add-CgTrust -Type 'cert' -Key "$($Row.Target.Thumbprint)" -Label $label -Note $note)
    }

    $path = Get-CgRowPath $Row
    if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        # Родитель есть только у строки процесса. Для файла на диске его
        # неоткуда взять — и тогда область «родитель» просто не предлагается.
        $parentPath = ''
        $parentName = ''
        if ($Row.PSObject.Properties['ParentPath']) { $parentPath = [string]$Row.ParentPath }
        if ($Row.PSObject.Properties['ParentName']) { $parentName = [string]$Row.ParentName }
        $anc = @()
        if ($Row.PSObject.Properties['Ancestors']) { $anc = @($Row.Ancestors) }

        $opts = Get-CgTrustOptions $path (Get-CgRowHash $Row) $parentPath $parentName $anc
        $res = Show-CgTrustDialog -Subject $path -Options $opts
        if (-not $res) { return $null }
        # «Родитель» и «всё семейство» несут в себе, чей именно родитель:
        # для семейства это хозяин цепочки, а не ближайший cmd.exe.
        $o = $res.Option
        if ($o -and $o.PSObject.Properties['ParentPath']) { $parentPath = "$($o.ParentPath)"; $parentName = "$($o.ParentName)" }
        $any = [bool]($o -and $o.PSObject.Properties['AnyChild'] -and $o.AnyChild)
        return (Add-CgTrust -Type 'file' -Path $path -Hash (Get-CgRowHash $Row) -Scope $res.Scope -Note $res.Note `
                    -ParentPath $parentPath -ParentName $parentName -AnyChild:$any)
    }

    # ни файла, ни расширения: доверяем самой находке
    $title = ''
    if ($Row.PSObject.Properties['Title']) { $title = [string]$Row.Title }
    $area = ''
    if ($Row.PSObject.Properties['Area']) { $area = [string]$Row.Area }
    if (-not $title) { return $null }

    $extra = ''
    if ($path) { $extra = "`n`nФайла по пути $path сейчас нет — доверие будет привязано к самой находке." }
    $note = Show-CgPrompt -Title 'Больше про это не спрашивать' `
        -Text ('Эта находка перестанет попадать в список.' + $extra) `
        -Subject $title -Default 'разобрался, так и должно быть' -OkText 'Доверять'
    if ($null -eq $note) { return $null }
    return (Add-CgTrust -Type 'finding' -Key "$area|$title" -Label $title -Note $note)
}

# ------------------------------------------------------------
#  Мелкие действия, одинаковые везде
# ------------------------------------------------------------
function Show-CgInExplorer {
    param($Row)
    $p = Get-CgRowPath $Row
    if (-not $p) { return $false }
    if (Test-Path -LiteralPath $p) {
        Start-Process explorer.exe ('/select,"{0}"' -f $p)
        return $true
    }
    $dir = Split-Path -Parent $p
    if ($dir -and (Test-Path -LiteralPath $dir)) { Start-Process explorer.exe $dir; return $true }
    return $false
}

function Copy-CgRowText {
    param([string]$Text)
    if (-not $Text) { return $false }
    try { Set-Clipboard -Value $Text; return $true } catch { return $false }
}

function Open-CgVirusTotal {
    param($Row)
    $h = Get-CgRowHash $Row
    if (-not $h) {
        $p = Get-CgRowPath $Row
        if ($p -and (Test-Path -LiteralPath $p -PathType Leaf)) { $h = Get-CgHash $p }
    }
    if ($h) { Start-Process "https://www.virustotal.com/gui/file/$h"; return $true }
    Start-Process 'https://www.virustotal.com/gui/home/upload'
    return $false
}
