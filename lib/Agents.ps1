# ============================================================
#  CookieGuard - Agents.ps1
#  Агенты-усы: каждый смотрит на cookie со своей стороны.
#
#  Аудит файла видит, кто ОТКРЫЛ базу. Но базу можно украсть, не
#  открывая её: снять теневую копию диска, попросить браузер отдать
#  cookie через отладочный порт, прочитать память браузера чужой
#  библиотекой. Поэтому вокруг базы — несколько независимых взглядов:
#
#    audit   — кто открыл базу (события 4656/4663)
#    canary  — приманка: ненастоящий профиль, который не открывает
#              ни один браузер; тронул — значит, перебирал профили
#    debug   — браузер с отладочным портом или без окна на вашем профиле
#    key     — кто читает Local State, где лежит ключ шифрования
#    vss     — теневые копии и копирование занятых файлов (esentutl /vss)
#    inject  — чужие неподписанные модули внутри процессов браузера
#    net     — теневой путь и каналы слива (Monitor.ps1)
#    hosts   — подмена адресов (Hosts.ps1)
#
#  Перекличка: каждый агент отмечает, когда работал последний раз.
#  Сторож пишет это в state\agents.json, наблюдатель (отдельный
#  процесс) сверяет — замолчавший агент сам становится тревогой.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$script:CgAgentDefs = [ordered]@{
    audit  = @{ Name = 'Аудит файла';          Every = 5 }
    canary = @{ Name = 'Приманка';             Every = 60 }
    debug  = @{ Name = 'Отладочный порт';      Every = 60 }
    key    = @{ Name = 'Ключ шифрования';      Every = 300 }
    vss    = @{ Name = 'Теневые копии';        Every = 300 }
    inject = @{ Name = 'Внедрение в браузер';  Every = 120 }
    net    = @{ Name = 'Сеть';                 Every = 5 }
    hosts  = @{ Name = 'hosts';                Every = 5 }
}

function Get-CgAgentsPath { Join-Path (Get-CgDir 'state') 'agents.json' }

function New-CgAgentsState {
    $a = @{}
    foreach ($k in $script:CgAgentDefs.Keys) {
        $a[$k] = [PSCustomObject]@{ Key = $k; Name = $script:CgAgentDefs[$k].Name; Every = $script:CgAgentDefs[$k].Every
                                    Last = [datetime]::MinValue; Ok = $true; Note = ''; Due = [datetime]::MinValue }
    }
    return $a
}

function Set-CgAgentTick {
    param($State, [string]$Key, [bool]$Ok = $true, [string]$Note = '')
    $a = $State.Agents[$Key]
    if (-not $a) { return }
    $a.Last = Get-Date; $a.Ok = $Ok
    if ($Note) { $a.Note = $Note }
}

function Test-CgAgentDue {
    param($State, [string]$Key)
    $a = $State.Agents[$Key]
    if (-not $a) { return $false }
    if ((Get-Date) -lt $a.Due) { return $false }
    $a.Due = (Get-Date).AddSeconds($a.Every)
    return $true
}

function Save-CgAgentsState {
    param($State)
    $o = [ordered]@{ at = (Get-Date).ToString('o'); pid = $PID; agents = [ordered]@{} }
    foreach ($a in $State.Agents.Values) {
        $o.agents[$a.Key] = [ordered]@{ name = $a.Name; every = $a.Every; ok = $a.Ok; note = $a.Note
                                         last = $(if ($a.Last -gt [datetime]::MinValue) { $a.Last.ToString('o') } else { '' }) }
    }
    try {
        $p = Get-CgAgentsPath
        [IO.File]::WriteAllText("$p.tmp", (ConvertTo-Json -InputObject $o -Depth 4), (New-Object Text.UTF8Encoding $false))
        if (Test-Path -LiteralPath $p) { [IO.File]::Replace("$p.tmp", $p, $null) } else { [IO.File]::Move("$p.tmp", $p) }
    } catch { }
}

