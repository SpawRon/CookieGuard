# ============================================================
#  CookieGuard - SafeDns.ps1
#  Безопасный сёрфинг через фильтрующий DNS.
#
#  Зачем именно так. Расширение-блокировщик, чтобы резать рекламу,
#  просит права «читать и менять все данные на всех сайтах» — то
#  есть ровно те, которыми уводят сессии. Получается, что защита
#  от рекламы покупается ценой самого опасного разрешения.
#
#  Фильтрация на уровне DNS снимает эту плату: вредоносные и
#  рекламные домена не разрешаются в адрес вообще, значит до
#  браузера они не доходят. Работает во ВСЕЙ системе, а не только
#  в браузере, и не требует ни одного расширения.
#
#  Честно о границах:
#   - страницу «заблокировано CookieGuard» показать нельзя:
#     браузер покажет обычную ошибку соединения. Уведомление
#     даёт наш сторож, а не сама страница;
#   - косметику (пустые блоки на месте баннеров) DNS не чинит —
#     он не прячет элементы, а не пускает запрос;
#   - если весь трафик идёт через VPN или прокси (у вас Karing),
#     DNS может решаться на его стороне и фильтр будет обойдён.
#     Это проверяется кнопкой «Проверить фильтрацию».
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$script:CgDnsProfiles = @(
    [PSCustomObject]@{
        Id = 'adguard'; Name = 'AdGuard DNS — реклама, трекеры и вредоносное'
        Servers = @('94.140.14.14', '94.140.15.15')
        Note = 'Ближе всего к тому, что делает расширение AdGuard, но без прав на ваши сайты.'
    },
    [PSCustomObject]@{
        Id = 'adguard-family'; Name = 'AdGuard Family — то же плюс взрослый контент'
        Servers = @('94.140.14.15', '94.140.15.16')
        Note = 'То же самое, дополнительно режет сайты для взрослых.'
    },
    [PSCustomObject]@{
        Id = 'quad9'; Name = 'Quad9 — только вредоносное, рекламу не трогает'
        Servers = @('9.9.9.9', '149.112.112.112')
        Note = 'Самый осторожный вариант: блокирует вредоносные домены и почти не даёт ложных срабатываний.'
    },
    [PSCustomObject]@{
        Id = 'cloudflare'; Name = 'Cloudflare — вредоносное, быстрый'
        Servers = @('1.1.1.2', '1.0.0.2')
        Note = 'Блокирует вредоносные домены, рекламу не трогает.'
    }
)

function Get-CgDnsProfiles { return $script:CgDnsProfiles }

function Get-CgDnsBackupPath { Join-Path (Get-CgDir 'state') 'dns-backup.json' }

# Сетевые подключения, которые реально используются (без Loopback и отключённых)
function Get-CgActiveNics {
    return @(Get-NetAdapter -Physical -ErrorAction SilentlyContinue |
             Where-Object { $_.Status -eq 'Up' })
}

function Get-CgDnsState {
    $out = @()
    foreach ($n in (Get-CgActiveNics)) {
        $cfg = Get-DnsClientServerAddress -InterfaceIndex $n.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        $servers = @()
        if ($cfg) { $servers = @($cfg.ServerAddresses) }
        $known = $null
        foreach ($p in $script:CgDnsProfiles) {
            if ($servers.Count -and -not (Compare-Object $servers $p.Servers)) { $known = $p; break }
        }
        $out += [PSCustomObject]@{
            Name = $n.Name; Index = $n.ifIndex
            Servers = $servers
            ServersText = $(if ($servers.Count) { $servers -join ', ' } else { 'автоматически (от роутера)' })
            Profile = $known
            Filtering = [bool]$known
        }
    }
    return @($out)
}

function Test-CgSafeDnsOn {
    $st = @(Get-CgDnsState)
    if (-not $st.Count) { return $false }
    return (@($st | Where-Object { $_.Filtering }).Count -eq $st.Count)
}

function Set-CgSafeDns {
    param([string]$ProfileId)
    if (-not (Test-CgAdmin)) { return [PSCustomObject]@{ Ok = $false; Message = 'Нужны права администратора' } }
    $prof = $script:CgDnsProfiles | Where-Object { $_.Id -eq $ProfileId } | Select-Object -First 1
    if (-not $prof) { return [PSCustomObject]@{ Ok = $false; Message = 'Неизвестный набор DNS' } }

    # запоминаем то, что было, чтобы вернуть точно так же
    $before = Get-CgDnsState
    if (-not (Test-Path -LiteralPath (Get-CgDnsBackupPath))) {
        try { $before | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Get-CgDnsBackupPath) -Encoding UTF8 } catch { }
    }

    $done = 0; $fail = @()
    foreach ($n in (Get-CgActiveNics)) {
        try {
            Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ServerAddresses $prof.Servers -ErrorAction Stop
            $done++
        } catch { $fail += "$($n.Name): $($_.Exception.Message)" }
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Write-CgLog 'INFO' ("Безопасный сёрфинг включён: $($prof.Name); подключений: $done")
    if (-not $done) { return [PSCustomObject]@{ Ok = $false; Message = ('Не удалось: ' + ($fail -join '; ')) } }
    return [PSCustomObject]@{ Ok = $true; Message = "Фильтрующий DNS включён на подключениях: $done" }
}

