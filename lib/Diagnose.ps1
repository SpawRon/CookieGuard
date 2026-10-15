# ============================================================
#  CookieGuard - Diagnose.ps1
#  «Почему не включается» — проверка предпосылок.
#
#  Зачем. Включение аудита, журнала запусков и сторожа опирается
#  на механизмы Windows, которых на конкретной машине может не
#  быть или которые могут быть перекрыты политикой. Раньше в
#  таком случае окно писало «завершено» и ничего не менялось:
#  человек видел, что ничего не работает, и не мог узнать почему.
#
#  Молчаливый отказ хуже честной ошибки. Здесь каждая проверка
#  отвечает тремя вещами: что проверяли, что нашли и что с этим
#  делать. Ничего не чинится само — только называется причина.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

function New-CgDiag {
    param(
        [ValidateSet('OK', 'WARN', 'CRIT', 'INFO')] [string]$Severity,
        [string]$Name,
        [string]$Value,
        [string]$Fix = ''
    )
    return [PSCustomObject]@{
        Severity = $Severity; Name = $Name; Value = $Value; Fix = $Fix
        Title = $Name; Path = ''; Hash = ''; Query = $Name
        Detail = "Проверка: $Name`nРезультат: $Value" + $(if ($Fix) { "`n`nЧто делать: $Fix" } else { '' })
    }
}

# ------------------------------------------------------------
#  Подкатегория аудита: включена ли на самом деле
#
#  Разбор ответа auditpol живёт в Core.ps1 — им пользуется и
#  проверка состояния на главной странице. Здесь только то, что
#  нужно самому разбору.
# ------------------------------------------------------------

