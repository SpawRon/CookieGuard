# ============================================================
#  CookieGuard - Ui.Inspector.ps1
#  Окно разбора: «куда ведёт эта находка».
#
#  Почему отдельное окно, а не панель справа. Карта объекта —
#  это дерево на сотни строк: ключ реестра со всеми ветками,
#  папка расширения со всеми файлами и подписями. В колонку
#  шириной 412 точек такое не кладётся, а резать его на части
#  значит снова прятать основание — ровно то, за что ругают
#  антивирусы.
#
#  Слева дерево, справа подробности выбранного узла. Дерево
#  раскрыто на два уровня: видно состав, но не свалено всё
#  сразу.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$script:CgInspectorXaml = Read-CgText 'ui\Inspector.xaml'

# Цвет строки по важности: тот же язык, что и в таблицах находок.
function Get-CgNodeBrush {
    param([string]$Severity)
    switch ($Severity) {
        'CRIT' { return '#FF5E5E' }
        'WARN' { return '#FFB340' }
        'OK'   { return '#4ADE80' }
        'NOTE' { return '#7CC4FF' }
        default { return '#A3ACB9' }
    }
}

function New-CgTreeItem {
    param($Node, [int]$Depth)

    $ti = New-Object System.Windows.Controls.TreeViewItem
    $ti.Tag = $Node

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    # квадрат важности, как в таблицах главного окна: цвет строки
    # легко списать на тему, а пометка читается как пометка
    $dot = New-Object System.Windows.Shapes.Rectangle
    $dot.Width = 6; $dot.Height = 6
    $dot.Margin = '0,0,9,0'
    $dot.VerticalAlignment = 'Center'
    $dot.Fill = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-CgNodeBrush $Node.Severity))))

    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = T "$($Node.Title)"
    $tb.VerticalAlignment = 'Center'
    $tb.TextTrimming = 'CharacterEllipsis'
    if ($Node.Severity -in @('CRIT', 'WARN')) { $tb.FontWeight = 'SemiBold' }
    $tb.Foreground = (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString((Get-CgNodeBrush $Node.Severity))))

    $null = $sp.Children.Add($dot)
    $null = $sp.Children.Add($tb)
    $ti.Header = $sp
    $ti.IsExpanded = ($Depth -lt 2)

    foreach ($c in @($Node.Children)) {
        $null = $ti.Items.Add((New-CgTreeItem $c ($Depth + 1)))
    }
    return $ti
}

function Show-CgInspector {
    param($Owner, $Finding)

    if (-not $Finding) { return }

    $root = Get-CgInspection $Finding
    $flat = @(ConvertTo-CgFlatTree $root)

    $w = New-CgWindow $script:CgInspectorXaml
    if ($Owner -and $Owner.IsVisible) { $w.Owner = $Owner }

    $w.FindName('InsSubject').Text = T "$($Finding.Title)"
    $bad = @($flat | Where-Object { $_.Severity -in @('CRIT', 'WARN') }).Count
    $w.FindName('InsCount').Text = ((T 'Узлов в карте: {0}, из них требующих внимания: {1}') -f $flat.Count, $bad)

    $tree = $w.FindName('InsTree')
    $null = $tree.Items.Add((New-CgTreeItem $root 0))

    $detail = $w.FindName('InsDetail')
    $tree.Add_SelectedItemChanged({
        param($s, $e)
        $it = $e.NewValue
        if (-not $it -or -not $it.Tag) { return }
        $n = $it.Tag
        $txt = T "$($n.Title)"
        if ($n.Path)   { $txt += "`n`n$($n.Path)" }
        if ($n.Detail) { $txt += "`n`n" + (T "$($n.Detail)") }
        $detail.Text = $txt
    }.GetNewClosure())

    # Карта целиком — обычным текстом, чтобы её можно было
    # приложить к письму или сохранить рядом с отчётом.
    $asText = {
        $sb = New-Object System.Text.StringBuilder
        $null = $sb.AppendLine((T 'Разбор находки: {0}') -f (T "$($Finding.Title)"))
        $null = $sb.AppendLine((Get-Date -Format 'dd.MM.yyyy HH:mm'))
        $null = $sb.AppendLine('')
        foreach ($r in $flat) {
            $mark = '  '
            if ($r.Severity -eq 'CRIT') { $mark = '!!' }
            elseif ($r.Severity -eq 'WARN') { $mark = ' !' }
            $null = $sb.AppendLine("$mark $($r.Indent)" + (T "$($r.Title)"))
            if ($r.Path) { $null = $sb.AppendLine("   $($r.Indent)    $($r.Path)") }
        }
        return $sb.ToString()
    }.GetNewClosure()

    $w.FindName('InsCopy').Add_Click({
        try { Set-Clipboard -Value (& $asText) } catch { }
        $w.FindName('InsHint').Text = T 'Карта скопирована в буфер обмена.'
    }.GetNewClosure())

    $w.FindName('InsExport').Add_Click({
        try {
            $dir = Get-CgDir 'reports'
            $p = Join-Path $dir ('inspect-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            [IO.File]::WriteAllText($p, (& $asText), (New-Object Text.UTF8Encoding($true)))
            $w.FindName('InsHint').Text = (T 'Сохранено: {0}') -f $p
            Write-CgLog 'INFO' ("Разбор сохранён: $p")
        } catch {
            $w.FindName('InsHint').Text = (T 'Не удалось сохранить: {0}') -f $_.Exception.Message
        }
    }.GetNewClosure())

    $close = { $w.Close() }.GetNewClosure()
    $w.FindName('InsOk').Add_Click($close)
    $w.FindName('InsClose').Add_Click($close)
    Add-CgWindowDrag $w $w.FindName('InsBar')
    $w.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $w.Close() } }.GetNewClosure())
    Add-CgWindowFadeIn $w

    $null = $w.ShowDialog()
}
