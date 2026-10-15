# ============================================================
#  CookieGuard - Ui.Dialogs.ps1
#  Собственные окна вопросов вместо системных.
#
#  Зачем. MessageBox и InputBox рисуются системой в светлой теме
#  и в стиле, который не менялся с Windows XP. Рядом с тёмным
#  окном они выглядят как чужая программа, влезшая в разговор, —
#  и ровно в тот момент, когда у человека спрашивают разрешение
#  на необратимое: удалить из карантина, обезвредить файл.
#  Окно, которому не доверяют, получает согласие не глядя.
#
#  Правило текста: заголовок — что произойдёт, одна строка под
#  ним — следствие, и всё. Длинные объяснения в диалоге никто
#  не читает; им место в подсказке и в подробностях.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$script:CgDialogOwner = $null
function Set-CgDialogOwner { param($Window) $script:CgDialogOwner = $Window }

$script:CgDialogXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" SizeToContent="Height" Width="470" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" Title="CookieGuard">
  <Window.Resources>
<!--THEME-->
  </Window.Resources>
  <!-- Диалог — та же плита, что и главное окно: прямые углы, рамка
       линией. Тень оставлена только здесь и у окна разбора: диалог
       висит над окном, и без тени его край сливается с фоном под ним. -->
  <Border Background="{StaticResource WinBg}" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" Margin="14">
    <Border.Effect><DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.5" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- шапка: значок, заголовок, следствие -->
      <Grid Grid.Row="0" Margin="24,22,24,0">
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width="Auto"/>
          <ColumnDefinition Width="*"/>
        </Grid.ColumnDefinitions>
        <Border x:Name="IconBg" Grid.Column="0" Width="38" Height="38" BorderBrush="{StaticResource StrongLine}" BorderThickness="1"
                VerticalAlignment="Top" Margin="0,2,16,0">
          <TextBlock x:Name="IconGlyph" Text="&#xE946;" Style="{StaticResource Glyph}" FontSize="17" Foreground="{StaticResource Accent}"/>
        </Border>
        <StackPanel Grid.Column="1">
          <TextBlock x:Name="DlgTitle" Style="{StaticResource H2}" TextWrapping="Wrap"/>
          <TextBlock x:Name="DlgText" Style="{StaticResource Sub}" FontSize="13" Margin="0,7,0,0" LineHeight="19"/>
        </StackPanel>
      </Grid>

      <!-- то, о чём речь: путь, имя файла -->
      <Border x:Name="DlgSubjectBox" Grid.Row="1" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="1"
              Margin="24,16,24,0" Padding="12,9" Visibility="Collapsed">
        <TextBlock x:Name="DlgSubject" FontFamily="{StaticResource FontMono}" FontSize="11.5" Foreground="{StaticResource TextDim}"
                   TextWrapping="Wrap" TextTrimming="CharacterEllipsis" MaxHeight="60"/>
      </Border>

      <!-- кнопки: полоса темнее тела, как строка состояния главного окна -->
      <Border Grid.Row="2" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0"
              Margin="0,22,0,0" Padding="24,16">
        <StackPanel x:Name="DlgButtons" Orientation="Horizontal" HorizontalAlignment="Right"/>
      </Border>
    </Grid>
  </Border>
</Window>
'@

# Цвет несёт только сам значок. Квадрат обведён той же линией,
# что значки настроек в главном окне: цветная заливка под ним
# спорила бы за внимание с красной кнопкой «Обезвредить».
$script:CgDialogKinds = @{
    'info'     = @('&#xE946;', '#3B9EFF')
    'question' = @('&#xE9CE;', '#3B9EFF')
    'ok'       = @('&#xE930;', '#4ADE80')
    'warn'     = @('&#xE7BA;', '#FFB340')
    'danger'   = @('&#xE730;', '#FF5E5E')
}

