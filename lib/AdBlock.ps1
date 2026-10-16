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

# Каталог списков. Default — что включено, пока человек сам не выбрал.
# Свои адреса — в настройке AdListsCustom (только https).
$script:CgAdBlockCatalog = @(
    @{ Id = 'easylist';    Name = 'EasyList';            Default = $true;  Url = 'https://easylist.to/easylist/easylist.txt';               Note = 'основной мировой список рекламы' }
    @{ Id = 'ruadlist';    Name = 'RuAdList';            Default = $true;  Url = 'https://easylist-downloads.adblockplus.org/ruadlist.txt'; Note = 'реклама на русскоязычных сайтах' }
    @{ Id = 'easyprivacy'; Name = 'EasyPrivacy';         Default = $true;  Url = 'https://easylist.to/easylist/easyprivacy.txt';            Note = 'счётчики, трекеры и сборщики статистики' }
    @{ Id = 'peterlowe';   Name = "Peter Lowe's list";   Default = $true;  Url = 'https://pgl.yoyo.org/adservers/serverlist.php?hostformat=adblockplus&showintro=0&mimetype=plaintext'; Note = 'короткий список рекламных и следящих серверов' }
    @{ Id = 'adguard-ru';  Name = 'AdGuard Russian';     Default = $false; Url = 'https://filters.adtidy.org/extension/ublock/filters/1.txt'; Note = 'второй взгляд на рунет: ловит то, что пропускает RuAdList' }
    @{ Id = 'adguard';     Name = 'AdGuard Base';        Default = $false; Url = 'https://filters.adtidy.org/extension/ublock/filters/2_without_easylist.txt'; Note = 'мировая реклама сверх EasyList' }
    @{ Id = 'annoyance';   Name = "Fanboy's Annoyance";  Default = $false; Url = 'https://secure.fanboy.co.nz/fanboy-annoyance.txt';        Note = 'всплывающие окна, баннеры cookie, виджеты соцсетей' }
    @{ Id = 'antiadblock'; Name = 'Anti-Adblock Killer'; Default = $false; Url = 'https://easylist-downloads.adblockplus.org/antiadblockfilters.txt'; Note = 'сайты, которые требуют выключить блокировщик' }
)

# Выбранные списки: настройка AdLists (Id из каталога) и AdListsCustom
# (свои адреса). Пока настройки нет — списки по умолчанию.
function Get-CgAdBlockLists {
    $s = Get-CgSettings
    $ids = @($script:CgAdBlockCatalog | Where-Object { $_.Default } | ForEach-Object { $_.Id })
    if ($null -ne $s.AdLists) { $ids = @($s.AdLists) }
    $out = @($script:CgAdBlockCatalog | Where-Object { $ids -contains $_.Id } | ForEach-Object { @{ Name = $_.Name; Url = $_.Url } })
    foreach ($u in @($s.AdListsCustom)) {
        $u = "$u".Trim()
        if ($u -notmatch '^https://[^\s/]+/\S*$') { continue }
        $name = $u -replace '^https://', ''
        if ($name.Length -gt 48) { $name = $name.Substring(0, 45) + '...' }
        $out += @{ Name = $name; Url = $u }
    }
    return $out
}

# Сколько правил в одном файле. Chrome гарантирует каждому расширению
# 30 000 статических правил, а сверх того выделяет из общего запаса
# браузера. Поэтому правила списков лежат в четырёх файлах: первый
# браузер включает всегда, остальные — пока хватает общего запаса.
$script:CgAdBlockMaxRules = 29000
$script:CgAdBlockRuleFiles = @('rules\lists.json', 'rules\lists-2.json', 'rules\lists-3.json', 'rules\lists-4.json')

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

$script:CgAdBlockListFiles = @($script:CgAdBlockRuleFiles) + @('data\lists-cosmetic.json', 'data\lists-generic.json', 'data\lists-meta.json', 'data\build.json')

function Write-CgAdBlockText {
    param([string]$Path, [string]$Text)
    [IO.File]::WriteAllText($Path, $Text, (New-Object System.Text.UTF8Encoding $false))   # браузеру — без BOM
}

# Отметка сборки. Расширение раз в минуту сверяет её с той, с которой
# загрузилось, и если программа что-то поменяла — перезагружается само.
# Так новый код и свежие списки доходят до браузера без кнопки
# «Обновить» на странице расширений.
function Set-CgAdBlockBuild {
    param([string]$Dir)
    $stamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss') + '-' + [Guid]::NewGuid().ToString('N').Substring(0, 6)
    try { Write-CgAdBlockText (Join-Path $Dir 'data\build.json') ('{"stamp":"' + $stamp + '"}') } catch { }
}

