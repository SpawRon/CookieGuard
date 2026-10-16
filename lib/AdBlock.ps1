# ============================================================
#  CookieGuard - AdBlock.ps1
#  Свой блокировщик рекламы: расширение для Chrome, Edge и Brave.
#
#  Почему расширение, а не DNS и не hosts. Фильтрующий DNS не видит
#  ничего, если браузер ходит через свой DoH или через прокси (Karing
#  и подобные), — поэтому AdGuard DNS «не помогал». hosts работает
#  так же и вдобавок не умеет прятать блоки на странице. Расширение
#  стоит там, где реклама и появляется, — в браузере.
#
#  Почему своё. Сторонний блокировщик — это чужой код с доступом ко
#  всем страницам. Наш короткий, лежит в папке adblock и читается за
#  десять минут. Запросы режет сам браузер по правилам из файлов;
#  расширению запрещено ходить в сеть (connect-src 'self').
#
#  Списки. Встроенных правил хватает на основные сети; для полноты
#  программа скачивает EasyList и RuAdList и сама переводит их в
#  правила браузера. Из списков берутся только адреса и CSS-селекторы.
#  Скриптлеты (+js), регулярные выражения и прочие «исполняемые»
#  части отбрасываются: кода из чужих списков в браузер не попадает.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$script:CgAdBlockLists = @(
    @{ Name = 'EasyList'; Url = 'https://easylist.to/easylist/easylist.txt' }
    @{ Name = 'RuAdList'; Url = 'https://easylist-downloads.adblockplus.org/ruadlist.txt' }
)

# Сколько правил отдавать браузеру. Chrome гарантирует каждому
# расширению 30 000 статических правил; встроенным оставляем запас.
$script:CgAdBlockMaxRules = 29000

function Get-CgAdBlockSrc { Join-Path (Get-CgRoot) 'adblock' }

# Рабочая копия — не в Program Files и не в папке данных программы.
# Браузер сам пишет в папку распакованного расширения (индекс правил
# в _metadata) и из папки «только чтение» его просто не загружает, а
# в папку данных CookieGuard пишут одни администраторы. Поэтому —
# в профиль пользователя. И обновление программы не сотрёт скачанные
# списки: оно туда не заглядывает.
function Get-CgAdBlockDir {
    $d = Join-Path (Join-Path $env:LOCALAPPDATA 'CookieGuard') 'adblock-ext'
    if (-not (Test-Path -LiteralPath $d)) { $null = New-Item -ItemType Directory -Path $d -Force }
    return $d
}

$script:CgAdBlockListFiles = @('rules\lists.json', 'data\lists-cosmetic.json', 'data\lists-meta.json')

# Скопировать код расширения в рабочую папку. Скачанные списки,
# если они уже есть, остаются на месте.
function Install-CgAdBlockFiles {
    $src = Get-CgAdBlockSrc
    $dst = Get-CgAdBlockDir
    if (-not (Test-Path -LiteralPath (Join-Path $src 'manifest.json'))) {
        return [PSCustomObject]@{ Ok = $false; Dir = $dst; Message = "Нет папки расширения: $src" }
    }
    $hasLists = $false
    try {
        $m = Get-Content -LiteralPath (Join-Path $dst 'data\lists-meta.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $hasLists = [bool]$m.date
    } catch { }
    $base = $src.TrimEnd('\').Length + 1
    $n = 0
    foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File -Force)) {
        $rel = $f.FullName.Substring($base)
        if ($hasLists -and ($script:CgAdBlockListFiles -contains $rel)) { continue }
        $to = Join-Path $dst $rel
        $dir = Split-Path -Parent $to
        if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
        Copy-Item -LiteralPath $f.FullName -Destination $to -Force
        $n++
    }
    return [PSCustomObject]@{ Ok = $true; Dir = $dst; Message = "Скопировано файлов: $n"; Copied = $n }
}

