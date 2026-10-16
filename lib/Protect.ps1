# ============================================================
#  CookieGuard - Protect.ps1
#  Автозащита: один переключатель, который включает всё сразу,
#  помнит, что включён, и сам поднимает обратно то, что выключили.
#
#  Раньше защита была пятью отдельными кнопками, и каждая жила
#  своей жизнью: «журнал запуска программ» не показывал, включён ли
#  он, выключение аудита cookie заодно гасило и журнал запусков,
#  наблюдатель за сторожем не создавался вовсе (задача с «вечным»
#  повтором отвергалась Windows 10, ошибка уходила в предупреждение),
#  а сторож от SYSTEM смотрел не в тот профиль. Снаружи это выглядело
#  как «защита то есть, то нет, а журнал выключается сам».
#
#  Здесь каждая часть описана один раз: как проверить и как
#  включить. Окно показывает список, установщик включает его
#  целиком, сторож раз в минуту проверяет и чинит.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'
if (-not (Get-Command Test-CgHostsAudit -ErrorAction SilentlyContinue)) { . (Join-Path $PSScriptRoot 'Hosts.ps1') }

$script:CgTaskGuard = 'CookieGuard Watcher'
$script:CgTaskDog   = 'CookieGuard Watchdog'
$script:CgGuidFs    = '{0CCE921D-69AE-11D9-BED3-505054503030}'   # File System
$script:CgGuidProc  = '{0CCE922B-69AE-11D9-BED3-505054503030}'   # Process Creation
$script:CgSecLogMin = 256MB

