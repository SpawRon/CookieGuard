# ============================================================
#  CookieGuard - Guard-Service.ps1
#  Головной сторож. Работает без окна, запускается при старте
#  Windows от SYSTEM, пишет тревоги в журнал (logs\cookieguard-*.log
#  и летопись logs\events-*.jsonl, которую читает окно) и
#  показывает всплывающие уведомления.
#
#  Отдельно следит за тем, что чаще всего и ломают первым делом:
#  не выключили ли защиту Windows и наш аудит. Если выключили —
#  это само по себе тревога, а аудит он поднимает обратно.
#
#  Параметры:
#   -AutoNeutralize   автоматически отправлять в карантин файлы,
#                     которые VirusTotal уже подтвердил как вредные
#                     (>= 5 детектов). Высокий порог, чтобы не
#                     трогать чистое. По умолчанию выключено.
# ============================================================

[CmdletBinding()]
param(
    [switch]$AutoNeutralize,
    [int]$IntervalMs = 1500
)

$ErrorActionPreference = 'SilentlyContinue'
$root = $PSScriptRoot
. (Join-Path $root 'lib\Core.ps1')
. (Join-Path $root 'lib\Checks.ps1')
. (Join-Path $root 'lib\Trust.ps1')
. (Join-Path $root 'lib\Monitor.ps1')
. (Join-Path $root 'lib\Actions.ps1')
. (Join-Path $root 'lib\VirusTotal.ps1')
. (Join-Path $root 'lib\Hosts.ps1')
. (Join-Path $root 'lib\Protect.ps1')

# Один сторож на компьютер. Наблюдатель может запустить его в обход
# планировщика, и без этой проверки иногда работали двое: каждая
# тревога приходила дважды, а копию hosts правили наперегонки.
$script:GuardMutex = $null
try {
    $created = $false
    $script:GuardMutex = New-Object System.Threading.Mutex($true, 'Global\CookieGuardGuard', [ref]$created)
    if (-not $created) {
        if (-not $script:GuardMutex.WaitOne(0)) { exit 0 }
    }
} catch { }

$settings = Get-CgSettings
if (-not $AutoNeutralize -and $settings.AutoNeutralize) { $AutoNeutralize = $true }
Write-CgLog 'INFO' ("Сторож запущен (PID $PID, автозащита=$($settings.AutoProtect), AutoNeutralize=$AutoNeutralize, профилей: $(@(Get-CgUserProfiles).Count))")

# ------------------------------------------------------------
#  Всплывающие уведомления
# ------------------------------------------------------------
Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
$script:Tray = $null
try {
    $script:Tray = New-Object System.Windows.Forms.NotifyIcon
    $script:Tray.Icon = [System.Drawing.SystemIcons]::Shield
    $ico = Join-Path $PSScriptRoot 'CookieGuard.ico'
    if (Test-Path -LiteralPath $ico) { try { $script:Tray.Icon = New-Object System.Drawing.Icon $ico } catch { } }
    $script:Tray.Visible = $true
    $script:Tray.Text = 'CookieGuard — сторож'
} catch { }

function Show-CgToast {
    param([string]$Title, [string]$Text, [string]$Level = 'Warning')
    if (-not $script:Tray) { return }
    $ico = [System.Windows.Forms.ToolTipIcon]::Warning
    if ($Level -eq 'CRIT') { $ico = [System.Windows.Forms.ToolTipIcon]::Error }
    try { $script:Tray.ShowBalloonTip(8000, $Title, $Text, $ico) } catch { }
}

# ------------------------------------------------------------
#  Контроль состояния защиты
#
#  Раз в минуту: всё ли, что включено автозащитой, на месте. Что
#  выключили — включаем обратно и говорим об этом. Сторож работает
#  от SYSTEM, ему для этого не нужно ни окно, ни согласие UAC.
# ------------------------------------------------------------
$script:LastDefenderOk = $true
$script:LastAuditOk = $true
$script:HealFailedAt = @{}
$script:FirstWatch = $true

