# ============================================================
#  CookieGuard - Checks.ps1
#  Движок проверок. Возвращает объекты-находки, ничего не печатает.
#  Используется и окном, и консольным сканером.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

function New-CgFinding {
    param(
        [string]$Severity, [string]$Area, [string]$Title,
        [string]$Detail = '', [string]$Path = '', [string]$Hash = '', [string]$Query = '',
        $Target = $null
    )
    $ord = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'INFO' = 3; 'OK' = 4 }[$Severity]
    if ($null -eq $ord) { $ord = 5 }
    if (-not $Query) { $Query = $Title }
    return [PSCustomObject]@{
        Severity = $Severity; Order = $ord; Area = $Area; Title = $Title
        Detail = $Detail; Path = $Path; Hash = $Hash; Query = $Query
        # Target — на что именно указывает находка: ключ реестра, папка,
        # запись автозапуска. Текст Detail написан для человека и может
        # поменяться в любой правке; чинить и разбирать нужно по объекту.
        Target = $Target
    }
}

# ------------------------------------------------------------
# 1. Защита Windows
# ------------------------------------------------------------
# Сторонние антивирусы регистрируются в SecurityCenter2. Если такой есть
# и он работает, Windows штатно отключает Defender — это не брешь. Без
# этой проверки окно показывало «защита ВЫКЛЮЧЕНА» на машине под ESET,
# и человек шёл искать проблему, которой нет.
function Get-CgOtherAntivirus {
    $out = @()
    try {
        foreach ($a in @(Get-CimInstance -Namespace root\SecurityCenter2 -ClassName AntiVirusProduct -ErrorAction Stop)) {
            $name = "$($a.displayName)"
            if ($name -match '(?i)windows\s+defender') { continue }
            # productState — три байта: тип, состояние защиты, состояние баз
            $hex = '{0:X6}' -f [int]$a.productState
            $rtp = [Convert]::ToInt32($hex.Substring(2, 2), 16)
            $def = [Convert]::ToInt32($hex.Substring(4, 2), 16)
            $out += [PSCustomObject]@{ Name = $name; Active = (($rtp -band 0x10) -ne 0); Fresh = ($def -eq 0) }
        }
    } catch { }
    return $out
}

# Кто сейчас защищает компьютер — сводка для плитки обзора. Логика та
# же, что в Get-CgDefenderFindings: Defender в запасе при работающем
# стороннем антивирусе — не брешь. Окна не касается, поэтому её можно
# вызвать и из консоли.
#   State      — Defender | Other | Off | Unknown
#   Name       — кто защищает (для Other — все работающие через запятую)
#   Fresh      — свежи ли базы у того, кто защищает
#   Idle       — сторонние антивирусы, которые установлены, но не защищают
#   Exclusions — сколько исключений у Defender; $null, если узнать не удалось
function Get-CgAntivirusSummary {
    $other  = @(Get-CgOtherAntivirus)
    $guards = @($other | Where-Object { $_.Active })
    $s = [PSCustomObject]@{
        State = 'Unknown'; Name = ''; Fresh = $null; SignatureAge = $null
        Idle = @($other | Where-Object { -not $_.Active } | ForEach-Object { $_.Name })
        Exclusions = $null
    }

    $st = $null
    try { $st = Get-MpComputerStatus -ErrorAction Stop } catch { }
    if ($st -and $st.RealTimeProtectionEnabled) {
        $s.State = 'Defender'; $s.Name = 'Microsoft Defender'
        $s.SignatureAge = $st.AntivirusSignatureAge
        $s.Fresh = ($st.AntivirusSignatureAge -le 3)
    } elseif ($guards.Count) {
        $s.State = 'Other'
        $s.Name  = ($guards | ForEach-Object { $_.Name }) -join ', '
        $s.Fresh = -not @($guards | Where-Object { -not $_.Fresh }).Count
    } elseif ($st) {
        $s.State = 'Off'
    }

    # Когда служба Defender стоит (а под чужим антивирусом она стоит),
    # Get-MpPreference падает. @($null).Count в Windows PowerShell — это 1,
    # поэтому пустые списки считаем только по непустым строкам. Без прав
    # администратора вместо списка приходит «N/A: Must be an administrator…» —
    # это тоже «не знаем», а не одно исключение.
    try {
        $pref = Get-MpPreference -ErrorAction Stop
        $all = @(@($pref.ExclusionPath) + @($pref.ExclusionExtension) + @($pref.ExclusionProcess) | Where-Object { "$_" })
        if (-not @($all | Where-Object { "$_" -match '^N/A' }).Count) { $s.Exclusions = $all.Count }
    } catch { }
    return $s
}

function Get-CgDefenderFindings {
    $f = @()
    $other  = @(Get-CgOtherAntivirus)
    $guards = @($other | Where-Object { $_.Active })

    # Установлен, зарегистрирован — и не защищает. Вот это настоящая беда:
    # Defender уступил место тому, кто не работает.
    foreach ($a in @($other | Where-Object { -not $_.Active })) {
        $f += New-CgFinding 'WARN' 'Defender' ('Антивирус {0} установлен, но не защищает' -f $a.Name) 'Он зарегистрирован в Windows, но его защита в реальном времени выключена. Включите её или удалите программу.'
    }

    try {
        $st = Get-MpComputerStatus -ErrorAction Stop

        # Defender ушёл в сторону целиком и штатно. Его собственные
        # показатели — подделка настроек, возраст баз, поведенческий
        # анализ — в этом состоянии ничего не значат, и сообщать о них
        # значит пугать человека без причины.
        $standDown = ((-not $st.RealTimeProtectionEnabled) -and $guards.Count -gt 0)

        if ($st.RealTimeProtectionEnabled) { $f += New-CgFinding 'OK' 'Defender' 'Защита в реальном времени включена' }
        elseif ($standDown) {
            $f += New-CgFinding 'OK' 'Defender' ('Защиту обеспечивает другой антивирус: {0}' -f (($guards | ForEach-Object { $_.Name }) -join ', ')) 'Windows штатно отключает Defender, когда работает сторонний антивирус.'
            foreach ($a in @($guards | Where-Object { -not $_.Fresh })) {
                $f += New-CgFinding 'WARN' 'Defender' ('У антивируса {0} устарели базы' -f $a.Name) 'Обновите его базы — защита есть, но она не знает про новое.'
            }
        }
        else { $f += New-CgFinding 'CRIT' 'Defender' 'Защита в реальном времени ВЫКЛЮЧЕНА' 'Основная защита не работает. Включите её в "Безопасность Windows".' }

        if ($standDown) { } elseif ($st.IsTamperProtected) { $f += New-CgFinding 'OK' 'Defender' 'Защита от подделки настроек включена' }
        else { $f += New-CgFinding 'WARN' 'Defender' 'Защита от подделки настроек выключена' 'Без неё вредонос сможет отключить антивирус сам.' }

        if ($standDown) { }
        elseif ($st.AntivirusSignatureAge -gt 3) { $f += New-CgFinding 'WARN' 'Defender' ('Базы не обновлялись {0} дн.' -f $st.AntivirusSignatureAge) }
        else { $f += New-CgFinding 'OK' 'Defender' ('Базы свежие ({0} дн.)' -f $st.AntivirusSignatureAge) }

        if (-not $standDown -and -not $st.BehaviorMonitorEnabled) { $f += New-CgFinding 'WARN' 'Defender' 'Поведенческий анализ выключен' }
    } catch {
        $f += New-CgFinding 'NOTE' 'Defender' 'Не удалось опросить Defender' 'Возможно, установлен другой антивирус.'
    }

    try {
        $pref = Get-MpPreference -ErrorAction Stop
        $exP = @($pref.ExclusionPath); $exE = @($pref.ExclusionExtension); $exPr = @($pref.ExclusionProcess)
        $total = $exP.Count + $exE.Count + $exPr.Count
        if ($total) {
            $d = ''
            if ($exP.Count)  { $d += "Папки:`n" + (($exP | ForEach-Object { '  ' + $_ }) -join "`n") + "`n" }
            if ($exE.Count)  { $d += "Расширения: " + ($exE -join ', ') + "`n" }
            if ($exPr.Count) { $d += "Процессы: " + ($exPr -join ', ') + "`n" }
            $d += "`nВсё, что лежит в этих местах, антивирус НЕ проверяет. Если вы их не добавляли — это следы вмешательства."
            $f += New-CgFinding 'WARN' 'Defender' ('Заданы исключения антивируса: {0} шт.' -f $total) $d
        } else {
            $f += New-CgFinding 'OK' 'Defender' 'Исключений антивируса нет'
        }
        if ($pref.DisableRealtimeMonitoring) { $f += New-CgFinding 'CRIT' 'Defender' 'В настройках принудительно отключён мониторинг' }
    } catch { }

    try {
        foreach ($fp in (Get-NetFirewallProfile -ErrorAction Stop)) {
            if ($fp.Enabled) { $f += New-CgFinding 'OK' 'Брандмауэр' ('Профиль {0}: включён' -f $fp.Name) }
            else { $f += New-CgFinding 'WARN' 'Брандмауэр' ('Профиль {0}: ВЫКЛЮЧЕН' -f $fp.Name) }
        }
    } catch { }
    return $f
}

