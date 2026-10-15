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

$script:CgInspectorXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Разбор находки" Height="720" Width="1180" MinHeight="460" MinWidth="820"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        WindowStartupLocation="CenterOwner" ShowInTaskbar="False">
  <Window.Resources>
<!--THEME-->
    <!-- Выделение в дереве Windows красит системным цветом: синим,
         а без фокуса — почти белым. На тёмной плите белая плашка
         под красным текстом читается как сбой. Подменяем системные
         кисти кистями темы — только внутри строк дерева. -->
    <Style x:Key="TvItem" TargetType="TreeViewItem">
      <Style.Resources>
        <StaticResource x:Key="{x:Static SystemColors.HighlightBrushKey}" ResourceKey="ControlBgHi"/>
        <StaticResource x:Key="{x:Static SystemColors.InactiveSelectionHighlightBrushKey}" ResourceKey="ControlBgHi"/>
        <StaticResource x:Key="{x:Static SystemColors.HighlightTextBrushKey}" ResourceKey="Text"/>
        <StaticResource x:Key="{x:Static SystemColors.InactiveSelectionHighlightTextBrushKey}" ResourceKey="Text"/>
      </Style.Resources>
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="FontFamily" Value="{StaticResource FontBody}"/>
      <Setter Property="FontSize"   Value="12.5"/>
      <Setter Property="Padding"    Value="3,4"/>
      <Setter Property="Cursor"     Value="Hand"/>
    </Style>
    <!-- Строки дерева создаются в коде и вложены друг в друга;
         ItemContainerStyle до вложенных не доходит, а стиль без
         ключа — доходит. -->
    <Style TargetType="TreeViewItem" BasedOn="{StaticResource TvItem}"/>
  </Window.Resources>

  <!-- Плита с прямыми углами, как главное окно. Тень оставлена:
       окно висит над главным и без неё сливается с ним краем.
       Отступ — место для тени, иначе окно обрезает её целиком. -->
  <Border Background="{StaticResource WinBg}" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" Margin="14">
    <Border.Effect><DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.5" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- заголовок -->
      <Border Grid.Row="0" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,0,0,1">
        <Grid x:Name="InsBar" Background="Transparent" Height="40">
          <TextBlock Text="Разбор находки" FontFamily="{StaticResource FontDisplay}" FontWeight="SemiBold" FontSize="13.5"
                     VerticalAlignment="Center" Margin="16,0,0,0"/>
          <Button x:Name="InsClose" Content="&#xE8BB;" Style="{StaticResource CaptionClose}" HorizontalAlignment="Right"/>
        </Grid>
      </Border>

      <!-- что разбираем -->
      <Border Grid.Row="1" BorderBrush="{StaticResource Line}" BorderThickness="0,0,0,1" Padding="20,16,20,14">
        <StackPanel>
          <TextBlock x:Name="InsSubject" Text="" Style="{StaticResource H2}" TextWrapping="Wrap"/>
          <TextBlock x:Name="InsCount" Text="" Style="{StaticResource Stat}" Margin="0,6,0,0"/>
        </StackPanel>
      </Border>

      <!-- Дерево и подробности — одна область, между ними линия.
           Разделитель шире линии и заходит на соседей: за линию в
           один пиксель не ухватиться. -->
      <Grid Grid.Row="2">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" MinWidth="330"/>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="430" MinWidth="240"/>
        </Grid.ColumnDefinitions>

        <TreeView x:Name="InsTree" Grid.Column="0" Background="Transparent" BorderThickness="0" Padding="10,10,6,10"
                  ScrollViewer.HorizontalScrollBarVisibility="Auto"/>

        <Border Grid.Column="1" Width="1" Background="{StaticResource Line}"/>

        <TextBox x:Name="InsDetail" Grid.Column="2" Style="{StaticResource Mono}" BorderThickness="0"
                 VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"
                 Text="Выберите строку слева — здесь появятся подробности."/>

        <GridSplitter Grid.Column="1" Width="7" Margin="-3,0" HorizontalAlignment="Stretch" Background="Transparent"
                      Panel.ZIndex="1"/>
      </Grid>

      <Border Grid.Row="3" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0" Padding="20,12">
        <Grid>
          <TextBlock x:Name="InsHint" Style="{StaticResource Sub}" VerticalAlignment="Center"
                     Text="Разбор ничего не меняет: он только читает реестр, файлы и список процессов."/>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="InsCopy"   Content="Копировать карту"/>
            <Button x:Name="InsExport" Content="Сохранить в файл"/>
            <Button x:Name="InsOk"     Content="Закрыть" Style="{StaticResource Primary}" Margin="0"/>
          </StackPanel>
        </Grid>
      </Border>
    </Grid>
  </Border>
</Window>
'@

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
    $tb.Text = "$($Node.Title)"
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

    $w.FindName('InsSubject').Text = "$($Finding.Title)"
    $bad = @($flat | Where-Object { $_.Severity -in @('CRIT', 'WARN') }).Count
    $w.FindName('InsCount').Text = ('Узлов в карте: {0}, из них требующих внимания: {1}' -f $flat.Count, $bad)

    $tree = $w.FindName('InsTree')
    $null = $tree.Items.Add((New-CgTreeItem $root 0))

    $detail = $w.FindName('InsDetail')
    $tree.Add_SelectedItemChanged({
        param($s, $e)
        $it = $e.NewValue
        if (-not $it -or -not $it.Tag) { return }
        $n = $it.Tag
        $txt = "$($n.Title)"
        if ($n.Path)   { $txt += "`n`n$($n.Path)" }
        if ($n.Detail) { $txt += "`n`n$($n.Detail)" }
        $detail.Text = $txt
    }.GetNewClosure())

    # Карта целиком — обычным текстом, чтобы её можно было
    # приложить к письму или сохранить рядом с отчётом.
    $asText = {
        $sb = New-Object System.Text.StringBuilder
        $null = $sb.AppendLine("Разбор находки: $($Finding.Title)")
        $null = $sb.AppendLine((Get-Date -Format 'dd.MM.yyyy HH:mm'))
        $null = $sb.AppendLine('')
        foreach ($r in $flat) {
            $mark = '  '
            if ($r.Severity -eq 'CRIT') { $mark = '!!' }
            elseif ($r.Severity -eq 'WARN') { $mark = ' !' }
            $null = $sb.AppendLine("$mark $($r.Indent)$($r.Title)")
            if ($r.Path) { $null = $sb.AppendLine("   $($r.Indent)    $($r.Path)") }
        }
        return $sb.ToString()
    }.GetNewClosure()

    $w.FindName('InsCopy').Add_Click({
        try { Set-Clipboard -Value (& $asText) } catch { }
        $w.FindName('InsHint').Text = 'Карта скопирована в буфер обмена.'
    }.GetNewClosure())

    $w.FindName('InsExport').Add_Click({
        try {
            $dir = Get-CgDir 'reports'
            $p = Join-Path $dir ('inspect-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
            [IO.File]::WriteAllText($p, (& $asText), (New-Object Text.UTF8Encoding($true)))
            $w.FindName('InsHint').Text = "Сохранено: $p"
            Write-CgLog 'INFO' ("Разбор сохранён: $p")
        } catch {
            $w.FindName('InsHint').Text = "Не удалось сохранить: $($_.Exception.Message)"
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
