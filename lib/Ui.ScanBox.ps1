# ============================================================
#  CookieGuard - Ui.ScanBox.ps1
#  Окно проверки: бросьте сюда файл или папку.
#
#  Что оно решает само, не спрашивая человека:
#    — что внутри папки вообще стоит проверять, а что нет;
#    — что перед проверкой надо распаковать;
#    — что архив под паролем и пароль надо спросить;
#    — что у файла действующая подпись известного издателя,
#      и тратить на него запрос к VirusTotal незачем.
#
#  ЧТО УХОДИТ НАРУЖУ. Только отпечаток SHA-256, никогда
#  содержимое. Отпечаток не позволяет восстановить файл, но
#  позволяет спросить «что про такой файл известно». Загрузка
#  самого файла — это публикация: его увидят другие, и поэтому
#  программа такого не делает вовсе.
#
#  Почему помощники вынесены наружу, а не вложены в функцию
#  окна: обработчики событий — замыкания, а замыкание копирует
#  переменные, но не таблицу функций. Вложенная функция из него
#  может оказаться не видна, и кнопка молча перестанет работать.
#  Поэтому состояние окна собрано в $ctx и передаётся явно.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

# ------------------------------------------------------------
#  Перетаскивание в окно с правами администратора
#
#  Windows не пропускает сообщения из обычного Проводника в
#  процесс с повышенными правами — иначе любая программа
#  подсовывала бы данные в привилегированное окно. Нам это
#  мешает: окно запускается от администратора, и перетаскивание
#  молча не работает. Открываем ровно три сообщения, нужных для
#  перетаскивания файлов, и ничего больше.
# ------------------------------------------------------------
if (-not ('CgDropFilter' -as [type])) {
    Add-Type -Name 'CgDropFilter' -Namespace 'Cg' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll", SetLastError = true)]
public static extern bool ChangeWindowMessageFilterEx(System.IntPtr hWnd, uint msg, uint action, System.IntPtr pChangeFilterStruct);
'@ -ErrorAction SilentlyContinue
}

function Enable-CgDropForElevated {
    param($Window)
    try {
        $h = (New-Object System.Windows.Interop.WindowInteropHelper($Window)).Handle
        if ($h -eq [IntPtr]::Zero) { return }
        foreach ($msg in @(0x0233, 0x0049, 0x004A)) {   # WM_DROPFILES, WM_COPYGLOBALDATA, WM_COPYDATA
            $null = [Cg.CgDropFilter]::ChangeWindowMessageFilterEx($h, $msg, 1, [IntPtr]::Zero)
        }
    } catch { }
}

# ------------------------------------------------------------
#  Что это за файл и стоит ли его проверять
# ------------------------------------------------------------
$script:CgKindExec = @('.exe', '.dll', '.sys', '.scr', '.com', '.pif', '.cpl', '.ocx', '.drv', '.efi', '.msi', '.msix', '.appx', '.node', '.ax')
$script:CgKindScript = @('.ps1', '.psm1', '.psd1', '.bat', '.cmd', '.vbs', '.vbe', '.js', '.jse', '.wsf', '.wsh', '.hta', '.py', '.pl', '.rb', '.lnk', '.reg', '.sh', '.jar', '.au3', '.scpt')
$script:CgKindDoc = @('.docm', '.xlsm', '.pptm', '.dotm', '.xltm', '.doc', '.xls', '.ppt', '.rtf', '.pdf', '.chm', '.xla', '.xlam', '.iqy', '.slk')
$script:CgKindQuiet = @(
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg', '.ico', '.heic', '.tif', '.tiff',
    '.mp3', '.mp4', '.avi', '.mkv', '.mov', '.wav', '.flac', '.ogg', '.webm', '.m4a',
    '.txt', '.md', '.csv', '.log', '.json', '.xml', '.yml', '.yaml', '.html', '.htm', '.css',
    '.ini', '.cfg', '.conf', '.srt', '.ttf', '.otf', '.woff', '.woff2'
)

