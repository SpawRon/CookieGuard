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
    <Style x:Key="TvItem" TargetType="TreeViewItem">
      <Setter Property="Foreground" Value="{StaticResource TextDim}"/>
      <Setter Property="FontFamily" Value="Segoe UI Variable Text, Segoe UI"/>
      <Setter Property="FontSize"   Value="12.5"/>
      <Setter Property="Padding"    Value="3,4"/>
      <Setter Property="Cursor"     Value="Hand"/>
    </Style>
  </Window.Resources>

  <Border Background="{StaticResource WinBg}" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" CornerRadius="10">
    <Border.Effect><DropShadowEffect BlurRadius="28" ShadowDepth="6" Opacity="0.6" Color="#000000"/></Border.Effect>
    <Grid Margin="1">
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- заголовок -->
      <Grid x:Name="InsBar" Grid.Row="0" Background="{StaticResource NavBg}" Height="44">
        <TextBlock Text="Разбор находки" Style="{StaticResource H2}" FontSize="14" VerticalAlignment="Center" Margin="20,0,0,0"/>
        <Button x:Name="InsClose" Content="&#xE8BB;" Style="{StaticResource CaptionClose}" HorizontalAlignment="Right" VerticalAlignment="Top"/>
      </Grid>

      <!-- что разбираем -->
      <Border Grid.Row="1" Background="{StaticResource CardBgAlt}" Padding="20,12">
        <StackPanel>
          <TextBlock x:Name="InsSubject" Text="" Style="{StaticResource H2}" FontSize="14" TextWrapping="Wrap"/>
          <TextBlock x:Name="InsCount" Text="" Style="{StaticResource Sub}" Margin="0,4,0,0"/>
        </StackPanel>
      </Border>

      <Grid Grid.Row="2" Margin="14,12,14,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="*" MinWidth="330"/>
          <ColumnDefinition Width="6"/>
          <ColumnDefinition Width="430" MinWidth="240"/>
        </Grid.ColumnDefinitions>

        <Border Grid.Column="0" Background="{StaticResource CardBg}" BorderBrush="{StaticResource Line}"
                BorderThickness="1" CornerRadius="9">
          <TreeView x:Name="InsTree" Background="Transparent" BorderThickness="0" Margin="6"
                    ScrollViewer.HorizontalScrollBarVisibility="Auto"/>
        </Border>

        <GridSplitter Grid.Column="1" Width="6" HorizontalAlignment="Stretch" Background="Transparent"/>

        <Border Grid.Column="2" Background="{StaticResource CardBg}" BorderBrush="{StaticResource Line}"
                BorderThickness="1" CornerRadius="9" Padding="2">
          <TextBox x:Name="InsDetail" Style="{StaticResource Mono}" BorderThickness="0"
                   VerticalScrollBarVisibility="Auto" TextWrapping="Wrap"
                   Text="Выберите строку слева — здесь появятся подробности."/>
        </Border>
      </Grid>

      <Border Grid.Row="3" Padding="14,12">
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
        default { return '#AAB3C0' }
    }
}

function New-CgTreeItem {
    param($Node, [int]$Depth)

    $ti = New-Object System.Windows.Controls.TreeViewItem
    $ti.Tag = $Node

    $sp = New-Object System.Windows.Controls.StackPanel
    $sp.Orientation = 'Horizontal'

    # точка важности вместо цветного текста: цвет строки легко
    # списать на тему, а точка читается как пометка
    $dot = New-Object System.Windows.Shapes.Ellipse
    $dot.Width = 7; $dot.Height = 7
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

    $null = $w.ShowDialog()
}
