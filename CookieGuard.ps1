# ============================================================
#  CookieGuard — окно приложения
#  Наблюдение за доступом к cookie и паролям браузеров.
#  Одно окно, вкладки, живой монитор, отчёты.
# ============================================================

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms, Microsoft.VisualBasic

. (Join-Path $PSScriptRoot 'lib\Core.ps1')
. (Join-Path $PSScriptRoot 'lib\Checks.ps1')
. (Join-Path $PSScriptRoot 'lib\Hosts.ps1')
. (Join-Path $PSScriptRoot 'lib\Monitor.ps1')
. (Join-Path $PSScriptRoot 'lib\Protect.ps1')
. (Join-Path $PSScriptRoot 'lib\Network.ps1')
. (Join-Path $PSScriptRoot 'lib\AppData.ps1')
. (Join-Path $PSScriptRoot 'lib\VirusTotal.ps1')
. (Join-Path $PSScriptRoot 'lib\Baseline.ps1')
. (Join-Path $PSScriptRoot 'lib\Actions.ps1')
. (Join-Path $PSScriptRoot 'lib\Trust.ps1')
. (Join-Path $PSScriptRoot 'lib\SafeDns.ps1')
. (Join-Path $PSScriptRoot 'lib\Archive.ps1')
. (Join-Path $PSScriptRoot 'lib\Diagnose.ps1')
. (Join-Path $PSScriptRoot 'lib\Update.ps1')
. (Join-Path $PSScriptRoot 'lib\Remedy.ps1')
. (Join-Path $PSScriptRoot 'lib\Inspect.ps1')
. (Join-Path $PSScriptRoot 'lib\AdBlock.ps1')
. (Join-Path $PSScriptRoot 'lib\Ui.Theme.ps1')
. (Join-Path $PSScriptRoot 'lib\Ui.Dialogs.ps1')
. (Join-Path $PSScriptRoot 'lib\Ui.Actions.ps1')
. (Join-Path $PSScriptRoot 'lib\Ui.MainXaml.ps1')
. (Join-Path $PSScriptRoot 'lib\Ui.Inspector.ps1')
. (Join-Path $PSScriptRoot 'lib\Ui.ScanBox.ps1')

$ErrorActionPreference = 'Continue'

# ------------------------------------------------------------
#  Своё место на панели задач
#
#  Окно живёт в процессе powershell.exe, и Windows группирует его
#  с PowerShell: на панели задач значок PowerShell, при наведении —
#  «Windows PowerShell». Собственный идентификатор приложения
#  отделяет окно от PowerShell, а значок окна (его ставит
#  New-CgWindow) Windows тогда и показывает.
# ------------------------------------------------------------
if (-not ('Cg.AppId' -as [type])) {
    Add-Type -Namespace 'Cg' -Name 'AppId' -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("shell32.dll", CharSet = System.Runtime.InteropServices.CharSet.Unicode)]
public static extern int SetCurrentProcessExplicitAppUserModelID(string id);
'@ -ErrorAction SilentlyContinue
}
try { $null = [Cg.AppId]::SetCurrentProcessExplicitAppUserModelID('CookieGuard.App') } catch { }

# ------------------------------------------------------------
#  Загрузка окна
#
#  Разметка вынесена в lib\Ui.MainXaml.ps1, стили — в
#  lib\Ui.Theme.ps1: одна и та же тема на главное окно, окно
#  проверки файлов и диалоги.
# ------------------------------------------------------------
$win = New-CgWindow $script:CgMainXaml
Set-CgDialogOwner $win

# Масштаб. Окно было мелким и тесным: шрифт 12–13 точек на экране
# 1920×1080 читается с трудом. Всё содержимое увеличивается разом,
# а окно — вместе с ним, но не больше рабочей области экрана.
$script:CgUiScale = 1.1
try { $v = [double](Get-CgSettings).UiScale; if ($v -ge 0.9 -and $v -le 1.6) { $script:CgUiScale = $v } } catch { }
if ($script:CgUiScale -ne 1.0 -and $win.Content -is [System.Windows.FrameworkElement]) {
    $win.Content.LayoutTransform = New-Object System.Windows.Media.ScaleTransform($script:CgUiScale, $script:CgUiScale)
}
$wa = [System.Windows.SystemParameters]::WorkArea
$win.Width  = [Math]::Min(1340 * $script:CgUiScale, $wa.Width * 0.94)
$win.Height = [Math]::Min(900 * $script:CgUiScale, $wa.Height * 0.94)
$win.MinWidth  = [Math]::Min($win.MinWidth * $script:CgUiScale, $wa.Width * 0.9)
$win.MinHeight = [Math]::Min($win.MinHeight * $script:CgUiScale, $wa.Height * 0.9)

$ui = @{}
foreach ($n in @('ChipAdmin','ChipAudit','ChipMon','BtnScan','BtnMon','Cards','BtnAudit','BtnAuditOff',
                 'BtnReports','BtnEvidence','Tabs','BtnMon2','BtnMonClear','ChkShowOk','MonStats','GridMon',
                 'BtnScan2','BtnSaveReport','ChkOnlyBad','ScanStats','GridFind','BtnProcRefresh','ChkOnlyRisky',
                 'ProcStats','GridProc','BtnExtRefresh','BtnExtStore','ExtStats','GridExt','BtnAutoRefresh',
                 'AutoStats','GridAuto','BtnLogRefresh','BtnLogFolder','LogBox','BtnExplorer','BtnWeb','BtnVT',
                 'BtnAsk','BtnCopy','DetailBox','StatusText','Progress',
                 'BtnRunRefresh','BtnProcAudit','ChkRunOnlyBad','RunStats','GridRun',
                 'BtnVtKey','BtnVtScan','BtnVtSite','VtStats',
                 'BtnBaseNew','BtnBaseDiff','BaseStats','BtnProcAudit2','BtnHelp',
                 'BtnKill','BtnQuar','BtnNeutr',
                 'BtnQuarRefresh','BtnQuarRestore','BtnQuarDelete','BtnQuarFolder','QuarStats','GridQuar',
                 'BtnGuardOn','BtnGuardOff','ChkAutoNeutr','GuardStats',
                 'BtnTrust','BtnTrustRefresh','BtnTrustRevoke','TrustStats','GridTrust',
                 'CmbDns','BtnDnsOn','BtnDnsOff','BtnDnsTest','DnsStats',
                 'TitleBar','BtnMinW','BtnMaxW','BtnCloseW','Nav','BtnScanFiles','BtnScanFiles2',
                 'TglAudit','TglGuard','AuditSub',
                 'TglAuto','AutoSub','BtnAutoMore','BtnAutoFix','ProtHead','AutoCount','AutoNeutrState',
                 'GridNet','BtnNetRefresh','ChkNetOnlyBad','NetStats','GridApp','BtnAppRefresh','ChkAppOnlyMarked','AppStats',
                 'BtnDnsMain','BtnDnsMore','BtnAdMore','BtnVtMore','BtnBaseMore','BtnUpdMore','ScaleState','CmbScale','AutoPartsBox','AutoParts','AutoPartsHint',
                 'Inspector','InspKind','InspTitle','BtnInspClose','BtnDiag',
                 'UpdStats','UpdWhere','BtnUpdCheck','BtnUpdInstall','BtnUpdToken',
                 'BtnInspect','FixHead','FixPanel',
                 'NavCol','NavPanel','BtnNavToggle','NavActions','NavActionsMini',
                 'BtnScanMini','BtnScanFilesMini','BtnMonMini','NavHeadWatch','NavHeadAnalyse',
                 'SearchBox','SearchHint','SearchPop','SearchList',
                 'TabFindBad','TabFindCrit','TabFindWarn','TabFindAll',
                 'HeroHead','HeroSub','HeroGo','HeroCrit','HeroWarn','HeroQuar','HeroTotal',
                 'HeroBarCrit','HeroBarWarn','HeroBarRest',
                 'BtnFixAll','BtnFixAll2','BtnExtVerify',
                 'SbAddFiles','SbAddFolder','SbClear','SbDeep','SbCheck','SbDropHint','SbListBox','SbGrid','SbStatus','SbProgress',
                 'CmbLang','LangSub','BtnLangRestart',
                 'AdStats','BtnAdInstall','BtnAdLists','BtnAdFolder')) {
    $ui[$n] = $win.FindName($n)
}

# ------------------------------------------------------------
#  Состояние приложения
# ------------------------------------------------------------
$sync = [hashtable]::Synchronized(@{})
$sync.Queue    = [System.Collections.Queue]::Synchronized((New-Object System.Collections.Queue))
$sync.Stop     = $false
$sync.Running  = $false
$sync.Root     = $PSScriptRoot
$sync.Error    = $null
$sync.Counters = $null
$sync.ScanDone = $false
$sync.ScanStep = ''
$sync.ScanResults = $null
$sync.BgBusy   = $false
$sync.BgDone   = $false
$sync.BgKind   = ''
$sync.BgResult = $null

$app = @{
    MonItems   = New-Object System.Collections.ObjectModel.ObservableCollection[object]
    Findings   = @()
    Procs      = @()
    Exts       = @()
    Autoruns   = @()
    Runs       = @()
    Quar       = @()
    Trust      = @()
    Selected   = $null
    MonRs      = $null
    MonPs      = $null
    ScanRs     = $null
    ScanPs     = $null
    BgRs       = $null
    BgPs       = $null
    LastJump   = $null
    IsAdmin    = (Test-CgAdmin)
    LastScan   = $null
    MonMode    = ''
    Net        = $null
    AppData    = $null
}

$ui.GridMon.ItemsSource = $app.MonItems

# ------------------------------------------------------------
#  Вспомогательное
# ------------------------------------------------------------
function Set-Status { param([string]$T) $ui.StatusText.Text = (T $T) }

function Set-Busy {
    param([bool]$On, [string]$Text = '')
    if ($On) { $ui.Progress.Visibility = 'Visible' } else { $ui.Progress.Visibility = 'Collapsed' }
    if ($Text) { Set-Status $Text }
}

function New-Card {
    param([string]$Title, [string]$Value, [string]$Color = '#ECEFF4', [string]$Sub = '')
    $b = New-Object System.Windows.Controls.Border
    $b.Style = $win.FindResource('Tile')
    $sp = New-Object System.Windows.Controls.StackPanel
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = (T $Title); $t1.FontSize = 11.5
    $t1.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#7C8694'))
    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = (T $Value); $t2.FontSize = 21; $t2.FontWeight = 'SemiBold'; $t2.Margin = '0,6,0,0'
    $t2.TextWrapping = 'Wrap'
    $t2.FontFamily = $win.FindResource('FontDisplay')
    $t2.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($Color))
    $null = $sp.Children.Add($t1); $null = $sp.Children.Add($t2)
    if ($Sub) {
        $t3 = New-Object System.Windows.Controls.TextBlock
        $t3.Text = (T $Sub); $t3.FontSize = 11; $t3.Margin = '0,4,0,0'; $t3.TextWrapping = 'Wrap'
        $t3.FontFamily = $win.FindResource('FontMono')
        $t3.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#7C8694'))
        $null = $sp.Children.Add($t3)
    }
    $b.Child = $sp
    return $b
}

function Update-Cards {
    $ui.Cards.Children.Clear()

    $auditOn = Test-CgAuditEnabled
    if ($auditOn) {
        $null = $ui.Cards.Children.Add((New-Card 'Аудит доступа к файлам' 'включён' '#4ADE80' 'Windows записывает, кто открывает cookie'))
        $ui.ChipAudit.Text = (T 'аудит: вкл')
        $ui.ChipAudit.Foreground = '#4ADE80'
    } else {
        $null = $ui.Cards.Children.Add((New-Card 'Аудит доступа к файлам' 'выключен' '#FF5E5E' 'Без него не видно, кто брал cookie'))
        $ui.ChipAudit.Text = (T 'аудит: выкл')
        $ui.ChipAudit.Foreground = '#FF5E5E'
    }

    # Спрашиваем не только Defender: под сторонним антивирусом Windows
    # штатно держит его выключенным, и красная плитка была бы ложной тревогой.
    $av = Get-CgAntivirusSummary
    switch ($av.State) {
        'Defender' {
            $col = '#4ADE80'; if (-not $av.Fresh) { $col = '#FFB340' }
            $null = $ui.Cards.Children.Add((New-Card 'Антивирус' 'работает' $col ("{0} · базы: {1} дн." -f $av.Name, $av.SignatureAge)))
        }
        'Other' {
            $col = '#4ADE80'; $sub = $av.Name
            if (-not $av.Fresh) { $col = '#FFB340'; $sub += ' · базы устарели' }
            $null = $ui.Cards.Children.Add((New-Card 'Антивирус' 'работает' $col $sub))
        }
        'Off' {
            $sub = 'Включите защиту в реальном времени'
            if ($av.Idle.Count) { $sub = '{0} установлен, но не защищает' -f ($av.Idle -join ', ') }
            $null = $ui.Cards.Children.Add((New-Card 'Антивирус' 'выключен' '#FF5E5E' $sub))
        }
        default {
            $null = $ui.Cards.Children.Add((New-Card 'Антивирус' 'неизвестно' '#7C8694' 'Не удалось опросить Defender'))
        }
    }

    # Исключения — это настройка Defender. Пока защищает другой антивирус,
    # плитку показываем, только если они заданы: с меткой «Defender», чтобы
    # их не приняли за исключения того, кто работает.
    if ($null -ne $av.Exclusions) {
        if ($av.State -eq 'Other') {
            if ($av.Exclusions) { $null = $ui.Cards.Children.Add((New-Card 'Исключения Defender' "$($av.Exclusions)" '#FFB340' 'Defender сейчас в запасе, но эти места он не проверит')) }
        }
        elseif ($av.Exclusions) { $null = $ui.Cards.Children.Add((New-Card 'Исключения антивируса' "$($av.Exclusions)" '#FFB340' 'Эти места Defender не проверяет')) }
        else { $null = $ui.Cards.Children.Add((New-Card 'Исключения антивируса' 'нет' '#4ADE80' '')) }
    }

    $brs = Get-CgBrowsers
    $tf = Get-CgTargetFiles
    $null = $ui.Cards.Children.Add((New-Card 'Под наблюдением' ("{0} файлов" -f $tf.Count) '#ECEFF4' (($brs | ForEach-Object { $_.Name }) -join ', ')))

    $bd = Get-CgBaselineDate
    if ($bd) {
        $null = $ui.Cards.Children.Add((New-Card 'Эталон системы' $bd.ToString('dd.MM.yyyy') '#4ADE80' ('снят в ' + $bd.ToString('HH:mm'))))
    } else {
        $null = $ui.Cards.Children.Add((New-Card 'Эталон системы' 'не снят' '#7C8694' 'Изменения в системе не отслеживаются'))
    }

    if ($app.LastScan) {
        $c = @($app.Findings | Where-Object { $_.Severity -eq 'CRIT' }).Count
        $w = @($app.Findings | Where-Object { $_.Severity -eq 'WARN' }).Count
        $col = '#4ADE80'; if ($w) { $col = '#FFB340' }; if ($c) { $col = '#FF5E5E' }
        $null = $ui.Cards.Children.Add((New-Card 'Последняя проверка' ("{0} критичных, {1} внимание" -f $c, $w) $col $app.LastScan.ToString('dd.MM.yyyy HH:mm')))
    } else {
        $null = $ui.Cards.Children.Add((New-Card 'Последняя проверка' 'не выполнялась' '#7C8694' 'Нажмите «Проверить систему»'))
    }

    Update-CgHero $bd

    if ($app.IsAdmin) { $ui.ChipAdmin.Text = (T 'администратор') } else { $ui.ChipAdmin.Text = (T 'без прав администратора') }
    Sync-CgToggles
}

function Get-CgPlural {
    param([int]$N, [string]$One, [string]$Few, [string]$Many)
    if ($script:CgLang -eq 'en') { if ($N -eq 1) { return (T $One) } return (T $Many) }
    $n10 = $N % 10; $n100 = $N % 100
    if ($n10 -eq 1 -and $n100 -ne 11) { return $One }
    if ($n10 -ge 2 -and $n10 -le 4 -and ($n100 -lt 12 -or $n100 -gt 14)) { return $Few }
    return $Many
}

# Три крупных числа наверху обзора и линейка под ними. Заголовок
# страницы говорит итог словами: «10 критичных находок ждут
# разбора» читается быстрее, чем слово «Обзор» над тремя цифрами.
function Update-CgHero {
    param($BaselineDate)
    $star = [System.Windows.GridUnitType]::Star
    $ui.HeroQuar.Text = "$(@(Get-CgQuarantineList).Count)"

    if (-not $app.LastScan) {
        $ui.HeroCrit.Text = '—'; $ui.HeroWarn.Text = '—'
        $ui.HeroHead.Text = (T 'Обзор')
        $ui.HeroSub.Text  = (T 'Проверки ещё не было — нажмите «Проверить систему».')
        $ui.HeroTotal.Text = (T 'проверки ещё не было')
        $ui.HeroBarCrit.Width = [System.Windows.GridLength]::new(0, $star)
        $ui.HeroBarWarn.Width = [System.Windows.GridLength]::new(0, $star)
        $ui.HeroBarRest.Width = [System.Windows.GridLength]::new(1, $star)
        return
    }

    $c = @($app.Findings | Where-Object { $_.Severity -eq 'CRIT' }).Count
    $w = @($app.Findings | Where-Object { $_.Severity -eq 'WARN' }).Count
    $ui.HeroCrit.Text = "$c"
    $ui.HeroWarn.Text = "$w"

    if ($c) {
        $ui.HeroHead.Text = (T '{0} {1} разбора') -f $c, (Get-CgPlural $c 'критичная находка ждёт' 'критичные находки ждут' 'критичных находок ждут')
    } elseif ($w) {
        $ui.HeroHead.Text = (T 'Критичного нет')
    } else {
        $ui.HeroHead.Text = (T 'Всё чисто')
    }
    $sub = 'Проверка {0} в {1}.' -f $app.LastScan.ToString('dd.MM.yyyy'), $app.LastScan.ToString('HH:mm')
    if ($BaselineDate) { $sub += ' Эталон снят {0} в {1}.' -f $BaselineDate.ToString('dd.MM.yyyy'), $BaselineDate.ToString('HH:mm') }
    $ui.HeroSub.Text = (T $sub)

    $t = $c + $w
    $ui.HeroTotal.Text = '{0} {1}' -f $t, (Get-CgPlural $t 'находка' 'находки' 'находок')
    $rest = 0; if (-not $t) { $rest = 1 }
    $ui.HeroBarCrit.Width = [System.Windows.GridLength]::new($c, $star)
    $ui.HeroBarWarn.Width = [System.Windows.GridLength]::new($w, $star)
    $ui.HeroBarRest.Width = [System.Windows.GridLength]::new($rest, $star)
}

# Разбор выбранной строки живёт в правой полосе и появляется
# только когда есть что разбирать: пустая панель на полэкрана
# занимала бы место и ничего не сообщала.
$script:CgSevMap = @{
    'CRIT' = @('КРИТИЧНО',         '#FF5E5E')
    'WARN' = @('ТРЕБУЕТ ВНИМАНИЯ', '#FFB340')
    'NOTE' = @('ЗАМЕТКА',          '#7CC4FF')
    'OK'   = @('НОРМА',            '#4ADE80')
    'INFO' = @('СВЕДЕНИЯ',         '#7C8694')
}