function Get-CgFileKind {
    param([string]$Path)
    $ext = ([IO.Path]::GetExtension($Path)).ToLowerInvariant()
    if (Test-CgArchive $Path)                { return [PSCustomObject]@{ Class = 'archive'; Text = 'архив';            Check = $false } }
    if ($script:CgKindExec   -contains $ext) { return [PSCustomObject]@{ Class = 'exec';    Text = 'программа';        Check = $true } }
    if ($script:CgKindScript -contains $ext) { return [PSCustomObject]@{ Class = 'script';  Text = 'сценарий';         Check = $true } }
    if ($script:CgKindDoc    -contains $ext) { return [PSCustomObject]@{ Class = 'doc';     Text = 'документ с кодом'; Check = $true } }
    if ($script:CgKindQuiet  -contains $ext) { return [PSCustomObject]@{ Class = 'quiet';   Text = 'данные';           Check = $false } }
    return [PSCustomObject]@{ Class = 'other'; Text = 'неизвестный формат'; Check = $true }
}

function Format-CgSize {
    param([long]$Bytes)
    if ($Bytes -ge 1073741824) { return ('{0:N1} ГБ' -f ($Bytes / 1073741824)) }
    if ($Bytes -ge 1048576)    { return ('{0:N1} МБ' -f ($Bytes / 1048576)) }
    if ($Bytes -ge 1024)       { return ('{0:N0} КБ' -f ($Bytes / 1024)) }
    return "$Bytes Б"
}

# ------------------------------------------------------------
#  Работа со списком окна. $Ctx — всё состояние окна:
#  @{ U = элементы; Items = строки; Temp = распакованные папки }
# ------------------------------------------------------------
function Set-CgSbStatus {
    param($Ctx, [string]$Text)
    $Ctx.U.SbStatus.Text = $Text
}

function Update-CgSbView {
    param($Ctx)
    if ($Ctx.Items.Count) {
        $Ctx.U.SbDropHint.Visibility = 'Collapsed'
        $Ctx.U.SbListBox.Visibility = 'Visible'
    } else {
        $Ctx.U.SbDropHint.Visibility = 'Visible'
        $Ctx.U.SbListBox.Visibility = 'Collapsed'
    }
    $check = @($Ctx.Items | Where-Object { $_.Check }).Count
    $skip = $Ctx.Items.Count - $check
    if ($Ctx.Items.Count) {
        Set-CgSbStatus $Ctx ("в списке: {0}    к проверке: {1}    пропущено как безобидное: {2}" -f $Ctx.Items.Count, $check, $skip)
    } else {
        Set-CgSbStatus $Ctx 'Пусто'
    }
}

