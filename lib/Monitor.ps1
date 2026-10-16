# ============================================================
#  CookieGuard - Monitor.ps1
#  Движок наблюдения. Работает по принципу "опроси и отдай события":
#  вызывающий сам решает, как часто опрашивать и что делать с
#  результатом. Поэтому один и тот же код годится и для окна,
#  и для консоли.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

if (-not (Get-Command ConvertFrom-CgHostsText -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'Hosts.ps1') }
if (-not (Get-Command Test-CgFileAudited -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'Protect.ps1') }
. (Join-Path $PSScriptRoot 'Agents.ps1')

function Update-CgMonitorTargets {
    param($State)
    $targets = Get-CgTargetFiles
    $canary = @{}
    foreach ($c in (Get-CgCanaryFiles)) { $canary[$c.ToLowerInvariant()] = $true }
    $watchMap = @{}
    foreach ($t in $targets) {
        $t | Add-Member -NotePropertyName IsCanary -NotePropertyValue ([bool]$canary[$t.Path.ToLowerInvariant()]) -Force
        $watchMap[$t.Path.ToLowerInvariant()] = $t
    }
    $browserExes = @{}
    foreach ($b in (Get-CgBrowsers)) {
        foreach ($e in $b.Exe) { $browserExes[$e.ToLowerInvariant()] = $b.Name }
    }
    $State.Targets = $targets
    $State.WatchMap = $watchMap
    $State.BrowserExes = $browserExes
    $State.TargetsAt = Get-Date
}

# -Persist: этот экземпляр — летописец. Он пишет события на диск и
# хранит запомненную копию hosts. Летописец один: сторож, а если
# сторожа нет — монитор окна. Иначе каждая тревога записывалась бы
# дважды, а копию hosts правили бы двое.
function New-CgMonitorState {
    param([switch]$Persist)
    $lastRecordId = 0
    try {
        $last = Get-WinEvent -LogName Security -MaxEvents 1 -ErrorAction Stop
        if ($last) { $lastRecordId = [int64]$last.RecordId }
    } catch { }

    $knownPids = @{}
    foreach ($p in (Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) { $knownPids[[int]$p.ProcessId] = $true }

    # hosts: что было, пока программа не работала, — тоже изменение
    $pending = New-Object System.Collections.ArrayList
    $hostsNow = Read-CgHostsText
    if ($null -eq $hostsNow) { $hostsNow = '' }
    $snap = Get-CgHostsSnapshot
    if ($null -eq $snap) {
        if ($Persist) { $null = Save-CgHostsSnapshot $hostsNow }
        $ents = @(ConvertFrom-CgHostsText $hostsNow)
        $null = $pending.Add((New-CgEvent 'INFO' 'hosts' ('Файл hosts взят под наблюдение: записей {0}, перенаправлений {1}' -f $ents.Count, @($ents | Where-Object { $_.Kind -eq 'redirect' }).Count) 'Копия запомнена. Любое следующее изменение — что добавили, что убрали и кто — появится здесь.' '' (Get-CgHostsPath)))
    } elseif ($snap -ne $hostsNow) {
        $rep = New-CgHostsChangeReport $snap $hostsNow @() -WhileAway
        if ($rep) { $null = $pending.Add((New-CgEvent $rep.Severity 'hosts' $rep.Title $rep.Detail '' (Get-CgHostsPath))) }
        if ($Persist) { $null = Save-CgHostsSnapshot $hostsNow }
    }
    $hostsStamp = ''
    try { $fi = Get-Item -LiteralPath (Get-CgHostsPath) -Force -ErrorAction Stop; $hostsStamp = "$($fi.LastWriteTimeUtc.Ticks)|$($fi.Length)" } catch { }

    $st = [PSCustomObject]@{
        Targets      = @()
        WatchMap     = @{}
        BrowserExes  = @{}
        TargetsAt    = Get-Date
        Persist      = [bool]$Persist
        Pending      = $pending
        HostsText    = $hostsNow
        HostsStamp   = $hostsStamp
        HostsLast    = Get-Date
        HostsWriters = New-Object System.Collections.ArrayList
        Suspects     = @{}
        NetSeen      = @{}
        NetProcs     = @{}
        NetLast      = (Get-Date).AddMinutes(-1)
        DnsMap       = @{}
        DnsLast      = (Get-Date).AddMinutes(-1)
        Agents       = (New-CgAgentsState)
        AgentsSaved  = [datetime]::MinValue
        InjectSeen   = @{}
        ShadowIds    = $null
        LastRecordId = $lastRecordId
        KnownPids    = $knownPids
        Seen         = @{}
        LastSweep    = Get-Date
        AuditOn      = (Test-CgAuditEnabled)
        Tolerated    = @{
            'msmpeng.exe' = 'Антивирус Windows Defender'
            'mpdefendercoreservice.exe' = 'Антивирус Windows Defender'
            'searchindexer.exe' = 'Индексатор поиска Windows'
            'searchprotocolhost.exe' = 'Индексатор поиска Windows'
            'system' = 'Ядро Windows'
            'ekrn.exe' = 'ESET'; 'egui.exe' = 'ESET'
            'avp.exe' = 'Kaspersky'; 'avastsvc.exe' = 'Avast'
            'mbamservice.exe' = 'Malwarebytes'
            'backgroundtaskhost.exe' = 'Фоновая задача Windows'
            'onedrive.exe' = 'OneDrive'
        }
        Counters     = [PSCustomObject]@{ Crit = 0; Warn = 0; Note = 0; Ok = 0; Events = 0 }
    }
    Update-CgMonitorTargets $st
    return $st
}

function New-CgEvent {
    param(
        [string]$Severity, [string]$Kind, [string]$Title, [string]$Detail = '',
        [string]$Process = '', [string]$Path = '', [int]$ProcId = 0, [string]$Hash = '',
        $Live = $null
    )
    # Родитель и предки едут вместе с событием: без них «Доверять» на
    # строке монитора не может предложить «всё, что запускает Claude».
    $pp = ''; $pn = ''; $anc = @()
    if ($Live) { $pp = "$($Live.ParentPath)"; $pn = "$($Live.ParentName)"; $anc = @($Live.Ancestors) }
    return [PSCustomObject]@{
        Time = Get-Date
        TimeText = (Get-Date -Format 'HH:mm:ss')
        Severity = $Severity
        Order = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'INFO' = 3; 'OK' = 4 }[$Severity]
        Kind = $Kind; Title = $Title; Detail = $Detail
        Process = $Process; Path = $Path; ProcId = $ProcId; Hash = $Hash
        Query = $(if ($Process) { $Process } else { $Title })
        ParentPath = $pp; ParentName = $pn; Ancestors = $anc
    }
}

