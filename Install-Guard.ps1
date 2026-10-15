# ============================================================
#  CookieGuard - Install-Guard.ps1
#  Ставит постоянного сторожа: запуск при старте Windows от SYSTEM
#  плюс сторож-наблюдатель, который поднимает его обратно, если
#  сторожа убили.
#
#  Честно о пределе. Это userland-программа. Задача запускается
#  рано (при старте системы, от SYSTEM) и перезапускается, если её
#  завершили, — но «раньше Windows» в смысле ядра грузится только
#  ELAM-драйвер, подписанный Microsoft. Настоящую неубиваемость
#  (protected process) даёт тоже только подписанный драйвер. Это
#  требует сертификата и процедуры подписи, которых у самодельной
#  программы нет. Поэтому: от обычного завершения и от «тихо убить
#  и спрятаться» эта схема защищает. От противника, уже имеющего
#  права SYSTEM и готового целенаправленно её сносить, — нет.
#  Честнее так, чем обещать защиту, которой нет.
#
#   -AutoNeutralize   передаётся сторожу: авто-карантин для файлов,
#                     подтверждённых VirusTotal (>= 5 детектов).
# ============================================================

[CmdletBinding()]
param([switch]$AutoNeutralize)

. (Join-Path $PSScriptRoot 'lib\Core.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

if (-not (Test-CgAdmin)) {
    Write-Host 'Нужны права администратора.' -ForegroundColor Red
    exit 1
}

Write-CgHead 'Установка постоянного сторожа'

# Задача автозапуска переживает перезагрузку, а временная папка — нет.
# Если программа лежит во временном расположении, сторож после перезагрузки
# будет указывать в пустоту: значок «защита включена» останется, а защиты
# не будет. Это опаснее, чем честное «не установлено».
$tempish = $PSScriptRoot -match '(?i)\\Temp\\|\\scratch-workspaces\\|\\AppData\\Local\\Temp'
if ($tempish) {
    Write-CgItem 'CRIT' 'Программа лежит во временной папке' (
        "$PSScriptRoot`n`nЭту папку система (или приложение) может удалить. Задача автозапуска переживёт перезагрузку, а папка — нет: сторож будет запускаться в никуда, а окно показывать «защита включена».`n`nПеренесите папку CookieGuard в постоянное место (например, C:\Program Files\CookieGuard или C:\Users\<вы>\CookieGuard) и включите защиту оттуда."
    )
    Write-Host ''
    Write-Host '  Установка прервана. Это защита от ложного чувства безопасности.' -ForegroundColor Red
    exit 2
}

$guardPs    = Join-Path $PSScriptRoot 'Guard-Service.ps1'
$watchdogPs = Join-Path $PSScriptRoot 'Watchdog.ps1'
$psExe      = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'

$guardArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$guardPs`""
if ($AutoNeutralize) { $guardArgs += ' -AutoNeutralize' }

$taskGuard = 'CookieGuard Watcher'
$taskDog   = 'CookieGuard Watchdog'

# --- 1. основной сторож: при старте системы, от SYSTEM, с перезапуском ---
try {
    # WorkingDirectory не задаём намеренно: планировщик от SYSTEM отвергает
    # некоторые пользовательские пути с ошибкой 0x8007010B («неверное имя
    # каталога»), а скрипту он и не нужен — внутри всё через $PSScriptRoot.
    $action  = New-ScheduledTaskAction -Execute $psExe -Argument $guardArgs
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                  -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) `
                  -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
    Register-ScheduledTask -TaskName $taskGuard -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-CgItem 'OK' 'Сторож будет запускаться при старте Windows (от SYSTEM) и перезапускаться, если его завершат'
} catch {
    Write-CgItem 'CRIT' 'Не удалось создать задачу сторожа' $_.Exception.Message
    exit 1
}

# --- 2. наблюдатель: раз в минуту поднимает сторожа, если сердцебиение пропало ---
try {
    $dogArgs = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdogPs`""
    $action2  = New-ScheduledTaskAction -Execute $psExe -Argument $dogArgs
    $trigger2 = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1) -RepetitionDuration ([TimeSpan]::MaxValue)
    $principal2 = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings2 = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    Register-ScheduledTask -TaskName $taskDog -Action $action2 -Trigger $trigger2 -Principal $principal2 -Settings $settings2 -Force | Out-Null
    Write-CgItem 'OK' 'Наблюдатель будет раз в минуту проверять, жив ли сторож, и поднимать его'
} catch {
    Write-CgItem 'WARN' 'Не удалось создать наблюдателя (сторож всё равно работает)' $_.Exception.Message
}

# --- 3. запускаем сторожа прямо сейчас ---
try { Start-ScheduledTask -TaskName $taskGuard; Write-CgItem 'OK' 'Сторож запущен' } catch { }

Write-Host ''
Write-Host '  Готово. Сторож работает в фоне и переживёт перезагрузку.' -ForegroundColor Green
Write-Host '  Тревоги — во всплывающих уведомлениях и в журнале.' -ForegroundColor Green
Write-Host '  Снять сторожа: Uninstall-Guard.ps1 (или кнопка в окне).' -ForegroundColor DarkGray