function Add-CgSbFile {
    param($Ctx, [string]$Path, [string]$From = '')

    $fi = $null
    try { $fi = Get-Item -LiteralPath $Path -Force -ErrorAction Stop } catch { return }
    if ($fi.PSIsContainer) { return }
    foreach ($r in $Ctx.Items) { if ($r.Path -eq $fi.FullName) { return } }

    $kind = Get-CgFileKind $fi.FullName
    $sign = ''
    $sev = 'INFO'
    $verdict = ''
    $signedByKnown = $false

    if ($kind.Check -or $kind.Class -eq 'archive') {
        $sig = Get-CgSignature $fi.FullName
        if ($sig.Valid -and $sig.Signer) {
            $sign = $sig.Signer
            if ($sig.Trusted) {
                $signedByKnown = $true
                $sev = 'OK'
                $verdict = 'подписано известным издателем — проверять незачем'
            }
        } elseif ($kind.Class -eq 'exec') {
            # Про подпись говорим только там, где она вообще бывает.
            # У zip и у файла с незнакомым расширением Windows отвечает
            # UnknownError просто потому, что подпись туда не кладут, —
            # и столбец заполнялся пугающей бессмыслицей.
            if ($sig.Status -eq 'NotSigned') {
                $sign = 'нет подписи'
            } elseif ($sig.Status -and $sig.Status -ne 'NoPath') {
                $sign = "подпись недействительна: $($sig.Status)"
                $sev = 'WARN'
            }
        }
    }

    $tr = Test-CgTrustedFile $fi.FullName
    if ($tr) { $sev = 'OK'; $verdict = 'доверено вами' }

    $check = ($kind.Check -and -not $tr -and -not $signedByKnown)
    if ($fi.Length -gt 2147483648) {
        $check = $false
        $verdict = 'слишком большой файл — пропущен'
    }
    if (-not $check -and -not $verdict) {
        if ($kind.Class -eq 'quiet')   { $verdict = 'данные, не исполняется — пропущен' }
        if ($kind.Class -eq 'archive') { $verdict = 'архив' }
    }

    $detail = "Файл: $($fi.FullName)`nРазмер: $(Format-CgSize $fi.Length)`nИзменён: $($fi.LastWriteTime)`nЧто это: $($kind.Text)`nПодпись: $(if ($sign) { $sign } else { 'не проверялась' })"
    if ($From) { $detail += "`nИз архива: $From" }

    # Одно и то же имя может прийти и с диска, и из архива.
    # Без пометки в списке две строки выглядят опечаткой.
    $display = $fi.Name
    if ($From) { $display = "$From  →  $($fi.Name)" }

    $Ctx.Items.Add([PSCustomObject]@{
        Severity = $sev
        Display  = $display
        Name     = $fi.Name
        Path     = $fi.FullName
        From     = $From
        SizeText = Format-CgSize $fi.Length
        Size     = $fi.Length
        KindText = $kind.Text
        Class    = $kind.Class
        SignText = $sign
        Check    = [bool]$check
        Hash     = ''
        Verdict  = $verdict
        Title    = $fi.Name
        Query    = $fi.Name
        Detail   = $detail
    })
}

function Set-CgSbVerdict {
    param($Ctx, [string]$Path, [string]$Verdict, [string]$Severity = '')
    foreach ($r in $Ctx.Items) {
        if ($r.Path -ne $Path) { continue }
        $r.Verdict = $Verdict
        if ($Severity) { $r.Severity = $Severity }
        break
    }
    $Ctx.U.SbGrid.Items.Refresh()
}

function Expand-CgSbArchive {
    param($Ctx, [string]$Path, [int]$Depth)

    $info = Get-CgArchiveInfo $Path
    if (-not $info.Ok) {
        Set-CgSbVerdict $Ctx $Path $info.Error 'WARN'
        return
    }

    $pass = ''
    if ($info.Encrypted) {
        $pass = Show-CgPrompt -Title 'Архив под паролем' `
            -Text 'Без пароля заглянуть внутрь нельзя. Пароль нужен только для распаковки: он не сохраняется и никуда не передаётся.' `
            -Subject (Split-Path -Leaf $Path) -OkText 'Открыть' -Password
        if ($null -eq $pass) {
            Set-CgSbVerdict $Ctx $Path 'архив под паролем — не открыт' 'WARN'
            return
        }
    }

    Set-CgSbStatus $Ctx "распаковываю $(Split-Path -Leaf $Path)..."
    $ex = Expand-CgArchive $Path $pass
    if (-not $ex.Ok) {
        $msg = $ex.Error
        if ($ex.WrongPassword) { $msg = 'пароль не подошёл' }
        Set-CgSbVerdict $Ctx $Path $msg 'WARN'
        return
    }

    $null = $Ctx.Temp.Add($ex.Dir)
    $inner = @(Get-ChildItem -LiteralPath $ex.Dir -Recurse -File -Force -ErrorAction SilentlyContinue | Select-Object -First 1500)
    foreach ($f in $inner) {
        Add-CgSbFile $Ctx $f.FullName (Split-Path -Leaf $Path)
        if ((Test-CgArchive $f.FullName) -and $Depth -lt 2) {
            Expand-CgSbArchive $Ctx $f.FullName ($Depth + 1)
        }
    }
    Set-CgSbVerdict $Ctx $Path "распакован: файлов внутри $($inner.Count)"
}