# ------------------------------------------------------------
# 2. Перехват трафика
# ------------------------------------------------------------
function Get-CgTrafficFindings {
    $f = @()
    $isKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $is = Get-ItemProperty -Path $isKey -ErrorAction SilentlyContinue

    if ($is.ProxyEnable -eq 1 -and $is.ProxyServer) {
        $detail = "Адрес прокси: $($is.ProxyServer)`n"
        $ownerPath = ''
        if ($is.ProxyServer -match ':(\d+)') {
            $port = [int]$matches[1]
            $conn = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($conn) {
                $op = Get-Process -Id $conn.OwningProcess -ErrorAction SilentlyContinue
                if ($op -and $op.Path) {
                    $ownerPath = $op.Path
                    $sg = Get-CgSignature $op.Path
                    $detail += "Слушает программа: $($op.Path)`nПодпись: $($sg.Status) $($sg.Signer)`n"
                }
            }
        }
        $detail += "`nЧерез эту программу идёт весь трафик браузеров — она видит всё. Убедитесь, что ставили её сами."
        $f += New-CgFinding 'WARN' 'Прокси' 'Включён прокси-сервер для всего трафика' $detail $ownerPath
    } else {
        $f += New-CgFinding 'OK' 'Прокси' 'Прокси не настроен'
    }

    if ($is.AutoConfigURL) {
        $f += New-CgFinding 'CRIT' 'Прокси' 'Задан скрипт автонастройки прокси (PAC)' ("URL: $($is.AutoConfigURL)`n`nЭто классический способ незаметно завернуть трафик на чужой сервер.") '' '' $is.AutoConfigURL
    } else {
        $f += New-CgFinding 'OK' 'Прокси' 'Скрипт автонастройки прокси (PAC) не задан'
    }

    $winhttp = & netsh winhttp show proxy 2>&1 | Out-String
    if ($winhttp -match '(?m)^\s*(Proxy Server\(s\)|Прокси-сервер)\s*:\s*(\S+)') {
        $f += New-CgFinding 'WARN' 'Прокси' 'Задан системный прокси WinHTTP' ($winhttp.Trim() + "`n`nЭто прокси для системных служб и обновлений, отдельно от браузерного.")
    } else {
        $f += New-CgFinding 'OK' 'Прокси' 'Системный прокси WinHTTP не задан'
    }

    $hostsPath = "$env:windir\System32\drivers\etc\hosts"
    $badHosts = @()
    if (Test-Path -LiteralPath $hostsPath) {
        foreach ($l in (Get-Content -LiteralPath $hostsPath -ErrorAction SilentlyContinue)) {
            $t = $l.Trim()
            if (-not $t -or $t.StartsWith('#')) { continue }
            if ($t -match '^\s*(127\.0\.0\.1|::1|0\.0\.0\.0)\s') { continue }
            if ($t -match 'docker\.internal|kubernetes\.docker') { continue }
            $badHosts += $t
        }
    }
    if ($badHosts.Count) {
        $f += New-CgFinding 'WARN' 'hosts' ('В файле hosts есть перенаправления: {0} шт.' -f $badHosts.Count) (($badHosts | Select-Object -First 25) -join "`n") $hostsPath
    } else {
        $f += New-CgFinding 'OK' 'hosts' 'Файл hosts без посторонних перенаправлений' '' $hostsPath
    }

    $knownCA = 'Microsoft|DigiCert|VeriSign|GlobalSign|Baltimore|Thawte|GeoTrust|Go Daddy|Entrust|COMODO|Sectigo|USERTrust|Certum|QuoVadis|Starfield|AddTrust|Symantec|SSL\.com|Amazon|ISRG|Actalis|Buypass|D-TRUST|Hellenic|IdenTrust|Network Solutions|SecureTrust|Security Communication|Staat der|SwissSign|T-TeleSec|TeliaSonera|UCA|XRamp|AffirmTrust|Atos|Autoridad|Certigna|certSIGN|CFCA|Chambers|CommScope|DigitalSign|E-Tugra|emSign|GDCA|GTS|Hongkong|HARICA|Izenpe|Microsec|NAVER|NetLock|OISTE|OpenTrust|SZAFIR|TUBITAK|TWCA|Telia|Trustwave|TrustCor|Visa|vTrus|WoSign'
    $odd = Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue |
           Where-Object { $_.Issuer -eq $_.Subject -and $_.Subject -notmatch $knownCA }
    if ($odd) {
        foreach ($c in $odd) {
            $sev = 'WARN'
            $extra = ''
            if ($c.NotAfter -lt (Get-Date)) { $sev = 'NOTE'; $extra = "`nСрок действия истёк — угрозы уже не представляет." }
            $nm = Get-CgSignerName $c.Subject
            $f += New-CgFinding $sev 'Сертификаты' ('Нестандартный корневой сертификат: {0}' -f $nm) ("Кому выдан: $($c.Subject)`nДействует до: $($c.NotAfter)`nОтпечаток: $($c.Thumbprint)`n`nВладелец такого сертификата может читать ваш защищённый трафик.$extra") '' '' $nm
        }
    } else {
        $f += New-CgFinding 'OK' 'Сертификаты' 'Посторонних корневых сертификатов не найдено'
    }

    try {
        foreach ($d in (Get-DnsClientServerAddress -AddressFamily IPv4 -ErrorAction Stop | Where-Object { $_.ServerAddresses })) {
            $f += New-CgFinding 'INFO' 'DNS' ('{0}: {1}' -f $d.InterfaceAlias, ($d.ServerAddresses -join ', '))
        }
    } catch { }
    return $f
}