function Watch-Defenses {
    $s = Get-CgSettings
    if ($s.AutoProtect) {
        # Какие базы потеряли аудит, а какие просто новые — до починки
        $lostSacl = @()
        try { $g0 = Get-CgCookieAuditGaps; if ($g0.Missing.Count) { $lostSacl = @(Get-CgCookieAuditLost $g0.Missing) } } catch { }
        foreach ($f in (Repair-CgProtection)) {
            if ($f.Key -eq 'sacl' -and $f.Ok -and -not $lostSacl.Count) {
                Write-CgLog 'INFO' 'Под аудит взяты новые файлы браузеров (браузер пересохранил файл, новый профиль, ключ шифрования или приманка)'
                continue
            }
            if ($f.Ok) {
                # Первая проверка после запуска — это включение, а не
                # «кто-то выключил»: так бывает после обновления, когда
                # появилась новая часть. Тревога — только потом.
                $alarm = ($f.Was -eq $false -and -not $script:FirstWatch)
                $lvl = $(if ($alarm) { 'CRIT' } else { 'INFO' })
                $msg = $(if ($alarm) { "Было выключено и включено обратно: $($f.Name)" } else { "Включено: $($f.Name)" })
                if ($alarm -and $f.Key -eq 'sacl') { $msg += ' (аудит сняли с: ' + (($lostSacl | Select-Object -First 3) -join ', ') + ')' }
                Write-CgLog $lvl $msg
                Write-CgEventRecord (New-CgEvent $(if ($lvl -eq 'CRIT') { 'WARN' } else { 'INFO' }) 'Защита' $msg 'Автозащита сама вернула эту часть. Если её выключали не вы — это повод разобраться: вредоносы первым делом гасят наблюдение.') 'guard'
                if ($alarm) { Show-CgToast 'CookieGuard' $msg 'CRIT' }
                $script:HealFailedAt.Remove($f.Key)
            } else {
                # Неудачу пишем раз в час, а не каждую минуту
                $last = $script:HealFailedAt[$f.Key]
                if (-not $last -or ((Get-Date) - $last).TotalMinutes -ge 60) {
                    Write-CgLog 'WARN' "Не удалось включить: $($f.Name)"
                    $script:HealFailedAt[$f.Key] = Get-Date
                }
            }
        }
    } else {
        # Автозащита не включалась — прежнее поведение: только аудит cookie
        # $null — не удалось спросить auditpol; это не «выключили»
        $auditNow = Test-CgFsAuditOn
        if ($null -ne $auditNow) {
            if (-not $auditNow -and $script:LastAuditOk) {
                Write-CgLog 'CRIT' 'Аудит доступа к файлам cookie был ВЫКЛЮЧЕН'
                Show-CgToast 'CookieGuard' 'Аудит доступа к cookie выключили. Поднимаю обратно.' 'CRIT'
                $null = Enable-CgFsAudit
            }
            $script:LastAuditOk = $auditNow
        }
    }

    $script:FirstWatch = $false

    # Защита Windows. Defender в запасе при работающем стороннем
    # антивирусе (у вас — ESET) — штатное состояние, а не тревога.
    # Раньше сторож кричал «защиту ВЫКЛЮЧИЛИ» при каждом старте.
    try {
        $st = Get-MpComputerStatus -ErrorAction Stop
        $defOk = [bool]$st.RealTimeProtectionEnabled
        if (-not $defOk) { $defOk = [bool](@(Get-CgOtherAntivirus | Where-Object { $_.Active }).Count) }
        if (-not $defOk -and $script:LastDefenderOk) {
            Write-CgLog 'CRIT' 'Защита в реальном времени ВЫКЛЮЧЕНА: Defender выключен и другого работающего антивируса нет'
            Show-CgToast 'CookieGuard' 'Защиту в реальном времени выключили, и другого антивируса нет. Разберитесь немедленно.' 'CRIT'
        }
        $script:LastDefenderOk = $defOk
    } catch { }
}