function Add-CgSbPath {
    param($Ctx, [string]$Path, [int]$Depth = 0)

    if ($Depth -gt 3) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }

    if (Test-Path -LiteralPath $Path -PathType Container) {
        # Потолок нужен: бросив C:\ целиком, человек получил бы
        # зависшее окно вместо ответа.
        $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue | Select-Object -First 3000)
        foreach ($f in $files) { Add-CgSbPath $Ctx $f.FullName ($Depth + 1) }
        return
    }

    Add-CgSbFile $Ctx $Path
    if ((Test-CgArchive $Path) -and $Ctx.U.SbDeep.IsChecked) {
        Expand-CgSbArchive $Ctx $Path $Depth
    }
}

function Add-CgSbPaths {
    param($Ctx, [string[]]$Paths)
    $Ctx.Window.Cursor = 'Wait'
    $Ctx.U.SbProgress.Visibility = 'Visible'
    try {
        foreach ($p in $Paths) { Add-CgSbPath $Ctx $p 0 }
    } finally {
        $Ctx.Window.Cursor = 'Arrow'
        $Ctx.U.SbProgress.Visibility = 'Collapsed'
        Update-CgSbView $Ctx
    }
}

# ------------------------------------------------------------
#  Проверка на VirusTotal идёт в отдельном потоке.
#
#  Бесплатный ключ даёт 4 запроса в минуту. Поэтому сперва
#  смотрим в местную базу вердиктов и ходим в сеть только за
#  тем, чего в ней нет, выдерживая паузу.
# ------------------------------------------------------------
$script:CgSbVtScript = {
    param($sync, $jobs)
    try {
        . (Join-Path $sync.Root 'lib\Core.ps1')
        . (Join-Path $sync.Root 'lib\Trust.ps1')
        . (Join-Path $sync.Root 'lib\VirusTotal.ps1')

        $key = Get-CgVtKey
        $cache = Get-CgVtCache
        $n = 0
        $asked = 0

        foreach ($j in $jobs) {
            $n++
            $sync.Step = "считаю отпечаток ($n из $($jobs.Count)): $($j.Name)"
            $h = Get-CgHash $j.Path
            if (-not $h) {
                $sync.Queue.Enqueue(@{ Path = $j.Path; Hash = ''; Severity = 'NOTE'; Verdict = 'не удалось прочитать файл' })
                continue
            }

            $v = $null
            if ($cache.ContainsKey($h)) { $v = $cache[$h] }

            if (-not $v) {
                if (-not $key) {
                    $sync.Queue.Enqueue(@{ Path = $j.Path; Hash = $h; Severity = 'NOTE'; Verdict = 'нет ключа VirusTotal — задайте его в разделе «Защита»' })
                    continue
                }
                if ($asked -gt 0) { Start-Sleep -Seconds 16 }
                $sync.Step = "спрашиваю VirusTotal ($n из $($jobs.Count)): $($j.Name)"
                $v = Invoke-CgVtLookup $h $key
                $asked++
                if ($v -and $v.Status -eq 'known') { $cache[$h] = $v }
            }

            $sev = 'NOTE'
            $txt = 'нет данных'
            if ($v) {
                switch ($v.Status) {
                    'known' {
                        $sev = Get-CgVtSeverity $v
                        if ($v.Malicious -gt 0 -or $v.Suspicious -gt 0) {
                            $txt = "опасным считают $($v.Malicious) из $($v.Total) антивирусов"
                            if ($v.Label) { $txt += " — $($v.Label)" }
                        } else {
                            $txt = "чисто: 0 из $($v.Total) антивирусов"
                        }
                    }
                    'unknown'   { $sev = 'NOTE'; $txt = 'VirusTotal такого файла не видел' }
                    'badkey'    { $sev = 'WARN'; $txt = 'ключ VirusTotal не принят' }
                    'ratelimit' { $sev = 'WARN'; $txt = 'исчерпана квота ключа — повторите позже' }
                    default     { $sev = 'NOTE'; $txt = "ошибка запроса: $($v.Label)" }
                }
            }
            $sync.Queue.Enqueue(@{ Path = $j.Path; Hash = $h; Severity = $sev; Verdict = $txt })
        }
        Save-CgVtCache $cache
    } catch {
        $sync.Error = $_.ToString()
    } finally {
        $sync.Done = $true
    }
}

