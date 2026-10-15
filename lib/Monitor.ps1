# ============================================================
#  CookieGuard - Monitor.ps1
#  Движок наблюдения. Работает по принципу "опроси и отдай события":
#  вызывающий сам решает, как часто опрашивать и что делать с
#  результатом. Поэтому один и тот же код годится и для окна,
#  и для консоли.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

function New-CgMonitorState {
    $targets = Get-CgTargetFiles
    $watchMap = @{}
    foreach ($t in $targets) { $watchMap[$t.Path.ToLowerInvariant()] = $t }

    $browserExes = @{}
    foreach ($b in (Get-CgBrowsers)) {
        foreach ($e in $b.Exe) { $browserExes[$e.ToLowerInvariant()] = $b.Name }
    }

    $lastRecordId = 0
    try {
        $last = Get-WinEvent -LogName Security -MaxEvents 1 -ErrorAction Stop
        if ($last) { $lastRecordId = [int64]$last.RecordId }
    } catch { }

    $knownPids = @{}
    foreach ($p in (Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) { $knownPids[[int]$p.ProcessId] = $true }

    return [PSCustomObject]@{
        Targets      = $targets
        WatchMap     = $watchMap
        BrowserExes  = $browserExes
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
}

function New-CgEvent {
    param(
        [string]$Severity, [string]$Kind, [string]$Title, [string]$Detail = '',
        [string]$Process = '', [string]$Path = '', [int]$ProcId = 0, [string]$Hash = ''
    )
    return [PSCustomObject]@{
        Time = Get-Date
        TimeText = (Get-Date -Format 'HH:mm:ss')
        Severity = $Severity
        Order = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'INFO' = 3; 'OK' = 4 }[$Severity]
        Kind = $Kind; Title = $Title; Detail = $Detail
        Process = $Process; Path = $Path; ProcId = $ProcId; Hash = $Hash
        Query = $(if ($Process) { $Process } else { $Title })
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
    $parentName = ''
    $pp = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)" -ErrorAction SilentlyContinue
    if ($pp) { $parentName = $pp.Name }
    return [PSCustomObject]@{
        Id = $ProcId; Name = $p.Name; Path = (Get-CgNormPath $p.ExecutablePath)
        CommandLine = $p.CommandLine; ParentId = [int]$p.ParentProcessId
        ParentName = $parentName; Started = $p.CreationDate
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
    $objl = $obj.ToLowerInvariant()
    if (-not $State.WatchMap.ContainsKey($objl)) { return $null }

    $target = $State.WatchMap[$objl]
    $accessorPath = Get-CgNormPath $d['ProcessName']
    $accessorName = ''
    if ($accessorPath) { $accessorName = (Split-Path -Leaf $accessorPath).ToLowerInvariant() }
    $procId = 0
    if ($d['ProcessId']) { try { $procId = [Convert]::ToInt32($d['ProcessId'], 16) } catch { } }

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
        $tr = Test-CgTrustedFile $accessorPath $hash
        if ($tr) {
            return New-CgEvent 'NOTE' 'Доступ' ("$accessorName обратился к cookie — доверено вами") (
                "Файл: $obj`nЧто делал: $kind`nПрограмма: $accessorPath`nВы пометили её доверенной" +
                $(if ($tr.Note) { ": $($tr.Note)" } else { '.' })
            ) $accessorName $accessorPath $procId $hash
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
    $lines += ''
    $lines += "Улики сохранены: $evFile"

    if (-not $readsContent) {
        # Доступ был, но содержимое не читали: права, свойства, удаление.
        # Знать об этом полезно, пугать — не за что.
        $extra = ''
        if ($kind -match 'смена прав доступа') { $extra = "`n`nСмена прав — так выглядит установка аудита, в том числе самим CookieGuard." }
        return New-CgEvent 'WARN' 'Доступ' ('Посторонняя программа трогала файл cookie: {0} ({1})' -f $accessorName, $kind) (($lines -join "`n") + $extra) $accessorName $accessorPath $procId $hash
    }

    return New-CgEvent 'CRIT' 'Доступ' ('ПОСТОРОННЯЯ ПРОГРАММА ЧИТАЕТ БАЗУ COOKIE: {0}' -f $accessorName) ($lines -join "`n") $accessorName $accessorPath $procId $hash
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
        if (Test-CgTrustedFile $p.Path) { return $null }
    }

    $detail = "Файл: $($p.Path)`nPID: $($p.Id)`nРодитель: $($p.ParentName) (PID $($p.ParentId))`nКоманда: $($p.CommandLine)`n`n" +
              (($p.Reasons | ForEach-Object { '- ' + $_ }) -join "`n")
    $hash = ''
    if ($lvl -eq 'CRIT') {
        $hash = Get-CgHash $p.Path
        $null = Save-CgEvidence 'process' $p
    }
    return New-CgEvent $lvl 'Процесс' ('Запустился подозрительный процесс: {0} (риск {1})' -f $p.Name, $p.Risk) $detail $p.Name $p.Path $p.Id $hash
}

# ------------------------------------------------------------
#  Копии баз cookie
# ------------------------------------------------------------
function Invoke-CgCopySweep {
    param($State)
    $out = @()
    $roots = @("$env:TEMP", "$env:USERPROFILE\Downloads", "$env:PUBLIC", "$env:ProgramData", "$env:USERPROFILE\Documents", "$env:USERPROFILE\Desktop")
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
#  Один цикл опроса
# ------------------------------------------------------------
function Invoke-CgMonitorPoll {
    param($State, [switch]$NoProcWatch)
    $out = New-Object System.Collections.ArrayList

    # обращения к файлам cookie
    if ($State.AuditOn) {
        try {
            $xpath = "*[System[(EventID=4656 or EventID=4663) and (EventRecordID>$($State.LastRecordId))]]"
            $evts = Get-WinEvent -LogName Security -FilterXPath $xpath -MaxEvents 400 -ErrorAction SilentlyContinue
            if ($evts) {
                foreach ($e in (@($evts) | Sort-Object RecordId)) {
                    if ([int64]$e.RecordId -gt $State.LastRecordId) { $State.LastRecordId = [int64]$e.RecordId }
                    $r = Resolve-CgAccessEvent $State $e
                    if ($r) { $null = $out.Add($r) }
                }
            }
        } catch { }
    }

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
        if ($r.Severity -in @('CRIT', 'WARN')) {
            Write-CgLog $r.Severity ("{0} :: {1} :: {2}" -f $r.Kind, $r.Title, $r.Path)
        }
    }
    return @($out)
}