# Для окна и наблюдателя: кто на связи, кто молчит
function Get-CgAgentsReport {
    $p = Get-CgAgentsPath
    $r = [PSCustomObject]@{ Fresh = $false; At = $null; Agents = @() }
    if (-not (Test-Path -LiteralPath $p)) { return $r }
    try {
        $j = [IO.File]::ReadAllText($p) | ConvertFrom-Json -ErrorAction Stop
        $r.At = [datetime]::Parse($j.at)
        $r.Fresh = (((Get-Date) - $r.At).TotalSeconds -lt 120)
        $list = @()
        foreach ($pr in $j.agents.PSObject.Properties) {
            $a = $pr.Value
            $last = $null
            if ($a.last) { try { $last = [datetime]::Parse($a.last) } catch { } }
            # Молчит — нет отметки дольше трёх интервалов (и минуты сверху)
            $silent = (-not $last) -or (((Get-Date) - $last).TotalSeconds -gt (3 * [int]$a.every + 60))
            $list += [PSCustomObject]@{ Key = $pr.Name; Name = "$($a.name)"; Ok = [bool]$a.ok; Note = "$($a.note)"; Last = $last; Silent = $silent }
        }
        $r.Agents = $list
    } catch { }
    return $r
}

# ------------------------------------------------------------
#  Приманка
#
#  Профиль «Profile 99» в папке каждого браузера на Chromium и
#  профиль в Firefox. Браузер открывает только профили из своего
#  списка (Local State, profiles.ini) — этот он не видит. Вор,
#  перебирающий все папки подряд, видит. Файлы — заголовок SQLite
#  и мусор: настоящих данных там нет.
# ------------------------------------------------------------
function Get-CgCanaryPath { Join-Path (Get-CgDir 'state') 'canary.json' }

function Get-CgCanaryFiles {
    $p = Get-CgCanaryPath
    if (-not (Test-Path -LiteralPath $p)) { return @() }
    try { return @(([IO.File]::ReadAllText($p) | ConvertFrom-Json -ErrorAction Stop) | ForEach-Object { "$_" }) } catch { return @() }
}

function New-CgCanaryBytes {
    $b = New-Object byte[] 8192
    (New-Object Random).NextBytes($b)
    $h = [Text.Encoding]::ASCII.GetBytes("SQLite format 3`0")
    [Array]::Copy($h, $b, $h.Length)
    $b[16] = 0x10; $b[17] = 0x00   # размер страницы 4096
    return $b
}

function Initialize-CgCanary {
    $made = @()
    foreach ($b in (Get-CgBrowsers)) {
        if ($b.Name -eq 'Firefox') {
            $dir = Join-Path $b.Root 'q3vd81ka.default'
            $files = @('cookies.sqlite', 'logins.json', 'key4.db')
        } else {
            $dir = Join-Path $b.Root 'Profile 99'
            $files = @('Network\Cookies', 'Login Data')
        }
        # Профиль с таким именем уже настоящий — приманку туда не кладём
        if ((Test-Path -LiteralPath $dir) -and -not (Test-Path -LiteralPath (Join-Path $dir '.cg-canary'))) { continue }
        foreach ($f in $files) {
            $fp = Join-Path $dir $f
            try {
                $null = New-Item -ItemType Directory -Path (Split-Path -Parent $fp) -Force -ErrorAction Stop
                if (-not (Test-Path -LiteralPath $fp)) {
                    if ($f -eq 'logins.json') { [IO.File]::WriteAllText($fp, '{"nextId":3,"logins":[],"version":3}') }
                    else { [IO.File]::WriteAllBytes($fp, (New-CgCanaryBytes)) }
                }
                $made += $fp
            } catch { }
        }
        try { [IO.File]::WriteAllText((Join-Path $dir '.cg-canary'), 'CookieGuard: приманка для воров паролей. Не профиль браузера.') } catch { }
    }
    if ($made.Count) {
        try { [IO.File]::WriteAllText((Get-CgCanaryPath), (ConvertTo-Json -InputObject @($made)), (New-Object Text.UTF8Encoding $false)) } catch { }
        if (Get-Command Set-CgCookieAuditRules -ErrorAction SilentlyContinue) {
            $need = @($made | Where-Object { (Test-CgFileAudited $_) -ne $true })
            if ($need.Count) { $null = Set-CgCookieAuditRules $need }
        }
    }
    return $made
}

function Remove-CgCanary {
    foreach ($f in (Get-CgCanaryFiles)) {
        $dir = Split-Path -Parent $f
        if ((Split-Path -Leaf $dir) -eq 'Network') { $dir = Split-Path -Parent $dir }
        if (Test-Path -LiteralPath (Join-Path $dir '.cg-canary')) { Remove-Item -LiteralPath $dir -Recurse -Force -ErrorAction SilentlyContinue }
    }
    Remove-Item -LiteralPath (Get-CgCanaryPath) -Force -ErrorAction SilentlyContinue
}

