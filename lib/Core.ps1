# ============================================================
#  CookieGuard - Core.ps1
#  Общие функции: браузеры, подписи, процессы, оценка риска.
#  Инструмент ТОЛЬКО наблюдает: он никогда не открывает и не
#  читает содержимое файлов cookie, паролей и т.п. Он смотрит
#  только на пути, метаданные и на то, КТО к ним обращается.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$script:SigCache  = @{}
$script:HashCache = @{}

# ---------- базовое ----------

function Test-CgAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    return ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-CgRoot { return (Split-Path -Parent $PSScriptRoot) }

# Куда писать рабочие данные: журналы, отчёты, улики, карантин, эталон.
#
# Установленная программа лежит в Program Files, куда обычный пользователь
# писать не может — и это правильно: так вредонос без прав администратора
# не подменит сам инструмент. Но тогда и данные туда класть нельзя,
# им место в ProgramData.
#
# Если же папку просто распаковали и запустили (переносной режим),
# данные остаются рядом с программой — ничего в системе не создаётся.
function Get-CgDataRoot {
    $root = Get-CgRoot
    if ($root -match '(?i)^[A-Z]:\\Program Files') {
        $d = Join-Path $env:ProgramData 'CookieGuard'
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
        return $d
    }
    return $root
}

function Get-CgDir {
    param([string]$Name)
    $d = Join-Path (Get-CgDataRoot) $Name
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    return $d
}

