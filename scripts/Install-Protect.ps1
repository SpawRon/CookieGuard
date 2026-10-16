# ============================================================
#  CookieGuard - Install-Protect.ps1
#  Автозащита целиком, одним действием:
#    — аудит доступа к базам cookie и паролей всех профилей;
#    — журнал запуска программ с командной строкой;
#    — аудит записи в hosts и запомненная копия файла;
#    — журнал безопасности 256 МБ;
#    — сторож от SYSTEM при старте Windows и наблюдатель за ним.
#  Выбор запоминается в state\settings.json. Дальше сторож раз в
#  минуту проверяет каждую часть и включает обратно то, что выключили.
#  Требуются права администратора.
# ============================================================

[CmdletBinding()]
param([switch]$AutoNeutralize)

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Core.ps1')
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Checks.ps1')
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Protect.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

if (-not (Test-CgAdmin)) {
    Write-Host 'Нужны права администратора.' -ForegroundColor Red
    exit 1
}

Write-CgHead 'Включение автозащиты'

# Программа во временной папке: задача переживёт перезагрузку, папка — нет
if ($PSScriptRoot -match '(?i)\\Temp\\|\\scratch-workspaces\\|\\AppData\\Local\\Temp') {
    Write-CgItem 'CRIT' 'Программа лежит во временной папке' "$PSScriptRoot`n`nПеренесите CookieGuard в постоянное место (лучше — установите в Program Files) и включите автозащиту оттуда."
    exit 2
}

$null = Set-CgSetting 'AutoProtect' $true
$null = Set-CgSetting 'AutoNeutralize' ([bool]$AutoNeutralize)

$failCore = 0
foreach ($p in (Get-CgProtectParts)) {
    if (-not $p.Heal) { continue }
    $v = $null
    try { $v = & $p.Test } catch { }
    if ($v -eq $true) { Write-CgItem 'OK' "$($p.Name) — уже включено"; continue }
    $ok = $false
    try { $ok = [bool](& $p.Heal) } catch { }
    if ($ok) { Write-CgItem 'OK' $p.Name }
    else {
        Write-CgItem $(if ($p.Core) { 'CRIT' } else { 'WARN' }) "Не удалось: $($p.Name)" $p.Why
        if ($p.Core) { $failCore++ }
    }
}

# Копия hosts: с этого момента любое изменение будет видно,
# даже сделанное, пока программа не работала
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Hosts.ps1')
if ($null -eq (Get-CgHostsSnapshot)) {
    $t = Read-CgHostsText
    if ($null -ne $t -and (Save-CgHostsSnapshot $t)) { Write-CgItem 'OK' 'Копия hosts запомнена' }
}

# Сторож и наблюдатель
try {
    Register-CgGuardTask -AutoNeutralize:$AutoNeutralize
    Write-CgItem 'OK' 'Сторож стартует вместе с Windows (от SYSTEM)'
} catch {
    Write-CgItem 'CRIT' 'Не удалось создать задачу сторожа' $_.Exception.Message
    $failCore++
}
try {
    Register-CgWatchdogTask
    Write-CgItem 'OK' 'Наблюдатель поднимает сторожа, если его убили'
} catch {
    Write-CgItem 'CRIT' 'Не удалось создать наблюдателя' $_.Exception.Message
    $failCore++
}
if (Restart-CgGuard) { Write-CgItem 'OK' 'Сторож запущен' }
else { Write-CgItem 'WARN' 'Сторож сразу не запустился — его поднимет наблюдатель в течение минуты' }

Write-Host ''
if ($failCore) {
    Write-Host "  Автозащита включена не полностью: не получилось частей — $failCore." -ForegroundColor Red
    exit 1
}
Write-Host '  Автозащита включена. Она помнит это после перезагрузки и обновления' -ForegroundColor Green
Write-Host '  и сама включает обратно то, что кто-то выключил.' -ForegroundColor Green
exit 0
