# ============================================================
#  CookieGuard - Scan.ps1
#  Консольная версия глубокой проверки.
#  Вся логика живёт в lib\Checks.ps1 — здесь только вывод.
#  Окно (CookieGuard.ps1) использует тот же движок.
# ============================================================

[CmdletBinding()]
param([switch]$NoTranscript)

. (Join-Path $PSScriptRoot 'lib\Core.ps1')
. (Join-Path $PSScriptRoot 'lib\Checks.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }
$ErrorActionPreference = 'SilentlyContinue'

$reportDir = Get-CgDir 'reports'
$reportFile = Join-Path $reportDir ('scan-{0}.txt' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
if (-not $NoTranscript) { Start-Transcript -LiteralPath $reportFile -Force | Out-Null }

Write-Host ''
Write-Host '  CookieGuard — глубокая проверка' -ForegroundColor Cyan
Write-Host ('  {0}   компьютер: {1}   пользователь: {2}' -f (Get-Date -Format 'dd.MM.yyyy HH:mm'), $env:COMPUTERNAME, $env:USERNAME) -ForegroundColor DarkGray
if (-not (Test-CgAdmin)) {
    Write-Host '  ВНИМАНИЕ: запущено без прав администратора — часть проверок будет пропущена.' -ForegroundColor Yellow
}

$findings = Invoke-CgFullScan -Progress {
    param($t)
    if ($t -ne 'Готово') { Write-Host ("  ... $t") -ForegroundColor DarkGray }
}

# порядок разделов как в отчёте
$areaOrder = @('Defender', 'Брандмауэр', 'Прокси', 'hosts', 'Сертификаты', 'DNS',
               'Автозапуск', 'WMI', 'Процессы', 'Сеть', 'Расширения', 'Adobe', 'Копии', 'Права',
               'Новые файлы', 'Аудит')
$seen = @{}
foreach ($area in ($areaOrder + @($findings | ForEach-Object { $_.Area }))) {
    if ($seen.ContainsKey($area)) { continue }
    $seen[$area] = $true
    $items = @($findings | Where-Object { $_.Area -eq $area })
    if (-not $items.Count) { continue }
    Write-CgHead $area
    foreach ($x in ($items | Sort-Object Order)) {
        Write-CgItem $x.Severity $x.Title $x.Detail
    }
}

Write-CgHead 'ИТОГ'
$crit = @($findings | Where-Object { $_.Severity -eq 'CRIT' })
$warn = @($findings | Where-Object { $_.Severity -eq 'WARN' })
$note = @($findings | Where-Object { $_.Severity -eq 'NOTE' })

Write-Host ''
Write-Host ('   Критично : {0}' -f $crit.Count) -ForegroundColor $(if ($crit.Count) { 'Red' } else { 'Green' })
Write-Host ('   Внимание : {0}' -f $warn.Count) -ForegroundColor $(if ($warn.Count) { 'Yellow' } else { 'Green' })
Write-Host ('   Заметки  : {0}' -f $note.Count) -ForegroundColor DarkYellow
Write-Host ''

if ($crit.Count) {
    Write-Host '   Требует разбирательства:' -ForegroundColor Red
    foreach ($f in $crit) { Write-Host ('     - [{0}] {1}' -f $f.Area, $f.Title) -ForegroundColor Red }
    Write-Host ''
}
if ($warn.Count) {
    Write-Host '   Стоит посмотреть:' -ForegroundColor Yellow
    foreach ($f in $warn) { Write-Host ('     - [{0}] {1}' -f $f.Area, $f.Title) -ForegroundColor Yellow }
    Write-Host ''
}

Write-Host '   Важно: это не антивирус. Находки выше — это НЕОБЫЧНОЕ,' -ForegroundColor Gray
Write-Host '   а не обязательно вредоносное. Разбирать нужно каждую по отдельности.' -ForegroundColor Gray
Write-Host ''
Write-CgLog 'INFO' ("Проверка из консоли: CRIT={0} WARN={1}" -f $crit.Count, $warn.Count)

if (-not $NoTranscript) {
    Stop-Transcript | Out-Null
    Write-Host ('   Отчёт сохранён: {0}' -f $reportFile) -ForegroundColor Cyan
}