function Get-CgEvData {
    param($Event)
    $h = @{}
    try {
        $x = [xml]$Event.ToXml()
        foreach ($d in $x.Event.EventData.Data) { $h[$d.Name] = $d.'#text' }
    } catch { }
    return $h
}

function Get-CgLiveProc {
    param([int]$ProcId)
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcId" -ErrorAction SilentlyContinue
    if (-not $p) { return $null }
    # Предки по одному запросу на ступень: весь список процессов на
    # каждое событие обходился бы дороже, чем пять точечных вопросов.
    $tbl = @{ ([int]$ProcId) = $p }
    $cur = $p
    for ($i = 0; $i -lt 6; $i++) {
        $ppid = [int]$cur.ParentProcessId
        if ($ppid -le 4 -or $tbl.ContainsKey($ppid)) { break }
        $pp = Get-CimInstance Win32_Process -Filter "ProcessId=$ppid" -ErrorAction SilentlyContinue
        if (-not $pp) { break }
        $tbl[$ppid] = $pp
        $cur = $pp
    }
    $anc = @(Get-CgAncestors $tbl ([int]$ProcId))
    $parentName = ''; $parentPath = ''
    if ($anc.Count) { $parentName = $anc[0].Name; $parentPath = $anc[0].Path }
    return [PSCustomObject]@{
        Id = $ProcId; Name = $p.Name; Path = (Get-CgNormPath $p.ExecutablePath)
        CommandLine = $p.CommandLine; ParentId = [int]$p.ParentProcessId
        ParentName = $parentName; ParentPath = $parentPath; Ancestors = $anc
        Started = $p.CreationDate
        Risk = 0; Reasons = @()
    }
}

function Save-CgEvidence {
    param([string]$Kind, $Data)
    $dir = Get-CgDir 'evidence'
    $f = Join-Path $dir ('{0}-{1}.json' -f (Get-Date -Format 'yyyyMMdd-HHmmss-fff'), $Kind)
    try { $Data | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $f -Encoding UTF8 } catch { }
    return $f
}