# ------------------------------------------------------------
#  Вопрос или сообщение
#  Возвращает номер нажатой кнопки (0 — первая) или -1, если
#  окно закрыли крестиком/Escape.
# ------------------------------------------------------------
function Show-CgDialog {
    param(
        [string]$Title,
        [string]$Text = '',
        [string]$Subject = '',
        [ValidateSet('info', 'question', 'ok', 'warn', 'danger')] [string]$Kind = 'info',
        [string[]]$Buttons = @('Понятно'),
        [int]$DangerButton = -1
    )

    $k = $script:CgDialogKinds[$Kind]
    $xaml = $script:CgDialogXaml.Replace('&#xE946;', $k[0])
    $w = New-CgWindow $xaml

    $w.FindName('IconGlyph').Foreground = $k[1]
    $w.FindName('DlgTitle').Text = $Title
    $tb = $w.FindName('DlgText')
    if ($Text) { $tb.Text = $Text } else { $tb.Visibility = 'Collapsed' }
    if ($Subject) {
        $w.FindName('DlgSubject').Text = $Subject
        $w.FindName('DlgSubjectBox').Visibility = 'Visible'
    }

    $res = @{ V = -1 }
    $panel = $w.FindName('DlgButtons')

    # Главная кнопка идёт первой слева — так расставляет кнопки
    # сама Windows 11. Строим с конца, вставляя в начало, чтобы
    # Buttons[0] оказалась слева и получила признак «по умолчанию».
    for ($i = $Buttons.Count - 1; $i -ge 0; $i--) {
        $b = New-Object System.Windows.Controls.Button
        $b.Content = $Buttons[$i]
        $b.MinWidth = 104
        $b.Margin = '8,0,0,0'
        if ($i -eq 0) {
            if ($DangerButton -eq 0) { $b.Style = $w.FindResource('Danger') } else { $b.Style = $w.FindResource('Primary') }
            $b.IsDefault = $true
        } elseif ($i -eq $DangerButton) {
            $b.Style = $w.FindResource('Danger')
        }
        if ($i -eq $Buttons.Count - 1 -and $Buttons.Count -gt 1) { $b.IsCancel = $true }
        $idx = $i
        $b.Add_Click({ $res.V = $idx; $w.Close() }.GetNewClosure())
        $panel.Children.Insert(0, $b)
    }

    $w.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $w.Close() } }.GetNewClosure())
    Add-CgWindowFadeIn $w
    if ($script:CgDialogOwner -and $script:CgDialogOwner.IsVisible) { $w.Owner = $script:CgDialogOwner }
    else { $w.WindowStartupLocation = 'CenterScreen' }
    $null = $w.ShowDialog()
    return $res.V
}

# Короткая обёртка для «да/нет». Возвращает $true, только если
# человек нажал именно подтверждающую кнопку.
function Confirm-CgDialog {
    param(
        [string]$Title, [string]$Text = '', [string]$Subject = '',
        [string]$Yes = 'Да', [string]$No = 'Отмена',
        [ValidateSet('info', 'question', 'ok', 'warn', 'danger')] [string]$Kind = 'question',
        [switch]$Dangerous
    )
    $d = -1
    if ($Dangerous) { $d = 0 }
    return ((Show-CgDialog -Title $Title -Text $Text -Subject $Subject -Kind $Kind -Buttons @($Yes, $No) -DangerButton $d) -eq 0)
}

# ------------------------------------------------------------
#  Ввод строки
# ------------------------------------------------------------
$script:CgPromptXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" SizeToContent="Height" Width="480" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" Title="CookieGuard">
  <Window.Resources>
<!--THEME-->
  </Window.Resources>
  <Border Background="{StaticResource WinBg}" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" Margin="14">
    <Border.Effect><DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.5" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <StackPanel Grid.Row="0" Margin="24,22,24,0">
        <TextBlock x:Name="PrTitle" Style="{StaticResource H2}" TextWrapping="Wrap"/>
        <TextBlock x:Name="PrText"  Style="{StaticResource Sub}" FontSize="13" Margin="0,7,0,0" LineHeight="19"/>
        <TextBlock x:Name="PrSubject" FontFamily="{StaticResource FontMono}" FontSize="11.5" Foreground="{StaticResource Muted}"
                   Margin="0,10,0,0" TextTrimming="CharacterEllipsis" Visibility="Collapsed"/>
        <TextBox     x:Name="PrInput" Margin="0,16,0,0"/>
        <PasswordBox x:Name="PrPass"  Margin="0,16,0,0" Visibility="Collapsed"/>
        <TextBlock x:Name="PrHint" Style="{StaticResource Sub}" FontSize="11.5" Margin="0,9,0,0" Visibility="Collapsed"/>
      </StackPanel>
      <Border Grid.Row="1" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0"
              Margin="0,22,0,0" Padding="24,16">
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="PrOk" Content="Сохранить" Style="{StaticResource Primary}" MinWidth="104" IsDefault="True"/>
          <Button x:Name="PrCancel" Content="Отмена" MinWidth="104" Margin="8,0,0,0" IsCancel="True"/>
        </StackPanel>
      </Border>
    </Grid>
  </Border>
</Window>
'@

