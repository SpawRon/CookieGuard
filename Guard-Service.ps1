# ============================================================
#  CookieGuard - Guard-Service.ps1
#  Головной сторож. Работает без окна, запускается при старте
#  Windows от SYSTEM, пишет тревоги в журнал и показывает
#  всплывающие уведомления.
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

Write-CgLog 'INFO' ("Сторож запущен (PID $PID, AutoNeutralize=$AutoNeutralize)")

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
# ------------------------------------------------------------
$script:LastDefenderOk = $true
$script:LastAuditOk = $true

function Watch-Defenses {
    # аудит доступа к cookie
    $auditNow = Test-CgAuditEnabled
    if (-not $auditNow -and $script:LastAuditOk) {
        Write-CgLog 'CRIT' 'Аудит доступа к файлам cookie был ВЫКЛЮЧЕН'
        Show-CgToast 'CookieGuard' 'Аудит доступа к cookie выключили. Поднимаю обратно.' 'CRIT'
        # поднимаем обратно — это и есть ответ на "вирус отключит защиту"
        $ap = Join-Path $root 'Install-Audit.ps1'
        if (Test-Path $ap) { & powershell -NoProfile -ExecutionPolicy Bypass -File "$ap" 2>&1 | Out-Null }
    }
    $script:LastAuditOk = $auditNow

    # защита Windows
    try {
        $st = Get-MpComputerStatus -ErrorAction Stop
        $defOk = $st.RealTimeProtectionEnabled
        if (-not $defOk -and $script:LastDefenderOk) {
            Write-CgLog 'CRIT' 'Защита Windows в реальном времени была ВЫКЛЮЧЕНА'
            Show-CgToast 'CookieGuard' 'Кто-то выключил защиту Windows в реальном времени. Разберитесь немедленно.' 'CRIT'
        }
        $script:LastDefenderOk = $defOk
    } catch { }
}

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
$state = New-CgMonitorState
$lastWatch = (Get-Date).AddMinutes(-1)

while ($true) {
    try {
        foreach ($e in (Invoke-CgMonitorPoll $state)) {
            if ($e.Severity -in @('CRIT', 'WARN')) {
                Show-CgToast ('CookieGuard: ' + $e.Kind) $e.Title $e.Severity
            }
            Try-AutoNeutralize $e
        }
    } catch {
        Write-CgLog 'WARN' ("Сбой в цикле сторожа: $($_.Exception.Message)")
    }

    if (((Get-Date) - $lastWatch).TotalSeconds -ge 20) {
        Watch-Defenses
        $lastWatch = Get-Date
        # отметка "я жив" — по ней watchdog понимает, что сторож работает
        try { [IO.File]::WriteAllText((Join-Path (Get-CgDir 'state') 'guard-heartbeat.txt'), (Get-Date).ToString('o'), [Text.UTF8Encoding]::new($false)) } catch { }
    }

    Start-Sleep -Milliseconds $IntervalMs
}