# ------------------------------------------------------------
#  Обращение к файлу cookie
# ------------------------------------------------------------
function Resolve-CgAccessEvent {
    param($State, $Ev)

    $d = Get-CgEvData $Ev
    $obj = $d['ObjectName']
    if (-not $obj) { return $null }
    $objl = (Get-CgNormPath $obj).ToLowerInvariant()

    # Запись в hosts или в папку etc. Само изменение разберёт опрос
    # hosts; здесь только запоминаем, кто писал, — это и есть ответ
    # на вопрос «кто подменил адреса».
    $etc = (Get-CgHostsDir).ToLowerInvariant()
    if ($objl -eq $etc -or $objl.StartsWith($etc + '')) {
        $wp = Get-CgNormPath $d['ProcessName']
        $wid = 0
        if ($d['ProcessId']) { try { $wid = [Convert]::ToInt32($d['ProcessId'], 16) } catch { } }
        $null = $State.HostsWriters.Add([PSCustomObject]@{
            Time = Get-Date; Path = $wp; ProcId = $wid; Object = $obj
            Name = $(if ($wp) { Split-Path -Leaf $wp } else { '?' })
        })
        while ($State.HostsWriters.Count -gt 50) { $State.HostsWriters.RemoveAt(0) }
        # следующий опрос hosts — сразу, не ждать трёх секунд
        $State.HostsStamp = ''
        return $null
    }

    if (-not $State.WatchMap.ContainsKey($objl)) { return $null }

    $target = $State.WatchMap[$objl]
    $accessorPath = Get-CgNormPath $d['ProcessName']
    $accessorName = ''
    if ($accessorPath) { $accessorName = (Split-Path -Leaf $accessorPath).ToLowerInvariant() }
    $procId = 0
    if ($d['ProcessId']) { try { $procId = [Convert]::ToInt32($d['ProcessId'], 16) } catch { } }

    # Приманка: ни один браузер её не открывает. Чтение — значит,
    # кто-то перебирал профили. Права и свойства — не в счёт (так
    # её ставит сам CookieGuard), антивирус и индексатор — тоже.
    if ($target.IsCanary) {
        if ($procId -eq $PID) { return $null }
        $kindC = Get-CgAccessKind $d['AccessList'] $d['AccessMask']
        if ($kindC -notmatch 'чтение содержимого') { return $null }
        $keyC = "canary|$accessorPath|$objl"
        if ($State.Seen.ContainsKey($keyC)) { return $null }
        $State.Seen[$keyC] = $true
        Set-CgAgentTick $State 'canary' $true ('сработала: ' + (Get-Date -Format 'HH:mm:ss'))
        if ($State.Tolerated.ContainsKey($accessorName)) {
            return New-CgEvent 'NOTE' 'Приманка' ("$accessorName ($($State.Tolerated[$accessorName])) проверил приманку") "Файл: $obj`nАнтивирус и индексатор читают все файлы подряд — это не кража." $accessorName $accessorPath $procId
        }
        $liveC = Get-CgLiveProc $procId
        $hashC = Get-CgHash $accessorPath
        Add-CgSuspect $State $procId $accessorName $accessorPath 'прочитал приманку' 'CRIT'
        $connC = @(Get-CgProcConnections $procId)
        $null = Save-CgEvidence 'canary' ([PSCustomObject]@{ Time = (Get-Date).ToString('o'); ObjectName = $obj; AccessorPath = $accessorPath; ProcessId = $procId; Sha256 = $hashC; Process = $liveC })
        $det = @(
            "Файл:      $obj",
            "Программа: $accessorPath",
            "PID:       $procId",
            "SHA256:    $hashC",
            $(if ($liveC -and $liveC.ParentName) { "Запущена из: $($liveC.ParentName)" } else { 'Процесс уже завершился.' }),
            '',
            'Это приманка: ненастоящий профиль браузера, которого браузер не видит и не открывает. Его читает только тот, кто перебирает все профили в поисках cookie и паролей, — так работают воры паролей.',
            'Что делать: завершить программу и отправить в карантин, затем сменить пароли и выйти из всех сеансов в важных аккаунтах.'
        )
        if ($connC.Count) { $det += ''; $det += 'Соединения в момент чтения:'; foreach ($c in ($connC | Select-Object -First 8)) { $det += '  ' + (Format-CgConn $State $c) } }
        return New-CgEvent 'CRIT' 'Приманка' ('ПРИМАНКА ТРОНУТА: {0} перебирает профили браузера' -f $accessorName) ($det -join "`n") $accessorName $accessorPath $procId $hashC $liveC
    }

    # свой браузер читает свои cookie — это норма
    if ($accessorPath -and $State.BrowserExes.ContainsKey($accessorPath.ToLowerInvariant())) {
        $who = $State.BrowserExes[$accessorPath.ToLowerInvariant()]
        if ($who -eq $target.Browser) {
            $key = "ok|$accessorPath|$objl"
            if ($State.Seen.ContainsKey($key)) { return $null }
            $State.Seen[$key] = $true
            return New-CgEvent 'OK' 'Доступ' ("$($target.Browser) читает свои cookie — норма") "Файл: $obj" $accessorName $accessorPath $procId
        }
        $key = "x|$accessorPath|$objl"
        if ($State.Seen.ContainsKey($key)) { return $null }
        $State.Seen[$key] = $true
        return New-CgEvent 'WARN' 'Доступ' ("$who обращается к данным браузера $($target.Browser)") ("Файл: $obj`nПроцесс: $accessorPath (PID $procId)`n`nТак выглядит импорт закладок и паролей из другого браузера.`nЕсли вы сейчас ничего не импортировали — разберитесь.") $accessorName $accessorPath $procId
    }

    $key = "a|$accessorPath|$objl"
    if ($State.Seen.ContainsKey($key)) { return $null }
    $State.Seen[$key] = $true

    if ($State.Tolerated.ContainsKey($accessorName)) {
        return New-CgEvent 'NOTE' 'Доступ' ("$accessorName ($($State.Tolerated[$accessorName])) обратился к $(Split-Path -Leaf $obj)") "Файл: $obj`nЭто ожидаемое поведение системной программы." $accessorName $accessorPath $procId
    }

    # Что именно делали с файлом. Смена прав — это не чтение cookie,
    # и выдавать одно за другое нельзя: человек перестанет верить тревогам.
    $kind = Get-CgAccessKind $d['AccessList'] $d['AccessMask']
    $readsContent = ($kind -match 'чтение содержимого')

    $live = Get-CgLiveProc $procId
    $sig = Get-CgSignature $accessorPath
    $hash = Get-CgHash $accessorPath

    # доверенная программа (например, вы сами пометили Claude) — не тревога
    if (Get-Command Test-CgTrustedFile -ErrorAction SilentlyContinue) {
        $tr = $null
        if ($live) { $tr = Test-CgTrustedFile $accessorPath $hash $live.ParentPath $live.ParentName $live.Ancestors }
        else { $tr = Test-CgTrustedFile $accessorPath $hash }
        if ($tr) {
            return New-CgEvent 'NOTE' 'Доступ' ("$accessorName обратился к cookie — доверено вами") (
                "Файл: $obj`nЧто делал: $kind`nПрограмма: $accessorPath`nВы пометили её доверенной" +
                $(if ($tr.Note) { ": $($tr.Note)" } else { '.' })
            ) $accessorName $accessorPath $procId $hash $live
        }
    }

    # Понятным языком: что именно за файл и чем это грозит.
    $whatFile = 'данные браузера'
    $whatMeans = ''
    $leafName = Split-Path -Leaf $obj
    switch -Regex ($leafName) {
        '^Cookies$'    { $whatFile = 'база cookie — активные входы в ваши аккаунты'
                         $whatMeans = 'Кто прочитал этот файл, может войти в ваши аккаунты без пароля, пока сессии живы.' }
        '^Login Data$' { $whatFile = 'база сохранённых паролей браузера'
                         $whatMeans = 'Здесь лежат логины и пароли, сохранённые в браузере.' }
        '^Web Data$'   { $whatFile = 'автозаполнение: адреса, карты, формы'
                         $whatMeans = 'Здесь данные автозаполнения, включая платёжные.' }
        '^Local State$' { $whatFile = 'ключ шифрования базы cookie'
                          $whatMeans = 'Без этого файла cookie не расшифровать. Его читают вместе с базой, чтобы раскрыть её.' }
        default        { $whatFile = $leafName }
    }
    # какой именно профиль браузера
    $profile = ''
    if ($obj -match '(?i)\\User Data\\([^\\]+)\\') { $profile = $matches[1] }
    elseif ($obj -match '(?i)\\User Data\\([^\\]+)$') { $profile = $matches[1] }

    $lines = @(
        "Время:      $(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')",
        "Что взяли:  $whatFile",
        "Браузер:    $($target.Browser)$(if ($profile) { ", профиль «$profile»" })",
        "Файл:       $obj",
        "Что делал:  $kind",
        "Процесс:    $accessorPath",
        "PID:        $procId",
        ("Подпись:    {0} {1}" -f $sig.Status, $sig.Signer),
        "SHA256:     $hash"
    )
    if ($whatMeans) { $lines += ''; $lines += "Чем это грозит: $whatMeans" }
    if ($live) {
        if ($live.ParentName) { $lines += "Запущен из: $($live.ParentName) (PID $($live.ParentId))" }
        if ($live.Started) { $lines += "Работает с: $($live.Started)" }
        if ($live.CommandLine) { $lines += "Команда:    $($live.CommandLine)" }
    } else {
        $lines += 'Процесс уже завершился — похоже, он взял файл и закрылся.'
    }
    $evFile = Save-CgEvidence 'access' ([PSCustomObject]@{
        Time = (Get-Date).ToString('o'); ObjectName = $obj; Browser = $target.Browser
        AccessorPath = $accessorPath; ProcessId = $procId; Signature = $sig; Sha256 = $hash
        Process = $live; AccessList = $d['AccessList']; AccessKind = $kind; User = $d['SubjectUserName']
    })
    # Куда эта программа соединена прямо сейчас. Вор паролей читает
    # базу и тут же отправляет её — часто раньше, чем человек увидит
    # тревогу. Дальше она 10 минут под наблюдением в сети.
    $conn = @(Get-CgProcConnections $procId)
    if ($conn.Count) {
        $lines += ''
        $lines += 'Соединения в момент обращения:'
        foreach ($c in ($conn | Select-Object -First 12)) { $lines += '  ' + (Format-CgConn $State $c) }
    }
    if ($procId -gt 4) {
        $why = $(if ($readsContent) { 'прочитал cookie' } else { 'трогал файл cookie' })
        Add-CgSuspect $State $procId $accessorName $accessorPath $why $(if ($readsContent) { 'CRIT' } else { 'WARN' })
    }

    $lines += ''
    $lines += "Улики сохранены: $evFile"

    if (-not $readsContent) {
        # Доступ был, но содержимое не читали: права, свойства, удаление.
        # Знать об этом полезно, пугать — не за что.
        $extra = ''
        if ($kind -match 'смена прав доступа') { $extra = "`n`nСмена прав — так выглядит установка аудита, в том числе самим CookieGuard." }
        return New-CgEvent 'WARN' 'Доступ' ('Посторонняя программа трогала файл cookie: {0} ({1})' -f $accessorName, $kind) (($lines -join "`n") + $extra) $accessorName $accessorPath $procId $hash $live
    }

    return New-CgEvent 'CRIT' 'Доступ' ('ПОСТОРОННЯЯ ПРОГРАММА ЧИТАЕТ БАЗУ COOKIE: {0}' -f $accessorName) ($lines -join "`n") $accessorName $accessorPath $procId $hash $live
}

