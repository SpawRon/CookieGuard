# ============================================================
#  CookieGuard - Hosts.ps1
#  Файл hosts: разбор, сверка с запомненным и «кто это сделал».
#
#  Зачем отдельно. hosts — самый дешёвый способ увести человека
#  на чужой сервер: одна строка, и банк, почта или обновления
#  антивируса открываются там, где скажет вирус. Проверка раз в
#  сканирование видела лишь «перенаправлений столько-то» и не
#  отличала обход блокировки Telegram, вписанный Zapret, от
#  подмены адреса банка.
#
#  Теперь:
#    — запомненная копия hosts лежит в state\hosts-snapshot.txt
#      и переживает перезагрузку и обновление: изменение, сделанное,
#      пока программа не работала, тоже будет замечено;
#    — каждое изменение разбирается построчно: что добавили, что
#      убрали, в каком разделе (Zapret, CyberMania и т.п. подписывают
#      свои разделы комментариями);
#    — на hosts и папку etc ставится аудит записи, поэтому Windows
#      сама говорит, какая программа писала в файл;
#    — прежняя версия сохраняется в улики, её можно вернуть.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

function Get-CgHostsPath { Join-Path $env:windir 'System32\drivers\etc\hosts' }
function Get-CgHostsDir  { Join-Path $env:windir 'System32\drivers\etc' }
function Get-CgHostsSnapshotPath { Join-Path (Get-CgDir 'state') 'hosts-snapshot.txt' }

function Read-CgHostsText {
    $p = Get-CgHostsPath
    if (-not (Test-Path -LiteralPath $p)) { return '' }
    # Файл держат открытым DNS-клиент и сами правящие его программы.
    # Читаем с общим доступом и с повтором, а не валимся на занятости.
    for ($i = 0; $i -lt 5; $i++) {
        try {
            $fs = New-Object IO.FileStream($p, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
            try {
                $sr = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8, $true)
                return $sr.ReadToEnd()
            } finally { $fs.Dispose() }
        } catch { Start-Sleep -Milliseconds 40 }
    }
    return $null
}

# ------------------------------------------------------------
#  Разбор
#
#  Раздел — последний осмысленный комментарий перед строками.
#  «### CyberMania CCleaner Block ###», «# --- Telegram Proxy
#  (auto-managed by Zapret 2 GUI) ---» и т.п. Строка с END или
#  «конец» и пустая строка закрывают раздел. Подпись раздела пишет та же программа,
#  что вписала строки, — вирус тоже может назваться Zapret. Поэтому
#  раздел показывается как подсказка, а не как оправдание.
# ------------------------------------------------------------
function ConvertFrom-CgHostsText {
    param([string]$Text)
    $out = New-Object System.Collections.ArrayList
    if (-not $Text) { return @() }
    $section = ''
    $n = 0
    foreach ($raw in ($Text -split "`r?`n")) {
        $n++
        $t = $raw.Trim()
        # пустая строка закрывает раздел: программы отделяют свои блоки
        # пустой строкой, и строка, дописанная после, — уже не их
        if (-not $t) { $section = ''; continue }
        if ($t.StartsWith('#')) {
            $c = $t.TrimStart('#').Trim().Trim('-', '=', '#', ' ').Trim()
            if (-not $c) { continue }
            # стандартная шапка Microsoft — не раздел
            if ($c -match '(?i)copyright|sample hosts|mappings of ip|individual line|first column|at least one|comments \(such|for example|rhino\.acme|x\.acme|localhost name resolution|^\s*(127\.0\.0\.1|::1)\s+localhost') { continue }
            if ($c -match '(?i)(^|\W)(end|конец)(\W|$)') { $section = ''; continue }
            $section = $c
            continue
        }
        $body = ($t -split '#', 2)[0].Trim()
        $parts = @($body -split '\s+' | Where-Object { $_ })
        if ($parts.Count -lt 2) { continue }
        $ip = $parts[0]
        foreach ($h in $parts[1..($parts.Count - 1)]) {
            $isBlock = ($ip -match '^(0\.0\.0\.0|127\.\d+\.\d+\.\d+|::1?|0:0:0:0:0:0:0:[01])$')
            $null = $out.Add([PSCustomObject]@{
                Ip = $ip; Host = $h.ToLowerInvariant(); Section = $section; LineNo = $n
                Kind = $(if ($isBlock) { 'block' } else { 'redirect' })
                Key = ('{0} {1}' -f $ip, $h.ToLowerInvariant())
            })
        }
    }
    return @($out)
}