# ------------------------------------------------------------
#  Запуски программ по журналу 4688
#
#  Опрос процессов раз в полторы секунды пропускает короткие запуски:
#  esentutl копирует базу за долю секунды и выходит. Журнал запуска
#  программ записывает каждый, с командной строкой, — по нему видно
#  то, что опрос не застал.
# ------------------------------------------------------------
$script:CgCredFileRx = '(?i)\\(Login Data|Cookies|Web Data|Local State|key4\.db|logins\.json|cookies\.sqlite)(["\s]|$)'
$script:CgBrowserImgRx = '(?i)\\(chrome|msedge|brave|vivaldi|opera|browser|firefox)\.exe$'

function Resolve-CgProcCreateEvent {
    param($State, $Ev)
    $d = Get-CgEvData $Ev
    $img = Get-CgNormPath $d['NewProcessName']
    $cmd = "$($d['CommandLine'])"
    $parent = Get-CgNormPath $d['ParentProcessName']
    if (-not $img) { return $null }
    $name = Split-Path -Leaf $img
    $nameL = $name.ToLowerInvariant()
    $procId = 0
    if ($d['NewProcessId']) { try { $procId = [Convert]::ToInt32($d['NewProcessId'], 16) } catch { } }

    $sev = ''; $title = ''; $why = ''; $agent = ''

    # отладочный порт браузера: обход шифрования cookie без чтения файла
    if ($img -match $script:CgBrowserImgRx -and $cmd -match '(?i)--remote-debugging-(port|pipe)') {
        $agent = 'debug'
        $udd = ''
        if ($cmd -match '(?i)--user-data-dir[= ]"?([^"]+?)"?(\s--|$)') { $udd = $matches[1] }
        $realProfile = (-not $udd) -or ($udd -match '(?i)\\User Data\\?$|\\Firefox\\Profiles')
        $sev = $(if ($realProfile) { 'CRIT' } else { 'WARN' })
        $title = $(if ($realProfile) { 'БРАУЗЕР ЗАПУЩЕН С ОТЛАДОЧНЫМ ПОРТОМ НА ВАШЕМ ПРОФИЛЕ: {0}' -f $name } else { 'Браузер запущен с отладочным портом: {0}' -f $name })
        $why = 'Через отладочный порт программа просит браузер отдать все cookie уже расшифрованными — сам файл при этом не открывают, и аудит файла этого не видит. Так обходят защиту cookie в Chrome 127+.' +
               $(if (-not $realProfile) { "`nПрофиль отдельный ($udd) — так работают автотесты и Playwright. Если это не вы — разберитесь." } else { '' })
    }
    # теневые копии и копирование занятых файлов
    elseif ($cmd -match '(?i)esentutl(\.exe)?["\s].*(/vss|/y\s)' -or $cmd -match '(?i)HarddiskVolumeShadowCopy|\\\\\.\\PhysicalDrive|\\\\\?\\GLOBALROOT') {
        $agent = 'vss'; $sev = 'CRIT'
        $title = 'Копирование занятых файлов в обход блокировки: {0}' -f $name
        $why = 'esentutl /vss и чтение теневой копии снимают копию базы cookie, не открывая сам файл — мимо аудита. Нормальные программы так почти не делают.'
    }
    elseif ($cmd -match '(?i)vssadmin(\.exe)?["\s]+create\s+shadow|shadowcopy\s+call\s+create|diskshadow') {
        $agent = 'vss'; $sev = 'WARN'
        $title = 'Создаётся теневая копия диска: {0}' -f $name
        $why = 'Теневую копию делают резервное копирование и точки восстановления — и воры, чтобы прочитать занятые файлы. Посмотрите, кто запустил.'
    }
    # командная строка с базой cookie/паролей у не-браузера
    elseif ($cmd -match $script:CgCredFileRx -and $img -notmatch $script:CgBrowserImgRx) {
        $agent = 'audit'; $sev = 'CRIT'
        $title = 'Команда обращается к базе cookie или паролей: {0}' -f $name
        $why = 'В командной строке — путь к базе cookie, паролей или ключу шифрования. Так её копируют перед отправкой.'
    }
    # гасят браузер, чтобы освободить базу
    elseif ($nameL -eq 'taskkill.exe' -and $cmd -match '(?i)(chrome|msedge|brave|firefox|opera|vivaldi)(\.exe)?') {
        $agent = 'audit'; $sev = 'NOTE'
        $title = 'Браузер закрывают из командной строки'
        $why = 'Воры паролей закрывают браузер, чтобы он отпустил базу cookie. Если закрывали вы — это ничего.'
    }
    elseif ($cmd -match '(?i)CryptUnprotectData|Security\.Cryptography\.ProtectedData') {
        $agent = 'key'; $sev = 'WARN'
        $title = 'Расшифровка данных DPAPI из командной строки: {0}' -f $name
        $why = 'DPAPI хранит ключ, которым зашифрованы cookie и пароли браузера. Вызывать его из командной строки обычным программам незачем.'
    }
    if (-not $sev) { return $null }

    $key = 'pc|' + $cmd
    if ($State.Seen.ContainsKey($key)) { return $null }
    $State.Seen[$key] = $true

    if ($parent -and (Get-Command Test-CgTrustedFile -ErrorAction SilentlyContinue)) {
        if (Test-CgTrustedFile $img '' $parent (Split-Path -Leaf $parent)) {
            if ($sev -eq 'CRIT') { $sev = 'WARN' } elseif ($sev -eq 'WARN') { $sev = 'NOTE' }
        }
    }
    if ($agent) { Set-CgAgentTick $State $agent $true ('сработал: ' + (Get-Date -Format 'HH:mm:ss')) }
    if ($sev -in @('CRIT', 'WARN') -and $procId -gt 4) { Add-CgSuspect $State $procId $name $img $title $sev }
    $detail = @(
        "Программа:  $img",
        "PID:        $procId",
        "Родитель:   $parent",
        "Команда:    $cmd",
        '',
        $why
    ) -join "`n"
    $null = Save-CgEvidence 'agent' ([PSCustomObject]@{ Time = (Get-Date).ToString('o'); Agent = $agent; Image = $img; Parent = $parent; CommandLine = $cmd })
    return New-CgEvent $sev 'Агент' $title $detail $name $img $procId
}

