# ============================================================
#  CookieGuard - Ui.ScanBox.ps1
#  Страница «Проверка файлов»: бросьте файл или папку в окно.
#
#  Раньше это было отдельное окно, и путь к проверке занимал три
#  щелчка: открыть окно, перетащить, закрыть. Теперь файл можно
#  бросить в любое место главного окна — оно само откроет эту
#  страницу.
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
#  Windows не пропускает перетаскивание из обычного Проводника в
#  процесс с повышенными правами — иначе любая программа
#  подсовывала бы данные в привилегированное окно. Перетаскивание
#  WPF идёт через OLE и так и не заработает, сколько фильтров ни
#  открывай. Работает старый способ — сообщение WM_DROPFILES:
#  снимаем OLE-приёмник окна, просим у Windows список файлов
#  по-старому и открываем ровно три сообщения, нужных для этого.
# ------------------------------------------------------------
if (-not ('Cg.DropTarget' -as [type])) {
    Add-Type -ReferencedAssemblies PresentationFramework, PresentationCore, WindowsBase, System.Xaml -TypeDefinition @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.Windows;
using System.Windows.Interop;
namespace Cg {
    public class DropArgs : EventArgs {
        public string[] Files { get; private set; }
        public DropArgs(string[] f) { Files = f; }
    }
    public class DropTarget {
        [DllImport("shell32.dll")] static extern void DragAcceptFiles(IntPtr h, bool accept);
        [DllImport("shell32.dll", CharSet = CharSet.Unicode)] static extern uint DragQueryFile(IntPtr d, uint i, StringBuilder s, uint cch);
        [DllImport("shell32.dll")] static extern void DragFinish(IntPtr d);
        [DllImport("ole32.dll")] static extern int RevokeDragDrop(IntPtr h);
        [DllImport("user32.dll")] static extern bool ChangeWindowMessageFilterEx(IntPtr h, uint msg, uint action, IntPtr p);
        public event EventHandler<DropArgs> Dropped;
        public DropTarget(Window w) {
            IntPtr h = new WindowInteropHelper(w).Handle;
            HwndSource src = HwndSource.FromHwnd(h);
            src.AddHook(Hook);
            RevokeDragDrop(h);
            DragAcceptFiles(h, true);
            foreach (uint m in new uint[] { 0x0233, 0x0049, 0x004A }) ChangeWindowMessageFilterEx(h, m, 1, IntPtr.Zero);
        }
        IntPtr Hook(IntPtr h, int msg, IntPtr w, IntPtr l, ref bool handled) {
            if (msg != 0x0233) return IntPtr.Zero;
            uint n = DragQueryFile(w, 0xFFFFFFFF, null, 0);
            string[] files = new string[n];
            for (uint i = 0; i < n; i++) {
                StringBuilder sb = new StringBuilder(1024);
                DragQueryFile(w, i, sb, 1024);
                files[i] = sb.ToString();
            }
            DragFinish(w);
            handled = true;
            if (Dropped != null) Dropped(this, new DropArgs(files));
            return IntPtr.Zero;
        }
    }
}
'@ -ErrorAction SilentlyContinue
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
    # Переводим здесь, на показе: строки хода проверки приходят из
    # отдельного потока, где словаря нет.
    $Ctx.U.SbStatus.Text = T $Text
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

# ------------------------------------------------------------
#  Подключить страницу к главному окну
#
#  $U — элементы страницы (Sb*), $OnShow — как показать страницу:
#  бросок файла в любое место окна сначала переключает на неё.
# ------------------------------------------------------------
function Initialize-CgScanPage {
    param($Window, [string]$Root, $U, [scriptblock]$OnShow)

    $ctx = @{
        Window = $Window
        U      = $U
        Items  = (New-Object System.Collections.ObjectModel.ObservableCollection[object])
        Temp   = (New-Object System.Collections.ArrayList)
    }
    $U.SbGrid.ItemsSource = $ctx.Items
    $u = $U
    $w = $Window

    # ---------- перетаскивание ----------
    # Кисти берём из темы, а не пишем цвет строкой: иначе после
    # перетаскивания зона возвращалась бы не к тому тону.
    $dz = @{
        Line = $w.FindResource('Line');   Bg   = $w.FindResource('WinBg')
        On   = $w.FindResource('Accent'); OnBg = $w.FindResource('ControlBg')
    }
    $take = {
        param([string[]]$Paths)
        if (-not @($Paths).Count) { return }
        if ($OnShow) { & $OnShow }
        $null = $w.Activate()
        Add-CgSbPaths $ctx @($Paths)
    }.GetNewClosure()

    if (Test-CgAdmin) {
        # С правами администратора — только старым способом (см. выше).
        # Подсветки зоны при наведении тут не бывает: Windows сообщает
        # о файлах, только когда их уже отпустили.
        $w.Add_SourceInitialized({
            try {
                $dt = New-Object Cg.DropTarget($w)
                $dt.add_Dropped({ param($s, $e) & $take @($e.Files) }.GetNewClosure())
                $ctx.DropTarget = $dt
            } catch { }
        }.GetNewClosure())
    } else {
        $w.AllowDrop = $true
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
            & $take @($e.Data.GetData([Windows.DataFormats]::FileDrop))
        }.GetNewClosure())
    }

    # ---------- выбор вручную ----------
    $u.SbAddFiles.Add_Click({
        $d = New-Object Microsoft.Win32.OpenFileDialog
        $d.Multiselect = $true
        $d.Title = T 'Что проверить'
        $d.Filter = T 'Все файлы|*.*'
        if ($d.ShowDialog()) { Add-CgSbPaths $ctx @($d.FileNames) }
    }.GetNewClosure())

    $u.SbAddFolder.Add_Click({
        $d = New-Object System.Windows.Forms.FolderBrowserDialog
        $d.Description = T 'Какую папку проверить'
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

    $w.Add_Closed({
        $timer.Stop()
        foreach ($d in $ctx.Temp) { Remove-CgTempDir $d }
    }.GetNewClosure())

    Update-CgSbView $ctx
    return $ctx
}