function Show-CgPrompt {
    param(
        [string]$Title,
        [string]$Text = '',
        [string]$Subject = '',
        [string]$Default = '',
        [string]$Hint = '',
        [string]$OkText = 'Сохранить',
        [switch]$Password
    )
    $w = New-CgWindow $script:CgPromptXaml
    $w.FindName('PrTitle').Text = $Title
    $tb = $w.FindName('PrText')
    if ($Text) { $tb.Text = $Text } else { $tb.Visibility = 'Collapsed' }
    if ($Subject) {
        $sb = $w.FindName('PrSubject'); $sb.Text = $Subject; $sb.Visibility = 'Visible'
    }
    if ($Hint) {
        $hb = $w.FindName('PrHint'); $hb.Text = $Hint; $hb.Visibility = 'Visible'
    }
    $w.FindName('PrOk').Content = $OkText

    $inp  = $w.FindName('PrInput')
    $pass = $w.FindName('PrPass')
    if ($Password) {
        $inp.Visibility = 'Collapsed'
        $pass.Visibility = 'Visible'
    } else {
        $inp.Text = $Default
    }

    $res = @{ V = $null }
    $w.FindName('PrOk').Add_Click({
        if ($Password) { $res.V = $pass.Password } else { $res.V = $inp.Text }
        $w.Close()
    }.GetNewClosure())
    $w.FindName('PrCancel').Add_Click({ $res.V = $null; $w.Close() }.GetNewClosure())
    $w.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $res.V = $null; $w.Close() } }.GetNewClosure())
    $w.Add_ContentRendered({ if ($Password) { $pass.Focus() } else { $inp.Focus(); $inp.SelectAll() } }.GetNewClosure())
    Add-CgWindowFadeIn $w

    if ($script:CgDialogOwner -and $script:CgDialogOwner.IsVisible) { $w.Owner = $script:CgDialogOwner }
    else { $w.WindowStartupLocation = 'CenterScreen' }
    $null = $w.ShowDialog()
    return $res.V
}

# ------------------------------------------------------------
#  Доверие: выбор области
#
#  Главная мысль окна — что именно перестанет попадать в
#  находки. Раньше спрашивали только причину, а область была
#  всегда «этот файл», и человек не понимал, почему назавтра
#  доверенная программа снова в списке.
# ------------------------------------------------------------
$script:CgTrustXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" SizeToContent="Height" Width="560" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" Title="CookieGuard">
  <Window.Resources>
<!--THEME-->
    <!-- Области — строки одной таблицы: стоят вплотную и делят
         линию (отступ -1). Выбранная светлее и с полосой слева —
         тот же знак «вот это выбрано», что в столбце разделов. -->
    <Style x:Key="ScopeCard" TargetType="RadioButton">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,0,-1"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Grid>
              <Border x:Name="b" Background="Transparent" BorderBrush="{StaticResource Line}" BorderThickness="1" Padding="16,12">
                <Grid>
                  <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                  </Grid.ColumnDefinitions>
                  <Border x:Name="dot" Grid.Column="0" Width="16" Height="16" CornerRadius="2" BorderBrush="{StaticResource StrongLine}"
                          BorderThickness="1" Background="{StaticResource ControlBg}" VerticalAlignment="Top" Margin="0,2,13,0">
                    <Rectangle x:Name="fill" Width="6" Height="6" Fill="{StaticResource Accent}" Opacity="0"/>
                  </Border>
                  <ContentPresenter Grid.Column="1"/>
                </Grid>
              </Border>
              <Border x:Name="bar" Width="2" Background="{StaticResource Accent}" HorizontalAlignment="Left" Opacity="0"/>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True">
                <Setter TargetName="b"   Property="Background"  Value="{StaticResource HoverBg}"/>
                <Setter TargetName="dot" Property="BorderBrush" Value="{StaticResource HoverLine}"/>
              </Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="b"    Property="Background"  Value="{StaticResource ControlBg}"/>
                <Setter TargetName="dot"  Property="BorderBrush" Value="{StaticResource Accent}"/>
                <Setter TargetName="fill" Property="Opacity"     Value="1"/>
                <Setter TargetName="bar"  Property="Opacity"     Value="1"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Border Background="{StaticResource WinBg}" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" Margin="14">
    <Border.Effect><DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.5" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <StackPanel Grid.Row="0" Margin="24,22,24,0">
        <TextBlock Text="Больше про это не спрашивать" Style="{StaticResource H2}"/>
        <TextBlock x:Name="TrSubject" FontFamily="{StaticResource FontMono}" FontSize="11.5" Foreground="{StaticResource Muted}"
                   Margin="0,8,0,0" TextTrimming="CharacterEllipsis"/>
        <TextBlock Text="НА ЧТО РАСПРОСТРАНЯЕТСЯ" Style="{StaticResource GroupLabel}" Margin="0,20,0,10"/>
        <StackPanel x:Name="TrScopes"/>
        <TextBlock Text="ПОЧЕМУ ОСТАВЛЯЕТЕ — ЗАМЕТКА СЕБЕ" Style="{StaticResource GroupLabel}" Margin="0,22,0,10"/>
        <TextBox x:Name="TrNote"/>
      </StackPanel>
      <Border Grid.Row="1" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0"
              Margin="0,22,0,0" Padding="24,16">
        <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
          <Button x:Name="TrOk" Content="Доверять" Style="{StaticResource Primary}" MinWidth="104" IsDefault="True"/>
          <Button x:Name="TrCancel" Content="Отмена" MinWidth="104" Margin="8,0,0,0" IsCancel="True"/>
        </StackPanel>
      </Border>
    </Grid>
  </Border>