$script:CgScanBoxXaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:shell="clr-namespace:System.Windows.Shell;assembly=PresentationFramework"
        Title="Проверка файлов — CookieGuard" Height="680" Width="1000" MinHeight="540" MinWidth="780"
        WindowStyle="None" Background="#0C0D10" WindowStartupLocation="CenterOwner" AllowDrop="True">
  <shell:WindowChrome.WindowChrome>
    <shell:WindowChrome CaptionHeight="0" ResizeBorderThickness="6" GlassFrameThickness="0" CornerRadius="0" UseAeroCaptionButtons="False"/>
  </shell:WindowChrome.WindowChrome>
  <Window.Resources>
<!--THEME-->
  </Window.Resources>

  <Border BorderBrush="{StaticResource Line}" BorderThickness="1">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="40"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="*"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <Border Grid.Row="0" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,0,0,1">
        <Grid x:Name="SbTitleBar" Background="Transparent">
          <StackPanel Orientation="Horizontal" VerticalAlignment="Center" Margin="14,0,0,0">
            <TextBlock Text="&#xE721;" Style="{StaticResource Glyph}" FontSize="14" Foreground="{StaticResource Accent}"/>
            <TextBlock Text="Проверка файлов" FontFamily="{StaticResource FontDisplay}" FontWeight="SemiBold" FontSize="13.5"
                       Margin="10,0,0,0" VerticalAlignment="Center"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="SbMin"   Content="&#xE921;" Style="{StaticResource CaptionBtn}"/>
            <Button x:Name="SbMax"   Content="&#xE922;" Style="{StaticResource CaptionBtn}"/>
            <Button x:Name="SbClose" Content="&#xE8BB;" Style="{StaticResource CaptionClose}"/>
          </StackPanel>
        </Grid>
      </Border>

      <!-- Панель кнопок стоит вплотную к списку и делит с ним линию,
           как панели над таблицами главного окна: вместе — один блок. -->
      <Border Grid.Row="1" Style="{StaticResource Card}" Background="{StaticResource NavBg}" Padding="12,8" Margin="20,20,20,-1">
        <Grid>
          <StackPanel Orientation="Horizontal">
            <Button x:Name="SbAddFiles"  Content="Выбрать файлы" Style="{StaticResource Primary}"/>
            <Button x:Name="SbAddFolder" Content="Выбрать папку"/>
            <Button x:Name="SbClear"     Content="Очистить" Style="{StaticResource Ghost}"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
            <CheckBox x:Name="SbDeep" Content="заглядывать в архивы" IsChecked="True"/>
            <Button x:Name="SbCheck" Content="Проверить на VirusTotal" Style="{StaticResource Primary}" Margin="6,0,0,0"/>
          </StackPanel>
        </Grid>
      </Border>

      <Grid Grid.Row="2" Margin="20,0,20,0">
        <Border x:Name="SbDropHint" BorderBrush="{StaticResource Line}" BorderThickness="1" Background="{StaticResource WinBg}">
          <StackPanel VerticalAlignment="Center" HorizontalAlignment="Center">
            <Border Width="72" Height="72" BorderBrush="{StaticResource StrongLine}" BorderThickness="1" HorizontalAlignment="Center">
              <TextBlock Text="&#xE8B5;" Style="{StaticResource Glyph}" FontSize="30" Foreground="{StaticResource Accent}"/>
            </Border>
            <TextBlock Text="Перетащите сюда файл или папку" Style="{StaticResource H2}" HorizontalAlignment="Center" Margin="0,22,0,0"/>
            <TextBlock Text="Программа сама решит, что стоит проверять, распакует архив и спросит пароль, если он нужен."
                       Style="{StaticResource Sub}" HorizontalAlignment="Center" TextAlignment="Center" MaxWidth="450" Margin="0,9,0,0"/>
            <TextBlock x:Name="SbDropNote" Style="{StaticResource Sub}" FontSize="11.5" HorizontalAlignment="Center"
                       TextAlignment="Center" MaxWidth="450" Margin="0,16,0,0" Foreground="#FFB340" Visibility="Collapsed"/>
          </StackPanel>
        </Border>

        <Border x:Name="SbListBox" Style="{StaticResource Card}" Padding="0" Margin="0" Visibility="Collapsed">
          <DataGrid x:Name="SbGrid">
            <DataGrid.Columns>
              <!-- Тема больше не красит строку целиком: важность
                   показывает пометка в своём столбце, как в таблицах
                   главного окна. Без столбца вердикт VirusTotal был бы
                   виден только словами. -->
              <DataGridTemplateColumn Header="УРОВЕНЬ" Width="96">
                <DataGridTemplateColumn.CellTemplate>
                  <DataTemplate>
                    <StackPanel Orientation="Horizontal" VerticalAlignment="Center">
                      <Rectangle Style="{StaticResource SevMark}"/>
                      <TextBlock Text="{Binding Severity}" Style="{StaticResource PillTextAuto}"/>
                    </StackPanel>
                  </DataTemplate>
                </DataGridTemplateColumn.CellTemplate>
              </DataGridTemplateColumn>
              <DataGridTextColumn Header="ФАЙЛ"    Binding="{Binding Display}"  Width="2*" MinWidth="180"/>
              <DataGridTextColumn Header="РАЗМЕР"  Binding="{Binding SizeText}" Width="85"/>
              <DataGridTextColumn Header="ЧТО ЭТО" Binding="{Binding KindText}" Width="135"/>
              <DataGridTextColumn Header="ПОДПИСЬ" Binding="{Binding SignText}" Width="150"/>
              <DataGridTextColumn Header="ВЕРДИКТ" Binding="{Binding Verdict}"  Width="3*" MinWidth="220"/>
            </DataGrid.Columns>
          </DataGrid>
        </Border>
      </Grid>

      <Border Grid.Row="3" Background="{StaticResource NavBg}" BorderBrush="{StaticResource Line}" BorderThickness="0,1,0,0" Padding="16,6" Margin="0,20,0,0">
        <Grid>
          <TextBlock x:Name="SbStatus" Text="Пусто" Style="{StaticResource Stat}" TextTrimming="CharacterEllipsis" Margin="0,0,210,0"/>
          <ProgressBar x:Name="SbProgress" Width="190" Height="2" HorizontalAlignment="Right" Visibility="Collapsed" IsIndeterminate="True"/>
        </Grid>
      </Border>
    </Grid>
  </Border>