# ------------------------------------------------------------
# 3. Автозапуск
# ------------------------------------------------------------
function Get-CgAutorunList {
    # ArrayList, а не массив: вложенная функция может дописывать только в объект,
    # присваивание $list += создало бы у неё собственную копию
    $list = New-Object System.Collections.ArrayList

    function Add-Entry {
        param([string]$Source, [string]$Name, [string]$Command, [string]$Kind)
        if (-not $Command) { return }
        # Путь без кавычек может содержать пробелы («C:\Program Files\...»),
        # поэтому «первое слово до пробела» не годится: в $exe попадала вся
        # командная строка вместе с аргументами, файл «не находился на
        # диске», а слово hidden из ключа --start-hidden поднимало находку
        # до CRIT. Берём префикс, который оканчивается на расширение
        # программы и существует на диске.
        $exe = $Command.Trim()
        if ($exe -match '^"([^"]+)"') {
            $exe = $matches[1]
        } else {
            $exp  = [Environment]::ExpandEnvironmentVariables($exe)
            $cand = ''
            foreach ($m in [regex]::Matches($exp, '(?i)\.(exe|dll|bat|cmd|vbs|js|ps1|scr|com|msi)(?=\s|$)')) {
                $c = $exp.Substring(0, $m.Index + $m.Length)
                if (-not $cand) { $cand = $c }
                if (Test-Path -LiteralPath $c) { $cand = $c; break }
            }
            if ($cand) { $exe = $cand }
        }
        $exe = Get-CgNormPath ([Environment]::ExpandEnvironmentVariables($exe))

        $cls = Get-CgPathClass $exe
        $sig = $null
        if (Test-Path -LiteralPath $exe) { $sig = Get-CgSignature $exe }

        $sev = 'INFO'; $notes = @()
        if (@('temp', 'downloads', 'public', 'odd') -contains $cls) { $sev = 'CRIT'; $notes += 'запускается из временной/пользовательской папки' }
        elseif (@('roaming', 'programdata') -contains $cls) { $sev = 'WARN'; $notes += 'запускается из AppData/ProgramData' }
        if ($sig -and $sig.Status -eq 'NotSigned' -and $cls -notin @('system32', 'windows', 'windowsapps')) {
            if ($sev -eq 'INFO') { $sev = 'NOTE' }
            $notes += 'файл без подписи'
        }
        if ($sig -and -not $sig.Valid -and $sig.Status -notin @('NotSigned', 'Valid', 'UnknownError', 'Error')) { $sev = 'CRIT'; $notes += "подпись недействительна ($($sig.Status))" }
        if ($Command -match 'powershell|pwsh|mshta|wscript|cscript|rundll32|regsvr32|certutil|bitsadmin') { $sev = 'CRIT'; $notes += 'в автозапуске интерпретатор или системная утилита' }
        if ($Command -match '-enc\b|-e\s+[A-Za-z0-9+/]{40,}|FromBase64String|DownloadString') { $sev = 'CRIT'; $notes += 'скрытая или закодированная команда' }
        elseif ($Command -match '(?i)hidden') {
            # Скрытое окно само по себе — обычный приём нормальных программ
            # (--start-hidden у Razer, -silent у Steam). Опасно оно в паре с
            # интерпретатором, а тот проверен строкой выше.
            if ($Command -match 'powershell|pwsh|mshta|wscript|cscript|rundll32|regsvr32|certutil|bitsadmin') { $sev = 'CRIT'; $notes += 'скрытый запуск интерпретатора' }
            else { $notes += 'запускается со скрытым окном' }
        }
        if ($exe -and -not (Test-Path -LiteralPath $exe)) {
            $notes += 'файл не найден на диске'
            # Запись автозапуска, ведущая в пустоту, — это уже мусор, а
            # если путь окажется доступен для записи, то и готовая точка
            # перехвата: кто положит туда файл, тот и получит автозапуск.
            # Молчать о ней нельзя, но и пугать как вредоносом не за что.
            if ($sev -eq 'INFO') { $sev = 'WARN' }
        }

        $sigTxt = 'нет данных'
        if ($sig) { $sigTxt = ($sig.Status + ' ' + $sig.Signer).Trim() }

        $null = $list.Add([PSCustomObject]@{
            Severity = $sev; Order = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'INFO' = 3 }[$sev]
            Kind = $Kind; Name = $Name; Command = $Command; Path = $exe
            Source = $Source; Signature = $sigTxt
            Notes = ($notes -join '; ')
            Detail = "Где прописано: $Source`nКоманда: $Command`nФайл: $exe`nПодпись: $sigTxt`n$($notes -join '; ')"
            Title = $Name; Hash = ''; Query = $Name
        })
    }

    foreach ($k in @(
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce')) {
        $p = Get-ItemProperty -Path $k -ErrorAction SilentlyContinue
        if (-not $p) { continue }
        foreach ($prop in $p.PSObject.Properties) {
            if ($prop.Name -like 'PS*') { continue }
            Add-Entry $k $prop.Name ([string]$prop.Value) 'Реестр'
        }
    }

    foreach ($sd in @("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
                      "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup")) {
        foreach ($file in (Get-ChildItem -LiteralPath $sd -File -Force -ErrorAction SilentlyContinue)) {
            if ($file.Name -eq 'desktop.ini') { continue }
            Add-Entry $sd $file.Name $file.FullName 'Папка автозагрузки'
        }
    }

    foreach ($t in (Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        if ($t.TaskPath -like '\Microsoft\*') { continue }
        foreach ($a in @($t.Actions)) {
            if (-not $a.Execute) { continue }
            Add-Entry ('Планировщик: ' + $t.TaskPath + $t.TaskName) ($t.TaskPath + $t.TaskName) (($a.Execute + ' ' + $a.Arguments).Trim()) 'Задача'
        }
    }

    foreach ($s in (Get-CimInstance Win32_Service -ErrorAction SilentlyContinue)) {
        if (-not $s.PathName) { continue }
        $exe = $s.PathName
        if ($exe -match '^"([^"]+)"') { $exe = $matches[1] } elseif ($exe -match '^(\S+\.exe)') { $exe = $matches[1] }
        $cls = Get-CgPathClass ([Environment]::ExpandEnvironmentVariables($exe))
        if (@('temp', 'downloads', 'public', 'odd', 'roaming') -contains $cls) {
            Add-Entry ('Служба: ' + $s.Name) $s.Name $s.PathName 'Служба'
        }
    }

    return @($list)
}

function Get-CgAutorunFindings {
    param($AutorunList)
    if (-not $AutorunList) { $AutorunList = Get-CgAutorunList }
    $f = @()
    foreach ($a in ($AutorunList | Where-Object { $_.Severity -in @('CRIT', 'WARN') })) {
        # Чем запись является, знает только тот, кто её собрал. Запись в
        # Run и задача планировщика убираются совершенно по-разному.
        $tg = $null
        switch ($a.Kind) {
            'Реестр'             { $tg = [PSCustomObject]@{ Kind = 'runvalue'; Path = $a.Source;  Name = $a.Name; Command = $a.Command; File = $a.Path } }
            'Папка автозагрузки' { $tg = [PSCustomObject]@{ Kind = 'runfile';  Path = $a.Command; Name = $a.Name; Command = $a.Command; File = $a.Path } }
            'Задача'             { $tg = [PSCustomObject]@{ Kind = 'task';     Path = $a.Name;    Name = $a.Name; Command = $a.Command; File = $a.Path } }
            'Служба'             { $tg = [PSCustomObject]@{ Kind = 'service';  Path = $a.Name;    Name = $a.Name; Command = $a.Command; File = $a.Path } }
        }
        $f += New-CgFinding $a.Severity 'Автозапуск' ('[{0}] {1}' -f $a.Kind, $a.Name) $a.Detail $a.Path -Target $tg
    }

    # Точки закрепления, которыми пользуются почти только вредоносы
    $sneaky = @(
        @{ Path = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Windows'; Name = 'AppInit_DLLs'; Why = 'указанная DLL подгружается в КАЖДУЮ запускаемую программу' },
        @{ Path = 'HKLM:\Software\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows'; Name = 'AppInit_DLLs'; Why = 'DLL подгружается в каждую 32-битную программу' },
        @{ Path = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'; Name = 'Userinit'; Why = 'запускается при каждом входе в систему'; Default = 'C:\Windows\system32\userinit.exe,' },
        @{ Path = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon'; Name = 'Shell'; Why = 'оболочка рабочего стола'; Default = 'explorer.exe' },
        @{ Path = 'HKCU:\Environment'; Name = 'UserInitMprLogonScript'; Why = 'скрытый скрипт при входе' }
    )
    foreach ($s in $sneaky) {
        $v = (Get-ItemProperty -Path $s.Path -Name $s.Name -ErrorAction SilentlyContinue).$($s.Name)
        if (-not $v) { continue }
        if ($s.Default -and ("$v".Trim() -eq $s.Default)) { continue }
        $f += New-CgFinding 'CRIT' 'Автозапуск' ('{0} изменён' -f $s.Name) ("Ключ: $($s.Path)`nЗначение: $v`n`n$($s.Why)") `
            -Target ([PSCustomObject]@{ Kind = 'regvalue'; Path = $s.Path; Name = $s.Name; Was = "$v"; Restore = $s.Default })
    }

    $ifeo = 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    foreach ($sub in (Get-ChildItem -Path $ifeo -ErrorAction SilentlyContinue)) {
        $dbg = (Get-ItemProperty -Path $sub.PSPath -Name 'Debugger' -ErrorAction SilentlyContinue).Debugger
        if (-not $dbg) { continue }
        $ifeoTarget = [PSCustomObject]@{
            Kind = 'regvalue'; Path = "$ifeo\$($sub.PSChildName)"; Name = 'Debugger'; Was = "$dbg"; Program = $sub.PSChildName
        }
        if ($dbg -match 'systray\.exe\s*$') {
            $f += New-CgFinding 'WARN' 'Автозапуск' ('Запуск программы заблокирован: {0}' -f $sub.PSChildName) ("Подставлено: $dbg`n`nsystray.exe — пустышка Windows. Так программы отключают утилиты для урезания телеметрии.`nЕсли вы такую ставили — это она. Если нет — разберитесь.") -Target $ifeoTarget
        } else {
            $f += New-CgFinding 'CRIT' 'Автозапуск' ('Подменён запуск программы: {0}' -f $sub.PSChildName) ("Вместо неё запускается: $dbg`n`nТак блокируют антивирусы и перехватывают запуск программ.") -Target $ifeoTarget
        }
    }

    $wmiBenign = 'SCM Event|BVTFilter|TSLogonEvent|RmAssistEvent|NTEventLog|MSFT_SCMEventLogEvent|WSManHTTPSCertFilter'
    $wmiFound = 0
    foreach ($cls in @('__EventFilter', 'CommandLineEventConsumer', 'ActiveScriptEventConsumer', '__FilterToConsumerBinding')) {
        foreach ($o in (Get-CimInstance -Namespace root\subscription -ClassName $cls -ErrorAction SilentlyContinue)) {
            $nm = $o.Name
            $d = "Класс: $cls"
            if ($cls -eq '__FilterToConsumerBinding') {
                $nm = ('{0} -> {1}' -f "$($o.Filter)", "$($o.Consumer)")
                $d += "`nФильтр: $($o.Filter)`nПотребитель: $($o.Consumer)"
            }
            if (-not $nm) { $nm = "$o" }
            if ($nm -match $wmiBenign) { continue }
            $wmiFound++
            if ($o.Query) { $d += "`nУсловие: $($o.Query)" }
            if ($o.CommandLineTemplate) { $d += "`nЗапускает: $($o.CommandLineTemplate)" }
            if ($o.ScriptText) { $d += "`nСкрипт: " + $o.ScriptText.Substring(0, [Math]::Min(300, $o.ScriptText.Length)) }
            $d += "`n`nЭто способ запускать код по событию в обход автозагрузки. Им почти никто не пользуется, кроме вредоносов."
            $f += New-CgFinding 'CRIT' 'WMI' ('Постоянная подписка WMI: {0}' -f $nm) $d
        }
    }
    if (-not $wmiFound) { $f += New-CgFinding 'OK' 'WMI' 'Посторонних постоянных подписок WMI нет' }
    if (-not ($f | Where-Object { $_.Area -eq 'Автозапуск' -and $_.Severity -in @('CRIT', 'WARN') })) {
        $f += New-CgFinding 'OK' 'Автозапуск' 'Подозрительных точек автозапуска не найдено'
    }
    return $f
}

# ------------------------------------------------------------
# 4. Процессы
# ------------------------------------------------------------
function Get-CgProcessList {
    $procs = Get-CgProcessTable | ForEach-Object { Measure-CgProcessRisk $_ }
    $out = @()
    foreach ($p in $procs) {
        $lvl = Get-CgRiskLevel $p.Risk
        $sigTxt = ''
        if ($p.Path) { $s = Get-CgSignature $p.Path; $sigTxt = ($s.Status + ' ' + $s.Signer).Trim() }

        # процесс, помеченный вами как доверенный (например, сам Claude)
        $trusted = $null
        if ($p.Path -and (Get-Command Test-CgTrustedFile -ErrorAction SilentlyContinue)) {
            # одна проверка на все области доверия: отпечаток, путь,
            # папка, «эта программа» и «этот издатель»
            $trusted = Test-CgTrustedFile $p.Path '' $p.ParentPath $p.ParentName
        }
        if ($trusted) {
            $lvl = 'OK'
            $p.Reasons = @($p.Reasons) + @('ДОВЕРЕНО ВАМИ' + $(if ($trusted.Note) { ": $($trusted.Note)" } else { '' }))
        }
        $out += [PSCustomObject]@{
            Severity = $lvl; Order = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'OK' = 3 }[$lvl]
            Name = $p.Name; Id = $p.Id; Risk = $p.Risk; User = $p.User
            Path = $p.Path; ParentName = $p.ParentName; ParentId = $p.ParentId; ParentPath = $p.ParentPath
            CommandLine = $p.CommandLine; Signature = $sigTxt
            Notes = ($p.Reasons -join '; ')
            Title = $p.Name; Hash = ''; Query = $p.Name
            Detail = "Файл: $($p.Path)`nPID: $($p.Id)`nРодитель: $($p.ParentName) (PID $($p.ParentId))`nОт имени: $($p.User)`nПодпись: $sigTxt`nЗапущен: $($p.Started)`nКоманда: $($p.CommandLine)`n`n" + (($p.Reasons | ForEach-Object { '- ' + $_ }) -join "`n")
        }
    }
    return $out
}

function Get-CgProcessFindings {
    param($ProcessList)
    if (-not $ProcessList) { $ProcessList = Get-CgProcessList }
    $f = @()
    # доверенные не показываем как находки — вы про них уже знаете
    $risky = $ProcessList | Where-Object { $_.Risk -ge 14 -and $_.Severity -ne 'OK' } | Sort-Object Risk -Descending
    if (-not $risky) {
        $f += New-CgFinding 'OK' 'Процессы' 'Процессов с признаками риска не найдено'
    } else {
        foreach ($p in $risky) {
            $f += New-CgFinding $p.Severity 'Процессы' ('{0}  (PID {1}, риск {2})' -f $p.Name, $p.Id, $p.Risk) $p.Detail $p.Path '' $p.Name
        }
    }
    return $f
}

# ------------------------------------------------------------
# 5. Сеть
# ------------------------------------------------------------
function Get-CgNetworkFindings {
    param($ProcessList)
    if (-not $ProcessList) { $ProcessList = Get-CgProcessList }
    $f = @()
    $byProc = @{}
    foreach ($c in (Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue)) {
        if ($c.RemoteAddress -match '^(127\.|::1|0\.0\.0\.0)') { continue }
        $k = [int]$c.OwningProcess
        if (-not $byProc.ContainsKey($k)) { $byProc[$k] = New-Object System.Collections.ArrayList }
        $null = $byProc[$k].Add(('{0}:{1}' -f $c.RemoteAddress, $c.RemotePort))
    }
    $bad = 0
    foreach ($k in $byProc.Keys) {
        $pr = $ProcessList | Where-Object { $_.Id -eq $k } | Select-Object -First 1
        if (-not $pr) { continue }
        $suspicious = ($pr.Risk -ge 14) -or (-not $pr.Path)
        if (-not $suspicious) { continue }
        $bad++
        $dests = ($byProc[$k] | Select-Object -Unique | Select-Object -First 10) -join ', '
        $sev = 'WARN'
        if ($pr.Risk -ge 60) { $sev = 'CRIT' }
        $f += New-CgFinding $sev 'Сеть' ('{0} (PID {1}) выходит в интернет' -f $pr.Name, $k) ("Файл: $($pr.Path)`nПодпись: $($pr.Signature)`nКуда: $dests`n`n$($pr.Notes)") $pr.Path '' $pr.Name
    }
    if (-not $bad) { $f += New-CgFinding 'OK' 'Сеть' 'Все соединения принадлежат известным подписанным программам' }
    return $f
}

# ------------------------------------------------------------
# 6. Расширения браузеров
# ------------------------------------------------------------
function Get-CgExtensionList {
    $dangerPerms = @('cookies', '<all_urls>', 'webRequest', 'webRequestBlocking', 'nativeMessaging',
                     'debugger', 'proxy', 'history', 'clipboardRead', 'declarativeNetRequest', 'tabs')
    $out = @()
    foreach ($b in (Get-CgBrowsers)) {
        $extRoots = Get-ChildItem -LiteralPath $b.Root -Directory -ErrorAction SilentlyContinue |
                    ForEach-Object { Join-Path $_.FullName 'Extensions' } |
                    Where-Object { Test-Path -LiteralPath $_ }
        foreach ($er in $extRoots) {
            foreach ($idDir in (Get-ChildItem -LiteralPath $er -Directory -ErrorAction SilentlyContinue)) {
                $verDir = Get-ChildItem -LiteralPath $idDir.FullName -Directory -ErrorAction SilentlyContinue |
                          Sort-Object Name -Descending | Select-Object -First 1
                if (-not $verDir) { continue }
                $mf = Join-Path $verDir.FullName 'manifest.json'
                if (-not (Test-Path -LiteralPath $mf)) { continue }
                $m = $null
                try { $m = Get-Content -LiteralPath $mf -Raw -Encoding UTF8 | ConvertFrom-Json } catch { continue }

                $nm = [string]$m.name
                if ($nm -like '__MSG_*') {
                    $loc = $m.default_locale
                    if (-not $loc) { $loc = 'en' }
                    $msgf = Join-Path $verDir.FullName ("_locales\$loc\messages.json")
                    if (Test-Path -LiteralPath $msgf) {
                        try {
                            $msgs = Get-Content -LiteralPath $msgf -Raw -Encoding UTF8 | ConvertFrom-Json
                            $keyName = $nm -replace '^__MSG_', '' -replace '__$', ''
                            if ($msgs.$keyName) { $nm = $msgs.$keyName.message }
                        } catch { }
                    }
                }
                if (-not $nm) { $nm = $idDir.Name }

                $perms = @()
                if ($m.permissions) { $perms += @($m.permissions) }
                if ($m.host_permissions) { $perms += @($m.host_permissions) }
                if ($m.optional_permissions) { $perms += @($m.optional_permissions) }
                $perms = @($perms | Where-Object { $_ -is [string] })

                $hit = @($perms | Where-Object { $p = $_; ($dangerPerms | Where-Object { $p -like "*$_*" }) })
                $hostPerms = @($perms | Where-Object { $_ -like '*://*' -or $_ -eq '<all_urls>' })
                $hasCookies = @($perms | Where-Object { $_ -eq 'cookies' }).Count -gt 0
                $hasAll = @($hostPerms | Where-Object { $_ -eq '<all_urls>' -or $_ -like '*://*/*' }).Count -gt 0

                $sev = 'OK'; $why = ''
                if ($hasCookies -and $hasAll) { $sev = 'CRIT'; $why = 'МОЖЕТ ЧИТАТЬ COOKIE НА ЛЮБОМ САЙТЕ — то есть войти в ваши аккаунты от вашего имени.' }
                elseif ($hasCookies) { $sev = 'WARN'; $why = 'Имеет доступ к cookie на перечисленных сайтах.' }
                elseif ($perms -contains 'debugger') { $sev = 'WARN'; $why = 'Право debugger — полный контроль над страницей, сильнее любого другого.' }
                elseif ($perms -contains 'proxy') { $sev = 'WARN'; $why = 'Может менять настройки прокси — то есть куда идёт ваш трафик.' }
                elseif ($perms -contains 'nativeMessaging') { $sev = 'WARN'; $why = 'Может общаться с программами на компьютере вне браузера.' }
                elseif ($hit.Count) { $sev = 'NOTE' }

                # расширение, про которое вы уже разобрались и решили оставить
                $tr = $null
                if (Get-Command Test-CgTrusted -ErrorAction SilentlyContinue) {
                    $tr = Test-CgTrusted 'extension' "$($b.Name)|$($idDir.Name)"
                }
                if ($tr) {
                    $sev = 'OK'
                    $why = 'ДОВЕРЕНО ВАМИ' + $(if ($tr.Note) { ": $($tr.Note)" } else { '' }) +
                           "`nПрава у расширения прежние — просто вы решили его оставить. Снять доверие: вкладка «Доверенные»."
                }

                $out += [PSCustomObject]@{
                    Severity = $sev; Order = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'OK' = 3 }[$sev]
                    Browser = $b.Name; Name = $nm; Id = $idDir.Name; Version = $verDir.Name
                    Perms = (($hit | Select-Object -Unique) -join ', ')
                    Sites = (($hostPerms | Select-Object -Unique | Select-Object -First 8) -join ', ')
                    Why = $why; Path = $verDir.FullName
                    Title = $nm; Hash = ''
                    Query = ('Chrome extension ' + $idDir.Name + ' ' + $nm)
                    Detail = "Браузер: $($b.Name)`nНазвание: $nm`nID: $($idDir.Name)`nВерсия: $($verDir.Name)`nОпасные права: $(($hit | Select-Object -Unique) -join ', ')`nСайты: $(($hostPerms | Select-Object -Unique | Select-Object -First 8) -join ', ')`n`n$why`n`nПапка: $($verDir.FullName)`nСтраница в магазине: https://chromewebstore.google.com/detail/$($idDir.Name)"
                }
            }
        }
    }
    return $out
}

function Get-CgExtensionFindings {
    param($ExtensionList)
    if ($null -eq $ExtensionList) { $ExtensionList = Get-CgExtensionList }
    $f = @()
    foreach ($e in ($ExtensionList | Where-Object { $_.Severity -in @('CRIT', 'WARN', 'NOTE') } | Sort-Object Order)) {
        $f += New-CgFinding $e.Severity 'Расширения' ('[{0}] {1}' -f $e.Browser, $e.Name) $e.Detail $e.Path '' $e.Query
    }
    if (-not ($ExtensionList | Where-Object { $_.Severity -in @('CRIT', 'WARN') })) {
        $f += New-CgFinding 'OK' 'Расширения' 'Расширений с опасными правами не найдено'
    }

    foreach ($rk in @('HKLM:\Software\Google\Chrome\Extensions', 'HKLM:\Software\Wow6432Node\Google\Chrome\Extensions',
                      'HKLM:\Software\Microsoft\Edge\Extensions', 'HKCU:\Software\Google\Chrome\Extensions')) {
        foreach ($e in (Get-ChildItem -Path $rk -ErrorAction SilentlyContinue)) {
            $up = Get-ItemProperty -Path $e.PSPath -ErrorAction SilentlyContinue
            $src = $up.update_url
            if (-not $src) { $src = $up.path }
            if (-not $src) {
                $f += New-CgFinding 'NOTE' 'Расширения' ('Пустой ключ расширения в реестре: {0}' -f $e.PSChildName) ("$rk`n`nЗначений нет — ничего не устанавливается, это след от удалённой программы.")
                continue
            }
            $f += New-CgFinding 'WARN' 'Расширения' ('Расширение ставится через реестр: {0}' -f $e.PSChildName) ("$rk`nИсточник: $src`n`nТак расширения ставят в обход вашего согласия — Chrome подтянет его сам.")
        }
    }
    return $f
}

# ------------------------------------------------------------
# 7. Копии баз cookie + права
# ------------------------------------------------------------
function Get-CgCopyFindings {
    $f = @()
    $names = @('cookies', 'login data', 'cookies.sqlite', 'logins.json', 'key4.db', 'web data')
    $searchRoots = @("$env:TEMP", "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Documents",
                     "$env:USERPROFILE\Desktop", "$env:PUBLIC", "$env:ProgramData", "$env:APPDATA")
    $browserRoots = @(Get-CgBrowsers | ForEach-Object { $_.Root.ToLowerInvariant() })
    $copies = 0; $ownStores = 0

    foreach ($r in $searchRoots) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $found = Get-ChildItem -LiteralPath $r -Recurse -Depth 3 -File -Force -ErrorAction SilentlyContinue |
                 Where-Object { $names -contains $_.Name.ToLowerInvariant() }
        foreach ($file in $found) {
            $fl = $file.FullName.ToLowerInvariant()
            $inBrowser = $false
            foreach ($br in $browserRoots) { if ($fl.StartsWith($br)) { $inBrowser = $true; break } }
            if ($inBrowser) { continue }

            $isOwnStore = ($fl -match '\\(network|electron|cef|default)\\cookies$' -or $fl -match '\\qtwebengine\\') -and
                          ($fl -match '\\appdata\\(roaming|local)\\')
            # Программы на Electron кладут Cookies и прямо в корень своей
            # папки в AppData, без подпапки Network — так делают сборки на
            # старом Chromium. Отличить такую папку от подброшенной копии
            # можно по соседям: GPUCache, Local Storage, blob_storage и
            # прочее создаёт только сам движок, и рядом с украденным
            # файлом этого не будет.
            if (-not $isOwnStore -and $fl -match '\\appdata\\(roaming|local)\\') {
                $dir = Split-Path -Parent $file.FullName
                $marks = 0
                foreach ($s in @('Local Storage', 'GPUCache', 'blob_storage', 'Code Cache',
                                 'Session Storage', 'IndexedDB', 'Network Persistent State',
                                 'Service Worker', 'Preferences')) {
                    if (Test-Path -LiteralPath (Join-Path $dir $s)) { $marks++ }
                }
                if ($marks -ge 2) { $isOwnStore = $true }
            }

            if ($isOwnStore) {
                $ownStores++
                $app = ($file.FullName -replace '(?i)^.*\\AppData\\(Roaming|Local)\\', '' -split '\\')[0]
                $f += New-CgFinding 'NOTE' 'Копии' ('Своё хранилище cookie у программы: {0}' -f $app) ("Путь: $($file.FullName)`nИзменён: $($file.LastWriteTime)`n`nЭто не копия браузера — программа на Chromium хранит здесь свои сессии.`nОпасно, только если вы эту программу не ставили.") $file.FullName '' $app
                continue
            }
            $copies++
            $f += New-CgFinding 'CRIT' 'Копии' ('Копия базы браузера в неожиданном месте: {0}' -f $file.Name) ("Путь: $($file.FullName)`nРазмер: $([math]::Round($file.Length/1KB)) КБ`nСоздан: $($file.CreationTime)`nИзменён: $($file.LastWriteTime)`n`nБраузеры и обычные программы сюда такие файлы не кладут.") $file.FullName
        }
    }
    if (-not $copies) { $f += New-CgFinding 'OK' 'Копии' ('Копий баз cookie в подозрительных местах нет (своих хранилищ у программ: {0})' -f $ownStores) }

    $aclBad = 0
    foreach ($t in (Get-CgTargetFiles | Where-Object { $_.Path -match '\\(Cookies|Login Data)$' })) {
        try {
            $acl = Get-Acl -LiteralPath $t.Path -ErrorAction Stop
            foreach ($ace in $acl.Access) {
                $idr = "$($ace.IdentityReference)"
                if ($idr -match 'S-1-1-0|Everyone|Все|ANONYMOUS|Guests|Гости') {
                    $aclBad++
                    $f += New-CgFinding 'CRIT' 'Права' ('К файлу cookie открыт доступ для {0}' -f $idr) ("Файл: $($t.Path)`nПрава: $($ace.FileSystemRights)`n`nЭти файлы должны быть доступны только вам.") $t.Path
                }
            }
        } catch { }
    }
    if (-not $aclBad) { $f += New-CgFinding 'OK' 'Права' 'Права на файлы cookie не ослаблены' }
    return $f
}