# ------------------------------------------------------------
#  Перевод списка Adblock в правила браузера
# ------------------------------------------------------------
$script:CgAbTypeMap = @{
    'script' = 'script'; 'image' = 'image'; 'stylesheet' = 'stylesheet'; 'object' = 'object'
    'xmlhttprequest' = 'xmlhttprequest'; 'xhr' = 'xmlhttprequest'; 'subdocument' = 'sub_frame'; 'frame' = 'sub_frame'
    'ping' = 'ping'; 'media' = 'media'; 'font' = 'font'; 'websocket' = 'websocket'; 'other' = 'other'
}
# селекторы, которые браузер сам не поймёт: расширенный синтаксис блокировщиков
$script:CgAbBadCss = [regex]'(?i):-abp-|:has-text\(|:contains\(|:xpath\(|:matches-|:upward\(|:remove\(|:style\(|:min-text-length\(|:watch-attr\(|:nth-ancestor\(|:others\(|:if\(|:if-not\(|:matches-path\('
$script:CgAbDomain = [regex]'^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$'
$script:CgAbPlainDomain = [regex]'^\|\|([a-z0-9.-]+)\^$'

function ConvertTo-CgJsonString {
    param([string]$S)
    # управляющих символов в списках не бывает; если попадутся — выбрасываем
    return '"' + ($S.Replace('\', '\\').Replace('"', '\"') -replace '[\x00-\x1F]', '') + '"'
}

function ConvertTo-CgJsonArray {
    param($Items)
    return '[' + ((@($Items) | ForEach-Object { ConvertTo-CgJsonString "$_" }) -join ',') + ']'
}

function Test-CgAscii { param([string]$S) return ($S -cmatch '^[\x20-\x7E]+$') }

# Разобрать одну сетевую строку. Возвращает $null, если её не перевести.
function ConvertFrom-CgNetRule {
    param([string]$Line)
    $allow = $false
    $body = $Line
    if ($body.StartsWith('@@')) { $allow = $true; $body = $body.Substring(2) }
    if ($body.StartsWith('/')) { return $null }                  # регулярное выражение
    $opts = ''
    $i = $body.LastIndexOf('$')
    if ($i -ge 0) { $opts = $body.Substring($i + 1); $body = $body.Substring(0, $i) }
    if (-not $body -or $body -eq '*' -or -not (Test-CgAscii $body)) { return $null }

    $r = [PSCustomObject]@{
        Allow = $allow; Pattern = $body; Types = @(); NotTypes = @(); DomainType = ''
        Init = @(); NotInit = @(); Case = $false; Important = $false
    }
    if ($opts) {
        foreach ($o in ($opts -split ',')) {
            $o = $o.Trim().ToLowerInvariant()
            if (-not $o) { continue }
            $neg = $o.StartsWith('~')
            $k = $o.TrimStart('~')
            if ($script:CgAbTypeMap.ContainsKey($k)) {
                if ($neg) { $r.NotTypes += $script:CgAbTypeMap[$k] } else { $r.Types += $script:CgAbTypeMap[$k] }
            } elseif ($k -in @('third-party', '3p')) {
                $r.DomainType = $(if ($neg) { 'firstParty' } else { 'thirdParty' })
            } elseif ($k -in @('first-party', '1p')) {
                $r.DomainType = $(if ($neg) { 'thirdParty' } else { 'firstParty' })
            } elseif ($o.StartsWith('domain=')) {
                foreach ($d in ($o.Substring(7) -split '\|')) {
                    $dn = $d.TrimStart('~')
                    if (-not $script:CgAbDomain.IsMatch($dn)) { continue }
                    if ($d.StartsWith('~')) { $r.NotInit += $dn } else { $r.Init += $dn }
                }
                if (-not $r.Init.Count -and -not $r.NotInit.Count) { return $null }
            } elseif ($o -eq 'match-case') {
                $r.Case = $true
            } elseif ($o -eq 'important') {
                $r.Important = $true
            } else {
                return $null    # popup, csp, redirect, removeparam и прочее — не переводим
            }
        }
    }
    if ($r.Types.Count -and $r.NotTypes.Count) {
        $r.Types = @($r.Types | Where-Object { $r.NotTypes -notcontains $_ })
        $r.NotTypes = @()
        if (-not $r.Types.Count) { return $null }
    }
    # слишком общий кусок без привязки к адресу — ложные срабатывания
    if (-not $body.StartsWith('||') -and -not $body.StartsWith('|') -and $body.Trim('*').Length -lt 5) { return $null }
    return $r
}

function ConvertTo-CgDnrRule {
    param($R, [int]$Id)
    $prio = 1
    if ($R.Allow) { $prio = 2 }
    if ($R.Important) { $prio = 3 }
    $act = $(if ($R.Allow) { 'allow' } else { 'block' })
    $c = @()
    if ($R.Domains) { $c += '"requestDomains":' + (ConvertTo-CgJsonArray $R.Domains) }
    else {
        $c += '"urlFilter":' + (ConvertTo-CgJsonString $R.Pattern)
        $c += '"isUrlFilterCaseSensitive":' + $(if ($R.Case) { 'true' } else { 'false' })
    }
    if ($R.Types.Count)      { $c += '"resourceTypes":' + (ConvertTo-CgJsonArray ($R.Types | Select-Object -Unique)) }
    if ($R.NotTypes.Count)   { $c += '"excludedResourceTypes":' + (ConvertTo-CgJsonArray ($R.NotTypes | Select-Object -Unique)) }
    if ($R.DomainType)       { $c += '"domainType":' + (ConvertTo-CgJsonString $R.DomainType) }
    if ($R.Init.Count)       { $c += '"initiatorDomains":' + (ConvertTo-CgJsonArray ($R.Init | Select-Object -Unique)) }
    if ($R.NotInit.Count)    { $c += '"excludedInitiatorDomains":' + (ConvertTo-CgJsonArray ($R.NotInit | Select-Object -Unique)) }
    return ('{{"id":{0},"priority":{1},"action":{{"type":"{2}"}},"condition":{{{3}}}}}' -f $Id, $prio, $act, ($c -join ','))
}

# Весь перевод: строки списков → правила и селекторы.
function ConvertFrom-CgFilterLists {
    param([string[]]$Lines)
    $blockDom = New-Object 'System.Collections.Generic.HashSet[string]'
    $blockDom3p = New-Object 'System.Collections.Generic.HashSet[string]'
    $allowDom = New-Object 'System.Collections.Generic.HashSet[string]'
    $rules = New-Object System.Collections.ArrayList
    $seenPat = New-Object 'System.Collections.Generic.HashSet[string]'
    $css = @{}
    $cssCount = 0
    $skipped = 0

    foreach ($raw in $Lines) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('!') -or $line.StartsWith('[')) { continue }

        # ---- скрытие элементов ----
        if ($line.Contains('#')) {
            $m = [regex]::Match($line, '^([^#]*)(##|#@#|#\?#|#\$#|#%#|#@\?#|#@\$#)(.+)$')
            if ($m.Success) {
                if ($m.Groups[2].Value -ne '##') { $skipped++; continue }
                $doms = @($m.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } |
                          Where-Object { $_ -and -not $_.StartsWith('~') -and $script:CgAbDomain.IsMatch($_) })
                $sel = $m.Groups[3].Value.Trim()
                # общие правила без сайта не берём: тысячи селекторов на
                # каждой странице и главный источник поломок
                if (-not $doms.Count -or -not $sel -or $script:CgAbBadCss.IsMatch($sel) -or $sel.StartsWith('+js(')) { $skipped++; continue }
                foreach ($d in $doms) {
                    if (-not $css.ContainsKey($d)) { $css[$d] = New-Object System.Collections.ArrayList }
                    $null = $css[$d].Add($sel)
                    $cssCount++
                }
                continue
            }
        }
        if ($line.Contains('$$')) { $skipped++; continue }

        # ---- сетевые ----
        $r = ConvertFrom-CgNetRule $line
        if (-not $r) { $skipped++; continue }
        $pm = $script:CgAbPlainDomain.Match($r.Pattern)
        $plain = ($pm.Success -and -not $r.Types.Count -and -not $r.NotTypes.Count -and -not $r.Init.Count -and -not $r.NotInit.Count -and -not $r.Case -and -not $r.Important)
        if ($plain -and $script:CgAbDomain.IsMatch($pm.Groups[1].Value)) {
            $d = $pm.Groups[1].Value
            if ($r.Allow) { if (-not $r.DomainType) { $null = $allowDom.Add($d) } else { $null = $rules.Add($r) } }
            elseif ($r.DomainType -eq 'thirdParty') { $null = $blockDom3p.Add($d) }
            elseif (-not $r.DomainType) { $null = $blockDom.Add($d) }
            else { $null = $rules.Add($r) }
            continue
        }
        $key = "$($r.Allow)|$line"
        if ($seenPat.Add($key)) { $null = $rules.Add($r) }
    }

    # ---- сборка ----
    $out = New-Object System.Collections.ArrayList
    $id = 1
    $chunk = {
        param($set, [string]$dt, [bool]$allow)
        $arr = @($set)
        for ($i = 0; $i -lt $arr.Count; $i += 2000) {
            $part = $arr[$i..([Math]::Min($i + 1999, $arr.Count - 1))]
            $x = [PSCustomObject]@{ Allow = $allow; Domains = $part; Types = @(); NotTypes = @(); DomainType = $dt; Init = @(); NotInit = @(); Case = $false; Important = $false; Pattern = '' }
            $null = $out.Add((ConvertTo-CgDnrRule $x $script:id))
            $script:id++
        }
    }
    $script:id = 1
    & $chunk $blockDom '' $false
    & $chunk $blockDom3p 'thirdParty' $false
    & $chunk $allowDom '' $true
    $id = $script:id
    $dropped = 0
    foreach ($r in $rules) {
        if ($out.Count -ge $script:CgAdBlockMaxRules) { $dropped++; continue }
        $r | Add-Member -NotePropertyName Domains -NotePropertyValue $null -Force
        $null = $out.Add((ConvertTo-CgDnrRule $r $id))
        $id++
    }

    $cssJson = New-Object System.Text.StringBuilder
    $null = $cssJson.Append('{')
    $first = $true
    foreach ($d in ($css.Keys | Sort-Object)) {
        if (-not $first) { $null = $cssJson.Append(',') }
        $first = $false
        $null = $cssJson.Append((ConvertTo-CgJsonString $d)).Append(':').Append((ConvertTo-CgJsonArray ($css[$d] | Select-Object -Unique)))
    }
    $null = $cssJson.Append('}')

    return [PSCustomObject]@{
        RulesJson   = '[' + ($out -join ",`n") + ']'
        CssJson     = $cssJson.ToString()
        RuleCount   = $out.Count
        DomainCount = $blockDom.Count + $blockDom3p.Count
        CssCount    = $cssCount
        Skipped     = $skipped
        Dropped     = $dropped
    }
}