# Дописать строку в файл так, чтобы её не потерять.
#
# В журнал пишут сразу двое: сторож от SYSTEM и окно. Add-Content
# открывает файл на запись без общего доступа, и если второй писал
# в ту же миллисекунду, строка молча пропадала в catch { }. Отсюда
# «журнал то пишется, то нет». Теперь файл открывается только на
# дозапись (AppendData — Windows сама ставит каждую запись в конец,
# даже если пишут двое), с общим доступом, и при занятости — повтор.
function Add-CgLine {
    param([string]$Path, [string]$Line)
    $bytes = [Text.Encoding]::UTF8.GetBytes($Line + "`r`n")
    for ($i = 0; $i -lt 12; $i++) {
        $fs = $null
        try {
            $fs = New-Object IO.FileStream($Path, [IO.FileMode]::Append,
                [Security.AccessControl.FileSystemRights]::AppendData,
                ([IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete), 4096, [IO.FileOptions]::None)
            $fs.Write($bytes, 0, $bytes.Length)
            $fs.Flush()
            return $true
        } catch {
            Start-Sleep -Milliseconds (15 + 15 * $i)
        } finally {
            if ($fs) { $fs.Dispose() }
        }
    }
    return $false
}

function Write-CgLog {
    param([string]$Level = 'INFO', [string]$Message)
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    $f = Join-Path (Get-CgDir 'logs') ('cookieguard-{0}.log' -f (Get-Date -Format 'yyyy-MM-dd'))
    $null = Add-CgLine $f $line
}

# ---------- настройки, которые помнятся ----------
#
# Всё, что человек включил один раз, должно оставаться включённым:
# после перезапуска окна, перезагрузки и обновления. Поэтому выбор
# хранится в state\settings.json, а не в памяти окна. Пишется через
# временный файл и замену — оборванная запись не оставит полфайла.
function Get-CgSettingsPath { Join-Path (Get-CgDir 'state') 'settings.json' }

function Get-CgSettings {
    $s = [ordered]@{ AutoProtect = $false; AutoNeutralize = $false; MonitorOn = $true }
    $p = Get-CgSettingsPath
    $have = $false
    if (Test-Path -LiteralPath $p) {
        try {
            $j = [IO.File]::ReadAllText($p) | ConvertFrom-Json -ErrorAction Stop
            foreach ($pr in $j.PSObject.Properties) { $s[$pr.Name] = $pr.Value }
            $have = $true
        } catch { }
    }
    if (-not $have) {
        # Первый запуск новой версии там, где сторож уже стоял:
        # человек защиту включал — значит, автозащита включена.
        # Без прав задачу SYSTEM не видно, и ответ «нет» был бы
        # неправдой — такой ответ не записываем.
        if (Test-CgAdmin) {
            try {
                if (Get-ScheduledTask -TaskName 'CookieGuard Watcher' -ErrorAction Stop) { $s.AutoProtect = $true }
            } catch { }
            try { Save-CgSettings $s } catch { }
        }
    }
    return [PSCustomObject]$s
}

# Записать файл состояния целиком или никак.
#
# Сначала временный файл, потом замена. [IO.File]::Replace в папке
# ProgramData отказывал второму и всем следующим вызовам: первый
# agents.json создавался, а дальше обновлялся только .tmp. Перекличка
# агентов застывала, наблюдатель решал, что агенты молчат, и раз в
# минуту перезапускал сторожа. Теперь: замена, а если Windows отказала —
# перенос поверх, а если и он — прямая запись. И с повтором: файл
# может на миг держать открытым окно, которое его читает.
function Write-CgFileAtomic {
    param([string]$Path, [string]$Text)
    $tmp = "$Path.tmp"
    $enc = New-Object Text.UTF8Encoding $false
    for ($i = 0; $i -lt 5; $i++) {
        try {
            [IO.File]::WriteAllText($tmp, $Text, $enc)
            if (-not (Test-Path -LiteralPath $Path)) { [IO.File]::Move($tmp, $Path); return $true }
            try { [IO.File]::Replace($tmp, $Path, $null); return $true } catch { }
            try { [IO.File]::Copy($tmp, $Path, $true); [IO.File]::Delete($tmp); return $true } catch { }
            [IO.File]::WriteAllText($Path, $Text, $enc)
            try { [IO.File]::Delete($tmp) } catch { }
            return $true
        } catch { Start-Sleep -Milliseconds (40 * ($i + 1)) }
    }
    return $false
}

function Save-CgSettings {
    param($Settings)
    $json = ([PSCustomObject]$Settings) | ConvertTo-Json -Depth 4
    if (-not (Write-CgFileAtomic (Get-CgSettingsPath) $json)) { throw 'Не удалось записать настройки' }
}

function Set-CgSetting {
    param([string]$Name, $Value)
    $s = [ordered]@{}
    foreach ($pr in (Get-CgSettings).PSObject.Properties) { $s[$pr.Name] = $pr.Value }
    $s[$Name] = $Value
    try { Save-CgSettings $s; return $true } catch { return $false }
}

# ---------- чьи профили смотреть ----------
#
# Сторож работает от SYSTEM, и для него %LOCALAPPDATA% — это профиль
# самой системы (C:\Windows\System32\config\systemprofile). Браузеров
# там нет. Поэтому фоновый сторож годами «следил» за пустым списком
# файлов cookie: тревоги о чтении cookie он не мог поднять в принципе.
# Под SYSTEM перебираем настоящие профили людей из реестра.
function Test-CgIsSystem {
    try { return ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18') } catch { return $false }
}

function Get-CgUserProfiles {
    if (-not (Test-CgIsSystem)) {
        $dl = ''
        try { $dl = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders' -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}' } catch { }
        if (-not $dl) { $dl = Join-Path $env:USERPROFILE 'Downloads' }
        return @([PSCustomObject]@{
            Sid = ''; Home = $env:USERPROFILE; Local = $env:LOCALAPPDATA; Roaming = $env:APPDATA
            Temp = $env:TEMP; Downloads = $dl
        })
    }
    $out = @()
    foreach ($k in (Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList' -ErrorAction SilentlyContinue)) {
        $sid = $k.PSChildName
        if ($sid -notmatch '^S-1-5-21-') { continue }
        # не $home: это встроенная переменная PowerShell, только для чтения
        $dir = ''
        try { $dir = [Environment]::ExpandEnvironmentVariables("$((Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction Stop).ProfileImagePath)") } catch { }
        if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { continue }
        # Папка «Загрузки» бывает перенесена (у вас — на диск E:).
        # Узнать это можно только из куста вошедшего человека.
        $dl = ''
        try { $dl = (Get-ItemProperty "Registry::HKEY_USERS\$sid\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" -ErrorAction Stop).'{374DE290-123F-4565-9164-39C4925E467B}' } catch { }
        if (-not $dl) { $dl = Join-Path $dir 'Downloads' }
        $out += [PSCustomObject]@{
            Sid = $sid; Home = $dir; Local = (Join-Path $dir 'AppData\Local'); Roaming = (Join-Path $dir 'AppData\Roaming')
            Temp = (Join-Path $dir 'AppData\Local\Temp'); Downloads = $dl
        }
    }
    return $out
}

function Write-CgHead {
    param([string]$Text)
    Write-Host ''
    Write-Host ('=' * 74) -ForegroundColor DarkCyan
    Write-Host ("  $Text") -ForegroundColor Cyan
    Write-Host ('=' * 74) -ForegroundColor DarkCyan
}

function Write-CgItem {
    param([string]$Severity, [string]$Text, [string]$Detail = '')
    $map = @{
        'CRIT' = @('КРИТИЧНО', 'Red')
        'WARN' = @('ВНИМАНИЕ', 'Yellow')
        'NOTE' = @('заметка ', 'DarkYellow')
        'OK'   = @('норма   ', 'DarkGreen')
        'INFO' = @('инфо    ', 'Gray')
    }
    $m = $map[$Severity]
    if (-not $m) { $m = @('        ', 'Gray') }
    Write-Host ('  [{0}] ' -f $m[0]) -ForegroundColor $m[1] -NoNewline
    Write-Host $Text
    if ($Detail) {
        foreach ($l in ($Detail -split "`n")) {
            if ($l.Trim()) { Write-Host ('             ' + $l.Trim()) -ForegroundColor DarkGray }
        }
    }
}

# ---------- браузеры и защищаемые файлы ----------

function Get-CgBrowsers {
    $out = @()
    foreach ($u in (Get-CgUserProfiles)) {
        $L = $u.Local; $R = $u.Roaming
        $defs = @(
            @{ Name = 'Chrome'; Root = "$L\Google\Chrome\User Data"
               Exe  = @("$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
                        "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
                        "$L\Google\Chrome\Application\chrome.exe") },
            @{ Name = 'Edge'; Root = "$L\Microsoft\Edge\User Data"
               Exe  = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
                        "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") },
            @{ Name = 'Brave'; Root = "$L\BraveSoftware\Brave-Browser\User Data"
               Exe  = @("$env:ProgramFiles\BraveSoftware\Brave-Browser\Application\brave.exe",
                        "${env:ProgramFiles(x86)}\BraveSoftware\Brave-Browser\Application\brave.exe",
                        "$L\BraveSoftware\Brave-Browser\Application\brave.exe") },
            @{ Name = 'Yandex'; Root = "$L\Yandex\YandexBrowser\User Data"
               Exe  = @("$L\Yandex\YandexBrowser\Application\browser.exe") },
            @{ Name = 'Opera'; Root = "$R\Opera Software\Opera Stable"
               Exe  = @("$L\Programs\Opera\opera.exe") },
            @{ Name = 'Vivaldi'; Root = "$L\Vivaldi\User Data"
               Exe  = @("$L\Vivaldi\Application\vivaldi.exe") },
            @{ Name = 'Firefox'; Root = "$R\Mozilla\Firefox\Profiles"
               Exe  = @("$env:ProgramFiles\Mozilla Firefox\firefox.exe",
                        "${env:ProgramFiles(x86)}\Mozilla Firefox\firefox.exe") }
        )
        foreach ($d in $defs) {
            if (Test-Path -LiteralPath $d.Root) {
                $out += [PSCustomObject]@{ Name = $d.Name; Root = $d.Root; Exe = @($d.Exe); Home = $u.Home }
            }
        }
    }
    return $out
}

# Файлы, за которыми следим. Содержимое не читается — только путь.
function Get-CgTargetFiles {
    $names = @('Cookies', 'Login Data', 'Login Data For Account', 'Web Data', 'Local State',
               'cookies.sqlite', 'logins.json', 'key4.db')
    $out = @()
    foreach ($b in (Get-CgBrowsers)) {
        $files = Get-ChildItem -LiteralPath $b.Root -Recurse -Depth 3 -Force -File -ErrorAction SilentlyContinue |
                 Where-Object { $names -contains $_.Name }
        foreach ($f in $files) {
            $out += [PSCustomObject]@{ Browser = $b.Name; Path = $f.FullName; Exe = $b.Exe }
        }
    }
    return $out
}

# ---------- подписи и хеши ----------

$script:TrustedSigners = @(
    'Microsoft Windows', 'Microsoft Corporation', 'Microsoft Windows Publisher',
    'Microsoft Windows Hardware Compatibility Publisher', 'Google LLC', 'Google Inc',
    'Brave Software', 'Mozilla Corporation', 'Opera Norway', 'Yandex',
    'Intel', 'NVIDIA', 'Advanced Micro Devices', 'Realtek', 'Logitech', 'Dell', 'HP Inc',
    'Lenovo', 'ASUSTeK', 'Acer', 'Synaptics', 'Elan Microelectronics',
    'ESET', 'Kaspersky', 'Avast', 'AVG', 'Bitdefender', 'Malwarebytes',
    'Valve', 'Discord', 'Telegram', 'JetBrains', 'Anthropic', 'Docker', 'Oracle',
    'Python Software Foundation', 'Git for Windows', 'Node.js', 'Adobe', 'Apple',
    'Spotify', 'Dropbox', 'VideoLAN', 'Notepad++', '7-Zip', 'Igor Pavlov', 'Overwolf'
)

function Get-CgSignerName {
    param([string]$Subject)
    if (-not $Subject) { return '' }
    if ($Subject -match 'CN="([^"]+)"') { return $matches[1] }
    if ($Subject -match 'CN=([^,]+)')   { return $matches[1].Trim() }
    return $Subject
}

function Get-CgSignature {
    param([string]$Path)
    if (-not $Path) {
        return [PSCustomObject]@{ Status = 'NoPath'; Signer = ''; Valid = $false; Trusted = $false }
    }
    $key = $Path.ToLowerInvariant()
    if ($script:SigCache.ContainsKey($key)) { return $script:SigCache[$key] }

    $status = 'Error'; $signer = ''; $valid = $false; $trusted = $false
    try {
        $s = Get-AuthenticodeSignature -LiteralPath $Path -ErrorAction Stop
        $status = [string]$s.Status
        if ($s.SignerCertificate) { $signer = Get-CgSignerName $s.SignerCertificate.Subject }
        $valid = ($status -eq 'Valid')
        if ($valid -and $signer) {
            foreach ($t in $script:TrustedSigners) {
                if ($signer -like "*$t*") { $trusted = $true; break }
            }
        }
    } catch { }

    $r = [PSCustomObject]@{ Status = $status; Signer = $signer; Valid = $valid; Trusted = $trusted }
    $script:SigCache[$key] = $r
    return $r
}

# ---------- политика аудита ----------
#
# auditpol отвечает на языке системы, и это уже один раз подвело:
# проверка искала слово Success, а русская Windows отвечает «Успех»,
# и включённый аудит читался как выключенный. Поэтому решение
# принимается по положительному совпадению со списком известных
# слов, а не по отсутствию слова «нет аудита»: незнакомый язык
# тогда даст «выключено», и человек увидит исходный текст рядом,
# а не бодрое «включён (Без аудита)».
#
# Формат /r — CSV:
#   Machine Name,Policy Target,Subcategory,Subcategory GUID,
#   Inclusion Setting,Exclusion Setting
# Нужен столбец сразу после GUID: последний (Exclusion) почти
# всегда пуст.
$script:CgAuditOnWords  = '(?i)success|failure|успех|отказ|сбой|erfolg|réussite|éxito'
$script:CgAuditOffWords = '(?i)^\s*(no auditing|нет аудита|без аудита|отсутствует)\s*$'

function Get-CgAuditPolState {
    param([string]$Guid)

    $r = & auditpol /get /subcategory:"$Guid" /r 2>&1
    if ($LASTEXITCODE -ne 0) {
        return [PSCustomObject]@{ Ok = $false; Enabled = $false; Text = ($r -join ' ') }
    }

    $setting = ''
    foreach ($line in @($r)) {
        if ("$line" -notmatch [regex]::Escape($Guid)) { continue }
        $cols = "$line" -split ','
        for ($i = 0; $i -lt $cols.Count; $i++) {
            if ($cols[$i].Trim() -ne $Guid) { continue }
            if ($i + 1 -lt $cols.Count) { $setting = $cols[$i + 1].Trim() }
            break
        }
        if ($setting) { break }
    }

    $on = ($setting -and $setting -notmatch $script:CgAuditOffWords -and $setting -match $script:CgAuditOnWords)
    return [PSCustomObject]@{ Ok = $true; Enabled = $on; Text = $setting }
}

function Get-CgHash {
    param([string]$Path)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return '' }
    $key = $Path.ToLowerInvariant()
    if ($script:HashCache.ContainsKey($key)) { return $script:HashCache[$key] }
    $h = ''
    try { $h = (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash } catch { }
    $script:HashCache[$key] = $h
    return $h
}

# ---------- классификация путей ----------

# Windows отдаёт пути в разных формах: \\?\C:\..., \??\C:\..., C:\...
function Get-CgNormPath {
    param([string]$Path)
    if (-not $Path) { return '' }
    $p = $Path -replace '^\\\\\?\\', '' -replace '^\\\?\?\\', ''
    return $p
}

function Get-CgPathClass {
    param([string]$Path)
    if (-not $Path) { return 'none' }
    $p = (Get-CgNormPath $Path).ToLowerInvariant()
    if ($p -like '*\windowsapps\*') { return 'windowsapps' }
    if ($p -like '*\appdata\local\temp\*' -or $p -like '*\windows\temp\*') { return 'temp' }
    if ($p -like '*\downloads\*')                                          { return 'downloads' }
    if ($p -like '*\users\public\*' -or $p -like '*$recycle.bin*')         { return 'public' }
    if ($p -like 'c:\programdata\*')                                       { return 'programdata' }
    if ($p -like '*\appdata\roaming\*')                                    { return 'roaming' }
    if ($p -like '*\appdata\local\*')                                      { return 'localapp' }
    if ($p -like 'c:\windows\system32\*' -or $p -like 'c:\windows\syswow64\*') { return 'system32' }
    if ($p -like 'c:\windows\*')                                           { return 'windows' }
    if ($p -like 'c:\program files*')                                      { return 'programfiles' }
    if ($p -like 'c:\perflogs\*' -or $p -like 'c:\intel\*' -or $p -like 'c:\temp\*') { return 'odd' }
    return 'other'
}

# Защищённые процессы Windows: путь к их файлу не виден даже администратору.
# Пустой путь у них — норма, а не признак маскировки.
$script:ProtectedProcs = @(
    'system','registry','idle','system idle process','memory compression','secure system',
    'smss.exe','csrss.exe','wininit.exe','services.exe','lsass.exe','lsaiso.exe','winlogon.exe',
    'svchost.exe','fontdrvhost.exe','audiodg.exe','ngciso.exe','wudfhost.exe',
    'msmpeng.exe','nissrv.exe','mpdefendercoreservice.exe','defendersessionhelper.exe',
    'securityhealthservice.exe','securityhealthsystray.exe','smartscreen.exe',
    'ekrn.exe','avp.exe','avastsvc.exe','mbamservice.exe'
)

# Системные имена, которые обязаны жить только в System32
$script:SystemImageNames = @(
    'svchost.exe','lsass.exe','csrss.exe','services.exe','winlogon.exe','smss.exe',
    'wininit.exe','taskhostw.exe','dllhost.exe','conhost.exe','spoolsv.exe','ctfmon.exe',
    'runtimebroker.exe','sihost.exe','fontdrvhost.exe','dwm.exe','audiodg.exe',
    'lsaiso.exe','searchindexer.exe','wuauclt.exe'
)

$script:LolBins = @(
    'powershell.exe','pwsh.exe','wscript.exe','cscript.exe','mshta.exe','rundll32.exe',
    'regsvr32.exe','certutil.exe','bitsadmin.exe','installutil.exe','msbuild.exe',
    'regasm.exe','regsvcs.exe','cmstp.exe','msiexec.exe','forfiles.exe','pcalua.exe',
    'curl.exe','wget.exe','hh.exe','wmic.exe','odbcconf.exe','xwizard.exe'
)

# ---------- инвентаризация процессов ----------

function Get-CgProcessTable {
    $cim = @{}
    foreach ($p in (Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)) {
        $cim[[int]$p.ProcessId] = $p
    }

    $owners = @{}
    try {
        foreach ($gp in (Get-Process -IncludeUserName -ErrorAction SilentlyContinue)) {
            $owners[[int]$gp.Id] = $gp.UserName
        }
    } catch { }

    $out = @()
    foreach ($procId in $cim.Keys) {
        $p = $cim[$procId]
        $path = $p.ExecutablePath
        $parent = $null
        $parentPath = ''
        if ($cim.ContainsKey([int]$p.ParentProcessId)) {
            $parent = $cim[[int]$p.ParentProcessId].Name
            # Путь родителя нужен доверию: подпись родителя переживает
            # его обновление, а имя процесса подделывается тривиально.
            $parentPath = "$($cim[[int]$p.ParentProcessId].ExecutablePath)"
        }
        $created = $null
        try { $created = $p.CreationDate } catch { }

        $out += [PSCustomObject]@{
            Id          = $procId
            Name        = $p.Name
            Path        = $path
            CommandLine = $p.CommandLine
            ParentId    = [int]$p.ParentProcessId
            ParentName  = $parent
            ParentPath  = $parentPath
            Ancestors   = @(Get-CgAncestors $cim $procId)
            User        = $owners[$procId]
            Started     = $created
            Risk        = 0
            Reasons     = @()
        }
    }
    return $out
}

# ------------------------------------------------------------
#  Цепочка предков процесса
#
#  Одного родителя мало. Claude Code запускает cmd, тот — node,
#  тот — railway.exe; у railway.exe родитель node.exe, и доверие
#  «всё, что запускает Claude» по одному родителю его не узнаёт.
#  Идём вверх на несколько ступеней, пока не кончатся предки.
#  Номера процессов Windows раздаёт повторно, поэтому предок,
#  запущенный позже потомка, — это уже чужой процесс: на нём
#  цепочку обрываем.
# ------------------------------------------------------------
function Get-CgAncestors {
    param($Table, [int]$ProcId, [int]$Depth = 6)
    $out = @()
    $seen = @{}
    $cur = $Table[$ProcId]
    while ($cur -and $out.Count -lt $Depth) {
        $ppid = [int]$cur.ParentProcessId
        if ($ppid -le 4 -or $seen.ContainsKey($ppid) -or -not $Table.ContainsKey($ppid)) { break }
        $par = $Table[$ppid]
        try { if ($par.CreationDate -and $cur.CreationDate -and $par.CreationDate -gt $cur.CreationDate) { break } } catch { }
        $seen[$ppid] = $true
        $out += [PSCustomObject]@{ Id = $ppid; Name = "$($par.Name)"; Path = (Get-CgNormPath "$($par.ExecutablePath)") }
        $cur = $par
    }
    return $out
}

# Chrome и его родня запускают помощника расширения (native messaging)
# через cmd.exe /d /s /c "...host.exe" chrome-extension://<id>/. Это штатный
# механизм браузера, а не «браузер запустил интерпретатор»: так работают
# менеджеры паролей, Claude в Chrome и любые расширения с программой на диске.
function Test-CgNativeMessagingHost {
    param([string]$Name, [string]$ParentName, [string]$CommandLine)
    if ("$Name".ToLowerInvariant() -ne 'cmd.exe') { return $false }
    if ("$ParentName".ToLowerInvariant() -notmatch '^(chrome|msedge|brave|vivaldi|opera|browser|firefox)\.exe$') { return $false }
    return ("$CommandLine" -match '(?i)/c\s+"*[^"]+\.exe"*\s+"?(chrome-extension://[a-p]{32}/|[a-z0-9_.-]+@[a-z0-9_.-]+|\{[0-9a-f-]{36}\})')
}

# Сторож и наблюдатель CookieGuard — powershell со скрытым окном и
# -ExecutionPolicy Bypass от SYSTEM: по признакам ровно то, что ищет
# оценка риска, а путь к образу процесса SYSTEM окно прочитать не
# может. Наблюдатель запускается раз в минуту, и монитор то и дело
# сообщал о «подозрительном powershell.exe» — о самом CookieGuard.
# Узнаём их по точной строке, которую ставят Register-CgGuardTask и
# Register-CgWatchdogTask, и по родителю — планировщику (svchost).
# Любая добавка к строке — уже не наша задача.
function Test-CgOwnTaskProcess {
    param([string]$Name, [string]$CommandLine, [string]$ParentName)
    if ("$Name".ToLowerInvariant() -ne 'powershell.exe') { return $false }
    if ("$ParentName".ToLowerInvariant() -ne 'svchost.exe') { return $false }
    $ps = [regex]::Escape((Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'))
    $root = [regex]::Escape((Get-CgRoot))
    $re = '(?i)^"?{0}"?\s+-NoProfile\s+-ExecutionPolicy\s+Bypass\s+-WindowStyle\s+Hidden\s+-File\s+"{1}\\(Watchdog|Guard-Service)\.ps1"(\s+-AutoNeutralize)?\s*$' -f $ps, $root
    return ("$CommandLine" -match $re)
}

# ---------- оценка риска ----------

function Measure-CgProcessRisk {
    param([PSCustomObject]$Proc)

    # Два счёта с разной судьбой:
    #   $score — статические признаки (подпись, расположение, возраст файла).
    #            Доверенная подпись их законно обесценивает.
    #   $behav — поведение (аргументы, кто кого запустил, маскировка под систему).
    #            Его обесценивать нельзя: атаки «за счёт самой Windows» ведутся
    #            именно подписанными Microsoft программами — powershell, mshta,
    #            certutil. Скидка за подпись спрятала бы ровно то, что ищем.
    $score = 0
    $behav = 0
    $why = New-Object System.Collections.ArrayList
    $name = ''
    if ($Proc.Name) { $name = $Proc.Name.ToLowerInvariant() }
    $path = Get-CgNormPath $Proc.Path
    $cls = Get-CgPathClass $path
    $cmd = ''
    if ($Proc.CommandLine) { $cmd = $Proc.CommandLine }
    $cmdl = $cmd.ToLowerInvariant()

    if (Test-CgOwnTaskProcess $name $cmd $Proc.ParentName) {
        $Proc.Risk = 0
        $Proc.Reasons = @('сторож или наблюдатель CookieGuard (задача планировщика)')
        return $Proc
    }

    # защищённые процессы Windows: пустой путь у них нормален
    $isProtected = ($script:ProtectedProcs -contains $name) -or ($Proc.Id -le 4)

    # Файлы в составе Windows и магазинных приложений подписаны каталогом,
    # а не встроенной подписью. Get-AuthenticodeSignature их не видит, поэтому
    # отсутствие подписи там само по себе ни о чём не говорит.
    $sysLocation = (@('system32', 'windows', 'windowsapps') -contains $cls)

    $sig = $null
    if ($path) { $sig = Get-CgSignature $path }

    # 1) подпись
    if (-not $isProtected) {
        if (-not $path) {
            $null = $why.Add('нет пути к исполняемому файлу (процесс скрывает образ)')
            $score += 25
        } elseif ($sysLocation) {
            # в системных папках верим расположению, а не подписи:
            # записать туда файл без прав администратора невозможно
            if ($sig.Status -notin @('Valid', 'NotSigned', 'UnknownError', 'Error')) {
                $null = $why.Add("подпись системного файла повреждена: $($sig.Status)")
                $score += 40
            }
        } elseif ($sig.Status -eq 'NotSigned') {
            # в Program Files без прав администратора тоже не запишешь
            if ($cls -eq 'programfiles') {
                $null = $why.Add('файл без цифровой подписи (но в Program Files)')
                $score += 12
            } else {
                $null = $why.Add('файл без цифровой подписи')
                $score += 32
            }
        } elseif (-not $sig.Valid) {
            $null = $why.Add("подпись недействительна: $($sig.Status)")
            $score += 40
        } elseif (-not $sig.Trusted) {
            $null = $why.Add("подписан малоизвестным издателем: $($sig.Signer)")
            $score += 8
        }
    }

    # 2) расположение
    switch ($cls) {
        'temp'        { $null = $why.Add('запущен из временной папки (Temp)');        $score += 32 }
        'downloads'   { $null = $why.Add('запущен прямо из папки Загрузки');          $score += 30 }
        'public'      { $null = $why.Add('запущен из Public / Корзины');              $score += 35 }
        'programdata' { $null = $why.Add('запущен из ProgramData');                   $score += 18 }
        'roaming'     { $null = $why.Add('запущен из AppData\Roaming');               $score += 10 }
        'odd'         { $null = $why.Add('запущен из нетипичной папки в корне диска');$score += 22 }
    }

    # 3) маскировка под системный процесс
    if (($script:SystemImageNames -contains $name) -and $path -and $cls -ne 'system32') {
        $null = $why.Add("имя системного процесса, но файл лежит НЕ в System32: $path")
        $behav += 48
    }

    # 4) подозрительное имя файла
    if ($name -match '\.(exe|scr|com|pif|bat|cmd)$' -and $name -match '\.(pdf|doc|docx|jpg|png|txt|xls|xlsx|mp4|zip)\.') {
        $null = $why.Add('двойное расширение в имени файла')
        $behav += 42
    }
    if ($Proc.Name -and $Proc.Name -match '[\u202A-\u202E\u2066-\u2069]') {
        $null = $why.Add('в имени файла спрятан символ переворота текста (RLO)')
        $behav += 50
    }

    # 5) интерпретаторы и системные утилиты с подозрительными аргументами
    if ($script:LolBins -contains $name) {
        if ($cmdl -match '(^|\s)-(e|en|enc|encod|encode|encoded|encodedcommand)(\s|:)') {
            $null = $why.Add('PowerShell запущен с командой в Base64 (-EncodedCommand)')
            $behav += 38
        }
        if ($cmdl -match 'frombase64string|::fromb') { $null = $why.Add('расшифровка Base64 прямо в командной строке'); $behav += 32 }
        if ($cmdl -match '-w\s+h|-windowstyle\s+hidden|-noni|-nop\b') { $null = $why.Add('скрытое окно / без профиля'); $behav += 18 }
        if ($cmdl -match 'downloadstring|downloadfile|invoke-webrequest|invoke-restmethod|iwr\s|irm\s|start-bitstransfer') {
            $null = $why.Add('скачивание из сети прямо из командной строки'); $behav += 28
        }
        if ($cmdl -match 'iex|invoke-expression') { $null = $why.Add('выполнение строки как кода (IEX)'); $behav += 30 }
        if ($name -eq 'certutil.exe' -and $cmdl -match '-decode|-urlcache|-f\s+-split') {
            $null = $why.Add('certutil используется для скачивания/декодирования файла'); $behav += 42
        }
        if ($name -eq 'bitsadmin.exe' -and $cmdl -match '/transfer') { $null = $why.Add('bitsadmin качает файл'); $behav += 38 }
        if ($name -eq 'mshta.exe' -and $cmdl -match 'http|javascript:|vbscript:') { $null = $why.Add('mshta выполняет удалённый/встроенный скрипт'); $behav += 45 }
        if ($name -eq 'regsvr32.exe' -and $cmdl -match '/i:|scrobj') { $null = $why.Add('regsvr32 подгружает сторонний скриптлет'); $behav += 45 }
        if ($name -eq 'rundll32.exe' -and $cmdl -match 'javascript:|\\appdata\\|\\temp\\') { $null = $why.Add('rundll32 грузит DLL из пользовательской папки'); $behav += 40 }
        if (@('temp','downloads','public','roaming') -contains $cls) {
            $null = $why.Add('системная утилита запущена копией из пользовательской папки'); $behav += 30
        }
    }

    # 6) подозрительная связка родитель -> потомок
    $parent = ''
    if ($Proc.ParentName) { $parent = $Proc.ParentName.ToLowerInvariant() }
    $officeParents = @('winword.exe','excel.exe','powerpnt.exe','outlook.exe','acrobat.exe','acrord32.exe')
    $scriptKids = @('powershell.exe','pwsh.exe','cmd.exe','wscript.exe','cscript.exe','mshta.exe','rundll32.exe','regsvr32.exe')
    if (($officeParents -contains $parent) -and ($scriptKids -contains $name)) {
        $null = $why.Add("офисная программа ($parent) запустила интерпретатор"); $behav += 45
    }
    if ($parent -match '^(chrome|msedge|brave|firefox|opera)\.exe$' -and ($scriptKids -contains $name)) {
        if (Test-CgNativeMessagingHost $name $parent $cmd) {
            $null = $why.Add("браузер ($parent) запустил помощника расширения — штатный механизм native messaging")
        } else {
            $null = $why.Add("браузер ($parent) запустил интерпретатор"); $behav += 35
        }
    }

    # 7) свежесозданный файл в пользовательской папке
    if ($path -and (@('temp','downloads','roaming','localapp','public','programdata') -contains $cls)) {
        try {
            $fi = Get-Item -LiteralPath $path -ErrorAction Stop
            $age = (Get-Date) - $fi.CreationTime
            if ($age.TotalDays -lt 3) {
                $null = $why.Add(('файл появился недавно: {0}' -f $fi.CreationTime.ToString('dd.MM.yyyy HH:mm')))
                $score += 14
            }
        } catch { }
    }

    # 8) доверенная подпись обесценивает только статические признаки.
    #    Поведенческие прибавляются после скидки — иначе подписанный Microsoft
    #    powershell.exe с командой в Base64 выглядел бы безобиднее неподписанной,
    #    но безвредной утилиты.
    if ($sig -and $sig.Trusted) { $score = [int]($score * 0.35) }
    $score += $behav

    $Proc.Risk = $score
    $Proc.Reasons = @($why.ToArray())
    return $Proc
}

function Get-CgRiskLevel {
    param([int]$Score)
    if ($Score -ge 60) { return 'CRIT' }
    if ($Score -ge 32) { return 'WARN' }
    if ($Score -ge 14) { return 'NOTE' }
    return 'OK'
}

# Язык интерфейса: функция T и перевод разметки. Здесь, а не в
# CookieGuard.ps1, чтобы T была везде, где загружено ядро, — в том
# числе в фоновых потоках.
. (Join-Path $PSScriptRoot 'Lang.ps1')