# ------------------------------------------------------------
# 8. Недавно появившиеся файлы
# ------------------------------------------------------------
function Get-CgRecentFileFindings {
    $f = @()
    $since = (Get-Date).AddDays(-14)
    $noise = '__PSScriptPolicyTest_|\\Microsoft\\WindowsApps\\|\\Packages\\|\\INetCache\\|\\WebCache\\'
    $recent = @()
    foreach ($r in @("$env:TEMP", "$env:USERPROFILE\Downloads", "$env:APPDATA", "$env:LOCALAPPDATA", "$env:ProgramData", "$env:PUBLIC")) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        $recent += Get-ChildItem -LiteralPath $r -Recurse -Depth 3 -File -Force -ErrorAction SilentlyContinue |
                   Where-Object {
                       $_.CreationTime -gt $since -and $_.FullName -notmatch $noise -and (
                           $_.Extension -match '^\.(exe|scr|ps1|vbs|js|bat|cmd|jar|msi)$' -or
                           ($_.Extension -eq '.dll' -and (Get-CgPathClass $_.FullName) -in @('temp', 'downloads', 'public'))
                       )
                   }
    }
    $groups = $recent | Group-Object { Split-Path -Parent $_.FullName }
    $n = 0
    foreach ($g in ($groups | Sort-Object { -$_.Count })) {
        $unsigned = @($g.Group | Where-Object { -not (Get-CgSignature $_.FullName).Trusted })
        if (-not $unsigned.Count) { continue }
        $n++
        $cls = Get-CgPathClass $g.Name
        $sev = 'NOTE'
        if (@('temp', 'downloads', 'public') -contains $cls) { $sev = 'WARN' }
        $newest = ($unsigned | Sort-Object CreationTime -Descending)[0]
        $sig = Get-CgSignature $newest.FullName
        $sample = (($unsigned | Sort-Object CreationTime -Descending | Select-Object -First 8).Name) -join ', '
        if ($unsigned.Count -gt 1) { $title = ('{0} — {1} новых файлов' -f (Split-Path -Leaf $g.Name), $unsigned.Count) }
        else { $title = ('{0} — {1}' -f (Split-Path -Leaf $g.Name), $newest.Name) }
        $f += New-CgFinding $sev 'Новые файлы' $title ("Папка: $($g.Name)`nПоявились: $($newest.CreationTime)`nФайлы: $sample`nПодпись: $($sig.Status) $($sig.Signer)") $newest.FullName (Get-CgHash $newest.FullName) $newest.Name
        if ($n -ge 20) { break }
    }
    if (-not $n) { $f += New-CgFinding 'OK' 'Новые файлы' 'Новых неподписанных программ за 14 дней не найдено' }
    return $f
}