function Show-Detail {
    param($Item)
    $app.Selected = $Item
    if (-not $Item) {
        $ui.DetailBox.Text = ''
        Show-CgDetailPanel $false
        return
    }

    $title = ''
    if ($Item.PSObject.Properties['Title'] -and $Item.Title) { $title = [string]$Item.Title }
    elseif ($Item.PSObject.Properties['Name']) { $title = [string]$Item.Name }
    $ui.InspTitle.Text = (T $title)

    $sev = ''
    if ($Item.PSObject.Properties['Severity']) { $sev = [string]$Item.Severity }
    $m = $script:CgSevMap[$sev]
    if (-not $m) { $m = @('ПОДРОБНОСТИ', '#7C8694') }
    $ui.InspKind.Text = (T $m[0])
    $ui.InspKind.Foreground = $m[1]

    $ui.DetailBox.Text = (T ("$($Item.Detail)".Trim()))
    Show-CgDetailPanel $true

    # Кнопка, которая ничего не сделает, хуже отсутствующей:
    # гасим то, для чего у этой строки нет данных.
    $path = ''
    if ($Item.PSObject.Properties['Path']) { $path = [string]$Item.Path }
    $isFile = ($path -and (Test-Path -LiteralPath $path -PathType Leaf))
    $procId = 0
    if ($Item.PSObject.Properties['Id']) { $procId = [int]($Item.Id -as [int]) }
    $hasHash = ($Item.PSObject.Properties['Hash'] -and $Item.Hash)

    $ui.BtnExplorer.IsEnabled = [bool]$path
    $ui.BtnVT.IsEnabled       = [bool]($isFile -or $hasHash)
    $ui.BtnKill.IsEnabled     = ($procId -gt 0)
    $ui.BtnQuar.IsEnabled     = [bool]$isFile
    $ui.BtnNeutr.IsEnabled    = (($procId -gt 0) -or $isFile)

    Update-FixButtons $Item
}

# ------------------------------------------------------------
#  «Что исправить» — кнопки под конкретную находку
#
#  Набор действий зависит от того, чем находка является:
#  ключ реестра чинится не так, как запись автозапуска, и уж
#  точно не так, как папка расширения. Поэтому кнопки не
#  прибиты к разметке, а собираются под выбранную строку.
# ------------------------------------------------------------
function Update-FixButtons {
    param($Item)

    $ui.FixPanel.Children.Clear()
    $fixers = @()
    if ($Item) { $fixers = @(Get-CgFixers $Item) }

    if (-not $fixers.Count) {
        $ui.FixHead.Visibility = 'Collapsed'
        return
    }
    $ui.FixHead.Visibility = 'Visible'

    foreach ($fx in $fixers) {
        $b = New-Object System.Windows.Controls.Button
        $b.Content = (T $fx.Button)
        $b.Margin  = '0,0,7,7'
        $b.ToolTip = ((T $fx.Title) + "`n`n" + (T $fx.Explain))
        if ($fx.Risky) { $b.Style = $win.FindResource('Danger') } else { $b.Style = $win.FindResource('Primary') }
        $theItem = $Item
        $theFix  = $fx
        $b.Add_Click({ Invoke-FixFromUi $theItem $theFix }.GetNewClosure())
        $null = $ui.FixPanel.Children.Add($b)
    }
}

# Показать план, спросить, выполнить. Именно в этом порядке:
# инструмент безопасности не правит реестр молча.
function Invoke-FixFromUi {
    param($Finding, $Fixer)

    $plan = @(Get-CgFixPlan $Finding $Fixer)
    if (-not $plan.Count) {
        $null = Show-CgDialog -Title 'Нечего исправлять' -Text 'Похоже, это уже исправлено.' -Kind 'ok'
        Update-FixButtons $Finding
        return
    }

    $lines = @()
    foreach ($s in $plan) {
        $t = "$($s.Text)"
        if ($s.Target) { $t += ": $($s.Target)" }
        if ($s.From -or $s.To) { $t += "   $($s.From) -> $($s.To)" }
        $lines += $t
    }
    $shown = @($lines | Select-Object -First 14)
    $subject = ($shown -join "`n")
    if ($lines.Count -gt $shown.Count) { $subject += "`n… и ещё $($lines.Count - $shown.Count)" }

    $kind = 'question'
    if ($Fixer.Risky) { $kind = 'warn' }
    if (-not (Confirm-CgDialog -Title $Fixer.Title -Text $Fixer.Explain -Subject $subject `
                -Kind $kind -Yes $Fixer.Button -Dangerous:([bool]$Fixer.Risky))) {
        Set-Status 'Исправление отменено'
        return
    }

    Set-Busy $true 'Исправляю...'
    $res = Invoke-CgFix $Finding $Fixer
    Set-Busy $false

    if (-not $res.Ok) {
        $null = Show-CgDialog -Title 'Не исправлено' -Text $res.Message -Kind 'danger'
        Set-Status 'Исправить не удалось'
        return
    }

    $txt = "$($res.Message)"
    if ($res.Undo) { $txt += "`n`nЭто обратимо: запись отката $($res.Undo.Id) лежит в папке undo рядом с журналами." }
    $null = Show-CgDialog -Title 'Исправлено' -Text $txt -Kind 'ok'
    Set-Status "$($res.Message)"
    Update-FixButtons $Finding
    Update-Cards
}

function Get-SelPath {
    if (-not $app.Selected) { return '' }
    if ($app.Selected.PSObject.Properties['Path']) { return [string]$app.Selected.Path }
    return ''
}

function Open-External {
    param([string]$Url)
    try { Start-Process $Url } catch { Set-Status "Не удалось открыть ссылку: $_" }
}

# ------------------------------------------------------------
#  Кнопки действий
# ------------------------------------------------------------
$ui.BtnExplorer.Add_Click({
    $p = Get-SelPath
    if (-not $p) { Set-Status 'У выбранной строки нет пути к файлу'; return }
    if (Test-Path -LiteralPath $p) {
        Start-Process explorer.exe "/select,`"$p`""
        Set-Status "Открыто в проводнике: $p"
    } else {
        $dir = Split-Path -Parent $p
        if ($dir -and (Test-Path -LiteralPath $dir)) { Start-Process explorer.exe "`"$dir`""; Set-Status "Файла нет, открыта папка: $dir" }
        else { Set-Status "Путь не найден: $p" }
    }
})

# Собирает ОСМЫСЛЕННЫЙ поисковый запрос, а не два слова.
# Отпечаток ищется первым: по нему находят конкретный образец,
# а не однофамильцев. Дальше имя файла, издатель и ключевые приметы.
function Build-SearchQuery {
    $s = $app.Selected
    if (-not $s) { return '' }
    $parts = New-Object System.Collections.ArrayList

    $path = Get-SelPath
    $leaf = ''
    if ($path) { $leaf = Split-Path -Leaf $path }
    $hash = ''
    if ($s.PSObject.Properties['Hash']) { $hash = [string]$s.Hash }
    if (-not $hash -and $path -and (Test-Path -LiteralPath $path -PathType Leaf)) { $hash = Get-CgHash $path }

    if ($hash) { $null = $parts.Add($hash) }
    if ($leaf) { $null = $parts.Add('"' + $leaf + '"') }

    # издатель из подписи — отсекает однофамильцев
    if ($s.PSObject.Properties['Signature'] -and $s.Signature) {
        $sg = [string]$s.Signature -replace '^(Valid|NotSigned|UnknownError|Error)\s*', ''
        if ($sg.Trim()) { $null = $parts.Add('"' + $sg.Trim() + '"') }
    }
    # для расширений браузера — идентификатор, он уникален
    if ($s.PSObject.Properties['Id'] -and "$($s.Id)" -match '^[a-p]{32}$') {
        $null = $parts.Add("chrome extension $($s.Id)")
    }
    if (-not $parts.Count) {
        $t = ''
        if ($s.PSObject.Properties['Query']) { $t = [string]$s.Query }
        if (-not $t) { $t = [string]$s.Title }
        $null = $parts.Add($t)
    }
    $null = $parts.Add('malware OR вирус OR "что за процесс"')
    return (($parts | Where-Object { $_ }) -join ' ')
}

$ui.BtnWeb.Add_Click({
    if (-not $app.Selected) { Set-Status 'Сначала выберите строку'; return }
    $q = Build-SearchQuery
    if (-not $q) { Set-Status 'Нечего искать'; return }
    $menu = New-Object System.Windows.Controls.ContextMenu
    foreach ($eng in @(
        @{ N = 'Google'; U = 'https://www.google.com/search?q=' },
        @{ N = 'Яндекс'; U = 'https://yandex.ru/search/?text=' },
        @{ N = 'DuckDuckGo'; U = 'https://duckduckgo.com/?q=' })) {
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = $eng.N
        $url = $eng.U + [uri]::EscapeDataString($q)
        $mi.Add_Click({ Open-External $url }.GetNewClosure())
        $null = $menu.Items.Add($mi)
    }
    $mi2 = New-Object System.Windows.Controls.MenuItem
    $mi2.Header = (T 'Скопировать запрос')
    $mi2.Add_Click({ Set-Clipboard -Value $q; Set-Status 'Запрос скопирован' }.GetNewClosure())
    $null = $menu.Items.Add($mi2)
    $menu.PlacementTarget = $ui.BtnWeb
    $menu.IsOpen = $true
    Set-Status ("Запрос: " + $q)
})

$ui.BtnVT.Add_Click({
    if (-not $app.Selected) { return }
    $h = ''
    if ($app.Selected.PSObject.Properties['Hash']) { $h = [string]$app.Selected.Hash }
    if (-not $h) {
        $p = Get-SelPath
        if ($p -and (Test-Path -LiteralPath $p)) {
            Set-Busy $true 'Считаю SHA256...'
            $h = Get-CgHash $p
            Set-Busy $false
        }
    }
    if (-not $h) { Set-Status 'Не удалось получить хеш — у строки нет файла на диске'; return }

    # есть ключ — спрашиваем вердикт прямо здесь и запоминаем его;
    # нет ключа — просто открываем страницу в браузере
    $key = Get-CgVtKey
    if (-not $key) {
        Open-External ('https://www.virustotal.com/gui/file/' + $h)
        Set-Status "Открыт VirusTotal по отпечатку: $h"
        return
    }
    Set-Busy $true 'Спрашиваю VirusTotal...'
    $cache = Get-CgVtCache
    $v = $null
    if ($cache.ContainsKey($h)) { $v = $cache[$h] }
    if (-not $v) {
        $v = Invoke-CgVtLookup -Hash $h -Key $key
        if ($v -and $v.Status -notin @('badkey', 'error')) { $cache[$h] = $v; Save-CgVtCache $cache; Update-VtStats }
    }
    Set-Busy $false
    if (-not $v) { Set-Status 'VirusTotal не ответил'; return }
    switch ($v.Status) {
        'badkey'    { Set-Status 'VirusTotal не принял ключ — задайте его заново в разделе «Защита»' }
        'ratelimit' { Set-Status 'Превышен предел запросов VirusTotal, попробуйте через минуту' }
        'unknown'   {
            $ui.DetailBox.Text = $ui.DetailBox.Text + (T "`n`n--- VirusTotal ---`nЭтот файл VirusTotal неизвестен.`nSHA256: $h`n`nЗначит, он редкий. Для самодельного файла это норма, для скачанной программы — повод задуматься.")
            Set-Status 'VirusTotal: файл неизвестен'
        }
        'known'     {
            $pct = Get-CgVtRiskPercent $v
            $ui.DetailBox.Text = $ui.DetailBox.Text + (T "`n`n--- VirusTotal ---`nВредоносным считают: $($v.Malicious) из $($v.Total) ($pct%)`nПодозрительным: $($v.Suspicious)`n$(if($v.Label){"Классификация: $($v.Label)`n"})SHA256: $h`nОтчёт: https://www.virustotal.com/gui/file/$h")
            Set-Status ("VirusTotal: {0} из {1} движков считают файл вредоносным" -f $v.Malicious, $v.Total)
        }
        default     { Set-Status "VirusTotal: $($v.Label)" }
    }
})

$ui.BtnAsk.Add_Click({
    if (-not $app.Selected) { return }
    $s = $app.Selected
    $title = ''
    if ($s.PSObject.Properties['Title'] -and $s.Title) { $title = $s.Title } elseif ($s.PSObject.Properties['Name']) { $title = $s.Name }
    $q = T @"
Разбираю находку на своём компьютере с Windows. Объясни простыми словами, опасно ли это и что делать.

Находка: $title
Уровень: $($s.Severity)
Путь: $(Get-SelPath)
SHA256: $(if ($s.PSObject.Properties['Hash']) { $s.Hash } else { '' })

Подробности:
$($s.Detail)
"@
    # Передаём вопрос вместе с данными прямо в адресе, а не просто
    # открываем сайт. В адрес влезает не всё: длинные адреса браузеры
    # и сервер режут, поэтому в ссылку кладём суть, а полный текст —
    # в буфер обмена, чтобы ничего не потерялось.
    $maxUrl = 6000
    $short = $q
    if ($short.Length -gt $maxUrl) {
        $short = $short.Substring(0, $maxUrl) + (T "`n`n[...текст обрезан для ссылки. Полная версия — в буфере обмена, вставьте Ctrl+V]")
    }
    try { Set-Clipboard -Value $q } catch { }

    $menu = New-Object System.Windows.Controls.ContextMenu
    $targets = @(
        @{ N = 'Claude'; U = 'https://claude.ai/new?q=' },
        @{ N = 'ChatGPT'; U = 'https://chatgpt.com/?q=' },
        @{ N = 'Perplexity'; U = 'https://www.perplexity.ai/search?q=' }
    )
    foreach ($t in $targets) {
        $mi = New-Object System.Windows.Controls.MenuItem
        $mi.Header = $t.N
        $url = $t.U + [uri]::EscapeDataString($short)
        $mi.Add_Click({ Open-External $url; Set-Status 'Вопрос передан вместе с данными. Полный текст также в буфере (Ctrl+V).' }.GetNewClosure())
        $null = $menu.Items.Add($mi)
    }
    $mi2 = New-Object System.Windows.Controls.MenuItem
    $mi2.Header = (T 'Только скопировать вопрос')
    $mi2.Add_Click({ Set-Status 'Вопрос с подробностями скопирован в буфер' }.GetNewClosure())
    $null = $menu.Items.Add($mi2)
    $menu.PlacementTarget = $ui.BtnAsk
    $menu.IsOpen = $true
})

$ui.BtnCopy.Add_Click({
    if (-not $ui.DetailBox.Text) { return }
    try { Set-Clipboard -Value $ui.DetailBox.Text; Set-Status 'Подробности скопированы в буфер' } catch { }
})

# ----- доверие -----
function Refresh-Trust {
    $app.Trust = @(Get-CgTrustView)
    $ui.GridTrust.ItemsSource = $app.Trust
    $ui.TrustStats.Text = ((T "доверенных записей: {0}") -f $app.Trust.Count)
}

# Доверие: выбор области вынесен в общее окно — одно и то же
# и здесь, и в окне проверки файлов.
function Invoke-CgTrustSelected {
    $s = $app.Selected
    if (-not $s) { Set-Status 'Сначала выберите строку'; return }

    $r = Invoke-CgTrustRow $s
    if (-not $r) { Set-Status 'Отменено'; return }
    if (-not $r.Ok) {
        $null = Show-CgDialog -Title 'Не удалось добавить в доверенные' -Text $r.Message -Kind 'warn'
        return
    }

    Set-Status $r.Message
    Reset-CgTrustCache
    Refresh-Trust
    Update-CgAfterTrust
}

# ------------------------------------------------------------
#  После «Доверять»: убрать доверенное отовсюду, сразу
#
#  Раньше после доверия заново собирался только список процессов,
#  и то в фоне: в находках строка оставалась, монитор продолжал
#  показывать старые события, а соседний процесс той же программы
#  с другим номером никуда не девался. Человек жал «Проверить
#  систему» ещё раз, чтобы увидеть, что доверие сработало.
#  Теперь каждая уже собранная таблица перепроверяется на месте:
#  подписи берутся из кеша, поэтому это быстро.
# ------------------------------------------------------------
function Test-CgRowTrusted {
    param($Row)
    if (-not $Row) { return $null }
    $path = ''; $hash = ''; $pp = ''; $pn = ''; $anc = @()
    if ($Row.PSObject.Properties['Path'])       { $path = [string]$Row.Path }
    if ($Row.PSObject.Properties['Hash'])       { $hash = [string]$Row.Hash }
    if ($Row.PSObject.Properties['ParentPath']) { $pp = [string]$Row.ParentPath }
    if ($Row.PSObject.Properties['ParentName']) { $pn = [string]$Row.ParentName }
    if ($Row.PSObject.Properties['Ancestors'])  { $anc = @($Row.Ancestors) }
    if ($Row.PSObject.Properties['ExtKey'] -and $Row.ExtKey) {
        $t = Test-CgTrusted 'extension' ([string]$Row.ExtKey)
        if ($t) { return $t }
    }
    if ($path -and (Test-Path -LiteralPath $path -PathType Leaf)) {
        return (Test-CgTrustedFile $path $hash $pp $pn $anc)
    }
    return $null
}

function Update-CgAfterTrust {
    if ($app.Findings.Count) {
        $app.Findings = @(Set-CgTrustOnFindings $app.Findings)
        Show-Findings
    }
    if ($app.Procs.Count) {
        foreach ($p in $app.Procs) {
            if ($p.Severity -eq 'OK') { continue }
            $t = Test-CgRowTrusted $p
            if ($t) {
                $p.Severity = 'OK'; $p.Order = 3
                $p.Notes = 'ДОВЕРЕНО ВАМИ' + $(if ($t.Note) { ": $($t.Note)" } else { '' })
                $p.Risk = 0
            }
        }
        Show-Procs
    }
    if ($app.Exts.Count) {
        foreach ($e in $app.Exts) {
            if ($e.Severity -eq 'OK') { continue }
            if (Test-CgTrusted 'extension' ("$($e.Browser)|$($e.Id)")) { $e.Severity = 'OK'; $e.Order = 3; $e.Verify = 'доверено вами' }
        }
        Show-Exts
    }
    if ($app.Runs.Count) {
        foreach ($r in $app.Runs) {
            if ($r.Severity -in @('OK', 'INFO')) { continue }
            if (Test-CgRowTrusted $r) { $r.Severity = 'INFO'; $r.Order = 3 }
        }
        Show-Runs
    }
    # монитор: доверенные события просто уходят из ленты
    for ($i = $app.MonItems.Count - 1; $i -ge 0; $i--) {
        $m = $app.MonItems[$i]
        if ($m.Severity -in @('CRIT', 'WARN') -and (Test-CgRowTrusted $m)) { $app.MonItems.RemoveAt($i) }
    }
    if ($script:CgScan) {
        foreach ($r in $script:CgScan.Items) {
            if ($r.Severity -eq 'OK') { continue }
            if (Test-CgRowTrusted $r) { $r.Severity = 'OK'; $r.Verdict = 'доверено вами'; $r.Check = $false }
        }
        $ui.SbGrid.Items.Refresh()
    }
    # строка, которой только что доверились, больше не выбрана
    Show-Detail $null
}

$ui.BtnTrust.Add_Click({ Invoke-CgTrustSelected })

$ui.BtnTrustRefresh.Add_Click({ Refresh-Trust })
$ui.BtnTrustRevoke.Add_Click({
    $s = $ui.GridTrust.SelectedItem
    if (-not $s) { Set-Status 'Выберите запись'; return }
    if (-not (Confirm-CgDialog -Title 'Снять доверие?' -Text 'Запись снова начнёт попадать в находки.' `
                -Subject "$($s.Name) — $($s.Covers)" -Kind 'question' -Yes 'Снять' -Dangerous)) { return }
    $res = Remove-CgTrust -Type $s.Type -Key $s.Key
    Set-Status $res.Message
    Refresh-Trust
})

# ----- безопасный сёрфинг через фильтрующий DNS -----
function Update-DnsStats {
    # @() обязательно: при одном сетевом подключении PowerShell разворачивает
    # массив в одиночный объект, и .Count становится пустым
    $st = @(Get-CgDnsState)
    if (-not $st.Count) { $ui.DnsStats.Text = (T 'сетевых подключений не найдено'); return }
    $on = @($st | Where-Object { $_.Filtering })
    if ($on.Count -eq $st.Count) {
        $ui.DnsStats.Text = (T "включён: $($on[0].Profile.Name -replace ' —.*','')")
        $ui.DnsStats.Foreground = 'LightGreen'
    } elseif ($on.Count) {
        $ui.DnsStats.Text = (T "включён частично ($($on.Count) из $($st.Count))")
        $ui.DnsStats.Foreground = '#FFB340'
    } else {
        $ui.DnsStats.Text = (T "выключен (сейчас: $($st[0].ServersText))")
        $ui.DnsStats.Foreground = '#7C8694'
    }
}

