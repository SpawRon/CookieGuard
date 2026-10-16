# ============================================================
#  CookieGuard - Install-ProcAudit.ps1
#  Включает журнал запуска программ (событие 4688) вместе с
#  командной строкой. После этого любое мелькнувшее окно можно
#  опознать: что именно запустилось, с какими аргументами и кто
#  его породил.
#  Требуются права администратора.
# ============================================================

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Core.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

if (-not (Test-CgAdmin)) {
    Write-Host 'Нужны права администратора.' -ForegroundColor Red
    exit 1
}

Write-CgHead 'Включение журнала запуска программ'

# Подкатегория "Process Creation" — GUID не зависит от языка системы
$pcGuid = '{0CCE922B-69AE-11D9-BED3-505054503030}'
$r = & auditpol /set /subcategory:$pcGuid /success:enable 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-CgItem 'OK' 'Windows теперь записывает каждый запуск программы (событие 4688)'
} else {
    Write-CgItem 'CRIT' 'Не удалось включить аудит запуска процессов' ($r -join ' ')
    exit 1
}

# Без этого в событии не будет командной строки — а она и есть самое важное
$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
try {
    if (-not (Test-Path $k)) { New-Item -Path $k -Force | Out-Null }
    New-ItemProperty -Path $k -Name 'ProcessCreationIncludeCmdLine_Enabled' -Value 1 -PropertyType DWord -Force | Out-Null
    Write-CgItem 'OK' 'В записи будет попадать полная командная строка'
} catch {
    Write-CgItem 'WARN' 'Не удалось включить запись командной строки' $_.Exception.Message
}

Write-Host ''
Write-Host '  Готово. Теперь любое мелькнувшее окно можно опознать:' -ForegroundColor Green
Write-Host '  вкладка «Запуски» в окне CookieGuard покажет, что запускалось,' -ForegroundColor Green
Write-Host '  с какой командой и какая программа это вызвала.' -ForegroundColor Green
Write-Host ''
Write-Host '  Учтите: записей будет много — это нормально, Windows запускает' -ForegroundColor DarkGray
Write-Host '  десятки служебных программ в минуту. Фильтр в окне это разбирает.' -ForegroundColor DarkGray
