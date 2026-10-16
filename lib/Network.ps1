# ============================================================
#  CookieGuard - Network.ps1
#  Кто куда соединяется — и десять контрольных точек на каждое.
#
#  По одному признаку «хорошо или плохо» не угадать: Zapret без
#  подписи безвреден, а подписанный powershell с командой в Base64 —
#  нет. Поэтому у соединения десять точек, и вердикт — их сумма:
#
#    sig     подпись файла цела
#    pub     издатель известен
#    dir     программа лежит там, куда без прав администратора не писать
#    dns     у адреса есть имя в кеше DNS
#    owner   адрес принадлежит этому имени (не подменён в hosts)
#    exfil   это не канал слива (или сам сервис: Telegram у Telegram)
#    direct  соединение напрямую, а не через локальный прокси
#    age     файлу программы больше недели
#    vt      VirusTotal знает файл и считает чистым
#    trust   вы пометили программу доверенной
#
#  Значения: 'y' — пройдена, 'n' — нет, '-' — не проверить.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

# Программы-прокси и туннели. Петлевое соединение к ним — это трафик,
# ушедший наружу через прокси; к кому-то ещё — разговор двух программ
# внутри компьютера (After Effects и dynamiclinkmanager), его не показываем.
$script:CgProxyNames = '(?i)^(karing|karingservice|v2ray|v2rayn|xray|sing-box|clash|clash-verge|mihomo|hiddify|hiddifycli|nekoray|nekobox|winws|privoxy|proxifier|outline|happ|tun2socks|wireproxy|zapret)'

$script:CgCheckpointNames = [ordered]@{
    sig = 'Подпись цела'; pub = 'Издатель известен'; dir = 'Обычная папка'; dns = 'Имя в DNS'
    owner = 'Адрес принадлежит имени'; exfil = 'Не канал слива'; direct = 'Напрямую, не через прокси'
    age = 'Файлу больше недели'; vt = 'VirusTotal: чисто'; trust = 'Доверено вами'
}