$ui.BtnDnsOn.Add_Click({
    $sel = $ui.CmbDns.SelectedItem
    if (-not $sel) { Set-Status 'Выберите набор DNS'; return }
    $prof = $sel.Tag
    if (-not (Confirm-CgDialog -Title 'Включить безопасный сёрфинг?' `
                -Text 'Вредоносные домены перестанут разрешаться в адрес — во всей системе. Прежние настройки сохранятся, кнопка «Вернуть» их восстановит.' `
                -Subject "$($prof.Name)  —  $($prof.Servers -join ', ')" -Kind 'question' -Yes 'Включить')) { return }
    Set-Busy $true 'Переключаю DNS...'
    $res = Set-CgSafeDns -ProfileId $prof.Id
    Set-Busy $false $res.Message
    Update-DnsStats
})

$ui.BtnDnsOff.Add_Click({
    Set-Busy $true 'Возвращаю DNS...'
    $res = Reset-CgSafeDns
    Set-Busy $false $res.Message
    Update-DnsStats
})

$ui.BtnDnsTest.Add_Click({
    Set-Busy $true 'Проверяю фильтрацию...'
    $r = Test-CgDnsFiltering
    Set-Busy $false
    $ui.DetailBox.Text = (T "--- Проверка безопасного сёрфинга ---`n`n") + (T $r.Message)
    if ($r.Working) { Set-Status 'Фильтрация работает' } else { Set-Status 'Фильтрация НЕ обнаружена — подробности ниже' }
})

# ----- уведомления Windows из окна -----
$script:TrayIcon = $null
function Show-CgNotify {
    param([string]$Title, [string]$Text, [string]$Level = 'WARN')
    try {
        if (-not $script:TrayIcon) {
            $script:TrayIcon = New-Object System.Windows.Forms.NotifyIcon
            $script:TrayIcon.Icon = [System.Drawing.SystemIcons]::Shield
            $icoFile = Join-Path $PSScriptRoot 'CookieGuard.ico'
            if (Test-Path -LiteralPath $icoFile) { try { $script:TrayIcon.Icon = New-Object System.Drawing.Icon $icoFile } catch { } }
            $script:TrayIcon.Text = 'CookieGuard'
            $script:TrayIcon.Visible = $true
            # клик по уведомлению поднимает окно
            $script:TrayIcon.Add_BalloonTipClicked({ $win.Activate() | Out-Null })
        }
        $ico = [System.Windows.Forms.ToolTipIcon]::Warning
        if ($Level -eq 'CRIT') { $ico = [System.Windows.Forms.ToolTipIcon]::Error }
        $script:TrayIcon.ShowBalloonTip(10000, (T $Title), (T $Text), $ico)
    } catch { }
}

# ----- активные действия: завершить / карантин / обезвредить -----
function Get-SelPid {
    if (-not $app.Selected) { return 0 }
    foreach ($prop in @('Id', 'ProcId', 'Pid')) {
        if ($app.Selected.PSObject.Properties[$prop]) {
            $v = $app.Selected.$prop
            if ($v -and [int]$v -gt 0) { return [int]$v }
        }
    }
    return 0
}

$ui.BtnKill.Add_Click({
    $procId = Get-SelPid
    if ($procId -le 0) { Set-Status 'У выбранной строки нет процесса с PID'; return }
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$procId" -ErrorAction SilentlyContinue
    if (-not $p) { Set-Status 'Процесс уже не работает'; return }
    if (-not (Confirm-CgDialog -Title 'Завершить процесс и все дочерние?' `
                -Text 'Несохранённые данные этой программы пропадут.' `
                -Subject "$($p.Name)  (PID $procId)`n$($p.ExecutablePath)" -Kind 'warn' -Yes 'Завершить' -Dangerous)) { return }
    $res = Stop-CgProcessTree -ProcId $procId -Reason 'вручную из окна'
    Set-Status $res.Message
    if ($res.Ok) { Refresh-Procs }
})