# ------------------------------------------------------------
#  Насколько опасна строка
# ------------------------------------------------------------

# Собственные сети Telegram (опубликованы самим Telegram). Строка
# «149.154.167.220 api.telegram.org» указывает на сервер Telegram —
# так обходят блокировку, а не перехватывают трафик.
$script:CgTelegramNets = @('91.108.4.0/22', '91.108.8.0/22', '91.108.12.0/22', '91.108.16.0/22',
                           '91.108.20.0/22', '91.108.56.0/22', '91.105.192.0/23', '149.154.160.0/20',
                           '185.76.151.0/24', '95.161.64.0/20')

function Test-CgIpInCidr {
    param([string]$Ip, [string]$Cidr)
    try {
        $a = [Net.IPAddress]::Parse($Ip)
        if ($a.AddressFamily -ne 'InterNetwork') { return $false }
        $net, $bits = $Cidr -split '/'
        $n = [Net.IPAddress]::Parse($net).GetAddressBytes()
        $b = $a.GetAddressBytes()
        [Array]::Reverse($n); [Array]::Reverse($b)
        $mask = [uint32]([math]::Pow(2, 32) - [math]::Pow(2, 32 - [int]$bits))
        return (([BitConverter]::ToUInt32($b, 0) -band $mask) -eq ([BitConverter]::ToUInt32($n, 0) -band $mask))
    } catch { return $false }
}

function Test-CgTelegramIp {
    param([string]$Ip)
    foreach ($c in $script:CgTelegramNets) { if (Test-CgIpInCidr $Ip $c) { return $true } }
    return $false
}

# Куда подмена бьёт больнее всего: входы в аккаунты, деньги, почта,
# обновления и сама защита.
$script:CgHostsSensitive = '(?i)(^|\.)(accounts\.google\.com|google\.com|gmail\.com|youtube\.com|login\.microsoftonline\.com|login\.live\.com|microsoft\.com|live\.com|outlook\.com|apple\.com|icloud\.com|paypal\.com|github\.com|githubusercontent\.com|steamcommunity\.com|steampowered\.com|discord\.com|telegram\.org|t\.me|web\.telegram\.org|whatsapp\.com|vk\.com|mail\.ru|yandex\.ru|ya\.ru|gosuslugi\.ru|sberbank\.ru|online\.sberbank\.ru|tinkoff\.ru|tbank\.ru|alfabank\.ru|vtb\.ru|binance\.com|bybit\.com|okx\.com|coinbase\.com|metamask\.io|blockchain\.com|facebook\.com|instagram\.com|twitter\.com|x\.com|amazon\.com|ozon\.ru|wildberries\.ru|avito\.ru)$'

# Блокировка этих адресов — классика вирусов: антивирус перестаёт
# обновляться, проверка на VirusTotal и обновление CookieGuard
# перестают работать. Её делают и «активаторы» платных программ —
# поэтому это вопрос к человеку, а не приговор.
$script:CgHostsProtection = '(?i)(eset\.com|eset\.ru|esetnod32|kaspersky|drweb|malwarebytes|mwbsys\.com|avast\.com|avg\.com|bitdefender|norton|symantec|mcafee|sophos|f-secure|trendmicro|360totalsecurity|virustotal\.com|windowsupdate\.com|update\.microsoft\.com|wdcp\.microsoft\.com|wdcpalt\.microsoft\.com|definitionupdates\.microsoft\.com|smartscreen|api\.github\.com|codeload\.github\.com)'