# Скачать списки, перевести, положить в рабочую копию расширения.
function Update-CgAdBlockLists {
    param([scriptblock]$Progress)
    $say = { param($t) if ($Progress) { & $Progress $t } }
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }

    $inst = Install-CgAdBlockFiles
    if (-not $inst.Ok) { return [PSCustomObject]@{ Ok = $false; Message = $inst.Message } }
    $dir = $inst.Dir

    $all = New-Object System.Collections.Generic.List[string]
    $got = @()
    foreach ($l in $script:CgAdBlockLists) {
        & $say "скачиваю $($l.Name)..."
        try {
            $r = Invoke-WebRequest -UseBasicParsing -Uri $l.Url -TimeoutSec 60 -ErrorAction Stop
            $text = $r.Content
            if ($text -is [byte[]]) { $text = [Text.Encoding]::UTF8.GetString($text) }
            # Invoke-WebRequest в Windows PowerShell читает текст без
            # кодировки в заголовке как Latin-1: перечитываем байты как UTF-8
            if ($r.RawContentStream) { $text = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) }
            if ("$text" -notmatch '^\s*\[Adblock') { throw 'это не список Adblock' }
            $all.AddRange([string[]]($text -split "`r?`n"))
            $got += $l.Name
        } catch {
            Write-CgLog 'WARN' ("Блокировщик: не скачан $($l.Name): $($_.Exception.Message)")
        }
    }
    if (-not $got.Count) {
        return [PSCustomObject]@{ Ok = $false; Message = 'Ни один список не скачался. Встроенные правила продолжают работать.' }
    }

    & $say "перевожу $($all.Count) строк в правила браузера..."
    $c = ConvertFrom-CgFilterLists $all.ToArray()

    $enc = New-Object System.Text.UTF8Encoding $false   # браузеру — без BOM
    [IO.File]::WriteAllText((Join-Path $dir 'rules\lists.json'), $c.RulesJson, $enc)
    [IO.File]::WriteAllText((Join-Path $dir 'data\lists-cosmetic.json'), $c.CssJson, $enc)
    $date = (Get-Date).ToString('dd.MM.yyyy')
    $meta = '{"date":' + (ConvertTo-CgJsonString $date) + ',"network":' + ($c.RuleCount + $c.DomainCount) +
            ',"cosmetic":' + $c.CssCount + ',"sources":' + (ConvertTo-CgJsonArray $got) + '}'
    [IO.File]::WriteAllText((Join-Path $dir 'data\lists-meta.json'), $meta, $enc)
    # Старый индекс правил браузер иначе мог бы и дальше брать вместо
    # новых списков. Нет индекса — браузер построит его заново.
    try { Remove-Item -LiteralPath (Join-Path $dir '_metadata') -Recurse -Force -ErrorAction Stop } catch { }

    Write-CgLog 'INFO' ("Блокировщик: списки $($got -join ', '): правил $($c.RuleCount), доменов $($c.DomainCount), скрытий $($c.CssCount), не переведено $($c.Skipped), сверх лимита $($c.Dropped)")
    return [PSCustomObject]@{
        Ok = $true; Dir = $dir; Sources = $got
        Rules = $c.RuleCount; Domains = $c.DomainCount; Cosmetic = $c.CssCount; Dropped = $c.Dropped
        Message = ('Списки {0}: доменов {1}, правил {2}, правил скрытия {3}' -f ($got -join ' + '), $c.DomainCount, $c.RuleCount, $c.CssCount)
    }
}