$ui.BtnQuar.Add_Click({
    $path = Get-SelPath
    if (-not $path) { Set-Status 'У выбранной строки нет файла'; return }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { Set-Status 'Файл не найден на диске'; return }
    $txt = 'Файл будет обратимо спрятан. Вернуть его можно в разделе «Карантин».'
    $kind = 'warn'
    if (Test-CgSystemPath $path) {
        $txt = 'Это системная папка Windows. Изъятие настоящего системного файла нарушит работу системы — убедитесь, что файл лишний.'
        $kind = 'danger'
    }
    if (-not (Confirm-CgDialog -Title 'Отправить файл в карантин?' -Text $txt -Subject $path `
                -Kind $kind -Yes 'В карантин' -Dangerous)) { return }
    Set-Busy $true 'Отправляю в карантин...'
    $hash = ''
    if ($app.Selected.PSObject.Properties['Hash']) { $hash = [string]$app.Selected.Hash }
    $res = Invoke-CgQuarantine -Path $path -Reason 'вручную из окна' -Hash $hash
    Set-Busy $false $res.Message
    if ($res.Ok) { Refresh-Quar }
})

$ui.BtnNeutr.Add_Click({
    $procId = Get-SelPid
    $path = Get-SelPath
    if ($procId -le 0 -and -not $path) { Set-Status 'Нужен процесс или файл'; return }
    if (-not (Confirm-CgDialog -Title 'Завершить процесс и изъять файл?' `
                -Text 'Карантин обратим: файл можно будет вернуть.' `
                -Subject "PID $procId`n$path" -Kind 'danger' -Yes 'Обезвредить' -Dangerous)) { return }
    Set-Busy $true 'Обезвреживаю...'
    $hash = ''
    if ($app.Selected.PSObject.Properties['Hash']) { $hash = [string]$app.Selected.Hash }
    $res = Invoke-CgNeutralize -ProcId $procId -Path $path -Reason 'обезврежено вручную' -Hash $hash
    Set-Busy $false $res.Message
    Refresh-Procs; Refresh-Quar
})

# ----- вкладка Карантин -----
function Refresh-Quar {
    $app.Quar = @(Get-CgQuarantineList)
    $ui.GridQuar.ItemsSource = $app.Quar
    $ui.QuarStats.Text = ((T "в карантине: {0}") -f $app.Quar.Count)
}
$ui.BtnQuarRefresh.Add_Click({ Refresh-Quar })
$ui.BtnQuarFolder.Add_Click({ Start-Process explorer.exe (Get-CgQuarantineDir) })
$ui.BtnQuarRestore.Add_Click({
    $s = $ui.GridQuar.SelectedItem
    if (-not $s) { Set-Status 'Выберите запись в карантине'; return }
    if (-not (Confirm-CgDialog -Title 'Вернуть файл на прежнее место?' `
                -Text 'Если это была угроза — она снова станет активной.' `
                -Subject $s.OriginalPath -Kind 'warn' -Yes 'Вернуть' -Dangerous)) { return }
    $res = Restore-CgQuarantine -Id $s.Id
    Set-Status $res.Message
    Refresh-Quar
})
$ui.BtnQuarDelete.Add_Click({
    $s = $ui.GridQuar.SelectedItem
    if (-not $s) { Set-Status 'Выберите запись в карантине'; return }
    if (-not (Confirm-CgDialog -Title 'Удалить насовсем?' `
                -Text 'Это необратимо: восстановить файл будет нельзя.' `
                -Subject $s.OriginalName -Kind 'danger' -Yes 'Удалить' -Dangerous)) { return }
    $res = Remove-CgQuarantine -Id $s.Id
    Set-Status $res.Message
    Refresh-Quar
})

# ----- постоянный сторож -----
function Update-GuardStats {
    $t = Get-ScheduledTask -TaskName 'CookieGuard Watcher' -ErrorAction SilentlyContinue
    if ($t) {
        $live = Test-CgGuardAlive
        if ($live) { $ui.GuardStats.Text = (T 'установлен, работает'); $ui.GuardStats.Foreground = 'LightGreen' }
        else { $ui.GuardStats.Text = (T 'установлен (сердцебиения пока нет)'); $ui.GuardStats.Foreground = '#FFB340' }
    } else {
        $ui.GuardStats.Text = (T 'не установлен — защита только при открытом окне')
        $ui.GuardStats.Foreground = '#7C8694'
    }
    Sync-CgToggles
}
$ui.BtnGuardOn.Add_Click({
    $auto = [bool]$ui.ChkAutoNeutr.IsChecked
    $autoLine = ''
    if ($auto) { $autoLine = "`n`nАвто-карантин ВКЛЮЧЁН: файлы, которые VirusTotal уже знает как вредоносные (5+ детектов), будут изыматься без вопросов. Остальное — только с вашего подтверждения." }
    $txt = 'Сторож будет стартовать вместе с Windows и работать в фоне. Это не драйвер ядра: противник с правами SYSTEM сможет его снести.'
    if ($auto) { $txt += ' Авто-карантин включён — подтверждённое вредоносное изымается без вопросов.' }
    if (-not (Confirm-CgDialog -Title 'Включить постоянную защиту?' -Text $txt -Kind 'question' -Yes 'Включить')) { return }
    Set-Busy $true 'Устанавливаю сторожа...'
    $extra = @()
    if ($auto) { $extra = @('-AutoNeutralize') }
    # через общий запуск: он читает код возврата и показывает причину,
    # а не рапортует об успехе вслепую
    $null = Invoke-AuditScript 'Install-Guard.ps1' 'Включение постоянной защиты' $extra
    Set-Busy $false
    Update-GuardStats
})
$ui.BtnGuardOff.Add_Click({
    Set-Busy $true 'Снимаю сторожа...'
    $null = Invoke-AuditScript 'Uninstall-Guard.ps1' 'Выключение постоянной защиты'
    Set-Busy $false
    Update-GuardStats
})

# ------------------------------------------------------------
#  Выбор строки в любой таблице
# ------------------------------------------------------------
foreach ($g in @($ui.GridMon, $ui.GridFind, $ui.GridProc, $ui.GridExt, $ui.GridAuto, $ui.GridRun, $ui.GridQuar, $ui.GridTrust, $ui.SbGrid, $ui.GridNet, $ui.GridApp)) {
    $g.Add_SelectionChanged({ Show-Detail $this.SelectedItem })
}

# ------------------------------------------------------------
#  Монитор
# ------------------------------------------------------------
# Монитор окна работает в одном из двух режимов.
#
# Сторож жив — окно не опрашивает систему само, а читает летопись
# сторожа (logs\events-*.jsonl) вживую. Один источник правды: нет
# двойных тревог, и то, что сторож увидел, пока окно было закрыто,
# уже лежит в списке.
#
# Сторожа нет — окно опрашивает само и само ведёт летопись.
$monScript = {
    param($sync)
    try {
        . (Join-Path $sync.Root 'lib\Core.ps1')
        . (Join-Path $sync.Root 'lib\Checks.ps1')
        . (Join-Path $sync.Root 'lib\Trust.ps1')
        . (Join-Path $sync.Root 'lib\Hosts.ps1')
        . (Join-Path $sync.Root 'lib\Monitor.ps1')
        . (Join-Path $sync.Root 'lib\Protect.ps1')
        $state = $null
        $tail = $null
        $cnt = [PSCustomObject]@{ Crit = 0; Warn = 0; Note = 0; Ok = 0; Events = 0 }
        $lastCheck = [datetime]::MinValue
        $guard = $false
        while (-not $sync.Stop) {
            # Читать летопись сторожа можно, только если он её ведёт:
            # старый сторож отмечается «жив», но летописи не пишет
            if (((Get-Date) - $lastCheck).TotalSeconds -ge 10) { $guard = Test-CgGuardCurrent; $lastCheck = Get-Date }
            try {
                if ($guard) {
                    $sync.Mode = 'guard'
                    $state = $null
                    if (-not $tail) { $tail = New-CgEventTail }
                    foreach ($e in (Read-CgEventTail $tail)) {
                        $cnt.Events++
                        switch ($e.Severity) { 'CRIT' { $cnt.Crit++ } 'WARN' { $cnt.Warn++ } 'NOTE' { $cnt.Note++ } default { $cnt.Ok++ } }
                        $sync.Queue.Enqueue($e)
                    }
                    $sync.Counters = $cnt
                    Start-Sleep -Milliseconds 1000
                } else {
                    $sync.Mode = 'self'
                    $tail = $null
                    if (-not $state) { $state = New-CgMonitorState -Persist }
                    foreach ($e in (Invoke-CgMonitorPoll $state -Source 'window')) {
                        $cnt.Events++
                        switch ($e.Severity) { 'CRIT' { $cnt.Crit++ } 'WARN' { $cnt.Warn++ } 'NOTE' { $cnt.Note++ } default { $cnt.Ok++ } }
                        $sync.Queue.Enqueue($e)
                    }
                    $sync.Counters = $cnt
                    Start-Sleep -Milliseconds 1500
                }
            } catch {
                $sync.Error = $_.ToString()
                Start-Sleep -Milliseconds 1500
            }
        }
    } catch {
        $sync.Error = $_.ToString()
    } finally {
        $sync.Running = $false
    }
}

function Set-CgMonChip {
    if (-not $sync.Running) {
        $ui.ChipMon.Text = (T 'монитор: остановлен'); $ui.ChipMon.Foreground = '#7C8694'
    } elseif ($sync.Mode -eq 'guard') {
        $ui.ChipMon.Text = (T 'монитор: от сторожа'); $ui.ChipMon.Foreground = '#4ADE80'
    } else {
        $ui.ChipMon.Text = (T 'монитор: работает'); $ui.ChipMon.Foreground = '#4ADE80'
    }
}

function Start-Monitor {
    param([switch]$Remember)
    if ($Remember) { $null = Set-CgSetting 'MonitorOn' $true }
    if ($sync.Running) { return }
    $sync.Stop = $false
    $sync.Error = $null
    $sync.Running = $true
    $sync.Mode = ''

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'MTA'
    $rs.ThreadOptions = 'ReuseThread'
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $null = $ps.AddScript($monScript).AddArgument($sync)
    $null = $ps.BeginInvoke()
    $app.MonRs = $rs; $app.MonPs = $ps

    $ui.BtnMon.Content  = (T 'Остановить монитор')
    $ui.BtnMon2.Content = (T 'Остановить монитор')
    Set-CgMonChip
    if (-not (Test-CgAuditEnabled)) {
        Set-Status 'Монитор запущен. Аудит выключен — обращения к cookie видны не будут, включите автозащиту в разделе «Защита».'
    } else {
        Set-Status 'Монитор запущен — наблюдаю за обращениями к cookie, запуском программ, hosts и сетью.'
    }
    Write-CgLog 'INFO' 'Монитор запущен из окна'
}

# -Remember: остановил человек — значит, и при следующем запуске окна
# монитор включать не надо. Закрытие окна выбор не меняет.
function Stop-Monitor {
    param([switch]$Remember)
    if ($Remember) { $null = Set-CgSetting 'MonitorOn' $false }
    if (-not $sync.Running -and -not $app.MonPs) { return }
    $sync.Stop = $true
    try { if ($app.MonPs) { $null = $app.MonPs.Stop(); $app.MonPs.Dispose() } } catch { }
    try { if ($app.MonRs) { $app.MonRs.Close(); $app.MonRs.Dispose() } } catch { }
    $app.MonPs = $null; $app.MonRs = $null
    $sync.Running = $false
    $ui.BtnMon.Content  = (T 'Запустить монитор')
    $ui.BtnMon2.Content = (T 'Запустить монитор')
    Set-CgMonChip
    Set-Status 'Монитор остановлен.'
    Write-CgLog 'INFO' 'Монитор остановлен'
}

$toggleMon = { if ($sync.Running) { Stop-Monitor -Remember } else { Start-Monitor -Remember } }
$ui.BtnMon.Add_Click($toggleMon)
$ui.BtnMon2.Add_Click($toggleMon)
$ui.BtnMonClear.Add_Click({ $app.MonItems.Clear(); Set-Status 'Список событий очищен' })

# ------------------------------------------------------------
#  Сканирование
# ------------------------------------------------------------
$scanScript = {
    param($sync)
    try {
        . (Join-Path $sync.Root 'lib\Core.ps1')
        . (Join-Path $sync.Root 'lib\Checks.ps1')
        . (Join-Path $sync.Root 'lib\Trust.ps1')
        $res = Invoke-CgFullScan -Progress { param($t) $sync.ScanStep = $t }
        $sync.ScanResults = @($res)
    } catch {
        $sync.Error = $_.ToString()
        $sync.ScanResults = @()
    } finally {
        $sync.ScanDone = $true
    }
}

function Start-Scan {
    if ($ui.Progress.Visibility -eq 'Visible') { return }
    $sync.ScanDone = $false; $sync.ScanResults = $null; $sync.ScanStep = 'запуск'
    $ui.BtnScan.IsEnabled = $false; $ui.BtnScan2.IsEnabled = $false
    Set-Busy $true 'Проверяю систему...'

    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'MTA'
    $rs.ThreadOptions = 'ReuseThread'
    $rs.Open()
    $ps = [powershell]::Create()
    $ps.Runspace = $rs
    $null = $ps.AddScript($scanScript).AddArgument($sync)
    $null = $ps.BeginInvoke()
    $app.ScanRs = $rs; $app.ScanPs = $ps
}

function Show-Findings {
    $src = $app.Findings
    # Галочка умела два состояния, а нужны четыре: после проверки
    # первый вопрос — «покажи только критичное», и ответом на него
    # галочка быть не может.
    if ($ui.TabFindCrit.IsChecked)     { $src = $src | Where-Object { $_.Severity -eq 'CRIT' } }
    elseif ($ui.TabFindWarn.IsChecked) { $src = $src | Where-Object { $_.Severity -eq 'WARN' } }
    elseif ($ui.TabFindBad.IsChecked)  { $src = $src | Where-Object { $_.Severity -in @('CRIT', 'WARN', 'NOTE') } }
    $ui.GridFind.ItemsSource = @($src | Sort-Object Order, Area, Title)
    $c = @($app.Findings | Where-Object { $_.Severity -eq 'CRIT' }).Count
    $w = @($app.Findings | Where-Object { $_.Severity -eq 'WARN' }).Count
    $n = @($app.Findings | Where-Object { $_.Severity -eq 'NOTE' }).Count
    $ui.ScanStats.Text = (T "критично: $c    внимание: $w    заметки: $n    всего проверок: $($app.Findings.Count)")
    Update-CgFixAllButton
}

# ------------------------------------------------------------
#  «Исправить всё»
#
#  Одно окно со списком всего, что программа умеет исправить сама,
#  — вместо того чтобы открывать каждую находку и жать кнопку в
#  ней. Каждой находке подбирается одно исправление: обратимое и
#  самое узкое из подходящих. «Опасные» (в карантин, удалить)
#  в список не попадают — их делают по одной, глядя на находку.
#  Одинаковые исправления сливаются: «PlayerDebugMode во всех
#  версиях Adobe» встаёт одной строкой, а не восемнадцатью.
# ------------------------------------------------------------
function Get-CgFixAllPlan {
    $out = @()
    $seen = @{}
    foreach ($f in @($app.Findings | Where-Object { $_.Severity -in @('CRIT', 'WARN') } | Sort-Object Order)) {
        $fx = @(Get-CgFixers $f | Where-Object { -not $_.Risky })
        if (-not $fx.Count) { continue }
        $all = @($fx | Where-Object { $_.Id -like '*-all' })
        $pick = $(if ($all.Count) { $all[0] } else { $fx[0] })
        $key = $(if ($pick.Id -like '*-all') { $pick.Id } else { "$($pick.Id)|$($f.Area)|$($f.Title)" })
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $out += [PSCustomObject]@{ Finding = $f; Fixer = $pick }
    }
    return $out
}

function Update-CgFixAllButton {
    $n = @(Get-CgFixAllPlan).Count
    if ($n) {
        $ui.BtnFixAll.Content = (T "Исправить всё ($n)")
        $ui.BtnFixAll.IsEnabled = $true
        $ui.BtnFixAll2.Content = (T "Исправить всё ($n)")
        $ui.BtnFixAll2.Visibility = 'Visible'
    } else {
        $ui.BtnFixAll.Content = (T 'Исправить всё')
        $ui.BtnFixAll.IsEnabled = $false
        $ui.BtnFixAll2.Visibility = 'Collapsed'
    }
}

function Invoke-CgFixAll {
    $plan = @(Get-CgFixAllPlan)
    if (-not $plan.Count) {
        $null = Show-CgDialog -Title 'Исправлять нечего' -Kind 'info' `
            -Text 'У оставшихся находок нет безопасного исправления в один щелчок. Откройте находку — справа будет сказано, что с ней делать, или нажмите «Доверять».'
        return
    }
    $items = @()
    foreach ($x in $plan) {
        $what = $x.Fixer.Title
        $sub = "$(T $x.Finding.Area): $(T $x.Finding.Title)"
        if ($x.Fixer.Id -like '*-all') { $sub = "$(T $x.Finding.Area): $(T 'все такие находки разом')" }
        # Подмену запуска на пустышку systray.exe почти всегда делают
        # намеренно — так глушат обновления и телеметрию. Отмечать её
        # за человека значило бы молча включить то, что он выключил.
        $on = $true
        if ($x.Fixer.Id -eq 'ifeo-remove' -and "$($x.Finding.Title)" -like 'Запуск программы заблокирован*') {
            $on = $false
            $sub += (T ' — похоже, отключено намеренно; отмечайте, только если это сделали не вы')
        }
        # Автозапуск. Мёртвую запись (файла уже нет) убираем смело. Живую
        # программу — нет: «из AppData» ещё не значит «вредонос», а убрать
        # из автозапуска LM Studio или помощника Razer за человека — это
        # сломать ему привычное, ничего не выиграв.
        if ($x.Fixer.Id -in @('run-remove', 'task-disable') -and $x.Finding.Target) {
            $file = "$($x.Finding.Target.File)"
            if ($file -and -not (Test-Path -LiteralPath $file)) {
                $sub += (T ' — файла уже нет, запись мёртвая')
            } elseif ($x.Finding.Severity -ne 'CRIT') {
                $on = $false
                $sub += (T ' — программа на месте; отмечайте, если она не нужна при старте Windows')
            }
        }
        $items += [PSCustomObject]@{ Title = $what; Sub = $sub; Checked = $on; Risky = $false }
    }
    $left = @($app.Findings | Where-Object { $_.Severity -in @('CRIT', 'WARN') }).Count - $plan.Count
    $txt = 'Каждое исправление обратимо: прежнее значение сохраняется в записи отката. Снимите галочку с того, что вы оставили намеренно.'
    if ($left -gt 0) { $txt += " Остальное ($left) так не чинится — это файлы и программы, решение по ним за вами." }
    $sel = Show-CgChecklistDialog -Title ("Исправить сразу: {0}" -f $plan.Count) -Text $txt -Items $items -OkText 'Исправить'
    if ($null -eq $sel) { Set-Status 'Исправление отменено'; return }
    $sel = @($sel)

    Set-Busy $true 'Исправляю...'
    $ok = 0; $bad = @()
    foreach ($i in $sel) {
        $x = $plan[$i]
        Set-Status ("Исправляю: {0}" -f $x.Fixer.Title)
        $r = Invoke-CgFix $x.Finding $x.Fixer
        if ($r.Ok) { $ok++ } else { $bad += ("{0}: {1}" -f $x.Finding.Title, $r.Message) }
    }
    Set-Busy $false

    $msg = "Исправлено: $ok из $($sel.Count). Записи отката лежат в папке undo рядом с журналами."
    if ($bad.Count) {
        $null = Show-CgDialog -Title 'Исправлено не всё' -Text $msg -Subject (($bad | Select-Object -First 6) -join "`n") -Kind 'warn'
    } else {
        $null = Show-CgDialog -Title 'Готово' -Text ($msg + ' Сейчас программа проверит систему заново, чтобы показать, что осталось.') -Kind 'ok'
    }
    Set-Status $msg
    Start-Scan
}

$ui.BtnScan.Add_Click({ Start-Scan })
$ui.BtnScan2.Add_Click({ Start-Scan })
$ui.BtnFixAll.Add_Click({ Invoke-CgFixAll })
$ui.BtnFixAll2.Add_Click({ Invoke-CgFixAll })
$ui.ChkOnlyBad.Add_Click({ Show-Findings })
foreach ($tb in @($ui.TabFindBad, $ui.TabFindCrit, $ui.TabFindWarn, $ui.TabFindAll)) {
    $tb.Add_Click({ Show-Findings })
}

$ui.BtnSaveReport.Add_Click({
    if (-not $app.Findings -or -not $app.Findings.Count) { Set-Status 'Сначала выполните проверку'; return }
    $dir = Get-CgDir 'reports'
    $f = Join-Path $dir ('scan-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.AppendLine((T 'CookieGuard — отчёт о проверке'))
    $null = $sb.AppendLine(((T '{0}   компьютер: {1}   пользователь: {2}') -f (Get-Date -Format 'dd.MM.yyyy HH:mm'), $env:COMPUTERNAME, $env:USERNAME))
    $null = $sb.AppendLine('')
    foreach ($area in ($app.Findings | Group-Object Area)) {
        $null = $sb.AppendLine('=' * 70)
        $null = $sb.AppendLine('  ' + (T $area.Name))
        $null = $sb.AppendLine('=' * 70)
        foreach ($x in ($area.Group | Sort-Object Order)) {
            $null = $sb.AppendLine(('[{0}] {1}' -f $x.Severity, (T $x.Title)))
            if ($x.Detail) { foreach ($l in ((T $x.Detail) -split "`n")) { $null = $sb.AppendLine('      ' + $l.TrimEnd()) } }
            $null = $sb.AppendLine('')
        }
    }
    [IO.File]::WriteAllText($f, $sb.ToString(), [Text.UTF8Encoding]::new($true))
    Set-Status "Отчёт сохранён: $f"
    Start-Process explorer.exe "/select,`"$f`""
})

# ------------------------------------------------------------
#  Процессы / расширения / автозапуск / журнал
# ------------------------------------------------------------
# Сбор процессов и расширений занимает десятки секунд (проверка подписей),
# поэтому выполняется в отдельном потоке — иначе окно повисло бы.
$bgScript = {
    param($sync, $kind)
    try {
        . (Join-Path $sync.Root 'lib\Core.ps1')
        . (Join-Path $sync.Root 'lib\Checks.ps1')
        . (Join-Path $sync.Root 'lib\Trust.ps1')
        . (Join-Path $sync.Root 'lib\VirusTotal.ps1')
        . (Join-Path $sync.Root 'lib\Baseline.ps1')
        . (Join-Path $sync.Root 'lib\AdBlock.ps1')
        switch ($kind) {
            'adlists' {
                $sync.AdInfo = Update-CgAdBlockLists -Progress { param($t) $sync.ScanStep = $t }
                $sync.BgResult = @()
            }
            'basenew'  {
                $b = New-CgBaselineData -Progress { param($t) $sync.ScanStep = $t }
                $null = Save-CgBaseline $b
                $sync.BgResult = @()
            }
            'basediff' { $sync.BgResult = @(Compare-CgBaseline -Progress { param($t) $sync.ScanStep = $t }) }
            'procs' { $sync.BgResult = @(Get-CgProcessList) }
            'net' {
                . (Join-Path $sync.Root 'lib\Monitor.ps1')
                . (Join-Path $sync.Root 'lib\Network.ps1')
                $sync.BgResult = @(Get-CgConnectionReport)
                $sync.NetInternal = $script:CgNetInternal
            }
            'appdata' {
                . (Join-Path $sync.Root 'lib\AppData.ps1')
                $sync.BgResult = @(Get-CgAppDataMap -Progress { param($t) $sync.BgStep = $t })
            }
            'exts'  {
                $l = @(Get-CgExtensionList)
                # Перепроверка по магазину — заодно, если в списке есть
                # непроверенное критичное: уходит только номер расширения.
                if (@($l | Where-Object { $_.FromStore -and $_.Severity -in @('CRIT', 'WARN') -and -not (Test-CgExtVerdictFresh $_.Id) }).Count) {
                    $sync.ScanStep = 'перепроверяю по магазину'
                    $null = Invoke-CgExtVerify $l -Progress { param($t) $sync.ScanStep = $t }
                    $l = @(Get-CgExtensionList)
                }
                $sync.BgResult = $l
            }
            'extverify' {
                $null = Invoke-CgExtVerify @(Get-CgExtensionList) -Force -Progress { param($t) $sync.ScanStep = $t }
                $sync.BgResult = @(Get-CgExtensionList)
            }
            'auto'  { $sync.BgResult = @(Get-CgAutorunList) }
            'runs'  { $sync.BgResult = @(Get-CgProcessStarts -Hours 6) }
            'vt'    {
                $r = Invoke-CgVtScan -Max 60 -Progress { param($t) $sync.ScanStep = $t }
                $sync.VtInfo = $r
                $sync.BgResult = @($r.Findings)
            }
            default { $sync.BgResult = @() }
        }
    } catch {
        $sync.Error = $_.ToString()
        $sync.BgResult = @()
    } finally {
        $sync.BgKind = $kind
        $sync.BgDone = $true
    }
}

function Start-BgTask {
    param([string]$Kind, [string]$Text)
    if ($sync.BgBusy) { Set-Status 'Подождите, предыдущая операция ещё идёт'; return }
    $sync.BgBusy = $true; $sync.BgDone = $false; $sync.BgResult = $null; $sync.BgKind = ''; $sync.BgStep = ''
    Set-Busy $true $Text
    $rs = [runspacefactory]::CreateRunspace()
    $rs.ApartmentState = 'MTA'; $rs.ThreadOptions = 'ReuseThread'; $rs.Open()
    $ps = [powershell]::Create(); $ps.Runspace = $rs
    $null = $ps.AddScript($bgScript).AddArgument($sync).AddArgument($Kind)
    $null = $ps.BeginInvoke()
    $app.BgRs = $rs; $app.BgPs = $ps
}

function Show-Procs {
    $src = $app.Procs
    if ($ui.ChkOnlyRisky.IsChecked) { $src = $src | Where-Object { $_.Risk -ge 14 } }
    $ui.GridProc.ItemsSource = @($src | Sort-Object @{ Expression = 'Risk'; Descending = $true }, @{ Expression = 'Name' })
    $ui.ProcStats.Text = ((T "всего: {0}    подозрительных: {1}") -f $app.Procs.Count, @($app.Procs | Where-Object { $_.Risk -ge 14 }).Count)
}

function Show-Exts {
    $ui.GridExt.ItemsSource = @($app.Exts | Sort-Object Order, Browser, Name)
    $c = @($app.Exts | Where-Object { $_.Severity -eq 'CRIT' }).Count
    $ui.ExtStats.Text = ((T "всего: {0}    с доступом к cookie на всех сайтах: {1}") -f $app.Exts.Count, $c)
}

function Show-Autoruns {
    $ui.GridAuto.ItemsSource = @($app.Autoruns | Sort-Object Order, Kind, Name)
    $ui.AutoStats.Text = ((T "записей: {0}    требуют внимания: {1}") -f $app.Autoruns.Count, @($app.Autoruns | Where-Object { $_.Severity -in @('CRIT', 'WARN') }).Count)
}

function Show-Runs {
    $src = $app.Runs
    if ($ui.ChkRunOnlyBad.IsChecked) { $src = $src | Where-Object { $_.Severity -in @('CRIT', 'WARN', 'NOTE') } }
    $ui.GridRun.ItemsSource = @($src | Sort-Object @{ Expression = 'Time'; Descending = $true })
    $src2 = @($app.Runs)
    $from = ''
    if ($src2.Count) { $from = $src2[0].Source }
    $ui.RunStats.Text = ((T "записей: {0}    источник: {1}") -f $src2.Count, (T $from))
}

function Refresh-Procs    { Start-BgTask 'procs' 'Собираю процессы и проверяю подписи...' }
function Refresh-Net      { Start-BgTask 'net'   'Проверяю соединения по десяти точкам...' }
function Refresh-AppData  { Start-BgTask 'appdata' 'Раскладываю AppData — около 20 секунд...' }

$script:CgCheckMark = @{ y = '✓'; n = '✗'; '-' = '—' }

function Show-Net {
    $rows = @()
    $proxy = @{}
    foreach ($r in @($app.Net)) {
        $c = $r.Checks
        $failed = @(); $lines = @(); $passed = 0; $total = 0
        foreach ($pr in $c.PSObject.Properties) {
            $name = $script:CgCheckpointNames[$pr.Name]
            $v = "$($pr.Value)"
            if ($v -ne '-') { $total++ }
            if ($v -eq 'y') { $passed++ }
            if ($v -eq 'n') { $failed += (T $name) }
            $say = $r.Says[$pr.Name]
            $lines += ('{0}  {1}{2}' -f $script:CgCheckMark[$v], (T $name), $(if ($say) { ' — ' + (T $say) } else { '' }))
        }
        $where = $(if ($r.Host) { "$($r.Host)  ($($r.Ip):$($r.Port))" } else { "$($r.Ip):$($r.Port)" })
        if ($r.Via) {
            $where = (T 'через') + " $($r.Via)"
            $proxy[$r.Via] = 1 + [int]$proxy[$r.Via]
        }
        $verdictText = @{ ok = 'Норма: все важные точки пройдены.'; check = 'Проверить: несколько точек не пройдены — посмотрите, какие, и решите, ваша ли это программа.'; bad = 'Опасно: неизвестная программа, канал слива или плохой вердикт VirusTotal.' }[$r.Verdict]
        $rows += [PSCustomObject]@{
            Severity = $r.Severity; Order = @{ 'CRIT' = 0; 'WARN' = 1; 'OK' = 4 }[$r.Severity]
            Process = $r.Process; Where = $where; Score = ('{0} из {1}' -f $passed, $total); Passed = $passed
            Failed = $(if ($failed.Count) { $failed -join ', ' } else { '—' })
            Title = ('{0} → {1}' -f $r.Process, $(if ($r.Host) { $r.Host } else { "$($r.Ip):$($r.Port)" }))
            Detail = ((@((T $verdictText), '', "$(T 'Программа:') $($r.Path)", "PID: $($r.ProcId)", '') + $lines) -join "`n")
            Path = $r.Path; Id = $r.ProcId; Hash = ''; Query = $r.Process
        }
    }
    $src = $rows
    if ($ui.ChkNetOnlyBad.IsChecked) { $src = @($rows | Where-Object { $_.Severity -ne 'OK' }) }
    $ui.GridNet.ItemsSource = @($src | Sort-Object Order, Process)
    $bad = @($rows | Where-Object { $_.Severity -eq 'CRIT' }).Count
    $chk = @($rows | Where-Object { $_.Severity -eq 'WARN' }).Count
    $px = ''
    if ($proxy.Count) { $px = '    ' + ((T 'через прокси: {0}') -f (($proxy.GetEnumerator() | ForEach-Object { "$($_.Key) — $($_.Value)" }) -join ', ')) }
    if ($sync.NetInternal) { $px += '    ' + ((T 'внутри компьютера (не показаны): {0}') -f $sync.NetInternal) }
    $ui.NetStats.Text = ((T 'соединений: {0}    проверить: {1}    опасно: {2}') -f $rows.Count, $chk, $bad) + $px
}

function Show-AppData {
    $rows = @()
    foreach ($r in @($app.AppData)) {
        $det = @(
            "$(T 'Путь:') $($r.Path)",
            "$(T 'Чья:') $(if ($r.Owner) { $r.Owner } else { T 'неизвестно — внутри нет подписанных программ' })",
            "$(T 'Размер:') $($r.Size), $(T 'файлов:') $($r.Files)",
            "$(T 'Программ (.exe):') $($r.Exe)$(if ($r.Unsigned) { ', ' + (T 'без подписи:') + " $($r.Unsigned)" })",
            "$(T 'Менялась:') $(if ($r.LastWrite) { $r.LastWrite.ToString('dd.MM.yyyy HH:mm') } else { '—' })"
        )
        if (@($r.Autoruns).Count) { $det += "$(T 'Стартует с Windows:') $(@($r.Autoruns) -join ', ')" }
        if ($r.Partial) { $det += (T 'Часть папок закрыта или считалась слишком долго — размер может быть больше.') }
        if ($r.Severity -eq 'WARN') { $det += ''; $det += (T 'Неподписанная программа в папке, из которой что-то стартует с Windows, или имя крупной компании без её подписи — так устроено большинство воров паролей и майнеров. Проверьте программы этой папки на VirusTotal.') }
        $rows += [PSCustomObject]@{
            Severity = $r.Severity; Order = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'OK' = 4 }[$r.Severity]
            Name = $r.Name; Root = $r.Root; Owner = $(if ($r.Owner) { $r.Owner } else { (T 'неизвестно') })
            Size = $r.Size; Bytes = $r.Bytes; Exe = $r.Exe; Marks = $(if ($r.Marks) { (T $r.Marks) } else { '—' })
            Title = "$($r.Root)\$($r.Name)"; Detail = ($det -join "`n"); Path = $r.Path; Hash = ''; Query = $r.Name
        }
    }
    $src = $rows
    if ($ui.ChkAppOnlyMarked.IsChecked) { $src = @($rows | Where-Object { $_.Severity -ne 'OK' }) }
    $ui.GridApp.ItemsSource = @($src | Sort-Object @{ Expression = 'Bytes'; Descending = $true })
    $sum = foreach ($root in @('Roaming', 'Local', 'LocalLow')) {
        $x = @($app.AppData | Where-Object { $_.Root -eq $root })
        '{0} {1}' -f $root, (Format-CgSize ([int64](($x | Measure-Object Bytes -Sum).Sum)))
    }
    $ui.AppStats.Text = ($sum -join '    ') + '    ' + ((T 'папок: {0}    с отметками: {1}') -f $rows.Count, @($rows | Where-Object { $_.Severity -ne 'OK' }).Count)
}

$ui.BtnNetRefresh.Add_Click({ Refresh-Net })
$ui.ChkNetOnlyBad.Add_Click({ if ($null -ne $app.Net) { Show-Net } })
$ui.BtnAppRefresh.Add_Click({ Refresh-AppData })
$ui.ChkAppOnlyMarked.Add_Click({ if ($null -ne $app.AppData) { Show-AppData } })
function Refresh-Exts     { Start-BgTask 'exts'  'Читаю расширения браузеров...' }
function Refresh-Autoruns { Start-BgTask 'auto'  'Читаю автозапуск...' }
function Refresh-Runs     { Start-BgTask 'runs'  'Читаю историю запуска программ...' }

# Журнал за несколько дней, а не только за сегодня: после полуночи
# страница была пустой, и казалось, что журнал не пишется вовсе.
function Refresh-Log {
    $files = @(Get-ChildItem -LiteralPath (Get-CgDir 'logs') -Filter 'cookieguard-*.log' -File -ErrorAction SilentlyContinue |
               Sort-Object Name -Descending | Select-Object -First 7)
    $lines = New-Object System.Collections.ArrayList
    foreach ($f in $files) {
        $chunk = @()
        try { $chunk = @((Read-CgSharedText $f.FullName) -split "`r?`n" | Where-Object { $_ }) } catch { }
        $lines.InsertRange(0, [string[]]$chunk)
        if ($lines.Count -ge 1500) { break }
    }
    if ($lines.Count) {
        $from = [Math]::Max(0, $lines.Count - 1500)
        $ui.LogBox.Text = ($lines.GetRange($from, $lines.Count - $from) -join "`r`n")
        $ui.LogBox.ScrollToEnd()
    } else {
        $ui.LogBox.Text = (T 'Журнал пока пуст.')
    }
}

$ui.BtnProcRefresh.Add_Click({ Refresh-Procs })
$ui.ChkOnlyRisky.Add_Click({ if ($app.Procs.Count) { Show-Procs } })
$ui.BtnExtRefresh.Add_Click({ Refresh-Exts })
$ui.BtnExtVerify.Add_Click({
    if (-not @($app.Exts | Where-Object { $_.Severity -in @('CRIT', 'WARN') -or $_.Verify }).Count) {
        if (-not $app.Exts.Count) { Refresh-Exts; return }
        Set-Status 'Перепроверять нечего: критичных расширений нет'
        return
    }
    Start-BgTask 'extverify' 'Перепроверяю расширения по магазину...'
})
$ui.BtnAutoRefresh.Add_Click({ Refresh-Autoruns })
$ui.BtnRunRefresh.Add_Click({ Refresh-Runs })
$ui.ChkRunOnlyBad.Add_Click({ if ($app.Runs.Count) { Show-Runs } })
$ui.BtnProcAudit.Add_Click({
    if (-not (Confirm-CgDialog -Title 'Включить журнал запуска программ?' `
                -Text 'Windows начнёт записывать каждый запуск с командной строкой и тем, кто его вызвал. Именно так опознаётся окно, которое мелькнуло и исчезло.' `
                -Kind 'question' -Yes 'Включить')) { Set-Status 'Журнал запуска не включён'; return }
    Invoke-AuditScript 'Install-ProcAudit.ps1' 'Включение журнала запуска программ'
    Refresh-Runs
})
$ui.BtnLogRefresh.Add_Click({ Refresh-Log })
$ui.BtnLogFolder.Add_Click({ Start-Process explorer.exe (Get-CgDir 'logs') })
$ui.BtnReports.Add_Click({ Start-Process explorer.exe (Get-CgDir 'reports') })
$ui.BtnEvidence.Add_Click({ Start-Process explorer.exe (Get-CgDir 'evidence') })

# ------------------------------------------------------------
#  VirusTotal
# ------------------------------------------------------------
function Update-VtStats {
    $key = Get-CgVtKey
    $cache = Get-CgVtCache
    if ($key) {
        $ui.VtStats.Text = ((T "ключ задан    в базе вердиктов: {0}") -f $cache.Count)
    } else {
        $ui.VtStats.Text = (T 'ключ не задан — проверка недоступна')
    }
}

function Update-BaseStats {
    $d = Get-CgBaselineDate
    if ($d) { $ui.BaseStats.Text = (T ('снят ' + $d.ToString('dd.MM.yyyy HH:mm'))) }
    else { $ui.BaseStats.Text = (T 'не снят') }
}

$ui.BtnBaseNew.Add_Click({
    $d = Get-CgBaselineDate
    $extra = ''
    if ($d) { $extra = "`n`nТекущий эталон от $($d.ToString('dd.MM.yyyy HH:mm')) будет заменён." }
    $txt = 'Запомнится автозапуск, расширения, сертификаты, прокси, hosts, исключения антивируса и службы. Снимайте, только когда уверены, что система в порядке.'
    if ($d) { $txt += " Эталон от $($d.ToString('dd.MM.yyyy HH:mm')) будет заменён." }
    if (-not (Confirm-CgDialog -Title 'Снять эталон состояния системы?' -Text $txt -Kind 'question' -Yes 'Снять')) { return }
    Start-BgTask 'basenew' 'Снимаю эталон...'
})

$ui.BtnBaseDiff.Add_Click({
    if (-not (Test-CgBaselineExists)) {
        $null = Show-CgDialog -Title 'Эталон ещё не снят' -Text 'Сравнивать не с чем. Сначала нажмите «Снять заново».' -Kind 'info'
        return
    }
    Start-BgTask 'basediff' 'Сверяю систему с эталоном...'
})

$ui.BtnProcAudit2.Add_Click({ $ui.BtnProcAudit.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) })