function Get-CgHostsEntryVerdict {
    param($Entry)
    if ($Entry.Kind -eq 'block') {
        if ($Entry.Host -match $script:CgHostsProtection) {
            return [PSCustomObject]@{ Severity = 'WARN'; Why = 'блокирует обновления или проверку защиты' }
        }
        return [PSCustomObject]@{ Severity = 'NOTE'; Why = 'блокировка (реклама, телеметрия)' }
    }
    if ($Entry.Host -match '(?i)telegram|t\.me$|telesco\.pe|tg\.dev' -and (Test-CgTelegramIp $Entry.Ip)) {
        return [PSCustomObject]@{ Severity = 'NOTE'; Why = 'адрес из собственной сети Telegram — обход блокировки, не перехват' }
    }
    if ($Entry.Host -match 'docker\.internal|kubernetes\.docker|\.local$|\.lan$|\.home$|\.test$|\.localhost$') {
        return [PSCustomObject]@{ Severity = 'NOTE'; Why = 'локальное имя' }
    }
    if ($Entry.Ip -match '^(10\.|192\.168\.|172\.(1[6-9]|2\d|3[01])\.)') {
        if ($Entry.Host -match $script:CgHostsSensitive) {
            return [PSCustomObject]@{ Severity = 'CRIT'; Why = 'важный сайт направлен на адрес внутри локальной сети' }
        }
        return [PSCustomObject]@{ Severity = 'NOTE'; Why = 'адрес в локальной сети' }
    }
    if ($Entry.Host -match $script:CgHostsSensitive) {
        return [PSCustomObject]@{ Severity = 'CRIT'; Why = 'вход в аккаунты, деньги или почта направлены на заданный вручную адрес' }
    }
    return [PSCustomObject]@{ Severity = 'WARN'; Why = 'сайт направлен на заданный вручную адрес' }
}

function Get-CgSevRank { param([string]$S) @{ 'CRIT' = 4; 'WARN' = 3; 'NOTE' = 2; 'INFO' = 1; 'OK' = 0 }[$S] }

# ------------------------------------------------------------
#  Сверка двух версий
# ------------------------------------------------------------
function Compare-CgHosts {
    param([string]$Old, [string]$New)
    $o = @(ConvertFrom-CgHostsText $Old)
    $n = @(ConvertFrom-CgHostsText $New)
    $oc = @{}; foreach ($e in $o) { $oc[$e.Key] = 1 + [int]$oc[$e.Key] }
    $nc = @{}; foreach ($e in $n) { $nc[$e.Key] = 1 + [int]$nc[$e.Key] }
    $added = @(); $removed = @()
    $seen = @{}
    foreach ($e in $n) {
        if ($seen.ContainsKey($e.Key)) { continue }
        $seen[$e.Key] = $true
        if ([int]$nc[$e.Key] -gt [int]$oc[$e.Key]) { $added += $e }
    }
    $seen = @{}
    foreach ($e in $o) {
        if ($seen.ContainsKey($e.Key)) { continue }
        $seen[$e.Key] = $true
        if ([int]$oc[$e.Key] -gt [int]$nc[$e.Key]) { $removed += $e }
    }
    return [PSCustomObject]@{ Added = $added; Removed = $removed; OldCount = $o.Count; NewCount = $n.Count }
}

function Get-CgHostsSnapshot {
    $p = Get-CgHostsSnapshotPath
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    try { return [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8) } catch { return $null }
}

function Save-CgHostsSnapshot {
    param([string]$Text)
    try {
        return (Write-CgFileAtomic (Get-CgHostsSnapshotPath) "$Text")
    } catch { return $false }
}

# Прежнюю версию — в улики: из неё hosts можно вернуть как был.
function Save-CgHostsEvidence {
    param([string]$Text, [string]$Tag)
    try {
        $f = Join-Path (Get-CgDir 'evidence') ('{0}-hosts-{1}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'), $Tag)
        [IO.File]::WriteAllText($f, "$Text", (New-Object Text.UTF8Encoding $false))
        return $f
    } catch { return '' }
}