# ------------------------------------------------------------
#  Подключено ли расширение и где
#
#  Распакованное расширение браузер не копирует к себе, а
#  запоминает путь в настройках профиля. По этому пути и ищем.
# ------------------------------------------------------------
function Get-CgAdBlockStatus {
    $dir = Get-CgAdBlockDir
    $st = [PSCustomObject]@{ Dir = $dir; Copied = (Test-Path -LiteralPath (Join-Path $dir 'manifest.json')); Lists = ''; Network = 0; Cosmetic = 0; LoadedIn = @() }
    try {
        $m = Get-Content -LiteralPath (Join-Path $dir 'data\lists-meta.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        $st.Lists = "$($m.date)"; $st.Network = [int]$m.network; $st.Cosmetic = [int]$m.cosmetic
    } catch { }
    $needle = ($dir.TrimEnd('\') -replace '\\', '\\').ToLowerInvariant()
    foreach ($b in (Get-CgBrowsers)) {
        if ($b.Name -eq 'Firefox') { continue }
        foreach ($p in (Get-ChildItem -LiteralPath $b.Root -Directory -ErrorAction SilentlyContinue)) {
            foreach ($f in @('Secure Preferences', 'Preferences')) {
                $fp = Join-Path $p.FullName $f
                if (-not (Test-Path -LiteralPath $fp)) { continue }
                try {
                    $txt = [IO.File]::ReadAllText($fp).ToLowerInvariant()
                    if ($txt.Contains($needle)) { $st.LoadedIn += "$($b.Name) ($($p.Name))"; break }
                } catch { }
            }
        }
    }
    $st.LoadedIn = @($st.LoadedIn | Select-Object -Unique)
    return $st
}

# Страница расширений нужного браузера. Сам браузер распакованное
# расширение без человека не подключит — это его защита, и обходить
# её мы не будем. Путь кладём в буфер обмена.
function Open-CgAdBlockInBrowser {
    param([string]$Browser = '')
    $dir = Get-CgAdBlockDir
    try { Set-Clipboard -Value $dir } catch { }
    $list = @(Get-CgBrowsers | Where-Object { $_.Name -ne 'Firefox' })
    if ($Browser) { $list = @($list | Where-Object { $_.Name -eq $Browser }) }
    foreach ($b in $list) {
        $exe = @($b.Exe | Where-Object { Test-Path -LiteralPath $_ }) | Select-Object -First 1
        if (-not $exe) { continue }
        $url = switch ($b.Name) { 'Edge' { 'edge://extensions' } 'Brave' { 'brave://extensions' } 'Opera' { 'opera://extensions' } 'Vivaldi' { 'vivaldi://extensions' } default { 'chrome://extensions' } }
        try { Start-Process -FilePath $exe -ArgumentList $url; return [PSCustomObject]@{ Ok = $true; Browser = $b.Name; Dir = $dir } } catch { }
    }
    return [PSCustomObject]@{ Ok = $false; Browser = ''; Dir = $dir }
}