# ------------------------------------------------------------
#  Блокировщик рекламы
#
#  Подключить распакованное расширение может только человек: так
#  устроена защита браузера, и обходить её инструмент безопасности
#  не будет. Программа делает всё остальное — кладёт файлы, качает
#  списки, открывает нужную страницу и кладёт путь в буфер обмена.
# ------------------------------------------------------------
$script:CgAdOpenAfter = $null

function Update-CgAdStats {
    $st = Get-CgAdBlockStatus
    $parts = @()
    if (@($st.LoadedIn).Count) { $parts += ('подключён: {0}' -f (@($st.LoadedIn) -join ', ')) }
    elseif ($st.Copied) { $parts += 'файлы готовы, в браузер ещё не подключён' }
    else { $parts += 'не подключён — реклама в браузере не режется' }
    if ($st.Lists) { $parts += ('списки от {0}: правил {1}, скрытий {2}' -f $st.Lists, $st.Network, $st.Cosmetic) }
    elseif ($st.Copied) { $parts += 'только встроенные правила' }
    $ui.AdStats.Text = ((@($parts) | ForEach-Object { $x = "$(T $_)"; $x.Substring(0, 1).ToUpper() + $x.Substring(1) }) -join '. ') + '.'
    if (@($st.LoadedIn).Count) { $ui.AdStats.Foreground = '#4ADE80' } else { $ui.AdStats.Foreground = '#7C8694' }
}

function Open-CgAdBlockSteps {
    param([string]$Browser)
    $r = Open-CgAdBlockInBrowser $Browser
    if (-not $r.Ok) {
        $null = Show-CgDialog -Title 'Браузер не найден' -Kind 'warn' `
            -Text 'Не нашёл Chrome, Edge или Brave. Откройте страницу расширений сами и загрузите папку, путь к ней — ниже.' -Subject $r.Dir
        return
    }
    $null = Show-CgDialog -Title ('Осталось три щелчка в {0}' -f $r.Browser) -Kind 'info' `
        -Text "1. На открывшейся странице расширений включите «Режим разработчика» (переключатель справа вверху или слева внизу).`n2. Нажмите «Загрузить распакованное» и вставьте путь клавишами Ctrl+V — он уже в буфере обмена.`n3. Готово: значок CookieGuard появится у адресной строки. В нём — выключить блокировку на сайте и настройки." `
        -Subject $r.Dir
    Update-CgAdStats
}

$ui.BtnAdInstall.Add_Click({
    $res = Install-CgAdBlockFiles
    if (-not $res.Ok) { $null = Show-CgDialog -Title 'Не удалось подготовить расширение' -Text $res.Message -Kind 'danger'; return }

    # Куда подключать: если браузеров несколько, спрашиваем
    $brs = @(Get-CgBrowsers | Where-Object { $_.Name -ne 'Firefox' } | Where-Object { @($_.Exe | Where-Object { Test-Path -LiteralPath $_ }).Count })
    if (-not $brs.Count) { Open-CgAdBlockSteps ''; return }
    $browser = $brs[0].Name
    if ($brs.Count -gt 1) {
        $names = @($brs | Select-Object -First 3 | ForEach-Object { $_.Name })
        $ans = Show-CgDialog -Title 'В какой браузер подключить блокировщик?' -Kind 'question' `
            -Text 'Для каждого браузера это делается отдельно; потом можно нажать кнопку ещё раз и подключить в следующий.' `
            -Buttons (@($names) + 'Отмена')
        if ($ans -lt 0 -or $ans -ge $names.Count) { return }
        $browser = $names[$ans]
    }

    $st = Get-CgAdBlockStatus
    if (-not $st.Lists) {
        $ans = Show-CgDialog -Title 'Скачать списки рекламы?' -Kind 'question' `
            -Text 'Встроенные правила режут около сотни рекламных сетей. Списки EasyList и RuAdList добавят ещё десятки тысяч — в том числе российские сайты. Скачиваются с easylist.to и adblockplus.org; из них берутся только адреса и CSS-селекторы, никакой код.' `
            -Buttons @('Скачать и подключить', 'Только встроенные')
        if ($ans -eq 0) {
            $script:CgAdOpenAfter = $browser
            Start-BgTask 'adlists' 'Скачиваю и перевожу списки рекламы...'
            return
        }
    }
    Open-CgAdBlockSteps $browser
})

$ui.BtnAdLists.Add_Click({
    Start-BgTask 'adlists' 'Скачиваю и перевожу списки рекламы...'
})

$ui.BtnAdFolder.Add_Click({
    $null = Install-CgAdBlockFiles
    Start-Process explorer.exe (Get-CgAdBlockDir)
})

$ui.BtnHelp.Add_Click({
    $p = Join-Path $PSScriptRoot 'README.md'
    if (Test-Path -LiteralPath $p) { Start-Process notepad.exe $p } else { Set-Status 'Файл справки не найден' }
})

$ui.BtnVtSite.Add_Click({
    Open-External 'https://www.virustotal.com/gui/my-apikey'
    Set-Status 'Зарегистрируйтесь, скопируйте API key и нажмите «Задать ключ»'
})

$ui.BtnVtKey.Add_Click({
    $cur = Get-CgVtKey
    $k = Show-CgPrompt -Title 'Ключ VirusTotal' `
        -Text 'Вставьте API key из профиля на virustotal.com.' `
        -Hint 'Ключ остаётся на этом компьютере. Наружу уходят только отпечатки файлов, сами файлы — никогда.' `
        -Default $cur
    if ($null -eq $k -or -not "$k".Trim()) { Set-Status 'Ключ не изменён'; return }
    Set-CgVtKey "$k"
    Update-VtStats
    Set-Status 'Ключ сохранён. Теперь можно нажать «Проверить через VirusTotal».'
})

$ui.BtnVtScan.Add_Click({
    if (-not (Get-CgVtKey)) {
        $null = Show-CgDialog -Title 'Нужен ключ VirusTotal' `
            -Text 'Он бесплатный: virustotal.com, регистрация, профиль, API key. Нажмите «Получить ключ».' -Kind 'info'
        return
    }
    if (-not (Confirm-CgDialog -Title 'Проверить неподписанные файлы?' `
                -Text 'Наружу уйдут только отпечатки SHA-256, сами файлы — никогда. Бесплатный ключ даёт 4 запроса в минуту, поэтому на 60 файлов уйдёт около 15 минут. Окном можно пользоваться дальше.' `
                -Kind 'question' -Yes 'Проверить')) { return }
    Start-BgTask 'vt' 'Проверяю файлы через VirusTotal (это долго из-за ограничений бесплатного ключа)...'
})

$ui.BtnExtStore.Add_Click({
    $s = $ui.GridExt.SelectedItem
    if (-not $s) { Set-Status 'Выберите расширение'; return }
    Open-External ('https://chromewebstore.google.com/detail/' + $s.Id)
    Set-Status "Открыта страница расширения: $($s.Name)"
})

# ------------------------------------------------------------
#  Аудит
# ------------------------------------------------------------
function Invoke-AuditScript {
    param([string]$ScriptName, [string]$What, [string[]]$Extra = @())
    # Пустой элемент уходил в сценарий как позиционный параметр $null:
    # «Не удаётся найти позиционный параметр, принимающий аргумент $null»
    $Extra = @($Extra | Where-Object { $_ })

    $sp = Join-Path $PSScriptRoot $ScriptName
    if (-not (Test-Path -LiteralPath $sp)) {
        $null = Show-CgDialog -Title "$What — не найден нужный файл" `
            -Text 'Похоже, установка повреждена: переустановите программу.' -Subject $sp -Kind 'danger'
        return $false
    }

    $out = ''
    $code = 0

    try {
        if ($app.IsAdmin) {
            # Выполняем прямо здесь, без порождения нового процесса:
            # Start-Process -WindowStyle Hidden в Windows 11 всё равно мелькает
            # чёрной консолью, если терминал по умолчанию — Windows Terminal.
            #
            # Звёздочка в «*>&1» обязательна. Вспомогательные сценарии пишут
            # через Write-Host, то есть в информационный поток, а не в поток
            # вывода. С прежним «2>&1» этот поток мимо $out, и окно рапортовало
            # «завершено» даже когда сценарий выходил с ошибкой: снаружи это
            # выглядело как «ничего не работает и ничего не сказано».
            $global:LASTEXITCODE = 0
            $out = (& $sp @Extra *>&1 | Out-String)
            $code = [int]$global:LASTEXITCODE
        } else {
            # Прав нет — нужен отдельный процесс с повышением; окно UAC
            # человек подтвердит сам. Перенаправить его вывод через
            # Start-Process нельзя (-Verb несовместим с -Redirect*),
            # поэтому дочерний процесс сам пишет отчёт в файл.
            $tmp = Join-Path $env:TEMP ('cookieguard-run-{0}.log' -f [Guid]::NewGuid().ToString('N').Substring(0, 8))
            $extraText = ''
            if ($Extra.Count) { $extraText = ' ' + (($Extra | ForEach-Object { "'$_'" }) -join ' ') }
            $cmd = "& '$sp'$extraText *>&1 | Out-File -LiteralPath '$tmp' -Encoding utf8; exit `$LASTEXITCODE"
            $p = Start-Process powershell -Verb RunAs -Wait -PassThru -ArgumentList @(
                '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-Command', $cmd)
            $code = [int]$p.ExitCode
            if (Test-Path -LiteralPath $tmp) {
                $out = (Get-Content -LiteralPath $tmp -Raw -Encoding UTF8)
                Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {
        # Самый частый случай здесь — человек нажал «Нет» в окне UAC
        Set-Status "$What — отменено"
        $null = Show-CgDialog -Title "$What — не выполнено" `
            -Text 'Windows не дала запустить изменение настроек. Чаще всего это отказ в окне запроса прав.' `
            -Subject "$($_.Exception.Message)" -Kind 'warn'
        Update-Cards
        return $false
    }

    Write-CgLog 'INFO' ("$What — код $code")
    if ($out) { Write-CgLog 'INFO' ("$What — вывод: " + (($out -split "`r?`n" | Where-Object { $_.Trim() }) -join ' | ')) }

    if ($code -ne 0) {
        # Говорим, что именно не получилось, и сразу предлагаем разбор:
        # молчаливый отказ — ровно то, из-за чего программа выглядела
        # неработающей.
        $tail = @($out -split "`r?`n" | Where-Object { $_.Trim() } | Select-Object -Last 4) -join "`n"
        $ans = Show-CgDialog -Title "$What не удалось" `
            -Text 'Windows отказала в изменении настройки. Разбор покажет, что именно мешает: прав, политики, служб или файлов браузера.' `
            -Subject $(if ($tail) { $tail } else { "код возврата $code" }) -Kind 'danger' `
            -Buttons @('Разобраться', 'Закрыть')
        Set-Status "$What — не выполнено (код $code)"
        Update-Cards
        if ($ans -eq 0) { Show-CgDiagnosis }
        return $false
    }

    Set-Status "$What — выполнено"
    Update-Cards
    return $true
}

# ------------------------------------------------------------
#  «Почему не включается»
# ------------------------------------------------------------
function Show-CgDiagnosis {
    Set-Busy $true 'Проверяю, что мешает...'
    $diag = @()
    try { $diag = @(Invoke-CgDiagnose) } catch {
        Set-Busy $false
        $null = Show-CgDialog -Title 'Разбор не удался' -Text "$($_.Exception.Message)" -Kind 'warn'
        return
    }
    Set-Busy $false (Get-CgDiagSummary $diag)

    # Находки разбора попадают в общий список: там у них и подробности,
    # и правая кнопка, и «Спросить у ИИ» — отдельного окна не нужно.
    $app.Findings = @($app.Findings | Where-Object { $_.Area -ne 'Почему не работает' }) + @(
        $diag | ForEach-Object {
            [PSCustomObject]@{
                Severity = $_.Severity
                Order    = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'INFO' = 3; 'OK' = 4 }[$_.Severity]
                Area     = 'Почему не работает'
                Title    = ('{0}: {1}' -f $_.Name, $_.Value)
                Detail   = $_.Detail
                Path     = ''; Hash = ''; Query = $_.Name
            }
        })
    # Разбор почти весь состоит из строк «норма» — ради них его и
    # запускают. С фильтром «только важное» человек попадал бы на
    # пустой список и решал, что проверка опять ничего не сделала.
    $ui.ChkOnlyBad.IsChecked = $false
    $ui.TabFindAll.IsChecked = $true
    Show-Findings
    Show-CgPage 'find'

    $bad = @($diag | Where-Object { $_.Severity -eq 'CRIT' })
    if ($bad.Count) {
        $null = Show-CgDialog -Title 'Нашлось, что мешает' `
            -Text ('Строк, из-за которых настройка не включается: {0}. Они открыты в «Находках» — выберите строку, справа будет сказано, что делать.' -f $bad.Count) `
            -Subject (($bad | Select-Object -First 3 | ForEach-Object { "$($_.Name): $($_.Value)" }) -join "`n") -Kind 'warn'
    } else {
        $null = Show-CgDialog -Title 'Непреодолимых помех не нашлось' `
            -Text 'Всё необходимое на месте. Если настройка всё равно не включается, посмотрите раздел «Журнал» — там записан вывод последней попытки.' -Kind 'ok'
    }
}

$ui.BtnAudit.Add_Click({
    if (-not (Confirm-CgDialog -Title 'Включить аудит доступа к cookie?' `
                -Text 'Windows начнёт записывать, какая программа открывает Cookies и Login Data. Включится политика аудита файловой системы, журнал безопасности вырастет до 256 МБ. Всё отменяется этим же переключателем.' `
                -Kind 'question' -Yes 'Включить')) { Set-Status 'Аудит не включён'; return }
    Set-Busy $true 'Включаю аудит...'
    Invoke-AuditScript 'Install-Audit.ps1' 'Включение аудита'
    Set-Busy $false
})

$ui.BtnAuditOff.Add_Click({
    Set-Busy $true 'Выключаю аудит...'
    Invoke-AuditScript 'Uninstall-Audit.ps1' 'Выключение аудита'
    Set-Busy $false
})

# ------------------------------------------------------------
#  Таймер: забираем события из монитора, проверяем сканирование
# ------------------------------------------------------------
$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(500)
$timer.Add_Tick({
    # события монитора
    $added = 0
    while ($sync.Queue.Count -gt 0 -and $added -lt 200) {
        $e = $sync.Queue.Dequeue()
        $added++
        if ($e.Severity -eq 'OK' -and -not $ui.ChkShowOk.IsChecked) { continue }
        $app.MonItems.Insert(0, $e)
        if ($e.Severity -in @('CRIT', 'WARN')) {
            Show-CgNotify ('CookieGuard: ' + $e.Kind) $e.Title $e.Severity
        }
        if ($e.Severity -eq 'CRIT') {
            try { [System.Media.SystemSounds]::Exclamation.Play() } catch { }
            # на вкладку монитора переключаем не чаще раза в 30 секунд,
            # чтобы шквал событий не выдёргивал пользователя из того, что он читает
            if (-not $app.LastJump -or ((Get-Date) - $app.LastJump).TotalSeconds -ge 30) {
                Show-CgPage 'mon'
                $app.LastJump = Get-Date
            }
        }
    }
    while ($app.MonItems.Count -gt 3000) { $app.MonItems.RemoveAt($app.MonItems.Count - 1) }

    if ($sync.Running -and $sync.Mode -ne $app.MonMode) { $app.MonMode = $sync.Mode; Set-CgMonChip }
    if ($sync.Counters) {
        $ui.MonStats.Text = ((T "событий: {0}    критично: {1}    внимание: {2}") -f $sync.Counters.Events, $sync.Counters.Crit, $sync.Counters.Warn)
    }

    if ($sync.Error) {
        Set-Status ('Ошибка: ' + $sync.Error)
        Write-CgLog 'WARN' ('Ошибка фонового потока: ' + $sync.Error)
        $sync.Error = $null
    }

    # результаты фоновых задач (процессы, расширения, автозапуск)
    if ($sync.BgDone) {
        $kind = $sync.BgKind
        $res = @($sync.BgResult)
        $sync.BgDone = $false; $sync.BgResult = $null; $sync.BgBusy = $false
        try { if ($app.BgPs) { $app.BgPs.Dispose() }; if ($app.BgRs) { $app.BgRs.Close(); $app.BgRs.Dispose() } } catch { }
        $app.BgPs = $null; $app.BgRs = $null
        switch ($kind) {
            'procs' { $app.Procs = $res;    Show-Procs;    Set-Busy $false 'Список процессов обновлён' }
            'net'     { $app.Net = $res; Show-Net; Set-Busy $false 'Соединения проверены' }
            'appdata' { $app.AppData = $res; Show-AppData; Set-Busy $false 'AppData разложена по полкам' }
            { $_ -in @('exts', 'extverify') } {
                $app.Exts = $res; Show-Exts
                # находки по расширениям — из того же свежего списка
                if ($app.Findings.Count) {
                    $app.Findings = @($app.Findings | Where-Object { $_.Area -ne 'Расширения' }) + @(Set-CgTrustOnFindings @(Get-CgExtensionFindings $res))
                    Show-Findings
                    Update-Cards
                }
                $nv = @($res | Where-Object { $_.Verify -match '^Магазин' }).Count
                Set-Busy $false $(if ($kind -eq 'extverify') { "Перепроверено по магазину: $nv" } else { 'Расширения обновлены' })
            }
            'auto'  { $app.Autoruns = $res; Show-Autoruns; Set-Busy $false 'Автозапуск обновлён' }
            'runs'  { $app.Runs = $res;     Show-Runs;     Set-Busy $false 'История запусков обновлена' }
            'adlists' {
                $info = $sync.AdInfo
                $sync.AdInfo = $null
                Update-CgAdStats
                if ($info -and $info.Ok) {
                    Set-Busy $false $info.Message
                    if ($script:CgAdOpenAfter) {
                        $b = $script:CgAdOpenAfter
                        $script:CgAdOpenAfter = $null
                        Open-CgAdBlockSteps $b
                    } else {
                        $null = Show-CgDialog -Title 'Списки обновлены' -Kind 'ok' -Text $info.Message `
                            -Subject 'Чтобы браузер их подхватил, нажмите «Перечитать списки» в настройках расширения (значок CookieGuard → Настройки) или перезапустите браузер.'
                    }
                } else {
                    Set-Busy $false 'Списки не обновлены'
                    $msg = 'Не удалось.'
                    if ($info) { $msg = $info.Message }
                    $null = Show-CgDialog -Title 'Списки не обновлены' -Text $msg -Kind 'warn'
                    if ($script:CgAdOpenAfter) { $b = $script:CgAdOpenAfter; $script:CgAdOpenAfter = $null; Open-CgAdBlockSteps $b }
                }
            }
            'basenew' {
                Set-Busy $false 'Эталон снят. Теперь любое изменение автозапуска, расширений, скриптов Adobe, сертификатов и сети будет заметно.'
                Update-Cards
                Write-CgLog 'INFO' 'Снят эталон состояния системы'
            }
            'basediff' {
                $app.Findings = @($app.Findings | Where-Object { $_.Area -ne 'Эталон' }) + @($res)
                Show-Findings
                Show-CgPage 'find'
                $ch = @($res | Where-Object { $_.Severity -in @('CRIT', 'WARN') }).Count
                if ($ch) { Set-Busy $false ("Сверка с эталоном: изменений, требующих внимания — $ch") }
                else { Set-Busy $false 'Сверка с эталоном: ничего не изменилось' }
                Update-Cards
            }
            'vt'    {
                $info = $sync.VtInfo
                $sync.VtInfo = $null
                if ($info -and $info.Error) {
                    Set-Busy $false ('VirusTotal: ' + $info.Error)
                } else {
                    # добавляем вердикты к общему списку находок
                    $app.Findings = @($app.Findings | Where-Object { $_.Area -ne 'VirusTotal' }) + @($res)
                    Show-Findings
                    Show-CgPage 'find'
                    $bad = @($res | Where-Object { $_.Severity -in @('CRIT', 'WARN') }).Count
                    Set-Busy $false ("VirusTotal: запрошено {0}, из базы {1}, с детектами {2}" -f $info.Checked, $info.FromCache, $bad)
                    Write-CgLog 'INFO' ("VirusTotal: checked={0} cache={1} bad={2}" -f $info.Checked, $info.FromCache, $bad)
                }
                Update-Cards
            }
            default { Set-Busy $false }
        }
    }

    # ход долгой фоновой задачи (AppData)
    if ($sync.BgBusy -and $sync.BgStep) { Set-Status ('AppData: ' + $sync.BgStep) }

    # сканирование
    if ($ui.Progress.Visibility -eq 'Visible' -and $sync.ScanStep -and -not $sync.BgBusy) {
        Set-Status ('Проверяю систему: ' + $sync.ScanStep)
    }
    if ($sync.ScanDone -and $null -ne $sync.ScanResults) {
        $app.Findings = @($sync.ScanResults)
        $app.LastScan = Get-Date
        $sync.ScanDone = $false; $sync.ScanResults = $null
        try { if ($app.ScanPs) { $app.ScanPs.Dispose() }; if ($app.ScanRs) { $app.ScanRs.Close(); $app.ScanRs.Dispose() } } catch { }
        $app.ScanPs = $null; $app.ScanRs = $null
        Show-Findings
        Update-Cards
        $ui.BtnScan.IsEnabled = $true; $ui.BtnScan2.IsEnabled = $true
        Set-Busy $false
        $c = @($app.Findings | Where-Object { $_.Severity -eq 'CRIT' }).Count
        $w = @($app.Findings | Where-Object { $_.Severity -eq 'WARN' }).Count
        Set-Status ("Проверка закончена: критичных {0}, требуют внимания {1}. Нажмите на строку, чтобы увидеть подробности." -f $c, $w)
        Write-CgLog 'INFO' "Проверка из окна: CRIT=$c WARN=$w"
        Show-CgPage 'find'
        if (@($app.Findings | Where-Object { $_.Area -eq 'Расширения' -and $_.Severity -in @('CRIT', 'WARN') -and $_.Detail -match 'Ещё не перепроверено' }).Count) {
            Start-BgTask 'exts' 'Перепроверяю критичные расширения по магазину...'
        }
    }
})
$timer.Start()