</Window>
'@

function Show-CgScanBox {
    param($Owner, [string]$Root)

    $w = New-CgWindow $script:CgScanBoxXaml
    $u = Get-CgUiMap $w @('SbTitleBar', 'SbMin', 'SbMax', 'SbClose', 'SbAddFiles', 'SbAddFolder', 'SbClear',
                          'SbDeep', 'SbCheck', 'SbDropHint', 'SbDropNote', 'SbListBox', 'SbGrid', 'SbStatus', 'SbProgress')

    $ctx = @{
        Window = $w
        U      = $u
        Items  = (New-Object System.Collections.ObjectModel.ObservableCollection[object])
        Temp   = (New-Object System.Collections.ArrayList)
    }
    $u.SbGrid.ItemsSource = $ctx.Items

    if ($Owner) { $w.Owner = $Owner }
    Add-CgWindowDrag $w $u.SbTitleBar
    $u.SbMin.Add_Click({ $w.WindowState = 'Minimized' }.GetNewClosure())
    $u.SbMax.Add_Click({
        if ($w.WindowState -eq 'Maximized') { $w.WindowState = 'Normal' } else { $w.WindowState = 'Maximized' }
    }.GetNewClosure())
    $u.SbClose.Add_Click({ $w.Close() }.GetNewClosure())

    # ---------- перетаскивание ----------
    # Кисти берём из темы, а не пишем цвет строкой: иначе после
    # перетаскивания зона возвращалась бы не к тому тону, с которого
    # начинала, — стоит теме сменить хоть один оттенок.
    $dz = @{
        Line = $w.FindResource('Line');   Bg   = $w.FindResource('WinBg')
        On   = $w.FindResource('Accent'); OnBg = $w.FindResource('ControlBg')
    }

    $w.Add_DragOver({
        param($s, $e)
        if ($e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) {
            $e.Effects = [Windows.DragDropEffects]::Copy
            $u.SbDropHint.BorderBrush = $dz.On
            $u.SbDropHint.Background = $dz.OnBg
        } else {
            $e.Effects = [Windows.DragDropEffects]::None
        }
        $e.Handled = $true
    }.GetNewClosure())

    $w.Add_DragLeave({
        $u.SbDropHint.BorderBrush = $dz.Line
        $u.SbDropHint.Background = $dz.Bg
    }.GetNewClosure())

    $w.Add_Drop({
        param($s, $e)
        $u.SbDropHint.BorderBrush = $dz.Line
        $u.SbDropHint.Background = $dz.Bg
        if (-not $e.Data.GetDataPresent([Windows.DataFormats]::FileDrop)) { return }
        $e.Handled = $true
        Add-CgSbPaths $ctx @($e.Data.GetData([Windows.DataFormats]::FileDrop))
    }.GetNewClosure())

    $w.Add_SourceInitialized({
        Enable-CgDropForElevated $w
        if (Test-CgAdmin) {
            $u.SbDropNote.Foreground = '#7C8694'
            $u.SbDropNote.Text = 'Если перетаскивание не сработает — так Windows ограждает окна с правами администратора. Тогда просто нажмите «Выбрать файлы».'
            $u.SbDropNote.Visibility = 'Visible'
        }
    }.GetNewClosure())

    # ---------- выбор вручную ----------
    $u.SbAddFiles.Add_Click({
        $d = New-Object Microsoft.Win32.OpenFileDialog
        $d.Multiselect = $true
        $d.Title = 'Что проверить'
        $d.Filter = 'Все файлы|*.*'
        if ($d.ShowDialog()) { Add-CgSbPaths $ctx @($d.FileNames) }
    }.GetNewClosure())

    $u.SbAddFolder.Add_Click({
        $d = New-Object System.Windows.Forms.FolderBrowserDialog
        $d.Description = 'Какую папку проверить'
        $d.ShowNewFolderButton = $false
        if ($d.ShowDialog() -eq 'OK') { Add-CgSbPaths $ctx @($d.SelectedPath) }
    }.GetNewClosure())

    $u.SbClear.Add_Click({
        $ctx.Items.Clear()
        foreach ($d in $ctx.Temp) { Remove-CgTempDir $d }
        $ctx.Temp.Clear()
        Update-CgSbView $ctx
    }.GetNewClosure())

    # ---------- проверка ----------
    $sync = [hashtable]::Synchronized(@{
        Root  = $Root
        Queue = (New-Object System.Collections.Concurrent.ConcurrentQueue[object])
        Done  = $false
        Step  = ''
        Error = ''
    })

    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(300)
    $timer.Add_Tick({
        $got = $null
        $any = $false
        while ($sync.Queue.TryDequeue([ref]$got)) {
            $any = $true
            foreach ($r in $ctx.Items) {
                if ($r.Path -ne $got.Path) { continue }
                $r.Severity = $got.Severity
                $r.Verdict  = $got.Verdict
                $r.Hash     = $got.Hash
                $r.Detail   = $r.Detail + "`nОтпечаток: $($got.Hash)`nВердикт: $($got.Verdict)"
                break
            }
        }
        if ($any) { $u.SbGrid.Items.Refresh() }
        if ($sync.Step) { Set-CgSbStatus $ctx $sync.Step }

        if ($sync.Done) {
            $timer.Stop()
            $u.SbProgress.Visibility = 'Collapsed'
            $u.SbCheck.IsEnabled = $true
            $bad = @($ctx.Items | Where-Object { $_.Severity -eq 'CRIT' -or $_.Severity -eq 'WARN' }).Count
            if ($sync.Error) {
                Set-CgSbStatus $ctx "проверка прервана: $($sync.Error)"
            } elseif ($bad) {
                Set-CgSbStatus $ctx "проверка закончена. Тревожных: $bad — это строки с пометкой CRIT и WARN."
            } else {
                Set-CgSbStatus $ctx 'проверка закончена, ничего тревожного не найдено'
            }
        }
    }.GetNewClosure())

    $u.SbCheck.Add_Click({
        $jobs = @($ctx.Items | Where-Object { $_.Check } | ForEach-Object { @{ Path = $_.Path; Name = $_.Name } })
        if (-not $jobs.Count) {
            $null = Show-CgDialog -Title 'Проверять нечего' `
                -Text 'В списке нет файлов, которые имело бы смысл проверять: всё либо данные, либо подписано известным издателем, либо уже доверено вами.' -Kind 'info'
            return
        }
        $u.SbCheck.IsEnabled = $false
        $u.SbProgress.Visibility = 'Visible'
        $sync.Done = $false
        $sync.Error = ''
        $sync.Step = 'начинаю'

        $rs = [runspacefactory]::CreateRunspace()
        $rs.ApartmentState = 'MTA'
        $rs.ThreadOptions = 'ReuseThread'
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $null = $ps.AddScript($script:CgSbVtScript).AddArgument($sync).AddArgument($jobs)
        $null = $ps.BeginInvoke()
        $timer.Start()
    }.GetNewClosure())

    # ---------- меню по правой кнопке ----------
    Add-CgRowMenu $u.SbGrid {
        param($row)
        return @(
            @{ Text = 'Доверять'; Glyph = 0xE8FB; Action = {
                param($r)
                $res = Invoke-CgTrustRow $r
                if ($res -and $res.Ok) {
                    $r.Severity = 'OK'
                    $r.Verdict = 'доверено вами'
                    $r.Check = $false
                    $u.SbGrid.Items.Refresh()
                    Set-CgSbStatus $ctx $res.Message
                } elseif ($res -and -not $res.Ok) {
                    $null = Show-CgDialog -Title 'Не удалось добавить в доверенные' -Text $res.Message -Kind 'warn'
                }
            } }
            @{ Text = 'Показать в проводнике'; Glyph = 0xEC50; Action = { param($r) $null = Show-CgInExplorer $r } }
            @{ Text = 'Открыть на VirusTotal'; Glyph = 0xE774; Action = { param($r) $null = Open-CgVirusTotal $r } }
            @{ Text = 'Искать в интернете';    Glyph = 0xE721; Action = {
                param($r) Start-Process ('https://duckduckgo.com/?q=' + [uri]::EscapeDataString("$($r.Name) вирус или нет"))
            } }
            @{ Separator = $true }
            @{ Text = 'Копировать путь';       Glyph = 0xE8C8; Action = { param($r) $null = Copy-CgRowText $r.Path } }
            @{ Text = 'Копировать подробности'; Glyph = 0xE8C8; Action = { param($r) $null = Copy-CgRowText $r.Detail } }
        )
    }.GetNewClosure()

    $w.Add_Closed({
        $timer.Stop()
        foreach ($d in $ctx.Temp) { Remove-CgTempDir $d }
    }.GetNewClosure())

    Update-CgSbView $ctx
    $null = $w.ShowDialog()
}
