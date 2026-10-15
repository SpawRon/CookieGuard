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
  <Border Background="#171A21" BorderBrush="#333A46" BorderThickness="1" CornerRadius="10" Margin="14">
    <Border.Effect><DropShadowEffect BlurRadius="28" ShadowDepth="6" Opacity="0.6" Color="#000000"/></Border.Effect>
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
        <Border x:Name="IconBg" Grid.Column="0" Width="38" Height="38" CornerRadius="19" Background="#1E3A5C"
                VerticalAlignment="Top" Margin="0,2,16,0">
          <TextBlock x:Name="IconGlyph" Text="&#xE946;" Style="{StaticResource Glyph}" FontSize="17" Foreground="#3B9EFF"/>
        </Border>
        <StackPanel Grid.Column="1">
          <TextBlock x:Name="DlgTitle" Style="{StaticResource H2}" TextWrapping="Wrap"/>
          <TextBlock x:Name="DlgText" Style="{StaticResource Sub}" FontSize="13" Margin="0,7,0,0" LineHeight="19"/>
        </StackPanel>
      </Grid>

      <!-- то, о чём речь: путь, имя файла -->
      <Border x:Name="DlgSubjectBox" Grid.Row="1" Background="#0F1216" BorderBrush="#262B34" BorderThickness="1"
              CornerRadius="6" Margin="24,16,24,0" Padding="12,9" Visibility="Collapsed">
        <TextBlock x:Name="DlgSubject" FontFamily="Cascadia Mono, Consolas" FontSize="11.5" Foreground="#AEB8C6"
                   TextWrapping="Wrap" TextTrimming="CharacterEllipsis" MaxHeight="60"/>
      </Border>

      <!-- кнопки -->
      <Border Grid.Row="2" Background="#13161C" CornerRadius="0,0,9,9" Margin="1,22,1,1" Padding="20,16">
        <StackPanel x:Name="DlgButtons" Orientation="Horizontal" HorizontalAlignment="Right"/>
      </Border>
    </Grid>
  </Border>
</Window>
'@