# ------------------------------------------------------------
#  Запуск
# ------------------------------------------------------------
$win.Add_Closing({
    $timer.Stop()
    Stop-Monitor
    try { if ($script:TrayIcon) { $script:TrayIcon.Visible = $false; $script:TrayIcon.Dispose() } } catch { }
})

# ------------------------------------------------------------
#  Подсказки при наведении
#  Задаются из кода, а не в разметке: так весь текст подсказок
#  лежит в одном месте и его видно целиком.
# ------------------------------------------------------------
$tips = @{
    BtnScan        = 'Полная проверка системы: защита, трафик, автозапуск, процессы, расширения, скрипты Adobe, копии баз cookie, сверка с эталоном.'
    BtnMon         = 'Наблюдение в реальном времени: кто обращается к cookie и какие программы запускаются.'
    BtnAudit       = 'Включить аудит Windows на файлы cookie и паролей. После этого видно, КАКАЯ программа их открыла.'
    BtnProcAudit2  = 'Включить журнал запуска программ (событие 4688) с командной строкой — чтобы опознать мелькнувшее окно.'
    BtnAuditOff    = 'Выключить аудит cookie и журнал запусков. Система вернётся в исходное состояние.'
    BtnBaseNew     = 'Запомнить текущее состояние системы как эталон: автозапуск, расширения, сертификаты, прокси, службы.'
    BtnBaseDiff    = 'Сравнить систему с эталоном и показать, что изменилось с тех пор.'
    BtnVtScan      = 'Проверить неподписанные файлы через VirusTotal (~70 антивирусов). Наружу уходит только отпечаток SHA256, сам файл — никогда.'
    BtnVtKey       = 'Задать бесплатный API-ключ VirusTotal. Хранится только на этом компьютере.'
    BtnVtSite      = 'Открыть страницу, где берут бесплатный ключ VirusTotal.'
    BtnGuardOn     = 'Постоянная защита: сторож стартует вместе с Windows, работает в фоне и перезапускается, если его завершат.'
    BtnGuardOff    = 'Снять постоянную защиту. Наблюдение останется только при открытом окне.'
    ChkAutoNeutr   = 'Сторож сам отправит в карантин файл, который VirusTotal уже знает как вредоносный (5 и более детектов). Остальное — только с вашего подтверждения.'
    BtnReports     = 'Открыть папку с сохранёнными отчётами проверок.'
    BtnEvidence    = 'Открыть папку с уликами по каждой тревоге (JSON с путями, PID, хешами).'
    BtnHelp        = 'Открыть подробное описание программы.'
    BtnExplorer    = 'Показать выбранный файл в проводнике.'
    BtnWeb         = 'Поиск в интернете по отпечатку, имени файла и издателю — не по двум словам, а по приметам, которые действительно что-то находят.'
    BtnVT          = 'Спросить вердикт VirusTotal по отпечатку выбранного файла.'
    BtnAsk         = 'Передать находку со всеми подробностями в чат с ИИ. Полный текст также попадёт в буфер обмена.'
    BtnCopy        = 'Скопировать подробности выбранной строки в буфер обмена.'
    BtnTrust       = 'Пометить как разобранное: больше не будет попадать в находки. Программа спросит, насколько широко: только этот файл, эта программа любой версии, весь издатель или вся папка.'
    BtnScanFiles   = 'Страница проверки файлов. Файл или папку можно бросить в любое место окна — программа сама распакует архив, спросит пароль и решит, что имеет смысл проверять.'
    BtnScanFiles2  = 'Перейти к проверке файлов. Файл можно просто бросить в окно.'
    BtnAdInstall   = 'Подключить свой блокировщик рекламы CookieGuard к Chrome, Edge или Brave. Запросы к рекламе режет сам браузер; расширению запрещено ходить в сеть.'
    BtnAdLists     = 'Скачать свежие EasyList и RuAdList и перевести их в правила браузера. Из списков берутся только адреса и CSS-селекторы.'
    BtnAdFolder    = 'Открыть папку расширения: весь его код там, его можно прочитать.'
    BtnFixAll      = 'Исправить разом всё, что программа умеет исправлять сама. Покажет список с галочками — снимите те, что оставили намеренно. Каждое исправление обратимо.'
    BtnFixAll2     = 'Исправить разом всё, что программа умеет исправлять сама. Покажет список с галочками.'
    BtnExtVerify   = 'Спросить магазин Chrome/Edge, что он знает о критичных расширениях: есть ли оно там и сколько у него пользователей. Наружу уходит только номер расширения.'
    SbCheck        = 'Спросить VirusTotal о файлах из списка. Наружу уходит только отпечаток SHA-256, сам файл — никогда.'
    SbDeep         = 'Распаковывать архивы и проверять то, что внутри. Для архива под паролем программа спросит пароль.'
    TglAudit       = 'Аудит доступа к файлам Windows: запись о том, какая программа открыла базу cookie или паролей. Без него главную задачу программы выполнить нечем.'
    TglGuard       = 'Сторож стартует вместе с Windows, работает в фоне и перезапускается, если его завершат. Это не драйвер ядра: противник с правами SYSTEM сможет его снести.'
    Nav            = 'Разделы программы. Нижние три — для разбора: что спрятано, чему вы доверяете, что программа делала.'
    BtnDiag        = 'Проверяет предпосылки: права, политику аудита, групповую политику поверх неё, службы, журнал безопасности, антивирус и файлы браузеров. Отвечает, почему переключатель не поддаётся.'
    BtnUpdCheck    = 'Спросить GitHub, вышла ли новая версия. Наружу уходит только запрос к api.github.com.'
    BtnUpdInstall  = 'Заменить файлы программы на версию из репозитория — даже если установлена та же самая. Рабочие данные — эталон, доверенные, карантин, журналы — остаются нетронутыми. Ставится только по этой кнопке, никогда само.'
    BtnUpdToken    = 'Ключ доступа GitHub. Нужен, только если репозиторий приватный. Хранится на этом компьютере, в папке state.'
    BtnKill        = 'Завершить выбранный процесс вместе со всеми дочерними. Критические процессы Windows программа не трогает.'
    BtnQuar        = 'Обратимо спрятать файл: запустить его будет нельзя, но можно вернуть в разделе «Карантин».'
    BtnNeutr       = 'Завершить процесс И отправить его файл в карантин — одним действием.'
    BtnQuarRestore = 'Вернуть файл из карантина на прежнее место, байт в байт.'
    BtnQuarDelete  = 'Удалить из карантина окончательно. Это необратимо.'
    BtnQuarFolder  = 'Открыть папку карантина.'
    BtnTrustRevoke = 'Снять доверие — запись снова начнёт попадать в находки.'
    BtnProcRefresh = 'Пересобрать список процессов и проверить подписи заново.'
    BtnExtRefresh  = 'Перечитать расширения браузеров и их права.'
    BtnExtStore    = 'Открыть страницу выбранного расширения в магазине Chrome.'
    BtnAutoRefresh = 'Перечитать автозапуск: реестр, папки автозагрузки, задачи, службы.'
    BtnRunRefresh  = 'Перечитать историю запуска программ.'
    BtnProcAudit   = 'Включить журнал запуска программ, чтобы видеть командную строку и родителя.'
    ChkOnlyBad     = 'Показывать только критичное, важное и заметки — скрыть строки «норма».'
    ChkOnlyRisky   = 'Показывать только процессы с признаками риска.'
    ChkShowOk      = 'Показывать и обычные обращения браузера к своим же cookie.'
    ChkRunOnlyBad  = 'Показывать только необычные запуски.'
    BtnSaveReport  = 'Сохранить находки в текстовый отчёт.'
    BtnMonClear    = 'Очистить список событий монитора.'
}
foreach ($k in $tips.Keys) {
    if ($ui[$k]) { $ui[$k].ToolTip = (T $tips[$k]) }
}

# ------------------------------------------------------------
#  Язык интерфейса
#
#  Разметка переводится при загрузке окна, поэтому новый язык
#  включается перезапуском: выбор сохраняется сразу, а кнопка
#  «Перезапустить» открывает окно заново. Подсказка о перезапуске
#  пишется на выбранном языке — его-то человек и читает.
# ------------------------------------------------------------
$script:CgSelfPath = $PSCommandPath
$script:CgLangShown = $script:CgLang
$ui.CmbLang.SelectedIndex = $(if ($script:CgLang -eq 'en') { 1 } else { 0 })
$ui.CmbLang.Add_SelectionChanged({
    $it = $ui.CmbLang.SelectedItem
    if (-not $it) { return }
    $lang = [string]$it.Tag
    try { Set-CgLang $lang } catch { Set-Status "Не удалось сохранить язык: $_"; return }
    if ($lang -eq $script:CgLangShown) {
        $ui.BtnLangRestart.Visibility = 'Collapsed'
        $ui.LangSub.Text = (T 'Новый язык включится после перезапуска окна.')
    } else {
        $ui.BtnLangRestart.Visibility = 'Visible'
        if ($lang -eq 'en') {
            $ui.BtnLangRestart.Content = 'Restart'
            $ui.LangSub.Text = 'English will be used after the window restarts.'
        } else {
            $ui.BtnLangRestart.Content = 'Перезапустить'
            $ui.LangSub.Text = 'Русский язык включится после перезапуска окна.'
        }
    }
})
$ui.BtnLangRestart.Add_Click({
    try {
        Start-Process (Join-Path $PSHOME 'powershell.exe') -WindowStyle Hidden -ArgumentList @(
            '-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$script:CgSelfPath`"")
        $win.Close()
    } catch {
        Set-Status "Не удалось перезапустить: $_"
    }
})

# ============================================================
#  Новая обвязка окна
# ============================================================

# ------------------------------------------------------------
#  Рамка окна рисуется нами, значит и кнопки заголовка — тоже
# ------------------------------------------------------------
Add-CgWindowDrag $win $ui.TitleBar
$ui.BtnMinW.Add_Click({ $win.WindowState = 'Minimized' })
$ui.BtnMaxW.Add_Click({
    if ($win.WindowState -eq 'Maximized') { $win.WindowState = 'Normal' } else { $win.WindowState = 'Maximized' }
})
$ui.BtnCloseW.Add_Click({ $win.Close() })
$win.Add_StateChanged({
    # 0xE923 — «восстановить», 0xE922 — «развернуть»
    if ($win.WindowState -eq 'Maximized') { $ui.BtnMaxW.Content = [string][char]0xE923 }
    else { $ui.BtnMaxW.Content = [string][char]0xE922 }
})

# ------------------------------------------------------------
#  Разделы слева ↔ страницы справа
#
#  В списке разделов есть заголовки групп, которые не
#  выбираются, поэтому номер строки и номер страницы не
#  совпадают — нужна карта.
# ------------------------------------------------------------
# Строка списка разделов → вкладка. Сеть и AppData — вкладки 12 и 13:
# новые страницы добавлены в конец, чтобы не сдвигать прежние номера.
$script:CgNavToPage = @{ 0 = 0; 1 = 1; 2 = 2; 4 = 3; 5 = 12; 6 = 4; 7 = 5; 8 = 6; 9 = 7; 10 = 8; 12 = 13; 13 = 9; 14 = 10; 15 = 11 }
$script:CgPageByKey = @{
    'over' = 0; 'guard' = 1; 'files' = 2; 'mon' = 3; 'find' = 4; 'proc' = 5; 'ext' = 6
    'auto' = 7; 'run' = 8; 'quar' = 9; 'trust' = 10; 'log' = 11; 'net' = 12; 'appdata' = 13
}

function Show-CgPage {
    param([string]$Key)
    if (-not $script:CgPageByKey.ContainsKey($Key)) { return }
    $idx = $script:CgPageByKey[$Key]
    $ui.Tabs.SelectedIndex = $idx
    foreach ($k in $script:CgNavToPage.Keys) {
        if ($script:CgNavToPage[$k] -eq $idx) { $ui.Nav.SelectedIndex = $k; break }
    }
}

$ui.Nav.Add_SelectionChanged({
    $i = $ui.Nav.SelectedIndex
    if ($script:CgNavToPage.ContainsKey($i)) {
        $ui.Tabs.SelectedIndex = $script:CgNavToPage[$i]
        # Журнал и состояние автозащиты — свежие при каждом открытии
        if ($script:CgNavToPage[$i] -eq $script:CgPageByKey['log']) { Refresh-Log }
        # Сеть и AppData считаются при первом открытии раздела
        if ($script:CgNavToPage[$i] -eq $script:CgPageByKey['net'] -and $null -eq $app.Net) { Refresh-Net }
        if ($script:CgNavToPage[$i] -eq $script:CgPageByKey['appdata'] -and $null -eq $app.AppData) { Refresh-AppData }
        if ($script:CgNavToPage[$i] -eq $script:CgPageByKey['guard'] -and $ui.AutoPartsBox.Visibility -eq 'Visible') { Update-CgAutoUi }
        Start-CgPageFade
    }
})
$ui.Nav.SelectedIndex = 0
$ui.Tabs.SelectedIndex = 0

# ------------------------------------------------------------
#  Свёрнутый столбец разделов
#
#  Окно на одиннадцать разделов большую часть времени показывает
#  таблицу, которой ширины не хватает. Свёрнутый столбец отдаёт
#  194 точки таблице и оставляет значки — так сделано и в
#  «Параметрах», и в тех программах, у которых разделов много.
# ------------------------------------------------------------
# ------------------------------------------------------------
#  Движение
#
#  Анимация здесь не украшение. Мгновенная подмена содержимого не
#  читается как переход: непонятно, открылась новая страница или
#  моргнула прежняя. Короткое движение отвечает на это без слов.
#  Длительности намеренно маленькие: интерфейс, который заставляет
#  себя ждать, надоедает быстрее, чем успевает понравиться.
# ------------------------------------------------------------
$script:CgEase = New-Object System.Windows.Media.Animation.CubicEase
$script:CgEase.EasingMode = 'EaseOut'

function New-CgAnim {
    param([double]$To, [int]$Ms)
    $a = New-Object System.Windows.Media.Animation.DoubleAnimation
    $a.To = $To
    $a.Duration = New-Object System.Windows.Duration ([TimeSpan]::FromMilliseconds($Ms))
    $a.EasingFunction = $script:CgEase
    return $a
}

# Страница не подменяется, а проявляется и чуть подаётся вверх.
function Start-CgPageFade {
    $ui.Tabs.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $ui.Tabs.Opacity = 0
    $ui.Tabs.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-CgAnim 1 180))
    $tt = $ui.Tabs.RenderTransform
    if ($tt -is [System.Windows.Media.TranslateTransform]) {
        $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, $null)
        $tt.Y = 10
        $tt.BeginAnimation([System.Windows.Media.TranslateTransform]::YProperty, (New-CgAnim 0 240))
    }
}