function Get-CgPsExe { Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe' }

# ------------------------------------------------------------
#  Задачи планировщика
# ------------------------------------------------------------
function Register-CgGuardTask {
    param([switch]$AutoNeutralize)
    $guardPs = Join-Path (Get-CgRoot) 'Guard-Service.ps1'
    $taskArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$guardPs`""
    if ($AutoNeutralize) { $taskArgs += ' -AutoNeutralize' }
    # WorkingDirectory не задаём намеренно: планировщик от SYSTEM отвергает
    # некоторые пользовательские пути с ошибкой 0x8007010B.
    $action    = New-ScheduledTaskAction -Execute (Get-CgPsExe) -Argument $taskArgs
    $trigger   = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                   -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
                   -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $script:CgTaskGuard -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
}

function Register-CgWatchdogTask {
    $dogPs = Join-Path (Get-CgRoot) 'Watchdog.ps1'
    $action = New-ScheduledTaskAction -Execute (Get-CgPsExe) -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$dogPs`""
    # Повтор БЕЗ -RepetitionDuration. С [TimeSpan]::MaxValue Windows 10
    # отвечает «The task XML contains a value which is incorrectly
    # formatted or out of range» — и наблюдатель не создавался ни разу,
    # хотя окно писало, что защита включена. Без длительности повтор
    # бессрочный. Второй триггер — при старте, на случай выключенного
    # компьютера в момент первого запуска.
    $t1 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
    $t2 = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable `
                  -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName $script:CgTaskDog -Action $action -Trigger @($t1, $t2) -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
}

function Test-CgTask {
    param([string]$Name)
    try { return [bool](Get-ScheduledTask -TaskName $Name -ErrorAction Stop) } catch { return $false }
}

# Отметка «жив»: «время|v2|PID|метка кода». Старый сторож писал только
# время — по нему и видно, что он работает на старом коде. Так и
# случилось после обновления fd19481: обновление ставило ещё старое
# окно, перезапускать сторожа оно не умело, и старый сторож продолжал
# отмечаться «жив», ничего не чиня. Две части автозащиты горели
# красным без объяснений.
function Get-CgHeartbeatPath { Join-Path (Get-CgDir 'state') 'guard-heartbeat.txt' }

function Get-CgGuardInfo {
    $r = [PSCustomObject]@{ Alive = $false; Age = $null; Version = 0; ProcId = 0; CodeStamp = [int64]0 }
    $hb = Get-CgHeartbeatPath
    if (-not (Test-Path -LiteralPath $hb)) { return $r }
    try {
        $parts = ([IO.File]::ReadAllText($hb)).Trim() -split '\|'
        $r.Age = ((Get-Date) - [datetime]::Parse($parts[0])).TotalSeconds
        $r.Alive = ($r.Age -lt 90)
        $r.Version = 1
        if ($parts.Count -ge 4 -and $parts[1] -eq 'v2') {
            $r.Version = 2
            $r.ProcId = [int]$parts[2]
            $r.CodeStamp = [int64]$parts[3]
        }
    } catch { }
    return $r
}

function Get-CgGuardHeartbeatAge { (Get-CgGuardInfo).Age }

function Test-CgGuardAlive { (Get-CgGuardInfo).Alive }

# Метка кода — самое позднее изменение файлов сторожа. Сторож пишет
# свою в отметку «жив»; меньше, чем у файлов на диске, — он на старом коде.
function Get-CgCodeStamp {
    $t = [datetime]::MinValue
    $root = Get-CgRoot
    foreach ($f in @(Get-Item -LiteralPath (Join-Path $root 'Guard-Service.ps1') -ErrorAction SilentlyContinue) +
                   @(Get-ChildItem -LiteralPath (Join-Path $root 'lib') -Filter *.ps1 -File -ErrorAction SilentlyContinue)) {
        if ($f.LastWriteTimeUtc -gt $t) { $t = $f.LastWriteTimeUtc }
    }
    return $t.Ticks
}

function Test-CgGuardCurrent {
    $g = Get-CgGuardInfo
    if (-not $g.Alive) { return $false }
    return ($g.Version -ge 2 -and $g.CodeStamp -ge (Get-CgCodeStamp))
}

# Перезапуск сторожа: нужен после обновления, чтобы фон заработал
# на новом коде сразу, а не после перезагрузки.
function Restart-CgGuard {
    if (-not (Test-CgTask $script:CgTaskGuard)) { return $false }
    try { Stop-ScheduledTask -TaskName $script:CgTaskGuard -ErrorAction SilentlyContinue } catch { }
    # Только сторож этой установки и только если он не завершился сам:
    # прежде гасились все powershell с «Guard-Service.ps1» в строке,
    # включая чужие копии и проверочные запуски.
    $mine = [regex]::Escape((Join-Path (Get-CgRoot) 'Guard-Service.ps1'))
    foreach ($p in (Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue)) {
        if ($p.ProcessId -eq $PID) { continue }
        if ("$($p.CommandLine)" -match "(?i)$mine") { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch { } }
    }
    Start-Sleep -Milliseconds 600
    try { Start-ScheduledTask -TaskName $script:CgTaskGuard -ErrorAction Stop; return $true } catch { return $false }
}

# ------------------------------------------------------------
#  Аудит: политика, файлы cookie, журнал безопасности
# ------------------------------------------------------------
function Test-CgProcAuditOn {
    $st = Get-CgAuditPolState $script:CgGuidProc
    if (-not $st.Ok) { return $null }
    if (-not $st.Enabled) { return $false }
    $v = 0
    try { $v = [int](Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -ErrorAction Stop).ProcessCreationIncludeCmdLine_Enabled } catch { }
    return ($v -eq 1)
}

function Enable-CgProcAudit {
    & auditpol /set /subcategory:$script:CgGuidProc /success:enable 2>&1 | Out-Null
    $k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
    if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    New-ItemProperty -Path $k -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -PropertyType DWord -Force | Out-Null
    return [bool](Test-CgProcAuditOn)
}

function Test-CgFsAuditOn {
    $st = Get-CgAuditPolState $script:CgGuidFs
    if (-not $st.Ok) { return $null }
    return [bool]$st.Enabled
}

function Enable-CgFsAudit {
    & auditpol /set /subcategory:$script:CgGuidFs /success:enable 2>&1 | Out-Null
    return [bool](Test-CgFsAuditOn)
}

function Get-CgCookieAuditFiles {
    # те же файлы, что ставит Install-Audit.ps1
    # Local State — ключ шифрования cookie: без него базу не расшифровать
    return @(Get-CgTargetFiles | Where-Object { $_.Path -match '\\(Cookies|Login Data|Local State|logins\.json|key4\.db|cookies\.sqlite)$' })
}

function Test-CgFileAudited {
    param([string]$Path)
    try {
        $everyone = New-Object System.Security.Principal.SecurityIdentifier 'S-1-1-0'
        $acl = Get-Acl -LiteralPath $Path -Audit -ErrorAction Stop
        foreach ($r in @($acl.GetAuditRules($true, $true, [System.Security.Principal.SecurityIdentifier]))) {
            if ($r.IdentityReference -eq $everyone -and (($r.FileSystemRights -band [System.Security.AccessControl.FileSystemRights]::ReadData) -ne 0)) { return $true }
        }
        return $false
    } catch { return $null }
}

# Сколько баз cookie и паролей под аудитом. Браузер, пересоздавший
# файл, и новый профиль приходят без правила — их и надо найти.
# Из пропусков аудита — те файлы, что уже были под аудитом. Только их
# потеря значит «кто-то снял». Новый профиль, пересозданный браузером
# файл, Local State и приманки, добавленные обновлением, — это не
# выключение, а первое включение. Путать одно с другим нельзя: так
# появилась ложная тревога «было выключено и включено обратно».
#
# Chrome сохраняет Local State не поверх старого, а подменой: пишет
# новую копию рядом и ставит её на место. Правило аудита было на
# старом файле и уходит вместе с ним — каждые несколько минут, пока
# браузер открыт. Отличает такую подмену время записи: у
# пересохранённого файла оно новее, чем когда мы в последний раз
# видели его под аудитом, а снятие правила время записи не трогает.
# Поэтому помним, каким было время записи при последнем «под аудитом».
if (-not $script:CgAuditSeen) { $script:CgAuditSeen = @{} }

function Get-CgWriteTicks {
    param([string]$Path)
    try { return [IO.File]::GetLastWriteTimeUtc($Path).Ticks } catch { return [int64]0 }
}

function Get-CgCookieAuditLost {
    param([string[]]$Missing)
    $f = Join-Path (Get-CgDir 'state') 'audited-files.txt'
    if (-not (Test-Path -LiteralPath $f)) { return @() }
    $had = @{}
    foreach ($l in (Get-Content -LiteralPath $f -Encoding UTF8)) { if ($l) { $had[$l.ToLowerInvariant()] = $true } }
    $lost = @()
    foreach ($p in $Missing) {
        $k = "$p".ToLowerInvariant()
        if (-not $had.ContainsKey($k)) { continue }
        $seen = $script:CgAuditSeen[$k]
        if ($seen -and (Get-CgWriteTicks $p) -gt $seen) { continue }   # браузер пересохранил файл
        $lost += $p
    }
    return $lost
}

function Get-CgCookieAuditGaps {
    $all = Get-CgCookieAuditFiles
    $gaps = @(); $unknown = $false
    foreach ($t in $all) {
        $r = Test-CgFileAudited $t.Path
        if ($null -eq $r) { $unknown = $true; continue }
        if ($r) { $script:CgAuditSeen[$t.Path.ToLowerInvariant()] = Get-CgWriteTicks $t.Path }
        else { $gaps += $t.Path }
    }
    return [PSCustomObject]@{ Total = $all.Count; Missing = $gaps; Unknown = $unknown }
}

function Set-CgCookieAuditRules {
    param([string[]]$Paths)
    $everyone = New-Object System.Security.Principal.SecurityIdentifier 'S-1-1-0'
    $rights = [System.Security.AccessControl.FileSystemRights]'ReadData, WriteData, Delete, TakeOwnership, ChangePermissions'
    $flags = [System.Security.AccessControl.AuditFlags]::Success
    $ok = 0
    foreach ($p in $Paths) {
        try {
            $acl = Get-Acl -LiteralPath $p -Audit -ErrorAction Stop
            $acl.AddAuditRule((New-Object System.Security.AccessControl.FileSystemAuditRule($everyone, $rights, $flags)))
            Set-Acl -LiteralPath $p -AclObject $acl -ErrorAction Stop
            $ok++
        } catch { }
    }
    # список для монитора и для снятия
    try {
        $f = Join-Path (Get-CgDir 'state') 'audited-files.txt'
        $have = @()
        if (Test-Path -LiteralPath $f) { $have = @(Get-Content -LiteralPath $f -Encoding UTF8) }
        @($have + $Paths) | Where-Object { $_ } | Sort-Object -Unique | Set-Content -LiteralPath $f -Encoding UTF8
    } catch { }
    return $ok
}

function Get-CgSecLogSize {
    try { return [int64](Get-WinEvent -ListLog Security -ErrorAction Stop).MaximumSizeInBytes } catch { return $null }
}

# ------------------------------------------------------------
#  Части автозащиты
#
#  Test  — $true / $false / $null («узнать нельзя»: нет прав)
#  Heal  — включить; вызывается установщиком и сторожем (SYSTEM)
#  Core  — без этой части защита не работает по существу
# ------------------------------------------------------------
function Get-CgProtectParts {
    return @(
        [PSCustomObject]@{ Key = 'guard'; Core = $true
            Name = 'Сторож стартует вместе с Windows'
            Why  = 'Работает от SYSTEM без окна. Следит, даже когда CookieGuard закрыт и никто не вошёл.'
            Test = { Test-CgTask $script:CgTaskGuard }
            Heal = $null }
        [PSCustomObject]@{ Key = 'alive'; Core = $true
            Name = 'Сторож работает на текущей версии'
            Why  = 'Отметка «жив» обновляется каждые 20 секунд и несёт метку кода: сторож на старой версии ничего не чинит и не ведёт летопись.'
            Test = { Test-CgGuardCurrent }
            Heal = $null }
        [PSCustomObject]@{ Key = 'watchdog'; Core = $false
            Name = 'Наблюдатель поднимает сторожа, если его убили'
            Why  = 'Раз в минуту проверяет отметку «жив» и запускает сторожа заново.'
            Test = { Test-CgTask $script:CgTaskDog }
            Heal = { Register-CgWatchdogTask; Test-CgTask $script:CgTaskDog } }
        [PSCustomObject]@{ Key = 'fsaudit'; Core = $true
            Name = 'Аудит доступа к файлам'
            Why  = 'Без него Windows не записывает, какая программа открыла базу cookie.'
            Test = { Test-CgFsAuditOn }
            Heal = { Enable-CgFsAudit } }
        [PSCustomObject]@{ Key = 'sacl'; Core = $true
            Name = 'Под аудитом все базы cookie и паролей'
            Why  = 'Всех профилей всех браузеров. Пересозданный браузером файл и новый профиль берутся под наблюдение сами.'
            Test = { $g = Get-CgCookieAuditGaps; if ($g.Unknown -and -not $g.Missing.Count) { $null } elseif ($g.Total -eq 0) { $false } else { -not $g.Missing.Count } }
            Heal = { $g = Get-CgCookieAuditGaps; if ($g.Missing.Count) { $null = Set-CgCookieAuditRules $g.Missing }; $g2 = Get-CgCookieAuditGaps; ($g2.Total -gt 0 -and -not $g2.Missing.Count) } }
        [PSCustomObject]@{ Key = 'procaudit'; Core = $false
            Name = 'Журнал запуска программ с командной строкой'
            Why  = 'Событие 4688: что запустилось, с какими аргументами и кто его вызвал.'
            Test = { Test-CgProcAuditOn }
            Heal = { Enable-CgProcAudit } }
        [PSCustomObject]@{ Key = 'hosts'; Core = $false
            Name = 'Слежение за hosts: что поменяли и кто'
            Why  = 'Копия файла помнится между запусками, каждое изменение разбирается построчно, автор берётся из журнала безопасности.'
            Test = { Test-CgHostsAudit }
            Heal = { $null = Set-CgHostsAudit; [bool](Test-CgHostsAudit) } }
        [PSCustomObject]@{ Key = 'net'; Core = $false
            Name = 'Теневой путь: куда соединяется тот, кто трогал cookie'
            Why  = 'Программа, прочитавшая cookie, и подозрительный процесс 10 минут под наблюдением в сети. Отдельно — любые соединения посторонних программ с Telegram, Discord и файлообменниками, куда воры паролей сливают добычу.'
            Test = { Test-CgGuardCurrent }
            Heal = $null }
        [PSCustomObject]@{ Key = 'agents'; Core = $false
            Name = 'Агенты-усы на связи'
            Why  = 'Приманка, отладочный порт, ключ шифрования, теневые копии, внедрение в браузер, сеть и hosts. Каждый отмечается раз в свой интервал; наблюдатель сверяет, не замолчал ли кто.'
            Test = { $r = Get-CgAgentsReport; if (-not $r.At) { $false } else { $r.Fresh -and -not @($r.Agents | Where-Object { $_.Silent }).Count } }
            Heal = $null }
        [PSCustomObject]@{ Key = 'seclog'; Core = $false
            Name = 'Журнал безопасности не меньше 256 МБ'
            Why  = 'Чтобы события о чтении cookie не затирались раньше, чем их прочтут.'
            Test = { $s = Get-CgSecLogSize; if ($null -eq $s) { $null } else { $s -ge $script:CgSecLogMin } }
            Heal = { & wevtutil sl Security /ms:$script:CgSecLogMin 2>&1 | Out-Null; $s = Get-CgSecLogSize; ($null -ne $s -and $s -ge $script:CgSecLogMin) } }
        [PSCustomObject]@{ Key = 'history'; Core = $false
            Name = 'Журнал событий на диске'
            Why  = 'Каждая тревога пишется в logs\events-ГГГГ-ММ.jsonl и видна в мониторе после перезапуска, перезагрузки и обновления.'
            Test = { Test-CgLogWritable }
            Heal = $null }
    )
}

function Test-CgLogWritable {
    try {
        $d = Get-CgDir 'logs'
        $f = Join-Path $d '.write-test'
        [IO.File]::WriteAllText($f, 'ok')
        Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        return $true
    } catch { return $null }
}

function Get-CgProtectStatus {
    $out = @()
    foreach ($p in (Get-CgProtectParts)) {
        $v = $null
        try { $v = & $p.Test } catch { $v = $null }
        $out += [PSCustomObject]@{ Key = $p.Key; Name = $p.Name; Why = $p.Why; Core = $p.Core; On = $v; CanHeal = [bool]$p.Heal }
    }
    return $out
}

# Включить то, что выключено. Возвращает, что пришлось чинить.
function Repair-CgProtection {
    param([string[]]$Skip = @())
    $fixed = @()
    foreach ($p in (Get-CgProtectParts)) {
        if (-not $p.Heal -or $Skip -contains $p.Key) { continue }
        $v = $null
        try { $v = & $p.Test } catch { }
        if ($v -eq $true) { continue }
        $ok = $false
        try { $ok = [bool](& $p.Heal) } catch { $ok = $false }
        $fixed += [PSCustomObject]@{ Key = $p.Key; Name = $p.Name; Was = $v; Ok = $ok }
    }
    return $fixed
}