$script:CgDialogKinds = @{
    'info'     = @('&#xE946;', '#3B9EFF', '#1E3A5C')
    'question' = @('&#xE9CE;', '#3B9EFF', '#1E3A5C')
    'ok'       = @('&#xE930;', '#4ADE80', '#16301F')
    'warn'     = @('&#xE7BA;', '#FFB340', '#3A2E18')
    'danger'   = @('&#xE730;', '#FF5E5E', '#3A1E22')
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
    $w.FindName('IconBg').Background    = $k[2]
    $w.FindName('DlgTitle').Text = $Title
    $tb = $w.FindName('DlgText')
    if ($Text) { $tb.Text = $Text } else { $tb.Visibility = 'Collapsed' }
    if ($Subject) {
        $w.FindName('DlgSubject').Text = $Subject
        $w.FindName('DlgSubjectBox').Visibility = 'Visible'
    }

    $result = -1
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
        $b.Add_Click({ $script:CgDlgResult = $idx; $w.Close() }.GetNewClosure())
        $panel.Children.Insert(0, $b)
    }

    $script:CgDlgResult = -1
    $w.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $w.Close() } }.GetNewClosure())
    if ($script:CgDialogOwner -and $script:CgDialogOwner.IsVisible) { $w.Owner = $script:CgDialogOwner }
    else { $w.WindowStartupLocation = 'CenterScreen' }
    $null = $w.ShowDialog()
    return $script:CgDlgResult
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
  <Border Background="#171A21" BorderBrush="#333A46" BorderThickness="1" CornerRadius="10" Margin="14">
    <Border.Effect><DropShadowEffect BlurRadius="28" ShadowDepth="6" Opacity="0.6" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <StackPanel Grid.Row="0" Margin="24,22,24,0">
        <TextBlock x:Name="PrTitle" Style="{StaticResource H2}" TextWrapping="Wrap"/>
        <TextBlock x:Name="PrText"  Style="{StaticResource Sub}" FontSize="13" Margin="0,7,0,0" LineHeight="19"/>
        <TextBlock x:Name="PrSubject" FontFamily="Cascadia Mono, Consolas" FontSize="11.5" Foreground="#8A94A2"
                   Margin="0,10,0,0" TextTrimming="CharacterEllipsis" Visibility="Collapsed"/>
        <TextBox     x:Name="PrInput" Margin="0,16,0,0" Height="38"/>
        <PasswordBox x:Name="PrPass"  Margin="0,16,0,0" Height="38" Visibility="Collapsed"/>
        <TextBlock x:Name="PrHint" Style="{StaticResource Sub}" FontSize="11.5" Margin="0,9,0,0" Visibility="Collapsed"/>
      </StackPanel>
      <Border Grid.Row="1" Background="#13161C" CornerRadius="0,0,9,9" Margin="1,22,1,1" Padding="20,16">
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

    $script:CgPromptResult = $null
    $w.FindName('PrOk').Add_Click({
        if ($Password) { $script:CgPromptResult = $pass.Password } else { $script:CgPromptResult = $inp.Text }
        $w.Close()
    }.GetNewClosure())
    $w.FindName('PrCancel').Add_Click({ $script:CgPromptResult = $null; $w.Close() }.GetNewClosure())
    $w.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $script:CgPromptResult = $null; $w.Close() } }.GetNewClosure())
    $w.Add_ContentRendered({ if ($Password) { $pass.Focus() } else { $inp.Focus(); $inp.SelectAll() } }.GetNewClosure())

    if ($script:CgDialogOwner -and $script:CgDialogOwner.IsVisible) { $w.Owner = $script:CgDialogOwner }
    else { $w.WindowStartupLocation = 'CenterScreen' }
    $null = $w.ShowDialog()
    return $script:CgPromptResult
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
    <Style x:Key="ScopeCard" TargetType="RadioButton">
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="Margin" Value="0,0,0,8"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="RadioButton">
            <Border x:Name="b" Background="#1B1F26" BorderBrush="#262B34" BorderThickness="1" CornerRadius="8" Padding="14,12">
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="Auto"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="dot" Grid.Column="0" Width="18" Height="18" CornerRadius="9" BorderBrush="#4A5260"
                        BorderThickness="1" Background="Transparent" VerticalAlignment="Top" Margin="0,2,13,0">
                  <Ellipse x:Name="fill" Width="8" Height="8" Fill="#07121D" Opacity="0"/>
                </Border>
                <ContentPresenter Grid.Column="1"/>
              </Grid>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsMouseOver" Value="True"><Setter TargetName="b" Property="BorderBrush" Value="#4A5260"/></Trigger>
              <Trigger Property="IsChecked" Value="True">
                <Setter TargetName="b"    Property="BorderBrush" Value="#3B9EFF"/>
                <Setter TargetName="b"    Property="Background"  Value="#17202C"/>
                <Setter TargetName="dot"  Property="Background"  Value="#3B9EFF"/>
                <Setter TargetName="dot"  Property="BorderBrush" Value="#3B9EFF"/>
                <Setter TargetName="fill" Property="Opacity"     Value="1"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
  </Window.Resources>
  <Border Background="#171A21" BorderBrush="#333A46" BorderThickness="1" CornerRadius="10" Margin="14">
    <Border.Effect><DropShadowEffect BlurRadius="28" ShadowDepth="6" Opacity="0.6" Color="#000000"/></Border.Effect>
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>
      <StackPanel Grid.Row="0" Margin="24,22,24,0">
        <TextBlock Text="Больше про это не спрашивать" Style="{StaticResource H2}"/>
        <TextBlock x:Name="TrSubject" FontFamily="Cascadia Mono, Consolas" FontSize="11.5" Foreground="#8A94A2"
                   Margin="0,8,0,0" TextTrimming="CharacterEllipsis"/>
        <TextBlock Text="НА ЧТО РАСПРОСТРАНЯЕТСЯ" Style="{StaticResource Sub}" FontSize="10.5" FontWeight="SemiBold"
                   Margin="0,18,0,9" Opacity="0.75"/>
        <StackPanel x:Name="TrScopes"/>
        <TextBlock Text="ПОЧЕМУ ОСТАВЛЯЕТЕ — ЗАМЕТКА СЕБЕ" Style="{StaticResource Sub}" FontSize="10.5" FontWeight="SemiBold"
                   Margin="0,10,0,9" Opacity="0.75"/>
        <TextBox x:Name="TrNote" Height="38"/>
      </StackPanel>
      <Border Grid.Row="1" Background="#13161C" CornerRadius="0,0,9,9" Margin="1,22,1,1" Padding="20,16">
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
        $r.Tag = $o.Scope

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

    $script:CgTrustResult = $null
    $w.FindName('TrOk').Add_Click({
        $sel = @($radios | Where-Object { $_.IsChecked })
        if (-not $sel.Count) { return }
        $script:CgTrustResult = [PSCustomObject]@{
            Scope = [string]$sel[0].Tag
            Note  = [string]$w.FindName('TrNote').Text
        }
        $w.Close()
    }.GetNewClosure())
    $w.FindName('TrCancel').Add_Click({ $script:CgTrustResult = $null; $w.Close() }.GetNewClosure())
    $w.Add_KeyDown({ param($s, $e) if ($e.Key -eq 'Escape') { $script:CgTrustResult = $null; $w.Close() } }.GetNewClosure())

    if ($script:CgDialogOwner -and $script:CgDialogOwner.IsVisible) { $w.Owner = $script:CgDialogOwner }
    else { $w.WindowStartupLocation = 'CenterScreen' }
    $null = $w.ShowDialog()
    return $script:CgTrustResult
}