# Панель разбора выезжает сбоку, а не возникает рывком: иначе
# таблица скачком теряет треть ширины, и строка, на которую вы
# только что смотрели, уезжает из-под курсора.
function Show-CgDetailPanel {
    param([bool]$On)
    if (-not $On) { $ui.Inspector.Visibility = 'Collapsed'; return }
    if ($ui.Inspector.Visibility -eq 'Visible') { return }
    $ui.Inspector.Visibility = 'Visible'
    $ui.Inspector.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, $null)
    $ui.Inspector.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $null)
    $ui.Inspector.Width = 0
    $ui.Inspector.Opacity = 0
    $ui.Inspector.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, (New-CgAnim 412 230))
    $ui.Inspector.BeginAnimation([System.Windows.UIElement]::OpacityProperty, (New-CgAnim 1 230))
}

$script:CgNavLabels = @()
foreach ($it in $ui.Nav.Items) {
    if (-not ($it -is [System.Windows.Controls.ListBoxItem])) { continue }
    $c = $it.Content
    if (-not ($c -is [System.Windows.Controls.StackPanel])) { continue }
    foreach ($ch in $c.Children) {
        if ($ch -is [System.Windows.Controls.TextBlock] -and "$($ch.Tag)" -eq 'navlabel') {
            $script:CgNavLabels += $ch
        }
    }
}
$script:CgNavCollapsed = $false

function Set-CgNavCollapsed {
    param([bool]$On)
    $script:CgNavCollapsed = $On
    $lbl = 'Visible'
    $mini = 'Collapsed'
    if ($On) { $lbl = 'Collapsed'; $mini = 'Visible' }

    foreach ($t in $script:CgNavLabels) { $t.Visibility = $lbl }
    $ui.NavActions.Visibility     = $lbl
    $ui.NavActionsMini.Visibility = $mini
    $ui.NavHeadWatch.Visibility   = $lbl
    $ui.NavHeadAnalyse.Visibility = $lbl

    $w = 252
    if ($On) { $w = 58 }
    $ui.NavPanel.BeginAnimation([System.Windows.FrameworkElement]::WidthProperty, (New-CgAnim $w 230))

    if ($On) { $ui.BtnNavToggle.ToolTip = (T 'Развернуть столбец разделов') }
    else     { $ui.BtnNavToggle.ToolTip = (T 'Свернуть столбец разделов') }
}

$ui.BtnNavToggle.Add_Click({ Set-CgNavCollapsed (-not $script:CgNavCollapsed) })
$ui.BtnScanMini.Add_Click({ Invoke-CgButton $ui.BtnScan })
$ui.BtnScanFilesMini.Add_Click({ Invoke-CgButton $ui.BtnScanFiles })
$ui.BtnMonMini.Add_Click({ Invoke-CgButton $ui.BtnMon })
$ui.HeroGo.Add_Click({ Show-CgPage 'find' })

# ------------------------------------------------------------
#  Поиск по окну
#
#  Ищет и разделы, и уже собранные строки: после проверки на
#  двести находок «где я видел это имя» — вопрос чаще, чем
#  «в каком разделе смотреть».
# ------------------------------------------------------------
$script:CgSearchPages = @(
    @{ Key = 'over';  Name = 'Обзор' },      @{ Key = 'guard'; Name = 'Защита' },
    @{ Key = 'files'; Name = 'Проверка файлов' },
    @{ Key = 'mon';   Name = 'Монитор' },    @{ Key = 'find';  Name = 'Находки' },
    @{ Key = 'proc';  Name = 'Процессы' },   @{ Key = 'ext';   Name = 'Расширения' },
    @{ Key = 'auto';  Name = 'Автозапуск' }, @{ Key = 'run';   Name = 'Запуски' },
    @{ Key = 'quar';  Name = 'Карантин' },   @{ Key = 'trust'; Name = 'Доверенные' },
    @{ Key = 'log';   Name = 'Журнал' }
)

function Get-CgGridFor {
    param([string]$Key)
    switch ($Key) {
        'find'  { return $ui.GridFind }
        'proc'  { return $ui.GridProc }
        'ext'   { return $ui.GridExt }
        'auto'  { return $ui.GridAuto }
        'run'   { return $ui.GridRun }
        'quar'  { return $ui.GridQuar }
        'trust' { return $ui.GridTrust }
        'mon'   { return $ui.GridMon }
        'files' { return $ui.SbGrid }
    }
    return $null
}

function Add-CgSearchResult {
    param([string]$Title, [string]$Sub, [string]$Page, $Row)
    $li = New-Object System.Windows.Controls.ListBoxItem
    $li.Padding = '9,6'
    $sp = New-Object System.Windows.Controls.StackPanel
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $Title
    $t1.TextTrimming = 'CharacterEllipsis'
    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = $Sub
    $t2.FontSize = 11
    $t2.Margin = '0,2,0,0'
    $t2.TextTrimming = 'CharacterEllipsis'
    $t2.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#7C8694'))
    $null = $sp.Children.Add($t1)
    $null = $sp.Children.Add($t2)
    $li.Content = $sp
    $li.Tag = [PSCustomObject]@{ Page = $Page; Row = $Row }
    $null = $ui.SearchList.Items.Add($li)
}

function Update-CgSearch {
    $q = "$($ui.SearchBox.Text)".Trim()
    if ($q) { $ui.SearchHint.Visibility = 'Collapsed' } else { $ui.SearchHint.Visibility = 'Visible' }

    $ui.SearchList.Items.Clear()
    if ($q.Length -lt 2) { $ui.SearchPop.IsOpen = $false; return }

    foreach ($pg in $script:CgSearchPages) {
        $pn = T $pg.Name
        if ($pn -like "*$q*") { Add-CgSearchResult $pn (T 'раздел окна') $pg.Key $null }
    }

    $sets = @(
        @{ Key = 'find';  Label = 'находка';    Items = $app.Findings },
        @{ Key = 'proc';  Label = 'процесс';    Items = $app.Procs },
        @{ Key = 'ext';   Label = 'расширение'; Items = $app.Exts },
        @{ Key = 'auto';  Label = 'автозапуск'; Items = $app.Autoruns },
        @{ Key = 'run';   Label = 'запуск';     Items = $app.Runs },
        @{ Key = 'quar';  Label = 'карантин';   Items = $app.Quar },
        @{ Key = 'trust'; Label = 'доверенное'; Items = $app.Trust }
    )
    $n = 0
    foreach ($st in $sets) {
        foreach ($r in @($st.Items)) {
            if ($n -ge 40) { break }
            $title = ''
            if ($r.PSObject.Properties['Title'] -and $r.Title) { $title = T ([string]$r.Title) }
            elseif ($r.PSObject.Properties['Name']) { $title = T ([string]$r.Name) }
            $path = ''
            if ($r.PSObject.Properties['Path']) { $path = [string]$r.Path }
            if (($title -notlike "*$q*") -and ($path -notlike "*$q*")) { continue }
            $sub = T "$($st.Label)"
            if ($path) { $sub = "$(T $st.Label) — $path" }
            Add-CgSearchResult $title $sub $st.Key $r
            $n++
        }
    }

    if (-not $ui.SearchList.Items.Count) {
        Add-CgSearchResult (T 'Ничего не найдено') (T 'Ищем по разделам и по уже собранным таблицам') '' $null
    }
    $ui.SearchPop.IsOpen = $true
}

function Invoke-CgSearchPick {
    param($Item)
    if (-not $Item -or -not $Item.Tag) { return }
    $d = $Item.Tag
    if (-not $d.Page) { return }
    $ui.SearchPop.IsOpen = $false
    Show-CgPage $d.Page
    if ($d.Row) {
        $g = Get-CgGridFor $d.Page
        if ($g) {
            $g.SelectedItem = $d.Row
            try { $g.ScrollIntoView($d.Row) } catch { }
        }
        Show-Detail $d.Row
    }
}

$ui.SearchBox.Add_TextChanged({ Update-CgSearch })
$ui.SearchBox.Add_KeyDown({
    param($s, $e)
    if ($e.Key -eq 'Escape') {
        $ui.SearchBox.Text = ''
        $ui.SearchPop.IsOpen = $false
        return
    }
    if ($e.Key -eq 'Return' -and $ui.SearchList.Items.Count) {
        Invoke-CgSearchPick $ui.SearchList.Items[0]
        $e.Handled = $true
    }
})
$ui.SearchList.Add_SelectionChanged({
    $sel = $ui.SearchList.SelectedItem
    if ($sel) {
        $ui.SearchList.SelectedIndex = -1
        Invoke-CgSearchPick $sel
    }
})

$ui.BtnInspClose.Add_Click({ $ui.Inspector.Visibility = 'Collapsed' })

# Разбор: показать, из чего состоит находка и что с ней связано.
$ui.BtnInspect.Add_Click({
    if (-not $app.Selected) { Set-Status 'Сначала выберите строку'; return }
    Set-Busy $true 'Собираю карту...'
    try { Show-CgInspector $win $app.Selected } catch {
        $null = Show-CgDialog -Title 'Разбор не собрался' -Text "$($_.Exception.Message)" -Kind 'danger'
    } finally { Set-Busy $false }
    Set-Status 'Готов'
})
$ui.BtnDiag.Add_Click({ Show-CgDiagnosis })

# ------------------------------------------------------------
#  Обновление с GitHub
#
#  Ставится только по кнопке. Самообновляющийся инструмент
#  безопасности — это канал доставки кода на компьютер, и
#  молчаливое обновление здесь было бы худшим из решений.
# ------------------------------------------------------------
$script:CgPendingUpdate = $null

function Update-CgVersionText {
    $ui.UpdWhere.Text = ((T "программа: {0}`nданные:    {1}`nисточник:  github.com/{2}/{3}, ветка {4}") -f
        (Get-CgRoot), (Get-CgDataRoot), $script:CgRepoOwner, $script:CgRepoName, $script:CgRepoBranch)
    $cur = Get-CgInstalledCommit
    if ($cur) {
        $ui.UpdStats.Text = ((T 'установлено: {0}') -f $cur.Substring(0, [Math]::Min(7, $cur.Length)))
    } else {
        $ui.UpdStats.Text = (T 'версия не отмечена — нажмите «Проверить»')
    }
    $ui.UpdStats.Foreground = '#7C8694'
    $script:CgPendingUpdate = $null
}