# ------------------------------------------------------------
# 9. История обращений к cookie
# ------------------------------------------------------------
function Test-CgAuditEnabled {
    # Разбор вынесен в Core.ps1: раньше здесь искалось слово Success
    # в выводе на языке системы, и на русской Windows включённый
    # аудит читался как выключенный.
    return (Get-CgAuditPolState '{0CCE921D-69AE-11D9-BED3-505054503030}').Enabled
}

# Расшифровка того, ЧТО именно делали с файлом. Это принципиально:
# чтение содержимого и смена прав доступа — совершенно разные события,
# и валить их в одну кучу значит пугать человека на ровном месте.
function Get-CgAccessKind {
    param([string]$AccessList, [string]$AccessMask)
    $a = "$AccessList"
    $kinds = @()
    if ($a -match '%%4416') { $kinds += 'чтение содержимого' }
    if ($a -match '%%4417|%%4418') { $kinds += 'запись' }
    if ($a -match '%%1537') { $kinds += 'удаление' }
    if ($a -match '%%1539|%%1540') { $kinds += 'смена прав доступа' }
    if ($a -match '%%4423' -and -not $kinds.Count) { $kinds += 'чтение свойств файла' }
    if (-not $kinds.Count) {
        if ($AccessMask -and ([Convert]::ToInt32($AccessMask, 16) -band 0x1)) { $kinds += 'чтение содержимого' }
        else { $kinds += "иное ($AccessMask)" }
    }
    return ($kinds -join ', ')
}

# Командная строка процесса по его PID около заданного времени.
# Работает, только если включён журнал запуска программ (4688).
function Get-CgCmdLineForPid {
    param([int]$ProcId, [datetime]$Near)
    if (-not (Test-CgProcAuditEnabled)) { return '' }
    try {
        $evts = Get-WinEvent -FilterHashtable @{
            LogName = 'Security'; Id = 4688
            StartTime = $Near.AddMinutes(-30); EndTime = $Near.AddMinutes(1)
        } -MaxEvents 1500 -ErrorAction SilentlyContinue
        foreach ($e in @($evts)) {
            $x = [xml]$e.ToXml(); $h = @{}
            foreach ($d in $x.Event.EventData.Data) { $h[$d.Name] = $d.'#text' }
            $np = $h['NewProcessId']
            if (-not $np) { continue }
            if ([Convert]::ToInt32($np, 16) -eq $ProcId) {
                $c = $h['CommandLine']
                if ($c) { return $c }
                return $h['NewProcessName']
            }
        }
    } catch { }
    return ''
}

function Get-CgAuditHistoryFindings {
    param([int]$Days = 7)
    $f = @()
    if (-not (Test-CgAuditEnabled)) {
        $f += New-CgFinding 'WARN' 'Аудит' 'Аудит доступа к файлам выключен — истории обращений нет' 'Нажмите «Включить аудит», чтобы Windows начала записывать, какая программа открывает файлы cookie. Без этого вопрос «кто взял мои cookie» остаётся без ответа.'
        return $f
    }

    $watch = @{}
    foreach ($t in (Get-CgTargetFiles)) { $watch[$t.Path.ToLowerInvariant()] = $t.Browser }

    # Группируем по связке процесс + ЧТО делал, а не просто по процессу
    $groups = @{}
    try {
        $evts = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4656, 4663; StartTime = (Get-Date).AddDays(-$Days) } -MaxEvents 20000 -ErrorAction SilentlyContinue
        foreach ($e in @($evts)) {
            $x = [xml]$e.ToXml(); $h = @{}
            foreach ($d in $x.Event.EventData.Data) { $h[$d.Name] = $d.'#text' }
            $o = $h['ObjectName']
            if (-not $o -or -not $watch.ContainsKey($o.ToLowerInvariant())) { continue }

            $proc = $h['ProcessName']
            if (-not $proc) { $proc = '(неизвестно)' }
            $kind = Get-CgAccessKind $h['AccessList'] $h['AccessMask']
            $procId = 0
            if ($h['ProcessId']) { try { $procId = [Convert]::ToInt32($h['ProcessId'], 16) } catch { } }

            $key = "$proc|$kind"
            if (-not $groups.ContainsKey($key)) {
                $groups[$key] = [PSCustomObject]@{
                    Proc = $proc; Kind = $kind; Count = 0
                    First = $e.TimeCreated; Last = $e.TimeCreated
                    Files = New-Object System.Collections.ArrayList
                    Pids = New-Object System.Collections.ArrayList
                    Events = New-Object System.Collections.ArrayList
                }
            }
            $g = $groups[$key]
            $g.Count++
            if ($e.TimeCreated -lt $g.First) { $g.First = $e.TimeCreated }
            if ($e.TimeCreated -gt $g.Last) { $g.Last = $e.TimeCreated }
            if (-not $g.Files.Contains($o)) { $null = $g.Files.Add($o) }
            if ($procId -and -not $g.Pids.Contains($procId)) { $null = $g.Pids.Add($procId) }
            if ($g.Events.Count -lt 40) {
                $null = $g.Events.Add(('{0}  PID {1}  {2}' -f $e.TimeCreated.ToString('dd.MM HH:mm:ss'), $procId, (Split-Path -Leaf $o)))
            }
        }
    } catch { }

    if (-not $groups.Count) {
        $f += New-CgFinding 'OK' 'Аудит' ('Аудит включён, обращений к файлам cookie за {0} дн. не зафиксировано' -f $Days)
        return $f
    }

    $browserExe = @{}
    foreach ($b in (Get-CgBrowsers)) { foreach ($e in $b.Exe) { $browserExe[$e.ToLowerInvariant()] = $b.Name } }

    foreach ($g in ($groups.Values | Sort-Object { -$_.Count })) {
        $leaf = Split-Path -Leaf $g.Proc
        $isBrowser = $browserExe.ContainsKey($g.Proc.ToLowerInvariant())
        $readsContent = ($g.Kind -match 'чтение содержимого')
        $onlyPerms = ($g.Kind -match 'смена прав доступа' -and -not $readsContent)

        # Подробности, по которым можно проверить самому
        $detail = "Программа: $($g.Proc)`n"
        $detail += "Что делала: $($g.Kind)`n"
        $detail += "Обращений: $($g.Count)`n"
        $detail += "Первое: $($g.First.ToString('dd.MM.yyyy HH:mm:ss'))`n"
        $detail += "Последнее: $($g.Last.ToString('dd.MM.yyyy HH:mm:ss'))`n"
        if ($g.Pids.Count) { $detail += "PID: $(($g.Pids | Select-Object -First 10) -join ', ')`n" }
        $sg = Get-CgSignature $g.Proc
        $detail += "Подпись: $($sg.Status) $($sg.Signer)`n"

        $cmd = ''
        if ($g.Pids.Count) { $cmd = Get-CgCmdLineForPid ([int]$g.Pids[0]) $g.First }
        if ($cmd) {
            $detail += "Команда запуска: $cmd`n"
        } else {
            $detail += "Команда запуска: неизвестна — включите «Журнал запуска программ» в разделе «Защита», тогда она будет видна`n"
        }
        $detail += "`nФайлы ($($g.Files.Count)):`n" + (($g.Files | Select-Object -First 15 | ForEach-Object { '  ' + $_ }) -join "`n")
        $detail += "`n`nСобытия:`n" + (($g.Events | Select-Object -First 20 | ForEach-Object { '  ' + $_ }) -join "`n")
        if ($g.Count -gt 20) { $detail += "`n  ... всего $($g.Count), показаны первые 20" }
        $detail += "`n`nПроверить самому: Просмотр событий → Журналы Windows → Безопасность → фильтр по коду 4663."

        if ($isBrowser) {
            $f += New-CgFinding 'OK' 'Аудит' ('{0} — {1}, обращений: {2} (это сам браузер)' -f $leaf, $g.Kind, $g.Count) $detail $g.Proc
            continue
        }

        if ($onlyPerms) {
            # Права меняет тот, кто ставит аудит. В том числе мы сами.
            $hint = "`n`nСмена прав доступа — это НЕ чтение ваших cookie. Так выглядит установка аудита."
            if ($leaf -match '^(powershell|pwsh)\.exe$') {
                $hint += "`nСкорее всего, это сам CookieGuard, когда вы нажали «Включить аудит»."
            }
            $f += New-CgFinding 'NOTE' 'Аудит' ('{0} менял права доступа к файлам cookie ({1} раз)' -f $leaf, $g.Count) ($detail + $hint) $g.Proc
            continue
        }

        if (-not $readsContent) {
            $f += New-CgFinding 'NOTE' 'Аудит' ('{0} — {1}, обращений: {2}' -f $leaf, $g.Kind, $g.Count) ($detail + "`n`nСодержимое файла при этом не читалось.") $g.Proc
            continue
        }

        $f += New-CgFinding 'CRIT' 'Аудит' ('{0} ЧИТАЛ содержимое базы cookie ({1} раз)' -f $leaf, $g.Count) (
            $detail + "`n`nУ обычной программы нет причин читать содержимое базы cookie браузера."
        ) $g.Proc (Get-CgHash $g.Proc) $leaf
    }
    return $f
}

