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

$script:CgDialogXaml = Read-CgText 'ui\Dialog.xaml'

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

    # Перевод — только того, что видно. Номера кнопок остаются
    # прежними: возвращается номер, а не надпись.
    $Title = T $Title
    $Text = T $Text
    $Subject = T $Subject

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
        $b.Content = T $Buttons[$i]
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
$script:CgPromptXaml = Read-CgText 'ui\Prompt.xaml'

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
    # $Default не переводим: это значение поля (ключ, токен), а не надпись.
    $Title = T $Title
    $Text = T $Text
    $Subject = T $Subject
    $Hint = T $Hint
    $OkText = T $OkText
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
$script:CgTrustXaml = Read-CgText 'ui\Trust.xaml'

function Show-CgTrustDialog {
    param([string]$Subject, $Options, [string]$DefaultNote = 'моя программа, разобрался')

    $w = New-CgWindow $script:CgTrustXaml
    $w.FindName('TrSubject').Text = T $Subject
    $w.FindName('TrNote').Text = T $DefaultNote
    $host_ = $w.FindName('TrScopes')
    $style = $w.FindResource('ScopeCard')

    $radios = @()
    foreach ($o in @($Options)) {
        $r = New-Object System.Windows.Controls.RadioButton
        $r.Style = $style
        $r.Tag = $o

        $sp = New-Object System.Windows.Controls.StackPanel
        $t1 = New-Object System.Windows.Controls.TextBlock
        $t1.Text = T "$($o.Title)"
        $t1.FontSize = 13.5
        $t1.FontWeight = 'SemiBold'
        $t1.Foreground = '#ECEFF4'
        $t1.TextWrapping = 'Wrap'
        $t2 = New-Object System.Windows.Controls.TextBlock
        $t2.Text = T "$($o.Hint)"
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
$script:CgChecklistXaml = Read-CgText 'ui\Checklist.xaml'

# $Items: объекты с полями Title, Sub, Checked, Risky. Возвращает
# номера отмеченных строк или $null, если окно закрыли.
function Show-CgChecklistDialog {
    param([string]$Title, [string]$Text = '', $Items, [string]$OkText = 'Исправить')
    $Title = T $Title
    $Text = T $Text
    $OkText = T $OkText
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
        $count.Text = T "отмечено: $n из $($boxes.Count)"
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
        $t1.Text = T "$($it.Title)"
        $t1.TextWrapping = 'Wrap'
        $t1.Foreground = $(if ($it.Risky) { '#FFB340' } else { '#ECEFF4' })
        $null = $sp.Children.Add($t1)
        if ($it.Sub) {
            $t2 = New-Object System.Windows.Controls.TextBlock
            $t2.Text = T "$($it.Sub)"
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
