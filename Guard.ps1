# ============================================================
#  CookieGuard - Guard.ps1
#  Консольный монитор. Движок — lib\Monitor.ps1, тот же,
#  что использует окно приложения.
# ============================================================

[CmdletBinding()]
param(
    [int]$IntervalMs = 1500,
    [switch]$Quiet,          # не показывать обычные обращения браузеров
    [switch]$NoProcWatch     # не следить за новыми процессами
)

. (Join-Path $PSScriptRoot 'lib\Core.ps1')
. (Join-Path $PSScriptRoot 'lib\Checks.ps1')
. (Join-Path $PSScriptRoot 'lib\Monitor.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$ErrorActionPreference = 'SilentlyContinue'

$state = New-CgMonitorState
$startTime = Get-Date

Clear-Host
Write-Host ''
Write-Host '   CookieGuard — наблюдение за доступом к cookie и паролям' -ForegroundColor Cyan
Write-Host ''
Write-Host ('   Под наблюдением файлов: {0}' -f $state.Targets.Count) -ForegroundColor Gray
Write-Host ('   Браузеры: {0}' -f ((Get-CgBrowsers | ForEach-Object { $_.Name }) -join ', ')) -ForegroundColor Gray
if ($state.AuditOn) {
    Write-Host '   Аудит доступа к файлам: ВКЛЮЧЁН' -ForegroundColor Green
} else {
    Write-Host '   Аудит доступа к файлам: ВЫКЛЮЧЕН' -ForegroundColor Red
    Write-Host '   -> запустите ENABLE-AUDIT.cmd, иначе не будет видно, кто открыл файл' -ForegroundColor Yellow
}
if (-not (Test-CgAdmin)) {
    Write-Host '   Права администратора: нет (часть сведений о процессах будет скрыта)' -ForegroundColor Yellow
}
Write-Host ''
Write-Host '   Q - выход    P - подозрительные процессы    C - очистить экран' -ForegroundColor DarkGray
Write-Host ('-' * 74) -ForegroundColor DarkCyan
Write-CgLog 'INFO' 'Консольный монитор запущен'

function Show-Event {
    param($E)
    if ($E.Severity -eq 'OK') {
        if (-not $Quiet) { Write-Host ('  {0}  {1}' -f $E.TimeText, $E.Title) -ForegroundColor DarkGray }
        return
    }
    if ($E.Severity -eq 'NOTE') {
        if (-not $Quiet) { Write-Host ('  {0}  {1}' -f $E.TimeText, $E.Title) -ForegroundColor DarkYellow }
        return
    }
    $col = 'Yellow'
    if ($E.Severity -eq 'CRIT') { $col = 'Red' }
    Write-Host ''
    Write-Host ('  +' + ('-' * 70)) -ForegroundColor $col
    Write-Host ('  | {0}  {1}' -f $E.TimeText, $E.Title) -ForegroundColor $col
    foreach ($l in ($E.Detail -split "`n")) { Write-Host ('  |   ' + $l.TrimEnd()) -ForegroundColor Gray }
    Write-Host ('  +' + ('-' * 70)) -ForegroundColor $col
    if ($E.Severity -eq 'CRIT') {
        try { [Console]::Beep(880, 200); [Console]::Beep(660, 300) } catch { }
    }
}

function Show-SuspiciousProcesses {
    Write-Host ''
    Write-Host '  Проверяю процессы (первый раз это занимает до минуты)...' -ForegroundColor DarkGray
    $all = Get-CgProcessList
    $bad = $all | Where-Object { $_.Risk -ge 14 } | Sort-Object Risk -Descending
    if (-not $bad) {
        Write-Host '    Ничего подозрительного среди запущенных процессов.' -ForegroundColor Green
    } else {
        foreach ($p in $bad) {
            Write-CgItem $p.Severity ('{0,-28} PID {1,-7} риск {2}' -f $p.Name, $p.Id, $p.Risk) ($p.Notes + "`n" + $p.Path)
        }
    }
    Write-Host ('  Всего процессов: {0}' -f $all.Count) -ForegroundColor DarkGray
    Write-Host ''
}

Show-SuspiciousProcesses
Write-Host '  ...наблюдаю. Тревоги будут появляться здесь.' -ForegroundColor DarkGray
Write-Host ''

# если ввод перенаправлен, клавиш нет — работаем без управления с клавиатуры
$canReadKeys = $true
try { $null = [Console]::KeyAvailable } catch { $canReadKeys = $false }
if (-not $canReadKeys) { Write-Host '  (консоль недоступна — остановка через Ctrl+C)' -ForegroundColor DarkGray }

$running = $true
while ($running) {
    if ($canReadKeys) {
        try {
            while ([Console]::KeyAvailable) {
                $k = [Console]::ReadKey($true)
                switch ("$($k.KeyChar)".ToUpperInvariant()) {
                    'Q' { $running = $false }
                    'P' { Show-SuspiciousProcesses }
                    'C' { Clear-Host; Write-Host '  CookieGuard — наблюдаю.' -ForegroundColor Cyan }
                }
            }
        } catch { $canReadKeys = $false }
    }
    if (-not $running) { break }

    foreach ($e in (Invoke-CgMonitorPoll $state -NoProcWatch:$NoProcWatch)) { Show-Event $e }

    Start-Sleep -Milliseconds $IntervalMs
}

Write-Host ''
Write-Host ('  Наблюдение остановлено. Время работы: {0:hh\:mm\:ss}. Критичных тревог: {1}' -f ((Get-Date) - $startTime), $state.Counters.Crit) -ForegroundColor Cyan
Write-Host ('  Журнал: {0}' -f (Get-CgDir 'logs')) -ForegroundColor DarkGray
Write-CgLog 'INFO' ("Консольный монитор остановлен, критичных: {0}" -f $state.Counters.Crit)