# ------------------------------------------------------------
#  Перехват самого браузера
#
#  Слабое место наблюдения за файлом cookie: современная кража
#  часто этот файл вообще не открывает. С Chrome 127 содержимое
#  защищено привязкой к приложению, и читать базу напрямую стало
#  невыгодно. Вместо этого браузер запускают с отладочным портом
#  и просят отдать cookie уже расшифрованными — для файловой
#  системы не происходит ничего. Поэтому следим ещё и за тем,
#  КАК запущен браузер.
# ------------------------------------------------------------
function Get-CgBrowserHijackFindings {
    $f = @()
    $bad = 0
    $browserNames = @('chrome.exe', 'msedge.exe', 'brave.exe', 'opera.exe', 'vivaldi.exe', 'browser.exe')

    foreach ($p in (Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
        if ($browserNames -notcontains "$($p.Name)".ToLowerInvariant()) { continue }
        $cmd = "$($p.CommandLine)"
        if (-not $cmd) { continue }
        $hits = @()
        if ($cmd -match '--remote-debugging-port|--remote-debugging-pipe') { $hits += 'включён отладочный порт — через него можно забрать cookie уже расшифрованными, не трогая файл' }
        if ($cmd -match '--load-extension=') { $hits += 'принудительно загружено расширение из папки, в обход магазина' }
        if ($cmd -match '--disable-web-security') { $hits += 'отключена защита между сайтами' }
        if ($cmd -match '--user-data-dir=' -and $cmd -notmatch '(?i)\\User Data') { $hits += 'подменена папка профиля' }
        if ($cmd -match '--disable-features=[^ ]*LockProfileCookieDatabase') { $hits += 'снята блокировка базы cookie' }
        if (-not $hits.Count) { continue }
        $bad++
        $parent = ''
        $pp = Get-CimInstance Win32_Process -Filter "ProcessId=$($p.ParentProcessId)" -ErrorAction SilentlyContinue
        if ($pp) { $parent = "$($pp.Name) (PID $($pp.ProcessId))" }
        $f += New-CgFinding 'CRIT' 'Браузер' ('{0} запущен с опасными ключами (PID {1})' -f $p.Name, $p.ProcessId) (
            "Процесс: $($p.ExecutablePath)`nPID: $($p.ProcessId)`nЗапущен из: $parent`n`nКоманда:`n$cmd`n`n" +
            (($hits | ForEach-Object { '- ' + $_ }) -join "`n") +
            "`n`nЕсли вы не запускали браузер вручную с такими ключами — закройте его и разберитесь, кто его так запустил."
        ) $p.ExecutablePath '' $p.Name
    }

    # Слушающий порт отладки — то же самое, но видно даже без командной строки
    foreach ($port in @(9222, 9223, 9229, 21222)) {
        foreach ($c in (Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue)) {
            $op = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
            $bad++
            $f += New-CgFinding 'CRIT' 'Браузер' ('Открыт порт удалённого управления браузером: {0}' -f $port) (
                "Слушает: $(if ($op) { "$($op.ProcessName) (PID $($op.Id))`n$($op.Path)" } else { "PID $($c.OwningProcess)" })`nАдрес: $($c.LocalAddress):$port`n`nЧерез этот порт можно управлять браузером и получать cookie в расшифрованном виде.`nОн нужен разработчикам. Если вы ничего не отлаживаете — это не должно быть открыто."
            ) $(if ($op) { $op.Path } else { '' })
        }
    }

    if (-not $bad) { $f += New-CgFinding 'OK' 'Браузер' 'Браузеры запущены обычным образом, портов удалённого управления нет' }
    return $f
}

# ------------------------------------------------------------
#  Adobe: скрипты и расширения
#
#  Почему это отдельный раздел. У Premiere, After Effects и
#  остальных есть ExtendScript — полноценный язык с доступом к
#  диску, к запуску программ и к сети. Скрипт из папки Startup
#  запускается САМ при каждом старте приложения, лежит в обычном
#  .jsx и никакой подписи не имеет. Для антивируса это просто
#  текстовый файл. Отсюда и берётся «тот же почерк»: конечная
#  цель та же — cookie и пароли, меняется только способ попасть
#  в систему (пиратский плагин вместо .exe).
# ------------------------------------------------------------

# Вызовы, которыми скрипт выходит за пределы монтажа.
# Сами по себе они законны — ими пользуются и честные плагины.
# Опасна их совокупность и место, где лежит файл.
$script:AdobeRiskyApi = @(
    @{ P = 'system\.callSystem';            W = 45; T = 'запускает команды операционной системы' },
    @{ P = '\$\.evalFile|\beval\s*\(';      W = 30; T = 'выполняет код из другого файла или из строки' },
    @{ P = 'new\s+Socket|\bSocket\s*\(';    W = 40; T = 'открывает сетевое соединение напрямую' },
    @{ P = 'XMLHttpRequest|\bfetch\s*\(';   W = 30; T = 'обращается к сети' },
    @{ P = 'cmd\.exe|powershell|certutil|bitsadmin|curl\s|wget\s'; W = 50; T = 'вызывает системные утилиты' },
    @{ P = 'String\.fromCharCode\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+'; W = 25; T = 'текст собирается из кодов символов (приём сокрытия)' },
    @{ P = 'decodeURIComponent\s*\(\s*escape|unescape\s*\(';      W = 20; T = 'строки спрятаны за перекодировкой' },
    @{ P = '[A-Za-z0-9+/]{200,}={0,2}';     W = 25; T = 'внутри большой блок Base64' },
    @{ P = 'Folder\.startup|Scripts[\\/]+Startup'; W = 45; T = 'сам обращается к папке автозапуска скриптов' },
    @{ P = '\.copy\s*\(|\.write\s*\(';      W = 10; T = 'пишет файлы на диск' }
)

function Get-CgAdobeScriptDirs {
    $dirs = New-Object System.Collections.ArrayList
    $appRoots = @()
    foreach ($b in @('C:\Program Files\Adobe', 'C:\Program Files (x86)\Adobe')) {
        $appRoots += @(Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    }
    foreach ($r in $appRoots) {
        foreach ($sub in @('Scripts', 'Scripts\Startup', 'Scripts\Shutdown', 'Scripts\ScriptUI Panels',
                           'Support Files\Scripts', 'Support Files\Scripts\Startup',
                           'Support Files\Scripts\Shutdown', 'Support Files\Scripts\ScriptUI Panels',
                           'Presets\Scripts', 'CEP\extensions')) {
            $p = Join-Path $r $sub
            if (Test-Path -LiteralPath $p) { $null = $dirs.Add($p) }
        }
    }
    # пользовательские места — туда пишут без прав администратора
    foreach ($p in @("$env:APPDATA\Adobe\CEP\extensions",
                     "$env:ProgramData\Adobe\CEP\extensions",
                     'C:\Program Files (x86)\Common Files\Adobe\CEP\extensions',
                     'C:\Program Files\Common Files\Adobe\CEP\extensions',
                     "$env:APPDATA\Adobe\UXP\Plugins",
                     "$env:APPDATA\Adobe\Common\Plug-ins")) {
        if (Test-Path -LiteralPath $p) { $null = $dirs.Add($p) }
    }
    foreach ($d in (Get-ChildItem "$env:APPDATA\Adobe" -Directory -ErrorAction SilentlyContinue)) {
        foreach ($sub in @('Scripts', 'Scripts\Startup', 'Scripts\ScriptUI Panels')) {
            $p = Join-Path $d.FullName $sub
            if (Test-Path -LiteralPath $p) { $null = $dirs.Add($p) }
        }
    }
    return @($dirs | Sort-Object -Unique)
}

function Get-CgAdobeFindings {
    $f = @()
    $appRoots = @()
    foreach ($b in @('C:\Program Files\Adobe', 'C:\Program Files (x86)\Adobe')) {
        $appRoots += @(Get-ChildItem -LiteralPath $b -Directory -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    }
    if (-not $appRoots.Count) {
        $f += New-CgFinding 'OK' 'Adobe' 'Программы Adobe не найдены — проверять нечего'
        return $f
    }
    $f += New-CgFinding 'INFO' 'Adobe' ('Найдено программ Adobe: {0}' -f $appRoots.Count) (($appRoots | ForEach-Object { Split-Path -Leaf $_ }) -join "`n")

    # ---- 1. Скрипты ----
    #
    # Отбор строгий, и вот почему. Сама Adobe привозит с собой сотни .js:
    # темы оформления, jQuery, CSInterface, сборки панелей. Они лежат в
    # Program Files, куда без прав администратора не записать, и ни один
    # из них не запускается сам. Если показывать их все, список находок
    # перестанут читать — а это хуже, чем не показывать ничего.
    #
    # Значимы три вещи:
    #   автозапуск      — скрипт стартует сам, без участия человека;
    #   место для всех  — файл можно подменить без прав администратора;
    #   .jsxbin         — содержимое намеренно нечитаемо.
    # Проверка содержимого применяется только к таким файлам.

    $adobeNoise = '\.bundle\.js$|-main-scss|^jquery|^CSInterface\.js$|^json2\.js(x)?$|' +
                  '^node-modules-bundle\.js$|\.min\.js$|\.worker\.js$|^shims\.jsx$|^base\.jsx$|' +
                  '\\CEP\\extensions\\com\.adobe\.|\\FirstMile\\|\\node_modules\\'

    $byHash = @{}
    $scanned = 0
    $hits = New-Object System.Collections.ArrayList

    foreach ($dir in (Get-CgAdobeScriptDirs)) {
        $isAutoRun = ($dir -match '\\(Startup|Shutdown|ScriptUI Panels)$')
        # куда может писать обычный пользователь, без повышения прав
        $isUserWritable = ($dir -match '(?i)\\AppData\\|\\ProgramData\\|\\Users\\Public\\')

        foreach ($file in (Get-ChildItem -LiteralPath $dir -Recurse -Depth 3 -File -ErrorAction SilentlyContinue)) {
            if ($file.Extension -notmatch '^\.(jsx|jsxbin|js)$') { continue }
            if ($file.FullName -match $adobeNoise) { continue }
            # обычный .js из комплекта поставки в Program Files не рассматриваем
            if ($file.Extension -eq '.js' -and -not $isUserWritable -and -not $isAutoRun) { continue }
            $scanned++

            $score = 0; $notes = @()
            if ($isAutoRun) { $score += 25; $notes += 'лежит в папке автозапуска — выполняется сам при каждом старте программы' }
            if ($isUserWritable) { $score += 25; $notes += 'лежит там, где файл можно подменить без прав администратора' }
            if ($file.Extension -eq '.jsxbin') { $score += 30; $notes += 'скомпилированный .jsxbin — прочитать, что он делает, невозможно' }

            # содержимое смотрим только у тех, кто уже чем-то выделился
            if ($score -gt 0 -and $file.Extension -ne '.jsxbin' -and $file.Length -lt 3MB) {
                $txt = ''
                try { $txt = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop } catch { }
                if ($txt) {
                    foreach ($rule in $script:AdobeRiskyApi) {
                        if ($txt -match $rule.P) { $score += $rule.W; $notes += $rule.T }
                    }
                }
            }
            if ($isAutoRun -and $file.CreationTime -gt (Get-Date).AddDays(-30)) {
                $score += 15
                $notes += ('появился недавно: {0}' -f $file.CreationTime.ToString('dd.MM.yyyy'))
            }
            if ($isAutoRun) {
                $h = Get-CgHash $file.FullName
                if ($h) {
                    if (-not $byHash.ContainsKey($h)) { $byHash[$h] = New-Object System.Collections.ArrayList }
                    $null = $byHash[$h].Add($file.FullName)
                }
            }

            if ($score -lt 45) { continue }
            $null = $hits.Add([PSCustomObject]@{ File = $file; Score = $score; Notes = @($notes | Select-Object -Unique) })
        }
    }

    foreach ($hit in ($hits | Sort-Object { -$_.Score } | Select-Object -First 25)) {
        $sev = 'NOTE'
        if ($hit.Score -ge 90) { $sev = 'CRIT' } elseif ($hit.Score -ge 60) { $sev = 'WARN' }
        $f += New-CgFinding $sev 'Adobe' ('Скрипт: {0}' -f $hit.File.Name) (
            "Файл: $($hit.File.FullName)`nРазмер: $([math]::Round($hit.File.Length/1KB)) КБ`nСоздан: $($hit.File.CreationTime)`nИзменён: $($hit.File.LastWriteTime)`nОценка: $($hit.Score)`n`n" +
            (($hit.Notes | ForEach-Object { '- ' + $_ }) -join "`n") +
            "`n`nЧто делать: вспомните, какой плагин вы ставили. Если такого плагина вы не ставили —`nуберите файл в карантин кнопкой ниже и перезапустите программу Adobe."
        ) $hit.File.FullName (Get-CgHash $hit.File.FullName) $hit.File.Name
    }
    if ($hits.Count -gt 25) {
        $f += New-CgFinding 'INFO' 'Adobe' ('Ещё {0} скриптов с признаками риска не показаны' -f ($hits.Count - 25))
    }
    $f += New-CgFinding 'INFO' 'Adobe' ('Проверено скриптов: {0}, помечено: {1}' -f $scanned, $hits.Count)
    if (-not $hits.Count) { $f += New-CgFinding 'OK' 'Adobe' 'Подозрительных скриптов в папках Adobe не найдено' }

    # ---- 2. Саморазмножение: один и тот же скрипт в нескольких автозапусках ----
    foreach ($h in $byHash.Keys) {
        if ($byHash[$h].Count -lt 2) { continue }
        $f += New-CgFinding 'CRIT' 'Adobe' 'Один и тот же скрипт лежит в автозапуске нескольких программ' (
            "SHA256: $h`n`nКопии:`n" + (($byHash[$h] | ForEach-Object { '  ' + $_ }) -join "`n") +
            "`n`nСам себя копирующий скрипт — это поведение червя. Законные плагины так не ставятся."
        ) $byHash[$h][0] $h
    }

    # ---- 3. Разрешение скриптам писать файлы и ходить в сеть ----
    $prefHit = $false
    foreach ($pf in (Get-ChildItem "$env:APPDATA\Adobe" -Recurse -Depth 3 -File -Filter '*Prefs*.txt' -ErrorAction SilentlyContinue)) {
        $t = ''
        try { $t = Get-Content -LiteralPath $pf.FullName -Raw -ErrorAction Stop } catch { }
        if (-not $t) { continue }
        if ($t -match '"Pref_SCRIPTING_FILE_NETWORK_SECURITY"\s*=\s*"?0*1"?') {
            $prefHit = $true
            $f += New-CgFinding 'WARN' 'Adobe' 'Скриптам разрешено писать файлы и выходить в сеть' (
                "Файл настроек: $($pf.FullName)`n`nЭто та самая галка «Allow Scripts to Write Files and Access Network».`nБез неё многие плагины не работают — но с ней ЛЮБОЙ скрипт получает диск и сеть.`n`nЕсли сейчас вы плагинами не пользуетесь, снимите её:`nPremiere/After Effects → Правка → Настройки → Сценарии и выражения."
            ) $pf.FullName
        }
    }
    if (-not $prefHit) { $f += New-CgFinding 'OK' 'Adobe' 'Разрешение скриптам на диск и сеть нигде не включено' }

    # ---- 4. Загрузка неподписанных расширений ----
    $dbg = $false
    foreach ($k in (Get-ChildItem 'HKCU:\Software\Adobe' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like 'CSXS*' })) {
        $v = (Get-ItemProperty -Path $k.PSPath -Name 'PlayerDebugMode' -ErrorAction SilentlyContinue).PlayerDebugMode
        if ("$v" -eq '1') {
            $dbg = $true
            $f += New-CgFinding 'CRIT' 'Adobe' ('Разрешена загрузка неподписанных расширений ({0})' -f $k.PSChildName) (
                "Ключ: $($k.PSPath)`nЗначение PlayerDebugMode = 1`n`nAdobe обычно грузит только подписанные расширения. Этот режим снимает проверку —`nего включают разработчики, а ещё его включают установщики пиратских плагинов,`nчтобы протащить своё. Если вы не пишете расширения сами — выключите."
            ) -Target ([PSCustomObject]@{
                Kind = 'regvalue'; Path = "HKCU:\Software\Adobe\$($k.PSChildName)"; Name = 'PlayerDebugMode'; Was = '1'; Restore = '0'
            })
        }
    }
    if (-not $dbg) { $f += New-CgFinding 'OK' 'Adobe' 'Загрузка неподписанных расширений выключена' }

    # ---- 5. Расширения CEP ----
    #
    # Прежняя версия помечала «ВНИМАНИЕ» любое расширение в
    # пользовательской папке. Это бесполезная тревога: Creative
    # Cloud сама ставит туда свои панели, и человек справедливо
    # отвечал «ну да, Adobe так работает». Такая находка не
    # помогает решить, а учит не читать находки.
    #
    # Что решает дело. Adobe грузит только ПОДПИСАННЫЕ расширения;
    # неподписанное загрузится, только если включён PlayerDebugMode
    # (это проверено выше, в $dbg). Значит, важны не папка и не
    # отсутствие подписи сами по себе, а сочетание:
    #
    #   подписано Adobe              — норма, это её собственная панель
    #   подписано третьей стороной   — заметка, издателя называем
    #   без подписи и debug выключен — лежит, но НЕ РАБОТАЕТ
    #   без подписи и debug включён  — вот это и надо смотреть
    #
    # и отдельно — что расширение делает: сетевые и системные
    # вызовы считаются теми же весами, что и для скриптов.
    $extN = 0
    $extDirs = @(
        @{ P = "$env:APPDATA\Adobe\CEP\extensions";   Who = 'только для вас' },
        @{ P = "$env:ProgramData\Adobe\CEP\extensions"; Who = 'для всех пользователей' }
    )

    foreach ($spec in $extDirs) {
        foreach ($d in (Get-ChildItem -LiteralPath $spec.P -Directory -ErrorAction SilentlyContinue)) {
            $extN++

            # --- кто это по документам самого расширения ---
            $bundleId = ''; $bundleName = ''; $bundleVer = ''; $hosts = @()
            $mf = Join-Path $d.FullName 'CSXS\manifest.xml'
            if (Test-Path -LiteralPath $mf) {
                try {
                    [xml]$mx = Get-Content -LiteralPath $mf -Raw -ErrorAction Stop
                    $bundleId   = "$($mx.ExtensionManifest.ExtensionBundleId)"
                    $bundleName = "$($mx.ExtensionManifest.ExtensionBundleName)"
                    $bundleVer  = "$($mx.ExtensionManifest.ExtensionBundleVersion)"
                    $hosts = @($mx.ExtensionManifest.ExecutionEnvironment.HostList.Host | ForEach-Object { "$($_.Name)" } | Where-Object { $_ })
                } catch { }
            }
            if (-not $bundleName) { $bundleName = $d.Name }

            # --- подписано ли ---
            # ZXP-пакет при установке приносит META-INF\signatures.xml;
            # у распакованного вручную расширения его нет.
            $signed = (Test-Path -LiteralPath (Join-Path $d.FullName 'META-INF\signatures.xml')) -or
                      (Test-Path -LiteralPath (Join-Path $d.FullName 'META-INF\signatures.xml.sig'))
            $byAdobe = ($bundleId -like 'com.adobe.*')

            # --- что оно умеет ---
            $score = 0
            $why = New-Object System.Collections.ArrayList
            $files = @()
            foreach ($jf in (Get-ChildItem -LiteralPath $d.FullName -Recurse -Depth 4 -File -ErrorAction SilentlyContinue |
                             Where-Object { $_.Extension -in '.js', '.jsx', '.html', '.htm', '.json' } | Select-Object -First 80)) {
                $t = ''
                try { $t = Get-Content -LiteralPath $jf.FullName -Raw -ErrorAction Stop } catch { }
                if (-not $t) { continue }
                foreach ($rule in $script:AdobeRiskyApi) {
                    if ($t -match $rule.P) {
                        if ($why -notcontains $rule.T) { $null = $why.Add($rule.T); $score += $rule.W }
                        $files += $jf.Name
                    }
                }
            }

            # --- вердикт ---
            $sev = 'INFO'
            $verdict = ''
            if ($byAdobe -and $signed) {
                $sev = 'OK'
                $verdict = 'Это собственная панель Adobe: подписана и опознана по идентификатору com.adobe.*. Так и должно быть.'
            } elseif ($signed) {
                $sev = 'NOTE'
                $verdict = 'Расширение подписано, то есть установлено из готового пакета ZXP, а не подложено в папку. Это не гарантия честности, но подделать подпись без ключа издателя нельзя.'
                if ($score -ge 60) { $sev = 'WARN' }
            } elseif (-not $dbg) {
                $sev = 'NOTE'
                $verdict = 'Подписи нет, но загрузка неподписанных расширений выключена (PlayerDebugMode = 0) — значит, Adobe его НЕ ЗАГРУЖАЕТ. Сейчас оно просто лежит на диске и не работает.'
            } else {
                $sev = 'WARN'
                $verdict = 'Подписи нет, И при этом включена загрузка неподписанных расширений. Вот сочетание, ради которого эта проверка и сделана: расширение будет загружено, хотя никто за него не отвечает.'
                if ($score -ge 45) { $sev = 'CRIT' }
            }

            $det = "Папка: $($d.FullName)`nУстановлено: $($spec.Who)"
            if ($bundleId)  { $det += "`nИдентификатор: $bundleId" }
            if ($bundleVer) { $det += "`nВерсия: $bundleVer" }
            if ($hosts.Count) { $det += "`nПодключается к: $($hosts -join ', ')" }
            $det += "`nПодпись пакета: " + $(if ($signed) { 'есть' } else { 'нет' })
            $det += "`nЗагрузка неподписанных (PlayerDebugMode): " + $(if ($dbg) { 'ВКЛЮЧЕНА' } else { 'выключена' })
            $det += "`n`n$verdict"

            if ($why.Count) {
                $det += "`n`nЧто расширение умеет (вес $score):`n" + (($why | ForEach-Object { '  - ' + $_ }) -join "`n")
                $det += "`nВстречено в файлах: " + (($files | Select-Object -Unique -First 6) -join ', ')
                $det += "`n`nСами по себе эти вызовы законны — ими пользуются и честные панели. Значение имеет их совокупность вместе с отсутствием подписи."
            } else {
                $det += "`n`nОбращений к системе и сети внутри не найдено."
            }

            if (-not $signed -and -not $dbg) {
                # Неподписанное и незагружаемое — но только пока режим
                # выключен. Сказать «ничего не делайте» было бы неполно:
                # один щелчок в PlayerDebugMode оживляет его.
                $det += "`n`nЧто делать: сейчас оно безвредно, потому что не загружается. Но если когда-нибудь включите загрузку неподписанных расширений — оно оживёт. Если такую панель вы не ставили, папку лучше убрать."
            } elseif ($sev -eq 'OK' -or $sev -eq 'NOTE') {
                $det += "`n`nЧто делать: ничего. Если панель вам не нужна — удалите её через Creative Cloud, а не из папки."
            } else {
                $det += "`n`nЧто делать: вспомните, ставили ли вы такую панель. Если нет — выключите PlayerDebugMode (находка выше), и расширение перестанет загружаться; саму папку можно убрать в карантин."
            }

            # Папка расширения целиком — это и есть «со всеми ветками»:
            # манифест, скрипты, ресурсы. Исправлению нужен именно каталог.
            $f += New-CgFinding $sev 'Adobe' ('Расширение Adobe: {0}' -f $bundleName) $det $d.FullName '' $bundleName `
                -Target ([PSCustomObject]@{ Kind = 'folder'; Path = $d.FullName; Name = $bundleName; Signed = $signed })
        }
    }
    if (-not $extN) { $f += New-CgFinding 'OK' 'Adobe' 'Расширений Adobe в пользовательских папках нет' }

    return $f
}

# ------------------------------------------------------------
#  История запуска программ — чтобы опознать мелькнувшее окно
# ------------------------------------------------------------
function Test-CgProcAuditEnabled {
    $out = & auditpol /get /subcategory:'{0CCE922B-69AE-11D9-BED3-505054503030}' 2>&1 | Out-String
    return ($out -match 'Success' -or $out -match 'Успех')
}

function Get-CgProcessStarts {
    param([int]$Hours = 6, [int]$Max = 2000)
    $out = New-Object System.Collections.ArrayList
    $since = (Get-Date).AddHours(-$Hours)

    # Шумные служебные запуски Windows: они идут десятками в минуту и
    # в списке «что это было» только мешают.
    $noise = '\\svchost\.exe$|\\RuntimeBroker\.exe$|\\backgroundTaskHost\.exe$|\\dllhost\.exe$|\\conhost\.exe$|\\taskhostw\.exe$|\\SearchProtocolHost\.exe$|\\SearchFilterHost\.exe$|\\WmiPrvSE\.exe$|\\audiodg\.exe$|\\smartscreen\.exe$|\\consent\.exe$|\\sppsvc\.exe$'

    if (Test-CgProcAuditEnabled) {
        try {
            $evts = Get-WinEvent -FilterHashtable @{ LogName = 'Security'; Id = 4688; StartTime = $since } -MaxEvents $Max -ErrorAction SilentlyContinue
            foreach ($e in @($evts)) {
                $x = [xml]$e.ToXml(); $h = @{}
                foreach ($d in $x.Event.EventData.Data) { $h[$d.Name] = $d.'#text' }
                $img = Get-CgNormPath $h['NewProcessName']
                if (-not $img) { continue }
                if ($img -match $noise) { continue }
                $cmd = $h['CommandLine']
                $parent = Get-CgNormPath $h['ParentProcessName']
                $cls = Get-CgPathClass $img
                $nm = Split-Path -Leaf $img

                $sev = 'INFO'; $notes = @()
                if (@('temp', 'downloads', 'public', 'odd') -contains $cls) { $sev = 'WARN'; $notes += 'запущен из временной или пользовательской папки' }
                if ($cmd -match '-enc\b|FromBase64String|DownloadString|-w\s+hidden|-windowstyle\s+hidden') { $sev = 'CRIT'; $notes += 'скрытая или закодированная команда' }
                if ($script:LolBins -contains $nm.ToLowerInvariant()) {
                    if ($sev -eq 'INFO') { $sev = 'NOTE' }
                    $notes += 'интерпретатор или системная утилита'
                }

                $null = $out.Add([PSCustomObject]@{
                    Severity = $sev; Order = @{ 'CRIT' = 0; 'WARN' = 1; 'NOTE' = 2; 'INFO' = 3 }[$sev]
                    Time = $e.TimeCreated; TimeText = $e.TimeCreated.ToString('HH:mm:ss')
                    Name = $nm; Path = $img; Command = $cmd
                    Parent = $(if ($parent) { Split-Path -Leaf $parent } else { '' })
                    User = $h['SubjectUserName']; Source = 'журнал 4688'
                    Title = $nm; Hash = ''; Query = $nm
                    Detail = "Программа: $img`nВремя: $($e.TimeCreated)`nКоманда: $cmd`nЗапущена из: $parent`nОт имени: $($h['SubjectUserName'])`n$($notes -join '; ')"
                })
            }
            return @($out)
        } catch { }
    }

    # Журнал выключен — показываем то, что помнит Prefetch.
    # Там нет командной строки и родителя, но время запуска видно.
    foreach ($pf in (Get-ChildItem 'C:\Windows\Prefetch\*.pf' -ErrorAction SilentlyContinue | Where-Object { $_.LastWriteTime -gt $since })) {
        $nm = ($pf.BaseName -split '-')[0]
        $null = $out.Add([PSCustomObject]@{
            Severity = 'INFO'; Order = 3
            Time = $pf.LastWriteTime; TimeText = $pf.LastWriteTime.ToString('HH:mm:ss')
            Name = $nm; Path = ''; Command = '(журнал запуска выключен — командная строка неизвестна)'
            Parent = ''; User = ''; Source = 'Prefetch'
            Title = $nm; Hash = ''; Query = $nm
            Detail = "Программа: $nm`nПоследний запуск: $($pf.LastWriteTime)`n`nЭто данные из Prefetch — Windows помнит сам факт запуска, но не команду и не того, кто запустил.`nВключите журнал запуска программ, чтобы видеть полную картину."
        })
    }
    return @($out)
}