# ------------------------------------------------------------
#  Новый процесс
# ------------------------------------------------------------
function Resolve-CgNewProcess {
    param($State, [int]$ProcId)
    $p = Get-CgLiveProc $ProcId
    if (-not $p) { return $null }
    $p = Measure-CgProcessRisk $p
    $lvl = Get-CgRiskLevel $p.Risk
    if ($lvl -in @('OK', 'NOTE')) { return $null }

    # доверенная программа — молчим
    if ($p.Path -and (Get-Command Test-CgTrustedFile -ErrorAction SilentlyContinue)) {
        if (Test-CgTrustedFile $p.Path '' $p.ParentPath $p.ParentName $p.Ancestors) { return $null }
    }

    $detail = "Файл: $($p.Path)`nPID: $($p.Id)`nРодитель: $($p.ParentName) (PID $($p.ParentId))`nКоманда: $($p.CommandLine)`n`n" +
              (($p.Reasons | ForEach-Object { '- ' + $_ }) -join "`n")
    $hash = ''
    if ($lvl -eq 'CRIT') {
        $hash = Get-CgHash $p.Path
        $null = Save-CgEvidence 'process' $p
        Add-CgSuspect $State $p.Id $p.Name $p.Path 'запустился с признаками вредоноса' 'WARN'
    }
    return New-CgEvent $lvl 'Процесс' ('Запустился подозрительный процесс: {0} (риск {1})' -f $p.Name, $p.Risk) $detail $p.Name $p.Path $p.Id $hash $p
}

# ------------------------------------------------------------
#  Копии баз cookie
# ------------------------------------------------------------
function Invoke-CgCopySweep {
    param($State)
    $out = @()
    # Папки всех профилей: под SYSTEM %TEMP% и %USERPROFILE% — это
    # папки системы, и копию, сложенную вором в Temp человека, обход
    # раньше не видел.
    $roots = @("$env:PUBLIC", "$env:ProgramData", (Join-Path $env:windir 'Temp'))
    foreach ($u in (Get-CgUserProfiles)) {
        $roots += @($u.Temp, $u.Downloads, (Join-Path $u.Home 'Documents'), (Join-Path $u.Home 'Desktop'))
    }
    $roots = @($roots | Where-Object { $_ } | Sort-Object -Unique)
    $since = (Get-Date).AddMinutes(-5)
    $names = @('cookies', 'login data', 'cookies.sqlite', 'logins.json', 'key4.db')
    foreach ($r in $roots) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $files = Get-ChildItem -LiteralPath $r -Recurse -Depth 2 -Force -File -ErrorAction SilentlyContinue |
                 Where-Object { $_.LastWriteTime -gt $since -and ($names -contains $_.Name.ToLowerInvariant()) }
        foreach ($f in $files) {
            $fl = $f.FullName.ToLowerInvariant()
            if ($fl -match '\\(network|electron|cef)\\cookies$' -or $fl -match '\\qtwebengine\\') { continue }
            $key = 'c|' + $fl
            if ($State.Seen.ContainsKey($key)) { continue }
            $State.Seen[$key] = $true
            $null = Save-CgEvidence 'copy' ([PSCustomObject]@{ Path = $f.FullName; Size = $f.Length; Created = $f.CreationTime })
            $out += New-CgEvent 'CRIT' 'Копия' 'ПОЯВИЛАСЬ КОПИЯ БАЗЫ COOKIE ВНЕ ПАПКИ БРАУЗЕРА' ("Файл: $($f.FullName)`nРазмер: $([math]::Round($f.Length/1KB)) КБ`nСоздан: $($f.CreationTime)`n`nБраузеры не кладут такие файлы сюда. Так делают программы, которые готовят данные к отправке наружу.") '' $f.FullName
        }
    }
    return $out
}