function Get-CgConnectionReport {
    param($State = $null)
    if (-not $State) {
        $State = [PSCustomObject]@{ DnsMap = @{}; DnsLast = [datetime]::MinValue; NetProcs = @{}; BrowserExes = @{}; Suspects = @{} }
        foreach ($b in (Get-CgBrowsers)) { foreach ($e in $b.Exe) { $State.BrowserExes[$e.ToLowerInvariant()] = $b.Name } }
    }
    Update-CgDnsMap $State

    # Какие имена заданы в hosts — адрес «из hosts» проверяется отдельно
    $hostsMap = @{}
    foreach ($e in @(ConvertFrom-CgHostsText (Read-CgHostsText))) { if ($e.Kind -eq 'redirect') { $hostsMap[$e.Host] = $e.Ip } }

    $vt = @{}
    if (Get-Command Get-CgVtCache -ErrorAction SilentlyContinue) { try { $vt = Get-CgVtCache } catch { } }

    $out = New-Object System.Collections.ArrayList
    $seen = @{}
    $script:CgNetInternal = 0
    foreach ($c in @(Get-NetTCPConnection -ErrorAction SilentlyContinue | Where-Object { "$($_.State)" -in @('Established', 'SynSent') })) {
        $procId = [int]$c.OwningProcess
        $ip = "$($c.RemoteAddress)"
        if ($procId -le 4 -or $ip -match '^(0\.0\.0\.0|::)$') { continue }
        $port = [int]$c.RemotePort
        $loop = ($ip -match '^(127\.|::1$)')
        # Karing в режиме TUN подменяет адреса на «поддельные» из
        # 198.18.0.0/15: настоящий сервер за ними не виден
        $tun = (-not $loop) -and (Test-CgIpInCidr $ip '198.18.0.0/15')
        $via = ''
        if ($loop) {
            $via = Get-CgListener $port
            if (-not $via -or $via -notmatch $script:CgProxyNames) { $script:CgNetInternal++; continue }
        }
        if ($tun) { $via = 'туннель прокси (TUN)' }
        $pinfo = Get-CgNetProc $State $procId
        if (-not $pinfo) { continue }
        $hostName = Get-CgConnHost $State $ip
        $k = '{0}|{1}|{2}' -f $pinfo.Path, $(if ($hostName) { $hostName } else { $ip }), $port
        if ($seen.ContainsKey($k)) { continue }
        $seen[$k] = $true

        $cp = [ordered]@{}; $say = @{}
        $sig = Get-CgSignature $pinfo.Path
        $cp.sig = $(if (-not $pinfo.Path) { '-' } elseif ($sig.Valid) { 'y' } else { 'n' })
        if ($cp.sig -eq 'n') { $say.sig = "Подпись: $($sig.Status)." }
        # Защищённые процессы (ESET, Defender) не отдают путь даже
        # администратору: подпись тогда «не проверить», а не «нет»
        $cp.pub = $(if (-not $pinfo.Path) { '-' } elseif ($sig.Trusted) { 'y' } else { 'n' })
        $say.pub = $(if ($sig.Signer) { "Издатель: $($sig.Signer)." } elseif (-not $pinfo.Path) { 'Путь к программе закрыт — так у защищённых процессов (антивирус).' } else { 'Издателя нет.' })
        $cls = Get-CgPathClass $pinfo.Path
        # Program Files и Windows — туда без прав администратора не
        # записать. Пользовательские папки — пишет кто угодно. Другой диск
        # (D:\ADOBE) — просто «не знаю».
        $cp.dir = $(if (-not $pinfo.Path) { '-' } elseif ($cls -in @('programfiles', 'system32', 'windows', 'windowsapps')) { 'y' } elseif ($cls -in @('temp', 'downloads', 'public', 'roaming', 'localapp', 'programdata', 'odd')) { 'n' } else { '-' })
        if ($cp.dir -eq 'n') { $say.dir = "Лежит в пользовательской папке ($cls) — туда пишет любая программа." }
        $cp.dns = $(if ($loop -or $tun) { '-' } elseif ($hostName) { 'y' } else { 'n' })
        if ($cp.dns -eq 'n') { $say.dns = 'Имени в кеше DNS нет — адрес задан напрямую или получен не через DNS Windows.' }
        if ($hostName -and $hostsMap.ContainsKey($hostName)) {
            $own = (Test-CgTelegramIp $ip) -and ($hostName -match 'telegram|t\.me|telesco\.pe')
            $cp.owner = $(if ($own) { 'y' } else { 'n' })
            $say.owner = $(if ($own) { 'Адрес задан в hosts, но это собственная сеть Telegram.' } else { 'Адрес для этого имени задан вручную в hosts.' })
        } else { $cp.owner = $(if ($hostName) { 'y' } else { '-' }) }
        $isExfil = ($hostName -match $script:CgExfilHosts) -or ((-not $loop) -and (Test-CgTelegramIp $ip))
        $official = $isExfil -and $sig.Trusted
        $cp.exfil = $(if (-not $isExfil -or $official) { 'y' } else { 'n' })
        if ($isExfil) { $say.exfil = $(if ($official) { "Канал $(if ($hostName) { $hostName } else { 'Telegram' }), но программа подписана $($sig.Signer) — это сам сервис." } else { 'Канал, куда воры паролей обычно отправляют украденное.' }) }
        $cp.direct = $(if ($via) { 'n' } else { 'y' })
        if ($via) { $say.direct = "Через $via — настоящий адрес назначения за ним не виден." }
        $age = '-'
        try { $fi = Get-Item -LiteralPath $pinfo.Path -ErrorAction Stop; $age = $(if (((Get-Date) - $fi.CreationTime).TotalDays -gt 7) { 'y' } else { 'n' }); if ($age -eq 'n') { $say.age = 'Файл появился ' + $fi.CreationTime.ToString('dd.MM HH:mm') + '.' } } catch { }
        $cp.age = $age
        # Хеш большого подписанного известным издателем файла (After
        # Effects — сотни мегабайт) ничего не добавит, а считается долго
        $hash = $(if ($sig.Trusted) { '' } else { Get-CgHash $pinfo.Path })
        $v = $(if ($hash) { $vt[$hash] } else { $null })
        $cp.vt = $(if (-not $v -or $v.Status -ne 'known') { '-' } elseif ([int]$v.Malicious -eq 0) { 'y' } else { 'n' })
        if ($cp.vt -eq 'n') { $say.vt = "VirusTotal: детектов $($v.Malicious)." }
        $tr = $null
        if ($pinfo.Path -and (Get-Command Test-CgTrustedFile -ErrorAction SilentlyContinue)) { $tr = Test-CgTrustedFile $pinfo.Path $hash }
        $cp.trust = $(if ($tr) { 'y' } else { '-' })

        $fails = @($cp.Values | Where-Object { $_ -eq 'n' }).Count
        $verdict = 'ok'
        if ($tr -or ($sig.Trusted -and $cp.exfil -eq 'y' -and $cp.vt -ne 'n')) { $verdict = 'ok' }
        elseif ($cp.vt -eq 'n' -or ($cp.exfil -eq 'n' -and ($cp.sig -eq 'n' -or $cp.dir -eq 'n')) -or $State.Suspects.ContainsKey($procId)) { $verdict = 'bad' }
        elseif ($fails -ge 3 -or $cp.exfil -eq 'n' -or $cp.owner -eq 'n') { $verdict = 'check' }

        $null = $out.Add([PSCustomObject]@{
            Process = $pinfo.Name; Path = $pinfo.Path; ProcId = $procId; Host = $hostName; Ip = $ip; Port = $port; Via = $via
            Checks = [PSCustomObject]$cp; Says = $say; Fails = $fails; Verdict = $verdict
            Severity = @{ ok = 'OK'; check = 'WARN'; bad = 'CRIT' }[$verdict]
        })
    }
    return @($out | Sort-Object @{ Expression = { @{ bad = 0; check = 1; ok = 2 }[$_.Verdict] } }, Process)
}