$ui.BtnUpdCheck.Add_Click({
    Set-Busy $true 'Спрашиваю GitHub...'
    $r = Test-CgUpdate
    Set-Busy $false

    if (-not $r.Ok) {
        $ui.UpdStats.Text = (T 'проверить не удалось')
        $ui.UpdStats.Foreground = '#FFB340'
        $null = Show-CgDialog -Title 'Не удалось проверить обновления' -Text $r.Error `
            -Subject "$script:CgRepoOwner/$script:CgRepoName ($script:CgRepoBranch)" -Kind 'warn'
        return
    }

    if (-not $r.HasUpdate) {
        $ui.UpdStats.Text = ((T 'установлена последняя версия: {0}') -f $r.Latest.Short)
        $ui.UpdStats.Foreground = '#4ADE80'
        Set-Status 'Обновлений нет — «Обновить» поставит ту же версию заново'
        return
    }

    $script:CgPendingUpdate = $r.Latest
    $when = ''
    if ($r.Latest.Date) { $when = $r.Latest.Date.ToLocalTime().ToString('dd.MM.yyyy HH:mm') }
    $ui.UpdStats.Text = ((T 'есть обновление: {0} от {1}') -f $r.Latest.Short, $when)
    $ui.UpdStats.Foreground = '#3B9EFF'
    Set-Status ('Доступно обновление: ' + $r.Latest.Message)
})

# Кнопка работает всегда, что бы ни показывала проверка. Нет
# свежей версии или проверку не нажимали — берём то, что сейчас
# лежит в репозитории, и ставим заново поверх установленного:
# так чинится копия, в которой файлы испорчены или заменены
# вручную, а отметка версии об этом не знает.
$ui.BtnUpdInstall.Add_Click({
    $u = $script:CgPendingUpdate
    if (-not $u) {
        Set-Busy $true 'Спрашиваю GitHub...'
        $latest = Get-CgLatestCommit
        Set-Busy $false
        if (-not $latest.Ok) {
            $null = Show-CgDialog -Title 'Не удалось связаться с GitHub' -Text $latest.Error `
                -Subject "$script:CgRepoOwner/$script:CgRepoName ($script:CgRepoBranch)" -Kind 'warn'
            return
        }
        $u = $latest
    }
    $same = ((Get-CgInstalledCommit) -eq $u.Sha)

    $when = ''
    if ($u.Date) { $when = $u.Date.ToLocalTime().ToString('dd.MM.yyyy HH:mm') }
    $title = 'Обновить программу?'; $text = 'Файлы программы будут заменены на версию из репозитория.'; $kind = 'question'; $yes = 'Обновить'
    if ($same) {
        $title = 'Переустановить ту же версию?'
        $text  = 'Эта версия уже установлена. Файлы программы будут переписаны заново из репозитория — все правки, сделанные в установленной копии, пропадут.'
        $kind  = 'warn'; $yes = 'Переустановить'
    }
    $text += ' Модули lib\*.ps1, которых нет в репозитории, будут удалены. Эталон, доверенные, карантин, журналы и настройки останутся на месте. Сторож и окно сами перезапустятся на новой версии.'
    if (-not (Confirm-CgDialog -Title $title -Text $text `
                -Subject ("{0}  {1}`n{2}" -f $u.Short, $when, $u.Message) -Kind $kind -Yes $yes)) { return }

    Set-Busy $true 'Обновляю...'
    $res = Install-CgUpdate $u.Sha { param($t) Set-Status $t }
    Set-Busy $false

    if (-not $res.Ok) {
        $null = Show-CgDialog -Title 'Обновление не установлено' -Text $res.Error -Kind 'danger'
        Set-Status 'Обновление не установлено'
        return
    }

    # Фон переходит на новый код сразу: сторож перезапускается сейчас,
    # а не после перезагрузки. Окно перезапускает само себя.
    $guardNote = ''
    if (Test-CgTask $script:CgTaskGuard) {
        if (Restart-CgGuard) { $guardNote = ' Сторож уже перезапущен на новой версии.' }
        else { $guardNote = ' Сторож перейдёт на новую версию сам в течение минуты.' }
    }
    $note = 'Окно сейчас перезапустится на новой версии.' + $guardNote
    if (@($res.Locked).Count) {
        # .exe занят, пока программа работает. Это не беда: он только
        # запускает .ps1, в котором и лежит вся логика.
        $note += ' Файлы, занятые работающей программой, останутся прежними: ' + (@($res.Locked) -join ', ') + '.'
    }
    $null = Show-CgDialog -Title 'Обновление установлено' -Text $note -Subject ('версия {0}, заменено файлов: {1}' -f $u.Short, $res.Copied) -Kind 'ok'
    Update-CgVersionText
    Write-CgLog 'INFO' 'Окно перезапускается после обновления'
    try {
        Start-Process (Join-Path $PSHOME 'powershell.exe') -WindowStyle Hidden -ArgumentList @(
            '-STA', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"{0}"' -f $script:CgSelfPath))
        $win.Close()
    } catch {
        Set-Status 'Обновление установлено — перезапустите программу'
    }
})

$ui.BtnUpdToken.Add_Click({
    $cur = Get-CgGitHubToken
    $k = Show-CgPrompt -Title 'Ключ доступа GitHub' `
        -Text 'Нужен только приватному репозиторию. Если репозиторий открытый, ключ не требуется — оставьте поле пустым.' `
        -Hint 'Токен хранится только на этом компьютере, в папке state, и наружу уходит лишь на api.github.com. Достаточно прав «только чтение» для этого репозитория.' `
        -Default $cur
    if ($null -eq $k) { Set-Status 'Ключ не изменён'; return }
    $null = Set-CgGitHubToken "$k"
    Set-Status $(if ("$k".Trim()) { 'Ключ GitHub сохранён' } else { 'Ключ GitHub убран' })
})

# ------------------------------------------------------------
#  Переключатели «Параметров» поверх прежних кнопок
#
#  Обработчики аудита и сторожа остались теми же и живут на
#  прежних кнопках — переключатель только нажимает их за
#  человека. Дублировать логику было бы верным способом
#  развести две её версии.
# ------------------------------------------------------------
function Invoke-CgButton {
    param($Btn)
    if (-not $Btn) { return }
    $Btn.RaiseEvent((New-Object System.Windows.RoutedEventArgs([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
}

$script:CgTogglesSyncing = $false

function Sync-CgToggles {
    # Состояние переключателя задаём мы, а не щелчок человека,
    # поэтому обработчик на время установки глушим — иначе
    # обновление состояния само же запустило бы установку.
    $script:CgTogglesSyncing = $true
    try {
        $on = [bool](Test-CgAuditEnabled)
        $ui.TglAudit.IsChecked = $on
        if ($on) { $ui.AuditSub.Text = (T 'Windows записывает, какая программа открывает базу cookie и паролей.') }
        else { $ui.AuditSub.Text = (T 'Выключен: не видно, кто брал cookie. Это главное, ради чего программа нужна.') }

        $t = Get-ScheduledTask -TaskName 'CookieGuard Watcher' -ErrorAction SilentlyContinue
        $ui.TglGuard.IsChecked = [bool]$t

        # «Журнал запуска программ» был кнопкой «Включить» без состояния:
        # включённый журнал выглядел выключенным, и его включали снова и
        # снова. Теперь видно, включён ли он.
        $pa = Test-CgProcAuditOn
        if ($pa -eq $true) { $ui.BtnProcAudit2.Content = (T 'Включён ✓'); $ui.BtnProcAudit2.IsEnabled = $false }
        else { $ui.BtnProcAudit2.Content = (T 'Включить'); $ui.BtnProcAudit2.IsEnabled = $true }

        # Пока работает автозащита, отдельные переключатели — её части:
        # выключить одну часть нельзя, сторож включил бы её через минуту.
        $auto = [bool](Get-CgSettings).AutoProtect
        $ui.TglAuto.IsChecked = $auto
        foreach ($c in @($ui.TglAudit, $ui.TglGuard)) {
            $c.IsEnabled = (-not $auto)
            $c.ToolTip = $(if ($auto) { (T 'Управляется автозащитой. Чтобы выключить отдельно, выключите автозащиту.') } else { $null })
        }
        if ($auto) { $ui.BtnProcAudit2.IsEnabled = $false }
    } catch { } finally {
        $script:CgTogglesSyncing = $false
    }
}

# Плиты частей автозащиты и одна фраза о состоянии сверху
$script:CgPartShort = @{
    guard    = 'от SYSTEM, без окна, даже когда никто не вошёл'
    alive    = 'отметка «жив» каждые 20 секунд, с меткой версии'
    watchdog = 'поднимет сторожа, если его убьют'
    fsaudit  = 'Windows записывает, кто открыл базу cookie'
    sacl     = 'базы cookie, паролей и ключ шифрования всех профилей'
    procaudit = 'событие 4688: что запустилось и с какой командой'
    hosts    = 'что поменяли и кто — построчно'
    net      = 'куда соединяется тот, кто трогал cookie'
    agents   = 'приманка, отладочный порт, теневые копии, внедрение'
    seclog   = 'журнал безопасности не меньше 256 МБ'
    history  = 'тревоги переживают перезапуск и обновление'
}
$script:CgPartTitle = @{
    guard = 'Сторож при старте Windows'; alive = 'Сторож на текущей версии'; watchdog = 'Наблюдатель'
    fsaudit = 'Аудит доступа к файлам'; sacl = 'Базы cookie и паролей'; procaudit = 'Журнал запуска программ'
    hosts = 'hosts'; net = 'Сеть и теневой путь'; agents = 'Агенты-усы'; seclog = 'Журнал безопасности'; history = 'Летопись событий'
}

function New-CgText {
    param([string]$Text, [double]$Size = 13, [string]$Color = '#ECEFF4', [string]$Margin = '0')
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text; $t.FontSize = $Size; $t.Foreground = $Color; $t.TextWrapping = 'Wrap'; $t.Margin = $Margin
    return $t
}

function Update-CgAutoUi {
    $st = @()
    try { $st = @(Get-CgProtectStatus) } catch { }
    $auto = [bool](Get-CgSettings).AutoProtect
    $ui.AutoParts.Children.Clear()
    $bad = 0; $unknown = 0; $ok = 0
    $agentsNote = ''
    try {
        $ar = Get-CgAgentsReport
        if ($ar.At) { $agentsNote = ('{0} из {1} на связи' -f @($ar.Agents | Where-Object { -not $_.Silent }).Count, @($ar.Agents).Count) }
    } catch { }
    foreach ($p in $st) {
        $broken = ($auto -and $p.On -eq $false)
        if ($p.On -eq $true) { $ok++ } elseif ($p.On -eq $false) { if ($auto) { $bad++ } } else { $unknown++ }

        $tile = New-Object System.Windows.Controls.Border
        $tile.Style = $win.FindResource('PartTile')
        if ($broken) { $tile.Background = '#130E0F' }
        $sp = New-Object System.Windows.Controls.StackPanel

        $head = New-Object System.Windows.Controls.StackPanel
        $head.Orientation = 'Horizontal'
        $dot = New-Object System.Windows.Shapes.Ellipse
        $dot.Width = 8; $dot.Height = 8; $dot.Margin = '0,0,12,0'; $dot.VerticalAlignment = 'Center'
        $dot.Fill = $(if ($p.On -eq $true) { if ($auto) { '#4ADE80' } else { '#2C5A3B' } } elseif ($broken) { '#FF5E5E' } else { '#3A404A' })
        $title = $script:CgPartTitle[$p.Key]; if (-not $title) { $title = $p.Name }
        $null = $head.Children.Add($dot)
        $null = $head.Children.Add((New-CgText (T $title) 14.5 '#ECEFF4'))
        $null = $sp.Children.Add($head)

        $line = $script:CgPartShort[$p.Key]; if (-not $line) { $line = $p.Why }
        if ($p.Key -eq 'agents' -and $agentsNote) { $line = $agentsNote + ' · ' + $line }
        $lt = New-CgText (T $line) 12.5 '#A3ACB9' '20,6,0,0'
        $lt.ToolTip = (T $p.Why)
        $null = $sp.Children.Add($lt)

        if ($broken) {
            $null = $sp.Children.Add((New-CgText (Get-CgPartFixText $p.Key) 12.5 '#FFB340' '20,10,0,0'))
        } elseif ($p.On -eq $null) {
            $null = $sp.Children.Add((New-CgText (T 'состояние видно только администратору') 12 '#7C8694' '20,8,0,0'))
        }
        $tile.Child = $sp
        $null = $ui.AutoParts.Children.Add($tile)
    }

    $total = @($st).Count
    $ui.AutoCount.Text = ((T 'ЧТО РАБОТАЕТ · {0} ИЗ {1}') -f $ok, $total)
    if (-not $auto) {
        $ui.ProtHead.Text = (T 'Защита выключена')
        $ui.ProtHead.Foreground = '#A3ACB9'
        $ui.AutoSub.Text = (T 'Включите автозащиту — всё наблюдение заработает разом, будет стартовать вместе с Windows и само включаться обратно.')
    } elseif ($bad) {
        $ui.ProtHead.Text = $(if ($bad -eq 1) { (T '1 часть не работает') } else { ((T '{0} части не работают') -f $bad) })
        $ui.ProtHead.Foreground = '#FFB340'
        $ui.AutoSub.Text = (T 'Причина — на плите. «Починить всё» один раз попросит права администратора и включит то, что выключено.')
    } else {
        $ui.ProtHead.Text = (T 'Защищено')
        $ui.ProtHead.Foreground = '#ECEFF4'
        $ui.AutoSub.Text = (T 'Автозащита включена. Сторож проверяет каждую часть раз в минуту и сам включает обратно то, что выключили.')
    }
    $g = Get-CgGuardInfo
    $ui.AutoPartsHint.Text = $(if ($g.Alive) { (T 'сторож отметился {0} с назад') -f [int]$g.Age } else { (T 'сторож не отвечает') })
    if ($unknown -and -not $app.IsAdmin) { $ui.AutoPartsHint.Text += ' · ' + (T 'без прав администратора видно не всё') }
    $ui.BtnAutoFix.Visibility = $(if ($auto -and $bad) { 'Visible' } else { 'Collapsed' })
    $ui.AutoNeutrState.Text = $(if ($ui.ChkAutoNeutr.IsChecked) { (T 'включён · изымает без вопроса') } else { (T 'выключен · всегда спросит') })
}

function Get-CgPartFixText {
    param([string]$Key)
    switch ($Key) {
        'guard'    { return (T 'Задачи сторожа нет. «Починить» поставит её.') }
        'alive'    {
            $g = Get-CgGuardInfo
            if ($g.Alive) { return (T 'Работает старая версия. «Починить» перезапустит сторожа.') }
            return (T 'Сторож не отвечает. «Починить» запустит его заново.')
        }
        'watchdog' { return (T 'Задачи наблюдателя нет. «Починить» создаст её.') }
        'net'      { return (T 'Работает внутри сторожа — оживёт вместе с ним.') }
        default    { return (T 'Выключено. «Починить» включит; дальше за этим следит сторож.') }
    }
}

# Меню «⋯» у строки настройки. Действие хранится в DataContext
# пункта, а не в замыкании: GetNewClosure и $script: уже однажды
# сломали все диалоги программы.
function Add-CgMoreMenu {
    param($Button, $Items)
    $Button.Tag = $Items
    $Button.Add_Click({
        param($s, $e)
        $list = $s.Tag
        if ($list -is [scriptblock]) { $list = & $list }
        $menu = New-Object System.Windows.Controls.ContextMenu
        foreach ($d in @($list)) {
            $mi = New-Object System.Windows.Controls.MenuItem
            $mi.Header = (T "$($d.Text)")
            $mi.DataContext = $d.Action
            $mi.Add_Click({ param($m, $a) & $m.DataContext })
            $null = $menu.Items.Add($mi)
        }
        $menu.PlacementTarget = $s
        $menu.Placement = 'Bottom'
        $menu.IsOpen = $true
    })
}

Add-CgMoreMenu $ui.BtnDnsMore @(
    @{ Text = 'Вернуть прежний DNS'; Action = { Invoke-CgButton $ui.BtnDnsOff } }
    @{ Text = 'Проверить, что фильтр работает'; Action = { Invoke-CgButton $ui.BtnDnsTest } }
)
# «Выбрать…» — список наборов: щелчок по набору и включает его
Add-CgMoreMenu $ui.BtnDnsMain {
    $items = @()
    for ($i = 0; $i -lt $ui.CmbDns.Items.Count; $i++) {
        $it = $ui.CmbDns.Items[$i]
        $items += @{ Text = "$($it.Content)"; Action = [scriptblock]::Create("`$ui.CmbDns.SelectedIndex = $i; Invoke-CgButton `$ui.BtnDnsOn") }
    }
    $items
}
Add-CgMoreMenu $ui.BtnAdMore @(
    @{ Text = 'Обновить списки рекламы'; Action = { Invoke-CgButton $ui.BtnAdLists } }
    @{ Text = 'Открыть папку расширения'; Action = { Invoke-CgButton $ui.BtnAdFolder } }
)
Add-CgMoreMenu $ui.BtnVtMore @(
    @{ Text = 'Задать ключ VirusTotal'; Action = { Invoke-CgButton $ui.BtnVtKey } }
    @{ Text = 'Получить ключ на сайте'; Action = { Invoke-CgButton $ui.BtnVtSite } }
)
Add-CgMoreMenu $ui.BtnBaseMore @(
    @{ Text = 'Снять эталон заново'; Action = { Invoke-CgButton $ui.BtnBaseNew } }
)
Add-CgMoreMenu $ui.BtnUpdMore @(
    @{ Text = 'Проверить, есть ли новая версия'; Action = { Invoke-CgButton $ui.BtnUpdCheck } }
    @{ Text = 'Ключ GitHub'; Action = { Invoke-CgButton $ui.BtnUpdToken } }
)

# Авто-карантин помнится и доходит до сторожа сразу
$ui.ChkAutoNeutr.Add_Click({
    $on = [bool]$ui.ChkAutoNeutr.IsChecked
    $null = Set-CgSetting 'AutoNeutralize' $on
    if ($app.IsAdmin -and (Test-CgGuardAlive)) { $null = Restart-CgGuard }
    $ui.AutoNeutrState.Text = $(if ($on) { (T 'включён · изымает без вопроса') } else { (T 'выключен · всегда спросит') })
    Write-CgLog 'INFO' ("Авто-карантин: " + $(if ($on) { 'включён' } else { 'выключен' }))
})

# Масштаб окна
$ui.CmbScale.Add_SelectionChanged({
    $it = $ui.CmbScale.SelectedItem
    if (-not $it -or $script:CgScaleInit) { return }
    $v = [double]::Parse("$($it.Tag)", [Globalization.CultureInfo]::InvariantCulture)
    $null = Set-CgSetting 'UiScale' $v
    $ui.ScaleState.Text = $(if ($v -eq $script:CgUiScale) { (T 'сейчас') } else { (T 'после перезапуска окна') })
    if ($v -ne $script:CgUiScale) { $ui.BtnLangRestart.Visibility = 'Visible'; $ui.BtnLangRestart.Content = (T 'Перезапустить') }
})
$script:CgScaleInit = $true
foreach ($it in $ui.CmbScale.Items) {
    if ([math]::Abs([double]::Parse("$($it.Tag)", [Globalization.CultureInfo]::InvariantCulture) - $script:CgUiScale) -lt 0.01) { $ui.CmbScale.SelectedItem = $it }
}
$script:CgScaleInit = $false
$ui.ScaleState.Text = (T 'сейчас')

$ui.BtnAutoFix.Add_Click({
    Set-Busy $true 'Чиню автозащиту...'
    $fixExtra = @()
    if ((Get-CgSettings).AutoNeutralize) { $fixExtra = @('-AutoNeutralize') }
    $null = Invoke-AuditScript 'Install-Protect.ps1' 'Починка автозащиты' $fixExtra
    Set-Busy $false
    Sync-CgToggles
    Update-GuardStats
    # сторожу нужно несколько секунд, чтобы отметиться на новой версии
    Start-Sleep -Milliseconds 2500
    Update-CgAutoUi
})

# Плиты автозащиты видны всегда: прятать состояние защиты за кнопкой незачем.

$ui.TglAuto.Add_Click({
    if ($script:CgTogglesSyncing) { return }
    if ($ui.TglAuto.IsChecked) {
        $autoQ = [bool]$ui.ChkAutoNeutr.IsChecked
        $txt = 'Включится всё сразу: аудит баз cookie и паролей всех профилей, журнал запуска программ, слежение за hosts, наблюдение за сетью после чтения cookie, сторож от SYSTEM при старте Windows и наблюдатель за ним. Выбор запомнится; что выключат — сторож включит обратно.'
        if ($autoQ) { $txt += ' Авто-карантин включён — подтверждённое вредоносное изымается без вопросов.' }
        if (-not (Confirm-CgDialog -Title 'Включить автозащиту?' -Text $txt -Kind 'question' -Yes 'Включить')) { Sync-CgToggles; return }
        # Список раскрывается сразу: человек видит, что именно включилось
        $ui.AutoPartsBox.Visibility = 'Visible'; $ui.BtnAutoMore.Content = (T 'Свернуть ▴')
        Set-Busy $true 'Включаю автозащиту...'
        $extra = @()
        if ($autoQ) { $extra = @('-AutoNeutralize') }
        $null = Invoke-AuditScript 'Install-Protect.ps1' 'Включение автозащиты' $extra
        Set-Busy $false
        if (-not $sync.Running) { Start-Monitor -Remember }
    } else {
        $okOff = Confirm-CgDialog -Title 'Выключить автозащиту?' -Text 'Сторож, аудит cookie, журнал запуска программ и слежение за hosts будут сняты. Журналы, улики и доверенные останутся.' -Kind 'warn' -Yes 'Выключить' -Dangerous
        if (-not $okOff) { Sync-CgToggles; return }
        Set-Busy $true 'Выключаю автозащиту...'
        $null = Invoke-AuditScript 'Uninstall-Protect.ps1' 'Выключение автозащиты'
        Set-Busy $false
    }
    Sync-CgToggles
    Update-GuardStats
    Update-CgAutoUi
})

$ui.TglAudit.Add_Click({
    if ($script:CgTogglesSyncing) { return }
    if ($ui.TglAudit.IsChecked) { Invoke-CgButton $ui.BtnAudit } else { Invoke-CgButton $ui.BtnAuditOff }
    Sync-CgToggles
})

$ui.TglGuard.Add_Click({
    if ($script:CgTogglesSyncing) { return }
    if ($ui.TglGuard.IsChecked) { Invoke-CgButton $ui.BtnGuardOn } else { Invoke-CgButton $ui.BtnGuardOff }
    Update-GuardStats
})

# ------------------------------------------------------------
#  Окно проверки файлов
# ------------------------------------------------------------
$script:CgScan = Initialize-CgScanPage $win $PSScriptRoot $ui { Show-CgPage 'files' }
$openScanBox = { Show-CgPage 'files' }
$ui.BtnScanFiles.Add_Click($openScanBox)
$ui.BtnScanFiles2.Add_Click($openScanBox)

# ------------------------------------------------------------
#  Меню по правой кнопке на строках таблиц
#
#  Пункты не повторяют логику кнопок, а нажимают те же кнопки:
#  одно место, где написано, что делает «В карантин».
# ------------------------------------------------------------
$cgRowMenu = {
    param($row)

    $path = ''
    if ($row.PSObject.Properties['Path']) { $path = [string]$row.Path }
    $isFile = ($path -and (Test-Path -LiteralPath $path -PathType Leaf))
    $procId = 0
    if ($row.PSObject.Properties['Id']) { $procId = [int]($row.Id -as [int]) }
    $hasHash = ($row.PSObject.Properties['Hash'] -and $row.Hash)

    return @(
        @{ Text = 'Доверять';              Glyph = 0xE8FB; Action = { Invoke-CgButton $ui.BtnTrust } }
        @{ Text = 'Показать в проводнике'; Glyph = 0xEC50; Enabled = [bool]$path;              Action = { Invoke-CgButton $ui.BtnExplorer } }
        @{ Text = 'Искать в интернете';    Glyph = 0xE721;                                     Action = { Invoke-CgButton $ui.BtnWeb } }
        @{ Text = 'Проверить на VirusTotal'; Glyph = 0xE774; Enabled = [bool]($isFile -or $hasHash); Action = { Invoke-CgButton $ui.BtnVT } }
        @{ Text = 'Спросить у ИИ';         Glyph = 0xE99A;                                     Action = { Invoke-CgButton $ui.BtnAsk } }
        @{ Separator = $true }
        @{ Text = 'Копировать подробности'; Glyph = 0xE8C8;                                    Action = { Invoke-CgButton $ui.BtnCopy } }
        @{ Separator = $true }
        @{ Text = 'Завершить процесс';     Glyph = 0xE711; Enabled = ($procId -gt 0);          Action = { Invoke-CgButton $ui.BtnKill } }
        @{ Text = 'В карантин';            Glyph = 0xE74D; Enabled = [bool]$isFile;            Action = { Invoke-CgButton $ui.BtnQuar } }
        @{ Text = 'Обезвредить';           Glyph = 0xE730; Enabled = (($procId -gt 0) -or $isFile); Action = { Invoke-CgButton $ui.BtnNeutr } }
    )
}

foreach ($g in @($ui.GridMon, $ui.GridFind, $ui.GridProc, $ui.GridExt, $ui.GridAuto, $ui.GridRun, $ui.SbGrid, $ui.GridNet, $ui.GridApp)) {
    Add-CgRowMenu $g $cgRowMenu
}

Add-CgRowMenu $ui.GridQuar {
    param($row)
    return @(
        @{ Text = 'Восстановить';      Glyph = 0xE777; Action = { Invoke-CgButton $ui.BtnQuarRestore } }
        @{ Text = 'Удалить насовсем';  Glyph = 0xE74D; Action = { Invoke-CgButton $ui.BtnQuarDelete } }
        @{ Separator = $true }
        @{ Text = 'Папка карантина';   Glyph = 0xEC50; Action = { Invoke-CgButton $ui.BtnQuarFolder } }
    )
}

Add-CgRowMenu $ui.GridTrust {
    param($row)
    return @(
        @{ Text = 'Снять доверие';       Glyph = 0xE711; Action = { Invoke-CgButton $ui.BtnTrustRevoke } }
        @{ Separator = $true }
        @{ Text = 'Копировать ключ';     Glyph = 0xE8C8; Action = { param($r) $null = Copy-CgRowText $r.Key } }
    )
}

Add-CgRowMenu $ui.GridExt {
    param($row)
    return @(
        @{ Text = 'Доверять';            Glyph = 0xE8FB; Action = { Invoke-CgButton $ui.BtnTrust } }
        @{ Text = 'Открыть в магазине';  Glyph = 0xE774; Action = { Invoke-CgButton $ui.BtnExtStore } }
        @{ Text = 'Искать в интернете';  Glyph = 0xE721; Action = { Invoke-CgButton $ui.BtnWeb } }
        @{ Separator = $true }
        @{ Text = 'Копировать подробности'; Glyph = 0xE8C8; Action = { Invoke-CgButton $ui.BtnCopy } }
    )
}
# Тяжёлый опрос системы (Defender, аудит, DNS, файлы браузеров) занимает
# несколько секунд. Если делать его до первой отрисовки, окно висит чёрным
# и программа выглядит сломанной. Поэтому окно показывается сразу, а
# карточки заполняются следом — пользователь видит интерфейс немедленно.
$script:InitDone = $false
function Invoke-CgLateInit {
    if ($script:InitDone) { return }
    $script:InitDone = $true
    Update-Cards
    Update-VtStats
    Update-BaseStats
    Update-GuardStats
    Update-CgVersionText
    Refresh-Quar
    Refresh-Trust
    # наборы фильтрующего DNS в выпадающий список
    $ui.CmbDns.Items.Clear()
    foreach ($p in (Get-CgDnsProfiles)) {
        $it = New-Object System.Windows.Controls.ComboBoxItem
        $it.Content = (T $p.Name)
        $it.Tag = $p
        $it.ToolTip = (T $p.Note)
        $null = $ui.CmbDns.Items.Add($it)
    }
    $ui.CmbDns.SelectedIndex = 0
    Update-DnsStats
    Update-CgAdStats
    Refresh-Log
    # Сторож на старой версии (обновление ставило прежнее окно, которое
    # не умело его перезапускать) — перезапускаем сразу, права есть
    $gi = Get-CgGuardInfo
    if ($gi.Alive -and -not (Test-CgGuardCurrent) -and $app.IsAdmin) {
        if (Restart-CgGuard) { Write-CgLog 'INFO' 'Сторож работал на старой версии — перезапущен из окна' }
    }
    $ui.ChkAutoNeutr.IsChecked = [bool](Get-CgSettings).AutoNeutralize
    Update-CgAutoUi
    # Прошлые события — из летописи на диске: список не начинается с
    # пустоты после перезапуска, перезагрузки или обновления
    try {
        foreach ($e in @(Get-CgEventHistory 300)) {
            if ($e.Severity -eq 'OK' -and -not $ui.ChkShowOk.IsChecked) { continue }
            $null = $app.MonItems.Add($e)
        }
    } catch { }
    # Монитор помнит, включали ли его: включать каждый раз руками не нужно
    if ((Get-CgSettings).MonitorOn) { Start-Monitor } else { Set-CgMonChip }
    if (-not $app.IsAdmin) {
        Set-Status 'Запущено без прав администратора. Включение аудита запросит повышение прав отдельно.'
    } else {
        Set-Status 'Готов. Начните с «Проверить систему» или включите аудит в разделе «Защита».'
    }
}

# Окно отрисовалось — только теперь опрашиваем систему, и то с низким
# приоритетом очереди, чтобы интерфейс успел стать отзывчивым.
$win.Add_ContentRendered({
    Set-Status 'Опрашиваю систему...'
    $null = $win.Dispatcher.BeginInvoke(
        [System.Windows.Threading.DispatcherPriority]::Background,
        [action] { Invoke-CgLateInit })
})

$null = $win.ShowDialog()