# Обновление заменило код — работать дальше на старом нельзя: новая
# защита появилась бы только после перезагрузки. Сторож выходит,
# наблюдатель (или окно, поставившее обновление) поднимает его снова.
# Метка кода — Get-CgCodeStamp из Protect.ps1.

# ------------------------------------------------------------
#  Автообезвреживание — только для подтверждённо вредного
# ------------------------------------------------------------
function Try-AutoNeutralize {
    param($Event)
    if (-not $AutoNeutralize) { return }
    if ($Event.Severity -ne 'CRIT') { return }
    if (-not $Event.Path) { return }
    $hash = $Event.Hash
    if (-not $hash) { $hash = Get-CgHash $Event.Path }
    if (-not $hash) { return }

    # Решение не наше — его выносит VirusTotal. Порог высокий,
    # чтобы автоматически трогать только то, что много движков
    # уже назвали вредоносным.
    $cache = Get-CgVtCache
    $v = $cache[$hash]
    if (-not $v -or $v.Status -ne 'known' -or [int]$v.Malicious -lt 5) { return }

    $r = Invoke-CgNeutralize -ProcId $Event.ProcId -Path $Event.Path -Reason "авто: VirusTotal $($v.Malicious) детектов" -Hash $hash
    Write-CgLog 'CRIT' ("АВТООБЕЗВРЕЖИВАНИЕ: $($Event.Path) — $($r.Message)")
    Show-CgToast 'CookieGuard обезвредил угрозу' ("$(Split-Path -Leaf $Event.Path): $($r.Message)") 'CRIT'
}

# ------------------------------------------------------------
#  Главный цикл
# ------------------------------------------------------------
$hbPath = Get-CgHeartbeatPath
$codeStamp = Get-CgCodeStamp
function Write-CgHeartbeat {
    $t = '{0}|v2|{1}|{2}' -f (Get-Date).ToString('o'), $PID, $codeStamp
    try { [IO.File]::WriteAllText($hbPath, $t, [Text.UTF8Encoding]::new($false)) } catch { }
}
Write-CgHeartbeat

$state = New-CgMonitorState -Persist
$lastWatch = (Get-Date).AddMinutes(-5)
$lastBeat = Get-Date
$lastCode = Get-Date

while ($true) {
    try {
        foreach ($e in (Invoke-CgMonitorPoll $state -Source 'guard')) {
            if ($e.Severity -in @('CRIT', 'WARN')) {
                Show-CgToast ('CookieGuard: ' + $e.Kind) $e.Title $e.Severity
            }
            Try-AutoNeutralize $e
        }
    } catch {
        Write-CgLog 'WARN' ("Сбой в цикле сторожа: $($_.Exception.Message)")
    }

    # отметка "я жив" — по ней наблюдатель и окно понимают, что сторож работает
    if (((Get-Date) - $lastBeat).TotalSeconds -ge 20) { Write-CgHeartbeat; $lastBeat = Get-Date }

    if (((Get-Date) - $lastWatch).TotalSeconds -ge 60) {
        try { Watch-Defenses } catch { Write-CgLog 'WARN' ("Сбой проверки защиты: $($_.Exception.Message)") }
        $lastWatch = Get-Date
        Write-CgHeartbeat; $lastBeat = Get-Date
    }

    if (((Get-Date) - $lastCode).TotalSeconds -ge 30) {
        $lastCode = Get-Date
        if ((Get-CgCodeStamp) -gt $codeStamp) {
            Write-CgLog 'INFO' 'Код программы обновлён — сторож перезапускается на новой версии'
            # Без отметки «жив» наблюдатель поднимет сторожа в течение минуты
            Remove-Item -LiteralPath $hbPath -Force -ErrorAction SilentlyContinue
            try { if ($script:GuardMutex) { $script:GuardMutex.ReleaseMutex() } } catch { }
            exit 0
        }
    }

    Start-Sleep -Milliseconds $IntervalMs
}