function Reset-CgSafeDns {
    if (-not (Test-CgAdmin)) { return [PSCustomObject]@{ Ok = $false; Message = 'Нужны права администратора' } }
    $backup = $null
    if (Test-Path -LiteralPath (Get-CgDnsBackupPath)) {
        try { $backup = Get-Content -LiteralPath (Get-CgDnsBackupPath) -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
    }
    $done = 0
    foreach ($n in (Get-CgActiveNics)) {
        $prev = $null
        if ($backup) { $prev = @($backup | Where-Object { $_.Index -eq $n.ifIndex }) | Select-Object -First 1 }
        try {
            if ($prev -and @($prev.Servers).Count) {
                Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ServerAddresses @($prev.Servers) -ErrorAction Stop
            } else {
                # вернуть выдачу адресов роутером
                Set-DnsClientServerAddress -InterfaceIndex $n.ifIndex -ResetServerAddresses -ErrorAction Stop
            }
            $done++
        } catch { }
    }
    Clear-DnsClientCache -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Get-CgDnsBackupPath) -Force -ErrorAction SilentlyContinue
    Write-CgLog 'INFO' "Безопасный сёрфинг выключен, DNS возвращён ($done подключений)"
    return [PSCustomObject]@{ Ok = $true; Message = "DNS возвращён как было на подключениях: $done" }
}

# ------------------------------------------------------------
#  Проверка, что фильтр действительно работает
#  Это важно: при включённом VPN/прокси DNS может решаться на его
#  стороне, и настройка в Windows ни на что не влияет.
# ------------------------------------------------------------
function Test-CgDnsFiltering {
    # Сначала контрольный домен. Без него проверка бессмысленна:
    # если имена не разрешаются вообще (нет сети, перехват прокси),
    # то «заблокировано» неотличимо от «не работает интернет», и
    # мы бы показали «вы защищены» там, где защиты нет.
    $control = Resolve-DnsName -Name 'example.com' -Type A -ErrorAction SilentlyContinue
    $controlIps = @($control | Where-Object { $_.IPAddress } | ForEach-Object { $_.IPAddress })
    if (-not $controlIps.Count) {
        return [PSCustomObject]@{
            Working = $false
            Message = "Проверить не удалось: даже обычный домен example.com не разрешается.`nЛибо нет сети, либо запросы имён перехватывает что-то другое (VPN, прокси).`nЭто НЕ значит, что фильтр работает."
        }
    }

    # Проверяем только тем, чем можно проверить честно: доменом
    # рекламной сети. Общепринятого «тестового вредоносного домена»
    # не существует, и выдумывать его нельзя — получилась бы
    # проверка, которая всегда говорит «не защищено».
    $lines = @("Контроль: example.com -> $($controlIps[0]) (сеть и DNS работают)")
    $blockedAny = $false
    $r = Resolve-DnsName -Name 'doubleclick.net' -Type A -ErrorAction SilentlyContinue
    $ips = @($r | Where-Object { $_.IPAddress } | ForEach-Object { $_.IPAddress })
    if (-not $ips.Count -or $ips -contains '0.0.0.0' -or $ips -contains '::') {
        $lines += 'doubleclick.net: заблокирован — реклама и слежка фильтруются'
        $blockedAny = $true
    } else {
        $lines += "doubleclick.net: разрешается в $($ips -join ', ') — реклама НЕ фильтруется"
    }

    # что обещает выбранный набор — это не проверка, а напоминание
    $cur = @(Get-CgDnsState | Where-Object { $_.Profile })
    if ($cur.Count) {
        $lines += ''
        $lines += "Сейчас выбран: $($cur[0].Profile.Name)"
        $lines += $cur[0].Profile.Note
        $lines += 'Блокировку вредоносных доменов проверить отдельным запросом нельзя — её обеспечивает выбранный сервис, и видно это только по факту срабатывания.'
    } elseif (-not $blockedAny) {
        $lines += ''
        $lines += 'Фильтрующий DNS не включён.'
    }
    # не идёт ли DNS мимо через прокси
    $proxyWarn = ''
    $prox = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    if ($prox.ProxyEnable -eq 1 -and $prox.ProxyServer) {
        $proxyWarn = "`n`nВНИМАНИЕ: включён прокси ($($prox.ProxyServer)). Браузер может спрашивать адреса через него, и тогда системный DNS-фильтр обходится. Настройте фильтрацию в самой программе-прокси."
    }
    return [PSCustomObject]@{
        Working = $blockedAny
        Message = (($lines -join "`n") + $proxyWarn)
    }
}