# ------------------------------------------------------------
#  Полная проверка
# ------------------------------------------------------------
function Invoke-CgFullScan {
    param([scriptblock]$Progress)
    function Step { param([string]$T) if ($Progress) { & $Progress $T } }

    $all = @()
    Step 'Защита Windows'      ; $all += Get-CgDefenderFindings
    Step 'Перехват трафика'    ; $all += Get-CgTrafficFindings
    Step 'Автозапуск'          ; $all += Get-CgAutorunFindings
    Step 'Процессы'            ; $procs = Get-CgProcessList; $all += Get-CgProcessFindings $procs
    Step 'Сетевые соединения'  ; $all += Get-CgNetworkFindings $procs
    Step 'Расширения браузеров'; $all += Get-CgExtensionFindings
    Step 'Запуск браузеров'    ; $all += Get-CgBrowserHijackFindings
    Step 'Скрипты Adobe'       ; $all += Get-CgAdobeFindings
    Step 'Копии баз cookie'    ; $all += Get-CgCopyFindings
    Step 'Новые файлы'         ; $all += Get-CgRecentFileFindings
    Step 'История обращений'   ; $all += Get-CgAuditHistoryFindings
    if (Get-Command Compare-CgBaseline -ErrorAction SilentlyContinue) {
        Step 'Сверка с эталоном'; $all += Compare-CgBaseline
    }
    # то, про что вы уже разобрались, опускается до «норма»
    if (Get-Command Set-CgTrustOnFindings -ErrorAction SilentlyContinue) {
        $all = Set-CgTrustOnFindings $all
    }
    Step 'Готово'
    return $all
}