# ------------------------------------------------------------
#  Отладочный порт: браузер, который слушает порт
# ------------------------------------------------------------
function Invoke-CgDebugPortCheck {
    param($State)
    $out = @()
    try {
        $listen = @(Get-NetTCPConnection -State Listen -ErrorAction Stop)
    } catch { Set-CgAgentTick $State 'debug' $false 'нет доступа к списку портов'; return $out }
    foreach ($l in $listen) {
        $p = $null
        try { $p = Get-Process -Id ([int]$l.OwningProcess) -ErrorAction Stop } catch { continue }
        $n = "$($p.ProcessName).exe".ToLowerInvariant()
        if ($n -notin @('chrome.exe', 'msedge.exe', 'brave.exe', 'vivaldi.exe', 'opera.exe', 'browser.exe', 'firefox.exe')) { continue }
        $key = 'dbg|{0}|{1}' -f $p.Id, $l.LocalPort
        if ($State.Seen.ContainsKey($key)) { continue }
        $State.Seen[$key] = $true
        $path = ''; try { $path = $p.Path } catch { }
        $out += New-CgEvent 'WARN' 'Агент' ('Браузер слушает порт {0}: {1}' -f $l.LocalPort, $n) (
            "Программа: $path`nPID: $($p.Id)`nАдрес: $($l.LocalAddress):$($l.LocalPort)`n`nОбычный браузер портов не открывает. Открытый порт у браузера — это отладка: через неё можно забрать все cookie, не трогая файл.") $n $path $p.Id
    }
    Set-CgAgentTick $State 'debug' $true ('портов браузеров: ' + @($out).Count)
    return $out
}