</Window>
'@

function Show-CgTrustDialog {
    param([string]$Subject, $Options, [string]$DefaultNote = 'моя программа, разобрался')

    $w = New-CgWindow $script:CgTrustXaml
    $w.FindName('TrSubject').Text = $Subject
    $w.FindName('TrNote').Text = $DefaultNote
    $host_ = $w.FindName('TrScopes')
    $style = $w.FindResource('ScopeCard')

    $radios = @()
    foreach ($o in @($Options)) {
        $r = New-Object System.Windows.Controls.RadioButton
        $r.Style = $style
        $r.Tag = $o

        $sp = New-Object System.Windows.Controls.StackPanel
        $t1 = New-Object System.Windows.Controls.TextBlock
        $t1.Text = $o.Title
        $t1.FontSize = 13.5
        $t1.FontWeight = 'SemiBold'
        $t1.Foreground = '#ECEFF4'
        $t1.TextWrapping = 'Wrap'
        $t2 = New-Object System.Windows.Controls.TextBlock
        $t2.Text = $o.Hint
        $t2.FontSize = 12
        $t2.Margin = '0,4,0,0'
        $t2.TextWrapping = 'Wrap'
        $t2.Foreground = $(if ($o.Safe -eq 'risky') { '#FFB340' } else { '#7C8694' })
        $null = $sp.Children.Add($t1)
        $null = $sp.Children.Add($t2)
        $r.Content = $sp

        $null = $host_.Children.Add($r)
        $radios += $r
    }
    if ($radios.Count) { $radios[0].IsChecked = $true }

    $res = @{ V = $null }
    $w.FindName('TrOk').Add_Click({
        $sel = @($radios | Where-Object { $_.IsChecked })
        if (-not $sel.Count) { return }
        $res.V = [PSCustomObject]@{
            Scope  = [string]$sel[0].Tag.Scope
            Option = $sel[0].Tag
            Note   = [string]$w.FindName('TrNote').Text
        }
        $w.Close()
    }.GetNewClosure())
    $w.FindName('TrCancel').Add_Click({ $res.V = $null; $w.Close() }.GetNewClosure())
    $w.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $res.V = $null; $w.Close() } }.GetNewClosure())
    Add-CgWindowFadeIn $w

    if ($script:CgDialogOwner -and $script:CgDialogOwner.IsVisible) { $w.Owner = $script:CgDialogOwner }
    else { $w.WindowStartupLocation = 'CenterScreen' }
    $null = $w.ShowDialog()
    return $res.V
}

# ------------------------------------------------------------
#  Список с галочками: «Исправить всё»
#
#  Одно окно вместо двадцати подтверждений. Каждая строка — что
#  именно изменится; снять галочку можно с любой. Так «всё сразу»
#  не превращается в «всё вслепую»: человек видит список целиком
#  и убирает то, что решил оставить (например, отключённые им
#  самим обновления Windows).
# ------------------------------------------------------------
$script:CgChecklistXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" SizeToContent="Height" Width="640" ResizeMode="NoResize"
        WindowStartupLocation="CenterOwner" Title="CookieGuard">
  <Window.Resources>
