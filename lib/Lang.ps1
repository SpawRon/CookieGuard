# ============================================================
#  Язык интерфейса: русский или английский
#
#  Вся программа написана по-русски, и русский остаётся основным:
#  в русском режиме T просто возвращает то, что ей дали, — ни
#  словаря, ни компиляции, ни лишней миллисекунды при запуске.
#
#  В английском режиме T ищет строку в словаре lib\lang\en.tsv
#  (строка «русский<TAB>английский»). Словарь понимает шаблоны:
#  «Путь: {0}» совпадёт и с готовой строкой «Путь: C:\x», а
#  подставленное значение переводится тем же словарём. Многострочный
#  текст, которого нет целиком, переводится по строкам, строка —
#  по предложениям.
#
#  Находки при этом остаются русскими внутри: заголовок находки —
#  ключ доверия, подробности и раздел сравниваются в коде. Переводится
#  только то, что видно: разметка окон при загрузке (New-CgWindow),
#  ячейки таблиц (конвертер на столбцах) и тексты, которые код
#  выводит сам, — через T.
#
#  Язык читается при запуске; смена требует перезапуска окна.
# ============================================================

function Get-CgLangPath { Join-Path (Get-CgDir 'state') 'language.txt' }

function Get-CgLang {
    $v = ''
    try {
        $p = Get-CgLangPath
        if (Test-Path -LiteralPath $p) { $v = ([IO.File]::ReadAllText($p)).Trim() }
    } catch { }
    if ($v -eq 'en') { return 'en' }
    return 'ru'
}

function Set-CgLang {
    param([ValidateSet('ru', 'en')][string]$Lang)
    [IO.File]::WriteAllText((Get-CgLangPath), $Lang, (New-Object System.Text.UTF8Encoding $false))
}

$script:CgLang = Get-CgLang
$script:CgLangReady = $false

$script:CgLangSource = Read-CgText 'lib\native\Lang.cs'

function Initialize-CgLang {
    if ($script:CgLangReady) { return }
    $script:CgLangReady = $true
    if ($script:CgLang -ne 'en') { return }
    try {
        if (-not ('Cg.Lang' -as [type])) {
            Add-CgType 'Cg.Lang' $script:CgLangSource -Refs PresentationFramework, PresentationCore, WindowsBase, System.Xaml
        }
        if (-not [Cg.Lang]::Loaded) {
            $null = [Cg.Lang]::LoadText((Read-CgText 'lib\lang\en.tsv'))
        }
    } catch {
        # Словарь не собрался — лучше русский интерфейс, чем никакой.
        try { Write-CgLog 'WARN' "Английский интерфейс недоступен: $_" } catch { }
        $script:CgLang = 'ru'
    }
}

# Перевод строки для показа. В русском режиме — та же строка.
function T {
    param([Parameter(Position = 0)]$Text)
    if ($script:CgLang -ne 'en' -or $null -eq $Text) { return $Text }
    if (-not $script:CgLangReady) { Initialize-CgLang }
    if ($script:CgLang -ne 'en') { return $Text }
    return [Cg.Lang]::T([string]$Text)
}

# Разметка окна до загрузки: подписи, заголовки, подсказки.
# Tag и имена не трогаются — по ним работает код.
function Convert-CgXamlLang {
    param([xml]$Doc)
    if ($script:CgLang -ne 'en') { return }
    foreach ($a in @($Doc.SelectNodes('//@*'))) {
        if ($a.LocalName -notin @('Text', 'Content', 'Header', 'ToolTip', 'Title')) { continue }
        if ($a.Value -notmatch '[\u0400-\u04FF]') { continue }
        $a.Value = T $a.Value
    }
    foreach ($n in @($Doc.SelectNodes('//text()'))) {
        if ($n.Value -match '[\u0400-\u04FF]') { $n.Value = T $n.Value }
    }
}

# Ячейки таблиц: данные остаются русскими (по ним работает код),
# а на экран идут через переводчик.
function Add-CgLangToGrids {
    param($Root)
    if ($script:CgLang -ne 'en' -or -not $Root) { return }
    Initialize-CgLang
    if ($script:CgLang -ne 'en') { return }
    if (-not $script:CgLangConverter) { $script:CgLangConverter = New-Object Cg.LangConverter }
    $stack = New-Object System.Collections.Stack
    $stack.Push($Root)
    while ($stack.Count) {
        $o = $stack.Pop()
        if ($o -is [System.Windows.Controls.DataGrid]) {
            foreach ($c in $o.Columns) {
                if ($c -isnot [System.Windows.Controls.DataGridTextColumn]) { continue }
                $b = $c.Binding
                if ($b -isnot [System.Windows.Data.Binding] -or $b.Converter) { continue }
                $nb = New-Object System.Windows.Data.Binding
                $nb.Path = $b.Path
                $nb.Mode = $b.Mode
                if ($b.StringFormat) { $nb.StringFormat = $b.StringFormat }
                $nb.Converter = $script:CgLangConverter
                $c.Binding = $nb
            }
        }
        if ($o -is [System.Windows.DependencyObject]) {
            foreach ($ch in [System.Windows.LogicalTreeHelper]::GetChildren($o)) {
                if ($ch -is [System.Windows.DependencyObject]) { $stack.Push($ch) }
            }
        }
    }
}