function Invoke-CgDiagnose {
    $d = @()

    # ---- 1. права ----
    if (Test-CgAdmin) {
        $d += New-CgDiag 'OK' 'Права администратора' 'есть'
    } else {
        $d += New-CgDiag 'CRIT' 'Права администратора' 'нет' (
            'Аудит, журнал запусков и сторож меняют настройки Windows и без прав администратора ' +
            'включиться не могут. Закройте окно и запустите CookieGuard.exe (он запросит повышение), ' +
            'либо правой кнопкой по ярлыку — «Запуск от имени администратора».')
    }

    # ---- 2. auditpol вообще работает ----
    $fsGuid = '{0CCE921D-69AE-11D9-BED3-505054503030}'
    $pcGuid = '{0CCE922B-69AE-11D9-BED3-505054503030}'
    $fs = Get-CgAuditPolState $fsGuid
    if (-not $fs.Ok) {
        $d += New-CgDiag 'CRIT' 'Средство auditpol' 'не отвечает' (
            "Windows не дала опросить политику аудита: $($fs.Text)`n" +
            'Без auditpol включить аудит доступа к файлам нельзя. Такое бывает на сильно урезанных ' +
            'сборках Windows и в системах под управлением организации.')
    } else {
        $d += New-CgDiag 'OK' 'Средство auditpol' 'работает'
        if ($fs.Enabled) {
            $d += New-CgDiag 'OK' 'Политика аудита файловой системы' "включена ($($fs.Text))"
        } else {
            $d += New-CgDiag 'WARN' 'Политика аудита файловой системы' 'выключена' (
                'Это и включает переключатель «Аудит доступа к cookie». Если после включения ' +
                'проверка снова показывает «выключена» — политику перекрывает групповая политика, смотрите следующий пункт.')
        }
        $pc = Get-CgAuditPolState $pcGuid
        if ($pc.Enabled) {
            $d += New-CgDiag 'OK' 'Аудит запуска программ' "включён ($($pc.Text))"
        } else {
            $d += New-CgDiag 'INFO' 'Аудит запуска программ' 'выключен' 'Включается кнопкой «Журнал запуска программ» в разделе «Защита».'
        }
    }

    # ---- 3. групповая политика поверх ----
    #
    # Если домен или локальная политика задаёт аудит, настройки
    # auditpol откатываются при следующем обновлении политики —
    # и человек видит, что включённое само выключилось.
    $gp = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'SCENoApplyLegacyAuditPolicy' -ErrorAction SilentlyContinue
    $gpAudit = Test-Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Safer\CodeIdentifiers'
    $auditPol = 'C:\Windows\System32\GroupPolicy\Machine\Microsoft\Windows NT\Audit\audit.csv'
    if (Test-Path -LiteralPath $auditPol) {
        $d += New-CgDiag 'WARN' 'Групповая политика аудита' 'задана на этом компьютере' (
            "Файл: $auditPol`n" +
            'Политика перезапишет настройки аудита при очередном обновлении (gpupdate, перезагрузка). ' +
            'Если компьютер ваш — удалите этот файл или задайте аудит через «Локальная политика безопасности» ' +
            '(secpol.msc → Конфигурация расширенной политики аудита → Доступ к объектам → Аудит файловой системы).')
    } else {
        $d += New-CgDiag 'OK' 'Групповая политика аудита' 'не перекрывает настройки'
    }

    # ---- 4. есть ли за чем следить ----
    $targets = @(Get-CgTargetFiles)
    if ($targets.Count) {
        $brs = @(Get-CgBrowsers)
        $d += New-CgDiag 'OK' 'Файлы браузеров' ("найдено {0} в браузерах: {1}" -f $targets.Count, (($brs | ForEach-Object { $_.Name }) -join ', '))
    } else {
        $d += New-CgDiag 'CRIT' 'Файлы браузеров' 'не найдено ни одного' (
            'Аудит ставится на конкретные файлы — Cookies, Login Data. Если браузер ни разу не запускали ' +
            'или он установлен не туда, где его ищет программа, ставить аудит не на что, и включение ' +
            'заканчивается ничем. Запустите браузер хотя бы раз и повторите.')
    }

    # ---- 5. журнал безопасности ----
    $sec = & wevtutil gl Security 2>&1
    if ($LASTEXITCODE -eq 0) {
        $max = @($sec | Where-Object { $_ -match 'maxSize' } | Select-Object -First 1)
        $mb = ''
        if ($max.Count -and $max[0] -match '(\d+)') { $mb = [int]([int64]$matches[1] / 1MB) }
        $d += New-CgDiag 'OK' 'Журнал безопасности' ("доступен, размер {0} МБ" -f $mb)
    } else {
        $d += New-CgDiag 'CRIT' 'Журнал безопасности' 'недоступен' (
            'Без журнала безопасности события аудита читать неоткуда. Проверьте, запущена ли служба ' +
            '«Журнал событий Windows» (EventLog).')
    }

    # ---- 6. планировщик: без него не будет сторожа ----
    $sch = Get-Service -Name 'Schedule' -ErrorAction SilentlyContinue
    if ($sch -and $sch.Status -eq 'Running') {
        $d += New-CgDiag 'OK' 'Планировщик заданий' 'работает'
    } else {
        $d += New-CgDiag 'CRIT' 'Планировщик заданий' ("состояние: {0}" -f $(if ($sch) { $sch.Status } else { 'служба не найдена' })) (
            'Постоянная защита — это две задачи планировщика. Пока служба «Планировщик заданий» не запущена, ' +
            'переключатель будет возвращаться в положение «выключено».')
    }

    # ---- 7. Defender ----
    try {
        $mp = Get-MpComputerStatus -ErrorAction Stop
        if ($mp.RealTimeProtectionEnabled) {
            $d += New-CgDiag 'OK' 'Защита Windows в реальном времени' ("работает, базам {0} дн." -f $mp.AntivirusSignatureAge)
        } else {
            $d += New-CgDiag 'CRIT' 'Защита Windows в реальном времени' 'выключена' (
                'CookieGuard её не включает и включить не может — это делается в «Безопасность Windows» → ' +
                '«Защита от вирусов и угроз» → «Управление настройками». Если переключатель там не поддаётся, ' +
                'смотрите следующий пункт про защиту от подделки, либо на компьютере стоит другой антивирус, ' +
                'который отключил Defender намеренно — это нормально.')
        }
        $tp = $null
        try { $tp = $mp.IsTamperProtected } catch { }
        if ($null -ne $tp) {
            if ($tp) {
                $d += New-CgDiag 'INFO' 'Защита от подделки Defender' 'включена' (
                    'Пока она включена, настройки Defender нельзя менять программно — только руками в ' +
                    '«Безопасность Windows». Это защита, а не неисправность.')
            } else {
                $d += New-CgDiag 'OK' 'Защита от подделки Defender' 'выключена'
            }
        }
    } catch {
        $d += New-CgDiag 'WARN' 'Защита Windows' 'опросить не удалось' (
            'Модуль Defender не отвечает. Обычно это значит, что установлен сторонний антивирус и Defender отключён.')
    }

    # ---- 8. политика выполнения сценариев ----
    $ep = Get-ExecutionPolicy
    if ($ep -in @('Restricted', 'AllSigned')) {
        $d += New-CgDiag 'WARN' 'Политика выполнения PowerShell' "$ep" (
            'Вспомогательные сценарии запускаются с ключом -ExecutionPolicy Bypass и этой политике не подчиняются, ' +
            'но если политику задаёт домен, запуск может быть заблокирован целиком.')
    } else {
        $d += New-CgDiag 'OK' 'Политика выполнения PowerShell' "$ep"
    }

    # ---- 9. куда писать данные ----
    $dataRoot = Get-CgDataRoot
    $probe = Join-Path $dataRoot ('.probe-' + [Guid]::NewGuid().ToString('N').Substring(0, 6))
    try {
        Set-Content -LiteralPath $probe -Value 'x' -ErrorAction Stop
        Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue
        $d += New-CgDiag 'OK' 'Папка данных' "доступна на запись: $dataRoot"
    } catch {
        $d += New-CgDiag 'CRIT' 'Папка данных' "нет записи: $dataRoot" (
            'Сюда пишутся эталон, список доверенных и карантин. Без записи почти ничего не сохранится. ' +
            'Запустите программу от имени администратора.')
    }

    return @($d)
}

# Короткая сводка одной строкой — для строки состояния.
function Get-CgDiagSummary {
    param($Diag)
    $c = @($Diag | Where-Object { $_.Severity -eq 'CRIT' }).Count
    $w = @($Diag | Where-Object { $_.Severity -eq 'WARN' }).Count
    if ($c) { return "мешает работе: $c, под вопросом: $w" }
    if ($w) { return "под вопросом: $w, непреодолимых помех нет" }
    return 'помех не найдено — всё необходимое на месте'
}