<!--THEME-->
  </Window.Resources>
  <Border Background="{StaticResource WinBg}" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" Margin="14">
    <Border.Effect><DropShadowEffect BlurRadius="16" ShadowDepth="2" Opacity="0.5" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <StackPanel Grid.Row="0" Margin="24,22,24,0">
        <TextBlock x:Name="ClTitle" Style="{StaticResource H2}" TextWrapping="Wrap"/>
        <TextBlock x:Name="ClText" Style="{StaticResource Sub}" FontSize="13" Margin="0,7,0,0" LineHeight="19"/>
        <StackPanel Orientation="Horizontal" Margin="0,14,0,8">
          <Button x:Name="ClAll"  Content="Отметить всё" Style="{StaticResource Ghost}" Padding="10,4"/>
          <Button x:Name="ClNone" Content="Снять всё" Style="{StaticResource Ghost}" Padding="10,4"/>
        </StackPanel>
      </StackPanel>
      <Border Grid.Row="1" Margin="24,0,24,0" BorderBrush="{StaticResource Line}" BorderThickness="1" Background="{StaticResource NavBg}">
        <ScrollViewer MaxHeight="380" VerticalScrollBarVisibility="Auto">
          <StackPanel x:Name="ClList" Margin="0,4"/>
        </ScrollViewer>
      </Border>
      <Border Grid.Row="2" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0"
              Margin="0,22,0,0" Padding="24,16">
        <Grid>
          <TextBlock x:Name="ClCount" Style="{StaticResource Stat}" VerticalAlignment="Center"/>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="ClOk" Content="Исправить" Style="{StaticResource Primary}" MinWidth="104" IsDefault="True"/>
            <Button x:Name="ClCancel" Content="Отмена" MinWidth="104" Margin="8,0,0,0" IsCancel="True"/>
          </StackPanel>
        </Grid>
      </Border>
    </Grid>
  </Border>
</Window>
'@

# $Items: объекты с полями Title, Sub, Checked, Risky. Возвращает
# номера отмеченных строк или $null, если окно закрыли.
function Show-CgChecklistDialog {
    param([string]$Title, [string]$Text = '', $Items, [string]$OkText = 'Исправить')
    $w = New-CgWindow $script:CgChecklistXaml
    $w.FindName('ClTitle').Text = $Title
    $tb = $w.FindName('ClText')
    if ($Text) { $tb.Text = $Text } else { $tb.Visibility = 'Collapsed' }
    $w.FindName('ClOk').Content = $OkText
    $list = $w.FindName('ClList')
    $count = $w.FindName('ClCount')

    $boxes = New-Object System.Collections.ArrayList
    $upd = {
        $n = @($boxes | Where-Object { $_.IsChecked }).Count
        $count.Text = "отмечено: $n из $($boxes.Count)"
        $w.FindName('ClOk').IsEnabled = ($n -gt 0)
    }.GetNewClosure()

    $i = 0
    foreach ($it in @($Items)) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Margin = '14,8,14,8'
        $cb.VerticalAlignment = 'Top'
        $cb.IsChecked = [bool]$it.Checked
        $cb.Tag = $i
        $sp = New-Object System.Windows.Controls.StackPanel
        $t1 = New-Object System.Windows.Controls.TextBlock
        $t1.Text = "$($it.Title)"
        $t1.TextWrapping = 'Wrap'
        $t1.Foreground = $(if ($it.Risky) { '#FFB340' } else { '#ECEFF4' })
        $null = $sp.Children.Add($t1)
        if ($it.Sub) {
            $t2 = New-Object System.Windows.Controls.TextBlock
            $t2.Text = "$($it.Sub)"
            $t2.FontSize = 11.5
            $t2.TextWrapping = 'Wrap'
            $t2.Margin = '0,2,0,0'
            $t2.Foreground = '#7C8694'
            $null = $sp.Children.Add($t2)
        }
        $sp.MaxWidth = 520
        $cb.Content = $sp
        $cb.Add_Click($upd)
        $null = $list.Children.Add($cb)
        $null = $boxes.Add($cb)
        $i++
    }
    & $upd

    $w.FindName('ClAll').Add_Click({ foreach ($b in $boxes) { $b.IsChecked = $true }; & $upd }.GetNewClosure())
    $w.FindName('ClNone').Add_Click({ foreach ($b in $boxes) { $b.IsChecked = $false }; & $upd }.GetNewClosure())

    $res = @{ V = $null }
    $w.FindName('ClOk').Add_Click({
        $res.V = @($boxes | Where-Object { $_.IsChecked } | ForEach-Object { [int]$_.Tag })
        $w.Close()
    }.GetNewClosure())
    $w.FindName('ClCancel').Add_Click({ $res.V = $null; $w.Close() }.GetNewClosure())
    $w.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $res.V = $null; $w.Close() } }.GetNewClosure())
    Add-CgWindowFadeIn $w
    if ($script:CgDialogOwner -and $script:CgDialogOwner.IsVisible) { $w.Owner = $script:CgDialogOwner }
    else { $w.WindowStartupLocation = 'CenterScreen' }
    $null = $w.ShowDialog()
    return $res.V
}