# Пустые файлы правил, которых нет в копии, сделанной старой версией:
# без них браузер не загрузит расширение с новым manifest.json.
function Add-CgAdBlockRuleStubs {
    param([string]$Dir)
    foreach ($r in $script:CgAdBlockRuleFiles) {
        $p = Join-Path $Dir $r
        if (-not (Test-Path -LiteralPath $p)) { Write-CgAdBlockText $p '[]' }
    }
}

# Привести рабочую копию к коду из программы: только изменившиеся
# файлы, скачанные списки не трогаются. Вызывается при каждом запуске
# окна: после обновления программы расширение догоняет её само.
function Sync-CgAdBlockFiles {
    $src = Get-CgAdBlockSrc
    $dst = Join-Path (Join-Path $env:LOCALAPPDATA 'CookieGuard') 'adblock-ext'
    if (-not (Test-Path -LiteralPath (Join-Path $dst 'manifest.json'))) { return 0 }   # расширение не ставили
    if (-not (Test-Path -LiteralPath (Join-Path $src 'manifest.json'))) { return 0 }
    $base = $src.TrimEnd('\').Length + 1
    $n = 0
    foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File -Force)) {
        $rel = $f.FullName.Substring($base)
        if ($script:CgAdBlockListFiles -contains $rel) { continue }
        $to = Join-Path $dst $rel
        if ((Test-Path -LiteralPath $to) -and (Get-Item -LiteralPath $to).Length -eq $f.Length -and
            [Linq.Enumerable]::SequenceEqual([byte[]][IO.File]::ReadAllBytes($to), [byte[]][IO.File]::ReadAllBytes($f.FullName))) { continue }
        $dir = Split-Path -Parent $to
        if (-not (Test-Path -LiteralPath $dir)) { $null = New-Item -ItemType Directory -Path $dir -Force }
        try { Copy-Item -LiteralPath $f.FullName -Destination $to -Force -ErrorAction Stop; $n++ } catch { }
    }
    Add-CgAdBlockRuleStubs $dst
    if ($n) {
        Set-CgAdBlockBuild $dst
        Write-CgLog 'INFO' "Блокировщик: код расширения обновлён (файлов: $n), браузер перезагрузит его сам"
    }
    return $n
}

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
    Add-CgAdBlockRuleStubs $dst
    Set-CgAdBlockBuild $dst
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
        Init = @(); NotInit = @(); Case = $false; Important = $false; NotReq = @(); Methods = @()
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
            } elseif ($o -eq 'all') {
                # все типы — то же, что без указания типа
            } elseif ($o.StartsWith('redirect=') -and -not $allow) {
                # «заменить заглушкой»: заглушек у нас нет, но сам запрос
                # всё равно рекламный — блокируем
            } elseif ($o.StartsWith('denyallow=')) {
                foreach ($d in ($o.Substring(10) -split '\|')) { if ($script:CgAbDomain.IsMatch($d)) { $r.NotReq += $d } }
                if (-not $r.NotReq.Count) { return $null }
            } elseif ($o.StartsWith('method=')) {
                foreach ($mm in ($o.Substring(7) -split '\|')) {
                    if ($mm -in @('get', 'post', 'head', 'put', 'delete', 'patch', 'options', 'connect')) { $r.Methods += $mm }
                }
                if (-not $r.Methods.Count) { return $null }
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
    if (@($R.NotReq).Count)  { $c += '"excludedRequestDomains":' + (ConvertTo-CgJsonArray ($R.NotReq | Select-Object -Unique)) }
    if (@($R.Methods).Count) { $c += '"requestMethods":' + (ConvertTo-CgJsonArray ($R.Methods | Select-Object -Unique)) }
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
    # Общие правила скрытия (без сайта: «##.ad-banner»). Подставлять все
    # на каждую страницу нельзя — их десятки тысяч. Поэтому каждое
    # разложено по первому классу или id в селекторе; страница сообщает,
    # какие классы и id в ней есть, и получает только подходящие.
    $genCls = @{}; $genIds = @{}
    $genKill = New-Object 'System.Collections.Generic.HashSet[string]'   # «#@#селектор» — отменён везде
    $exc = @{}                                                            # сайт → отменённые на нём селекторы
    $genOff = New-Object 'System.Collections.Generic.HashSet[string]'    # $generichide: общие на сайте не нужны
    $genCount = 0
    $tokRx = [regex]'^[a-zA-Z*]*([#.])([A-Za-z_][\w-]*)'

    foreach ($raw in $Lines) {
        $line = $raw.Trim()
        if (-not $line -or $line.StartsWith('!') -or $line.StartsWith('[')) { continue }

        # ---- скрытие элементов ----
        if ($line.Contains('#')) {
            $m = [regex]::Match($line, '^([^#]*)(##|#@#|#\?#|#\$#|#%#|#@\?#|#@\$#)(.+)$')
            if ($m.Success) {
                $sep = $m.Groups[2].Value
                if ($sep -ne '##' -and $sep -ne '#@#') { $skipped++; continue }
                $all = @($m.Groups[1].Value -split ',' | ForEach-Object { $_.Trim().ToLowerInvariant() } | Where-Object { $_ })
                $doms = @($all | Where-Object { -not $_.StartsWith('~') -and $script:CgAbDomain.IsMatch($_) })
                $nots = @($all | Where-Object { $_.StartsWith('~') } | ForEach-Object { $_.Substring(1) } | Where-Object { $script:CgAbDomain.IsMatch($_) })
                $sel = $m.Groups[3].Value.Trim()
                if (-not $sel -or $script:CgAbBadCss.IsMatch($sel) -or $sel.StartsWith('+js(') -or $sel.Contains('{')) { $skipped++; continue }
                if ($sep -eq '#@#') {
                    if ($doms.Count) { foreach ($d in $doms) { if (-not $exc.ContainsKey($d)) { $exc[$d] = New-Object System.Collections.ArrayList }; $null = $exc[$d].Add($sel) } }
                    elseif (-not $all.Count) { $null = $genKill.Add($sel) }
                    continue
                }
                if ($doms.Count) {
                    foreach ($d in $doms) {
                        if (-not $css.ContainsKey($d)) { $css[$d] = New-Object System.Collections.ArrayList }
                        $null = $css[$d].Add($sel)
                        $cssCount++
                    }
                    continue
                }
                if ($all.Count -and -not $nots.Count) { $skipped++; continue }   # сайты указаны, но не разобрались
                $tm = $tokRx.Match($sel)
                if (-not $tm.Success) { $skipped++; continue }   # без класса или id — слишком дорого на каждой странице
                $bag = $(if ($tm.Groups[1].Value -eq '.') { $genCls } else { $genIds })
                $k = $tm.Groups[2].Value
                if (-not $bag.ContainsKey($k)) { $bag[$k] = New-Object System.Collections.ArrayList }
                $null = $bag[$k].Add($sel)
                $genCount++
                foreach ($d in $nots) { if (-not $exc.ContainsKey($d)) { $exc[$d] = New-Object System.Collections.ArrayList }; $null = $exc[$d].Add($sel) }
                continue
            }
        }
        if ($line.Contains('$$')) { $skipped++; continue }

        # сайты, где общие правила скрытия выключены самим списком
        $gm = [regex]::Match($line, '^@@\|\|([a-z0-9.-]+)\^?\$(?:[^,]*,)*(generichide|ghide|elemhide|ehide)(,|$)')
        if ($gm.Success) {
            if ($script:CgAbDomain.IsMatch($gm.Groups[1].Value)) { $null = $genOff.Add($gm.Groups[1].Value) }
            continue
        }

        # ---- сетевые ----
        $r = ConvertFrom-CgNetRule $line
        if (-not $r) { $skipped++; continue }
        $pm = $script:CgAbPlainDomain.Match($r.Pattern)
        $plain = ($pm.Success -and -not $r.Types.Count -and -not $r.NotTypes.Count -and -not $r.Init.Count -and -not $r.NotInit.Count -and -not $r.Case -and -not $r.Important -and -not $r.NotReq.Count -and -not $r.Methods.Count)
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
    # Остальные правила — по файлам, в каждом номера с единицы
    $parts = New-Object System.Collections.ArrayList
    $null = $parts.Add($out)
    $id = $script:id
    $dropped = 0
    $total = $out.Count
    foreach ($r in $rules) {
        $cur = $parts[$parts.Count - 1]
        if ($cur.Count -ge $script:CgAdBlockMaxRules) {
            if ($parts.Count -ge $script:CgAdBlockRuleFiles.Count) { $dropped++; continue }
            $cur = New-Object System.Collections.ArrayList
            $null = $parts.Add($cur)
            $id = 1
        }
        $r | Add-Member -NotePropertyName Domains -NotePropertyValue $null -Force
        $null = $cur.Add((ConvertTo-CgDnrRule $r $id))
        $id++
        $total++
    }

    $map = {
        param($h, [scriptblock]$Filter)
        $sb = New-Object System.Text.StringBuilder
        $null = $sb.Append('{')
        $first = $true
        foreach ($k in ($h.Keys | Sort-Object)) {
            $v = @($h[$k] | Select-Object -Unique)
            if ($Filter) { $v = @($v | Where-Object $Filter) }
            if (-not $v.Count) { continue }
            if (-not $first) { $null = $sb.Append(',') }
            $first = $false
            $null = $sb.Append((ConvertTo-CgJsonString $k)).Append(':').Append((ConvertTo-CgJsonArray $v))
        }
        $null = $sb.Append('}')
        $sb.ToString()
    }
    $notKilled = { -not $genKill.Contains($_) }
    $gen = '{"cls":' + (& $map $genCls $notKilled) + ',"ids":' + (& $map $genIds $notKilled) +
           ',"exc":' + (& $map $exc $null) + ',"off":' + (ConvertTo-CgJsonArray @($genOff | Sort-Object)) + '}'

    return [PSCustomObject]@{
        RulesJson    = @($parts | ForEach-Object { '[' + ($_ -join ",`n") + ']' })
        CssJson      = (& $map $css $null)
        GenericJson  = $gen
        RuleCount    = $total
        DomainCount  = $blockDom.Count + $blockDom3p.Count
        CssCount     = $cssCount
        GenericCount = $genCount
        Skipped      = $skipped
        Dropped      = $dropped
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
    foreach ($l in @(Get-CgAdBlockLists)) {
        & $say "скачиваю $($l.Name)..."
        try {
            $r = Invoke-WebRequest -UseBasicParsing -Uri $l.Url -TimeoutSec 60 -ErrorAction Stop
            $text = $r.Content
            if ($text -is [byte[]]) { $text = [Text.Encoding]::UTF8.GetString($text) }
            # Invoke-WebRequest в Windows PowerShell читает текст без
            # кодировки в заголовке как Latin-1: перечитываем байты как UTF-8
            if ($r.RawContentStream) { $text = [Text.Encoding]::UTF8.GetString($r.RawContentStream.ToArray()) }
            # заголовок «[Adblock Plus 2.0]» есть не у всех (у AdGuard — «!»);
            # главное, чтобы это был список правил, а не страница сайта
            if ("$text" -notmatch '^\s*!?\s*\[Adblock' -and "$text" -notmatch '(?m)^\|\|[a-z0-9.-]+\^') { throw 'это не список Adblock' }
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

    for ($i = 0; $i -lt $script:CgAdBlockRuleFiles.Count; $i++) {
        $txt = '[]'
        if ($i -lt @($c.RulesJson).Count) { $txt = @($c.RulesJson)[$i] }
        Write-CgAdBlockText (Join-Path $dir $script:CgAdBlockRuleFiles[$i]) $txt
    }
    Write-CgAdBlockText (Join-Path $dir 'data\lists-cosmetic.json') $c.CssJson
    Write-CgAdBlockText (Join-Path $dir 'data\lists-generic.json') $c.GenericJson
    $date = (Get-Date).ToString('dd.MM.yyyy')
    $meta = '{"date":' + (ConvertTo-CgJsonString $date) + ',"network":' + ($c.RuleCount + $c.DomainCount) +
            ',"cosmetic":' + ($c.CssCount + $c.GenericCount) + ',"sources":' + (ConvertTo-CgJsonArray $got) + '}'
    Write-CgAdBlockText (Join-Path $dir 'data\lists-meta.json') $meta
    # Старый индекс правил браузер иначе мог бы и дальше брать вместо
    # новых списков. Нет индекса — браузер построит его заново.
    try { Remove-Item -LiteralPath (Join-Path $dir '_metadata') -Recurse -Force -ErrorAction Stop } catch { }
    Set-CgAdBlockBuild $dir

    Write-CgLog 'INFO' ("Блокировщик: списки $($got -join ', '): правил $($c.RuleCount), доменов $($c.DomainCount), скрытий по сайтам $($c.CssCount), общих скрытий $($c.GenericCount), не переведено $($c.Skipped), сверх лимита $($c.Dropped)")
    return [PSCustomObject]@{
        Ok = $true; Dir = $dir; Sources = $got
        Rules = $c.RuleCount; Domains = $c.DomainCount; Cosmetic = $c.CssCount + $c.GenericCount; Dropped = $c.Dropped
        Message = ('Списки {0}: доменов {1}, правил {2}, правил скрытия {3}' -f ($got -join ' + '), $c.DomainCount, $c.RuleCount, ($c.CssCount + $c.GenericCount))
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