# ------------------------------------------------------------
#  Внедрение: чужие модули в процессах браузера
# ------------------------------------------------------------
function Invoke-CgInjectionSweep {
    param($State)
    $out = @()
    $checked = 0
    foreach ($p in @(Get-Process -Name chrome, msedge, brave, vivaldi, opera, browser, firefox -ErrorAction SilentlyContinue)) {
        $exe = ''; try { $exe = $p.Path } catch { }
        if (-not $exe) { continue }
        $bdir = (Split-Path -Parent $exe).ToLowerInvariant()
        $mods = @(); try { $mods = @($p.Modules) } catch { continue }
        foreach ($m in $mods) {
            $mp = "$($m.FileName)"
            if (-not $mp) { continue }
            $ml = $mp.ToLowerInvariant()
            if ($State.InjectSeen.ContainsKey($ml)) { continue }
            $State.InjectSeen[$ml] = $true
            $checked++
            # папка браузера и системные — свои
            if ($ml.StartsWith($bdir) -or $ml -match '^[a-z]:\\windows\\(system32|syswow64|winsxs|microsoft\.net|systemapps)\\') { continue }
            $sig = Get-CgSignature $mp
            if ($sig.Valid) { continue }
            $out += New-CgEvent 'WARN' 'Агент' ('Неподписанный модуль внутри браузера: {0}' -f (Split-Path -Leaf $mp)) (
                "Модуль:   $mp`nБраузер:  $exe (PID $($p.Id))`nПодпись:  $($sig.Status)`n`nЧужая библиотека в процессе браузера может читать cookie прямо из памяти — уже расшифрованными. Бывает и безвредно (оверлей игры, старый драйвер мыши), но стоит проверить на VirusTotal.") (Split-Path -Leaf $mp) $mp $p.Id
        }
    }
    Set-CgAgentTick $State 'inject' $true ('новых модулей проверено: ' + $checked)
    return $out
}

# ------------------------------------------------------------
#  Теневые копии: появилась новая
# ------------------------------------------------------------
function Invoke-CgShadowCheck {
    param($State)
    $out = @()
    $ids = @()
    try { $ids = @(Get-CimInstance Win32_ShadowCopy -ErrorAction Stop | ForEach-Object { "$($_.ID)" }) }
    catch { Set-CgAgentTick $State 'vss' $true 'список копий недоступен — слежу по журналу запусков'; return $out }
    if ($null -ne $State.ShadowIds) {
        foreach ($i in $ids) {
            if ($State.ShadowIds -notcontains $i) {
                $out += New-CgEvent 'NOTE' 'Агент' 'Появилась новая теневая копия диска' (
                    "ID: $i`n`nТак делают точки восстановления и резервное копирование. Если одновременно была тревога о копировании базы cookie — это одна история.")
            }
        }
    }
    $State.ShadowIds = $ids
    Set-CgAgentTick $State 'vss' $true ('теневых копий: ' + $ids.Count)
    return $out
}

# ------------------------------------------------------------
#  Ключ шифрования: Local State под аудитом
# ------------------------------------------------------------
function Invoke-CgKeyCheck {
    param($State)
    $ls = @($State.Targets | Where-Object { $_.Path -match '\\Local State$' })
    $bad = @($ls | Where-Object { (Test-CgFileAudited $_.Path) -eq $false })
    if ($bad.Count -and $State.Persist -and (Get-Command Set-CgCookieAuditRules -ErrorAction SilentlyContinue)) {
        $null = Set-CgCookieAuditRules @($bad | ForEach-Object { $_.Path })
    }
    Set-CgAgentTick $State 'key' $true ('файлов Local State под аудитом: ' + ($ls.Count - $bad.Count) + ' из ' + $ls.Count)
}

# ------------------------------------------------------------
#  Один такт всех агентов (вызывается из опроса монитора)
# ------------------------------------------------------------
function Invoke-CgAgentsPoll {
    param($State)
    $out = @()
    if (Test-CgAgentDue $State 'canary') {
        $files = @(Get-CgCanaryFiles)
        if ($State.Persist -and (-not $files.Count -or @($files | Where-Object { -not (Test-Path -LiteralPath $_) }).Count)) {
            $files = @(Initialize-CgCanary)
            Update-CgMonitorTargets $State
        }
        Set-CgAgentTick $State 'canary' ([bool]$files.Count) ('приманок: ' + $files.Count)
    }
    if (Test-CgAgentDue $State 'debug')  { $out += @(Invoke-CgDebugPortCheck $State) }
    if (Test-CgAgentDue $State 'inject') { $out += @(Invoke-CgInjectionSweep $State) }
    if (Test-CgAgentDue $State 'vss')    { $out += @(Invoke-CgShadowCheck $State) }
    if (Test-CgAgentDue $State 'key')    { Invoke-CgKeyCheck $State }
    if ($State.Persist -and ((Get-Date) - $State.AgentsSaved).TotalSeconds -ge 30) {
        Save-CgAgentsState $State
        $State.AgentsSaved = Get-Date
    }
    return $out
}