# ------------------------------------------------------------
#  Аудит записи в hosts
#
#  Только запись, удаление и смена прав: чтение hosts делает
#  каждый запрос DNS, и его аудит утопил бы журнал. На папку etc —
#  наследуемое правило: многие программы пишут hosts через замену
#  (новый файл рядом, потом переименование), и правило с одного
#  файла при этом пропадает, а с папки — наследуется заново.
# ------------------------------------------------------------
$script:CgHostsAuditRights = [System.Security.AccessControl.FileSystemRights]'WriteData, AppendData, Delete, ChangePermissions, TakeOwnership'

function Test-CgHostsAudit {
    # $null — узнать нельзя (нет прав читать SACL)
    try {
        $everyone = New-Object System.Security.Principal.SecurityIdentifier 'S-1-1-0'
        $acl = Get-Acl -LiteralPath (Get-CgHostsPath) -Audit -ErrorAction Stop
        foreach ($r in @($acl.GetAuditRules($true, $true, [System.Security.Principal.SecurityIdentifier]))) {
            if ($r.IdentityReference -eq $everyone -and (($r.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::WriteData) -ne 0)) { return $true }
        }
        return $false
    } catch { return $null }
}

function Set-CgHostsAudit {
    param([switch]$Remove)
    $everyone = New-Object System.Security.Principal.SecurityIdentifier 'S-1-1-0'
    $flags = [System.Security.AccessControl.AuditFlags]::Success
    $ok = $true
    # сам файл
    try {
        $acl = Get-Acl -LiteralPath (Get-CgHostsPath) -Audit -ErrorAction Stop
        foreach ($r in @($acl.GetAuditRules($true, $false, [System.Security.Principal.SecurityIdentifier]))) {
            if ($r.IdentityReference -eq $everyone) { $null = $acl.RemoveAuditRule($r) }
        }
        if (-not $Remove) {
            $acl.AddAuditRule((New-Object System.Security.AccessControl.FileSystemAuditRule($everyone, $script:CgHostsAuditRights, $flags)))
        }
        Set-Acl -LiteralPath (Get-CgHostsPath) -AclObject $acl -ErrorAction Stop
    } catch { $ok = $false }
    # папка etc: появление нового файла и наследуемое правило на файлы
    try {
        $dir = Get-CgHostsDir
        $acl = Get-Acl -LiteralPath $dir -Audit -ErrorAction Stop
        foreach ($r in @($acl.GetAuditRules($true, $false, [System.Security.Principal.SecurityIdentifier]))) {
            if ($r.IdentityReference -eq $everyone) { $null = $acl.RemoveAuditRule($r) }
        }
        if (-not $Remove) {
            $acl.AddAuditRule((New-Object System.Security.AccessControl.FileSystemAuditRule($everyone,
                [System.Security.AccessControl.FileSystemRights]'CreateFiles, Delete, DeleteSubdirectoriesAndFiles',
                [System.Security.AccessControl.InheritanceFlags]::None, [System.Security.AccessControl.PropagationFlags]::None, $flags)))
            $acl.AddAuditRule((New-Object System.Security.AccessControl.FileSystemAuditRule($everyone, $script:CgHostsAuditRights,
                [System.Security.AccessControl.InheritanceFlags]::ObjectInherit, [System.Security.AccessControl.PropagationFlags]::InheritOnly, $flags)))
        }
        Set-Acl -LiteralPath $dir -AclObject $acl -ErrorAction Stop
    } catch { $ok = $false }
    return $ok
}

# ------------------------------------------------------------
#  Описание изменения человеческим языком
# ------------------------------------------------------------
function Format-CgHostsEntry {
    param($E)
    $v = Get-CgHostsEntryVerdict $E
    $sec = ''
    if ($E.Section) { $sec = "   [раздел «$($E.Section)»]" }
    return ('{0,-16} {1}   — {2}{3}' -f $E.Ip, $E.Host, $v.Why, $sec)
}