# ------------------------------------------------------------
#  Теневой путь: сеть
#
#  Вор паролей делает три вещи: читает базу cookie, складывает её
#  и отправляет. Первое видно по аудиту, второе — по обходу копий.
#  Третье раньше не видел никто. Теперь:
#    — программа, тронувшая cookie, и процесс с признаками вредоноса
#      10 минут под наблюдением: каждое их новое соединение — событие;
#    — любая посторонняя программа, соединяющаяся с Telegram API,
#      вебхуками Discord, файлообменниками и «узнай мой IP», — событие:
#      это любимые каналы слива у воров паролей.
#
#  Честно о пределах. Это опрос раз в три секунды, а не перехват:
#  соединение короче трёх секунд можно не застать. Объём отправленного
#  не виден. Если программа идёт через локальный прокси (Karing, v2ray),
#  видно только «отправляет через прокси такой-то», а не конечный адрес.
# ------------------------------------------------------------
$script:CgExfilHosts = '(?i)(^|\.)(api\.telegram\.org|discord\.com|discordapp\.com|discordapp\.net|pastebin\.com|paste\.ee|hastebin\.com|transfer\.sh|gofile\.io|file\.io|anonfiles\.com|catbox\.moe|temp\.sh|bashupload\.com|webhook\.site|pipedream\.net|ngrok\.io|ngrok\.app|ngrok-free\.app|trycloudflare\.com|mega\.nz|sendspace\.com|0x0\.st|filebin\.net)$'
$script:CgReconHosts = '(?i)(^|\.)(api\.ipify\.org|ipinfo\.io|ip-api\.com|icanhazip\.com|ifconfig\.me|checkip\.amazonaws\.com|myexternalip\.com|wtfismyip\.com|ipwho\.is|freegeoip\.app|ipapi\.co)$'
$script:CgBrowserNames = @('chrome.exe', 'msedge.exe', 'firefox.exe', 'brave.exe', 'opera.exe', 'vivaldi.exe', 'browser.exe', 'msedgewebview2.exe')

function Add-CgSuspect {
    param($State, [int]$ProcId, [string]$Name, [string]$Path, [string]$Reason, [string]$Severity = 'WARN', [int]$Minutes = 10)
    if ($ProcId -le 4) { return }
    $cur = $State.Suspects[$ProcId]
    if ($cur -and (Get-CgSevRank $cur.Severity) -gt (Get-CgSevRank $Severity)) { $Severity = $cur.Severity; $Reason = $cur.Reason }
    $State.Suspects[$ProcId] = [PSCustomObject]@{
        Name = $Name; Path = $Path; Reason = $Reason; Severity = $Severity
        Since = $(if ($cur) { $cur.Since } else { Get-Date }); Until = (Get-Date).AddMinutes($Minutes)
        Count = $(if ($cur) { $cur.Count } else { 0 })
    }
}

function Get-CgProcConnections {
    param([int]$ProcId)
    if ($ProcId -le 4) { return @() }
    try {
        return @(Get-NetTCPConnection -OwningProcess $ProcId -ErrorAction Stop |
                 Where-Object { "$($_.State)" -in @('Established', 'SynSent') -and "$($_.RemoteAddress)" -notmatch '^(0\.0\.0\.0|::)$' })
    } catch { return @() }
}

function Update-CgDnsMap {
    param($State)
    $m = @{}
    try {
        foreach ($r in (Get-DnsClientCache -ErrorAction Stop)) {
            if ([int]$r.Type -notin @(1, 28)) { continue }
            $ip = "$($r.Data)"
            if (-not $ip) { continue }
            if (-not $m.ContainsKey($ip)) { $m[$ip] = New-Object System.Collections.ArrayList }
            foreach ($n in @("$($r.Entry)", "$($r.Name)")) {
                if ($n -and -not $m[$ip].Contains($n.ToLowerInvariant())) { $null = $m[$ip].Add($n.ToLowerInvariant()) }
            }
        }
    } catch { }
    $State.DnsMap = $m
    $State.DnsLast = Get-Date
}

function Get-CgConnHost {
    param($State, [string]$Ip)
    # Петлевой адрес — это локальный прокси, а не сайт. В кеше DNS к
    # 127.0.0.1 привязаны имена из hosts (Zapret блокирует так max.ru),
    # и без этой проверки весь трафик через Karing назывался max.ru.
    if ($Ip -match '^(127\.|::1$)') { return '' }
    $n = @($State.DnsMap[$Ip])
    if (-not $n.Count) { return '' }
    # имя канала слива важнее случайного CDN-имени
    foreach ($x in $n) { if ($x -match $script:CgExfilHosts -or $x -match $script:CgReconHosts) { return $x } }
    return "$($n[0])"
}

$script:CgListenerCache = @{}
function Get-CgListener {
    param([int]$Port)
    if ($script:CgListenerCache.ContainsKey($Port)) { return $script:CgListenerCache[$Port] }
    $script:CgListenerCache[$Port] = ''
    try {
        $l = Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction Stop | Select-Object -First 1
        if ($l) {
            $p = Get-Process -Id ([int]$l.OwningProcess) -ErrorAction Stop
            $script:CgListenerCache[$Port] = "$($p.ProcessName).exe"
            return $script:CgListenerCache[$Port]
        }
    } catch { }
    return ''
}

function Format-CgConn {
    param($State, $C)
    $ip = "$($C.RemoteAddress)"; $port = [int]$C.RemotePort
    if ($ip -match '^(127\.|::1$)') {
        $who = Get-CgListener $port
        return ('{0}:{1}  — локальный прокси{2}: конечный адрес за ним не виден' -f $ip, $port, $(if ($who) { " $who" } else { '' }))
    }
    $h = Get-CgConnHost $State $ip
    $tg = $(if (Test-CgTelegramIp $ip) { '  [сеть Telegram]' } else { '' })
    return ('{0}:{1}{2}{3}' -f $ip, $port, $(if ($h) { "  ($h)" } else { '' }), $tg)
}

function Get-CgNetProc {
    param($State, [int]$ProcId)
    $c = $State.NetProcs[$ProcId]
    if ($c) { return $c }
    $path = ''; $name = ''
    try {
        $p = Get-Process -Id $ProcId -ErrorAction Stop
        $name = "$($p.ProcessName).exe"
        try { $path = "$($p.Path)" } catch { }
    } catch { return $null }
    if (-not $path) {
        try { $path = Get-CgNormPath "$((Get-CimInstance Win32_Process -Filter "ProcessId=$ProcId" -ErrorAction Stop).ExecutablePath)" } catch { }
    }
    $c = [PSCustomObject]@{ Name = $name; Path = $path }
    $State.NetProcs[$ProcId] = $c
    return $c
}

function Invoke-CgNetPoll {
    param($State)
    $out = @()
    $now = Get-Date
    if (($now - $State.NetLast).TotalSeconds -lt 3) { return $out }
    $State.NetLast = $now

    foreach ($k in @($State.Suspects.Keys)) { if ($State.Suspects[$k].Until -lt $now) { $State.Suspects.Remove($k) } }
    if (($now - $State.DnsLast).TotalSeconds -ge 15) { Update-CgDnsMap $State }
    if ($State.NetSeen.Count -gt 20000) { $State.NetSeen = @{} }

    $conns = @()
    try { $conns = @(Get-NetTCPConnection -ErrorAction Stop | Where-Object { "$($_.State)" -in @('Established', 'SynSent') }) } catch { return $out }

    $alive = @{}
    foreach ($c in $conns) {
        $procId = [int]$c.OwningProcess
        if ($procId -le 4) { continue }
        $alive[$procId] = $true
        $ip = "$($c.RemoteAddress)"
        if ($ip -match '^(0\.0\.0\.0|::)$') { continue }
        $port = [int]$c.RemotePort

        # 1) под наблюдением — каждое новое направление
        $s = $State.Suspects[$procId]
        if ($s) {
            $hostName = Get-CgConnHost $State $ip
            $dest = $(if ($hostName) { $hostName } else { "${ip}:$port" })
            $key = 's|{0}|{1}' -f $procId, $dest
            if ($State.NetSeen.ContainsKey($key)) { continue }
            $State.NetSeen[$key] = $true
            $s.Count++
            $null = Save-CgEvidence 'net' ([PSCustomObject]@{ Time = (Get-Date).ToString('o'); ProcId = $procId; Path = $s.Path; Reason = $s.Reason; Remote = "${ip}:$port"; Host = $hostName })
            if ($s.Count -gt 12) { continue }   # дальше — только в улики
            $detail = @(
                "Программа:  $($s.Path)",
                "PID:        $procId",
                "Чем попала под наблюдение: $($s.Reason) ($($s.Since.ToString('HH:mm:ss')))",
                "Соединилась: $(Format-CgConn $State $c)",
                '',
                'Это и есть «теневой путь»: программа, которая только что трогала cookie или выглядела вредоносной, выходит в сеть. Если это не ваша программа — завершите её и отправьте в карантин, затем смените пароли и выйдите из всех сеансов в важных аккаунтах.'
            ) -join "`n"
            if ($s.Severity -eq 'CRIT') { $title = 'ТЕНЕВОЙ ПУТЬ: {0} после чтения cookie соединился с {1}' -f $s.Name, $dest }
            else { $title = '{0} ({1}) выходит в сеть: {2}' -f $s.Name, $s.Reason, $dest }
            $out += New-CgEvent $s.Severity 'Сеть' $title $detail $s.Name $s.Path $procId
            continue
        }

        # 2) каналы слива
        $cat = ''; $hit = ''
        foreach ($n in @($State.DnsMap[$ip])) {
            if ($n -match $script:CgExfilHosts) { $cat = 'exfil'; $hit = $n; break }
            if ($n -match $script:CgReconHosts) { $cat = 'recon'; $hit = $n }
        }
        if (-not $cat -and (Test-CgTelegramIp $ip)) { $cat = 'exfil'; $hit = 'сеть Telegram' }
        if (-not $cat) { continue }

        $pinfo = Get-CgNetProc $State $procId
        if (-not $pinfo) { continue }
        $nameL = $pinfo.Name.ToLowerInvariant()
        $key = 'x|{0}|{1}|{2}' -f $(if ($pinfo.Path) { $pinfo.Path.ToLowerInvariant() } else { $nameL }), $cat, $hit
        if ($State.NetSeen.ContainsKey($key)) { continue }
        $State.NetSeen[$key] = $true

        $sig = Get-CgSignature $pinfo.Path
        # браузер и известные издатели (Telegram, Discord, Microsoft…) —
        # их собственная работа
        if ($sig.Trusted) { continue }
        if ($script:CgBrowserNames -contains $nameL -and $pinfo.Path -and $State.BrowserExes.ContainsKey($pinfo.Path.ToLowerInvariant())) { continue }
        if ($pinfo.Path -and (Get-Command Test-CgTrustedFile -ErrorAction SilentlyContinue)) {
            if (Test-CgTrustedFile $pinfo.Path) { continue }
        }

        $cls = Get-CgPathClass $pinfo.Path
        $sev = 'WARN'
        if ($cat -eq 'recon') { $sev = 'NOTE' }
        elseif (-not $sig.Valid -and @('temp', 'downloads', 'public', 'roaming', 'programdata', 'odd') -contains $cls) { $sev = 'CRIT' }
        $what = $(if ($cat -eq 'recon') { 'узнаёт внешний адрес компьютера — так вор паролей подписывает добычу страной и IP' } else { 'канал, куда воры паролей обычно отправляют украденное (бот Telegram, вебхук Discord, файлообменник)' })
        $detail = @(
            "Программа:  $($pinfo.Path)",
            "PID:        $procId",
            "Подпись:    $($sig.Status) $($sig.Signer)",
            "Куда:       $(Format-CgConn $State $c)",
            '',
            "Что это: $what.",
            'Ваш Telegram, Discord и браузер сюда не попадают. Если программа ваша (неофициальный клиент, бот, прокси) — пометьте её доверенной, и тревога больше не повторится.'
        ) -join "`n"
        if ($sev -ne 'NOTE') { $null = Save-CgEvidence 'net' ([PSCustomObject]@{ Time = (Get-Date).ToString('o'); ProcId = $procId; Path = $pinfo.Path; Remote = "${ip}:$port"; Host = $hit; Signature = $sig }) }
        $out += New-CgEvent $sev 'Сеть' ('{0} соединяется с {1}' -f $pinfo.Name, $hit) $detail $pinfo.Name $pinfo.Path $procId
    }
    # номера процессов Windows раздаёт повторно: кеш — только для живых
    foreach ($k in @($State.NetProcs.Keys)) { if (-not $alive.ContainsKey([int]$k)) { $State.NetProcs.Remove($k) } }
    return $out
}