# Writers — кто писал в hosts за последние минуты (по журналу безопасности)
function New-CgHostsChangeReport {
    param([string]$Old, [string]$New, $Writers = @(), [switch]$WhileAway)
    $d = Compare-CgHosts $Old $New
    if (-not $d.Added.Count -and -not $d.Removed.Count) { return $null }

    $sev = 'NOTE'
    foreach ($e in $d.Added) {
        $v = Get-CgHostsEntryVerdict $e
        if ((Get-CgSevRank $v.Severity) -gt (Get-CgSevRank $sev)) { $sev = $v.Severity }
    }

    $who = ''
    $whoPath = ''; $whoName = ''; $whoPid = 0
    $ws = @($Writers)
    if ($ws.Count) {
        $w = $ws[-1]
        $whoPath = $w.Path; $whoName = $w.Name; $whoPid = $w.ProcId
        $sig = Get-CgSignature $w.Path
        $who = "$($w.Name) (PID $($w.ProcId))`n            $($w.Path)`n            подпись: $($sig.Status) $($sig.Signer)"
        if ($ws.Count -gt 1) { $who += "`n            и ещё: " + (($ws[0..($ws.Count - 2)] | ForEach-Object { $_.Name } | Sort-Object -Unique) -join ', ') }
        # Доверенная вами программа (Zapret, ваш VPN) правит hosts —
        # это сведение, а не тревога. Блокировку защиты всё равно
        # показываем: о ней лучше знать.
        if (Get-Command Test-CgTrustedFile -ErrorAction SilentlyContinue) {
            if (Test-CgTrustedFile $w.Path) {
                $sev = $(if ($sev -eq 'CRIT') { 'WARN' } else { 'NOTE' })
                $who += "`n            вы пометили эту программу доверенной"
            }
        }
    } elseif ($WhileAway) {
        $who = 'неизвестно — файл изменили, пока CookieGuard не работал'
    } else {
        $who = 'неизвестно — аудит записи в hosts выключен (включается вместе с автозащитой)'
    }

    $lines = @()
    $lines += "Кто изменил: $who"
    $lines += "Записей было: $($d.OldCount), стало: $($d.NewCount)"
    if ($d.Added.Count) {
        $lines += ''
        $lines += "ДОБАВЛЕНО ($($d.Added.Count)):"
        $sorted = @($d.Added | Sort-Object @{ Expression = { -(Get-CgSevRank (Get-CgHostsEntryVerdict $_).Severity) } }, LineNo)
        foreach ($e in ($sorted | Select-Object -First 40)) { $lines += '  + ' + (Format-CgHostsEntry $e) }
        if ($sorted.Count -gt 40) { $lines += "  ... и ещё $($sorted.Count - 40)" }
    }
    if ($d.Removed.Count) {
        $lines += ''
        $lines += "УБРАНО ($($d.Removed.Count)):"
        foreach ($e in ($d.Removed | Select-Object -First 25)) { $lines += ('  − {0,-16} {1}' -f $e.Ip, $e.Host) }
        if ($d.Removed.Count -gt 25) { $lines += "  ... и ещё $($d.Removed.Count - 25)" }
    }
    $ev = Save-CgHostsEvidence $Old 'before'
    $lines += ''
    $lines += 'Что значит: строка в hosts решает, куда на самом деле пойдёт браузер. Перенаправление банка, почты или входа в аккаунт на чужой адрес — подмена сайта. Блокировка сайтов антивируса — способ ослепить защиту.'
    if ($ev) { $lines += "Прежняя версия hosts сохранена: $ev" }

    $title = 'Файл hosts изменён: +{0} / −{1}' -f $d.Added.Count, $d.Removed.Count
    if ($whoName) { $title += " — $whoName" }
    if ($WhileAway) { $title += ' (пока программа не работала)' }
    if ($sev -eq 'CRIT') { $title = 'ПОДМЕНА АДРЕСОВ В HOSTS: ' + $title }

    return [PSCustomObject]@{
        Severity = $sev; Title = $title; Detail = ($lines -join "`n")
        Process = $whoName; Path = $whoPath; ProcId = $whoPid; Diff = $d
    }
}