# ------------------------------------------------------------
#  hosts
# ------------------------------------------------------------
function Invoke-CgHostsPoll {
    param($State)
    $now = Get-Date
    if ($State.HostsStamp -and ($now - $State.HostsLast).TotalSeconds -lt 3) { return @() }
    $State.HostsLast = $now
    $stamp = 'none'
    try { $fi = Get-Item -LiteralPath (Get-CgHostsPath) -Force -ErrorAction Stop; $stamp = "$($fi.LastWriteTimeUtc.Ticks)|$($fi.Length)" } catch { }
    if ($stamp -eq $State.HostsStamp) { return @() }
    $text = Read-CgHostsText
    if ($null -eq $text) { return @() }          # занят — попробуем через три секунды
    $State.HostsStamp = $stamp
    if ($text -eq $State.HostsText) { return @() }

    $old = $State.HostsText
    $State.HostsText = $text
    $recent = @($State.HostsWriters | Where-Object { ($now - $_.Time).TotalMinutes -lt 3 })
    $rep = New-CgHostsChangeReport $old $text $recent
    if ($State.Persist) { $null = Save-CgHostsSnapshot $text }
    if (-not $rep) { return @() }                # поменялись только комментарии или порядок
    $State.HostsWriters.Clear()
    if ($rep.ProcId -gt 4 -and $rep.Severity -in @('CRIT', 'WARN')) {
        Add-CgSuspect $State $rep.ProcId $rep.Process $rep.Path 'подменил адреса в hosts' 'WARN'
    }
    return @(New-CgEvent $rep.Severity 'hosts' $rep.Title $rep.Detail $rep.Process $rep.Path $rep.ProcId)
}

# ------------------------------------------------------------
#  Летопись событий
#
#  Список в окне живёт в памяти и пропадал при каждом перезапуске
#  и обновлении. Теперь каждая тревога ложится строкой JSON в
#  logs\events-ГГГГ-ММ.jsonl: окно при запуске показывает прошлое,
#  а пока работает сторож — читает его записи вживую.
# ------------------------------------------------------------
function Get-CgEventLogPath {
    param([datetime]$When = (Get-Date))
    Join-Path (Get-CgDir 'logs') ('events-{0}.jsonl' -f $When.ToString('yyyy-MM'))
}

function Write-CgEventRecord {
    param($E, [string]$Source = '')
    $o = [ordered]@{
        t = $E.Time.ToString('o'); sev = $E.Severity; kind = $E.Kind; title = $E.Title; detail = $E.Detail
        proc = $E.Process; path = $E.Path; pid = $E.ProcId; hash = $E.Hash
        ppath = $E.ParentPath; pname = $E.ParentName; src = $Source
    }
    try { $null = Add-CgLine (Get-CgEventLogPath) (ConvertTo-Json -InputObject $o -Compress -Depth 3) } catch { }
}

function ConvertFrom-CgEventRecord {
    param([string]$Line)
    try { $j = $Line | ConvertFrom-Json -ErrorAction Stop } catch { return $null }
    $t = Get-Date
    try { $t = [datetime]::Parse("$($j.t)", [Globalization.CultureInfo]::InvariantCulture, [Globalization.DateTimeStyles]::RoundtripKind).ToLocalTime() } catch { }
    $sev = "$($j.sev)"
    return [PSCustomObject]@{
        Time = $t
        TimeText = $(if ($t.Date -eq (Get-Date).Date) { $t.ToString('HH:mm:ss') } else { $t.ToString('dd.MM HH:mm') })
        Severity = $sev
        Order = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'INFO' = 3; 'OK' = 4 }[$sev]
        Kind = "$($j.kind)"; Title = "$($j.title)"; Detail = "$($j.detail)"
        Process = "$($j.proc)"; Path = "$($j.path)"; ProcId = [int]$j.pid; Hash = "$($j.hash)"
        Query = $(if ($j.proc) { "$($j.proc)" } else { "$($j.title)" })
        ParentPath = "$($j.ppath)"; ParentName = "$($j.pname)"; Ancestors = @()
    }
}

function Read-CgSharedText {
    param([string]$Path)
    $fs = New-Object IO.FileStream($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
    try { return (New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)).ReadToEnd() } finally { $fs.Dispose() }
}

# Последние события, новые первыми
function Get-CgEventHistory {
    param([int]$Max = 300)
    $files = @(Get-ChildItem -LiteralPath (Get-CgDir 'logs') -Filter 'events-*.jsonl' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending)
    $out = New-Object System.Collections.ArrayList
    foreach ($f in $files) {
        $lines = @()
        try { $lines = @((Read-CgSharedText $f.FullName) -split "`r?`n" | Where-Object { $_ }) } catch { }
        for ($i = $lines.Count - 1; $i -ge 0 -and $out.Count -lt $Max; $i--) {
            $e = ConvertFrom-CgEventRecord $lines[$i]
            if ($e) { $null = $out.Add($e) }
        }
        if ($out.Count -ge $Max) { break }
    }
    return @($out)
}

# Чтение летописи вживую: с того места, где остановились
function New-CgEventTail {
    $p = Get-CgEventLogPath
    $len = 0
    try { if (Test-Path -LiteralPath $p) { $len = (Get-Item -LiteralPath $p).Length } } catch { }
    return [PSCustomObject]@{ Path = $p; Offset = [int64]$len }
}

function Read-CgEventTail {
    param($Tail)
    $out = @()
    $p = Get-CgEventLogPath
    if ($p -ne $Tail.Path) { $Tail.Path = $p; $Tail.Offset = 0 }   # новый месяц — новый файл
    if (-not (Test-Path -LiteralPath $p)) { return $out }
    try {
        $fs = New-Object IO.FileStream($p, [IO.FileMode]::Open, [IO.FileAccess]::Read, ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete))
        try {
            if ($fs.Length -lt $Tail.Offset) { $Tail.Offset = 0 }
            if ($fs.Length -eq $Tail.Offset) { return $out }
            $null = $fs.Seek($Tail.Offset, [IO.SeekOrigin]::Begin)
            $n = [int]([Math]::Min($fs.Length - $Tail.Offset, 4MB))
            $buf = New-Object byte[] $n
            $got = $fs.Read($buf, 0, $n)
            if ($got -le 0) { return $out }
            $last = [Array]::LastIndexOf($buf, [byte]10, $got - 1)
            if ($last -lt 0) { return $out }                       # строка ещё дописывается
            $text = [Text.Encoding]::UTF8.GetString($buf, 0, $last + 1)
            $Tail.Offset += ($last + 1)
            foreach ($l in ($text -split "`r?`n")) {
                if (-not $l) { continue }
                $e = ConvertFrom-CgEventRecord $l
                if ($e) { $out += $e }
            }
        } finally { $fs.Dispose() }
    } catch { }
    return $out
}

# ------------------------------------------------------------
#  Один цикл опроса
# ------------------------------------------------------------
function Invoke-CgMonitorPoll {
    param($State, [switch]$NoProcWatch, [string]$Source = '')
    $out = New-Object System.Collections.ArrayList

    foreach ($r in @($State.Pending)) { $null = $out.Add($r) }
    $State.Pending.Clear()

    # Новые профили и пересозданные браузером файлы — раз в пять минут
    if (((Get-Date) - $State.TargetsAt).TotalMinutes -ge 5) { Update-CgMonitorTargets $State }

    # обращения к файлам cookie и запись в hosts
    try {
        # -Oldest обязательно. Без него Get-WinEvent отдаёт 500 САМЫХ
        # НОВЫХ, номер последнего сдвигается на самый свежий, и всё,
        # что было между, пропадало навсегда — под нагрузкой, то есть
        # как раз тогда, когда кто-то перебирает файлы.
        # 4688 — запуски программ: по ним агенты видят то, что опрос
        # процессов не застаёт (esentutl /vss работает долю секунды)
        $xpath = "*[System[(EventID=4656 or EventID=4663 or EventID=4688) and (EventRecordID>$($State.LastRecordId))]]"
        $evts = $null
        try {
            $evts = Get-WinEvent -LogName Security -FilterXPath $xpath -MaxEvents 500 -Oldest -ErrorAction Stop
            Set-CgAgentTick $State 'audit' $true
        } catch {
            if ("$($_.FullyQualifiedErrorId)" -match 'NoMatchingEventsFound') { Set-CgAgentTick $State 'audit' $true }
            else { Set-CgAgentTick $State 'audit' $false 'журнал безопасности недоступен' }
        }
        if ($evts) {
            foreach ($e in @($evts)) {
                if ([int64]$e.RecordId -gt $State.LastRecordId) { $State.LastRecordId = [int64]$e.RecordId }
                if ($e.Id -eq 4688) { $r = Resolve-CgProcCreateEvent $State $e }
                else { $r = Resolve-CgAccessEvent $State $e }
                if ($r) { $null = $out.Add($r) }
            }
        }
    } catch { }

    # новые процессы
    if (-not $NoProcWatch) {
        $now = @{}
        foreach ($p in (Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
            $procId = [int]$p.ProcessId
            $now[$procId] = $true
            if (-not $State.KnownPids.ContainsKey($procId)) {
                $r = Resolve-CgNewProcess $State $procId
                if ($r) { $null = $out.Add($r) }
            }
        }
        $State.KnownPids = $now
    }

    # hosts, сеть и остальные агенты
    try { foreach ($r in (Invoke-CgHostsPoll $State)) { $null = $out.Add($r) }; Set-CgAgentTick $State 'hosts' $true } catch { Set-CgAgentTick $State 'hosts' $false $_.Exception.Message }
    try { foreach ($r in (Invoke-CgNetPoll $State)) { $null = $out.Add($r) }; Set-CgAgentTick $State 'net' $true } catch { Set-CgAgentTick $State 'net' $false $_.Exception.Message }
    try { foreach ($r in (Invoke-CgAgentsPoll $State)) { $null = $out.Add($r) } } catch { }

    # периодический обход раз в минуту
    if (((Get-Date) - $State.LastSweep).TotalSeconds -ge 60) {
        foreach ($r in (Invoke-CgCopySweep $State)) { $null = $out.Add($r) }
        $State.LastSweep = Get-Date
    }

    foreach ($r in $out) {
        $State.Counters.Events++
        switch ($r.Severity) {
            'CRIT' { $State.Counters.Crit++ }
            'WARN' { $State.Counters.Warn++ }
            'NOTE' { $State.Counters.Note++ }
            default { $State.Counters.Ok++ }
        }
        if ($State.Persist) {
            if ($r.Severity -ne 'OK') { Write-CgEventRecord $r $Source }
            if ($r.Severity -in @('CRIT', 'WARN')) {
                Write-CgLog $r.Severity ("{0} :: {1} :: {2}" -f $r.Kind, $r.Title, $r.Path)
            }
        }
    }
    return @($out)
}
