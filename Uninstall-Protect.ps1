# ============================================================
#  CookieGuard - Uninstall-Protect.ps1
#  Выключает автозащиту: то же самое, что она включала, в обратном
#  порядке. Сначала запоминается «выключено» — иначе сторож успел
#  бы включить всё обратно, пока мы снимаем части.
#  Журналы, улики, копия hosts и доверенные остаются на месте.
#  Требуются права администратора.
# ============================================================

. (Join-Path $PSScriptRoot 'lib\Core.ps1')
. (Join-Path $PSScriptRoot 'lib\Protect.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

if (-not (Test-CgAdmin)) {
    Write-Host 'Нужны права администратора.' -ForegroundColor Red
    exit 1
}

Write-CgHead 'Выключение автозащиты'

$null = Set-CgSetting 'AutoProtect' $false
Write-CgItem 'OK' 'Автозащита больше не включает части обратно'

& (Join-Path $PSScriptRoot 'Uninstall-Guard.ps1')
& (Join-Path $PSScriptRoot 'Uninstall-Audit.ps1')

if (Set-CgHostsAudit -Remove) { Write-CgItem 'OK' 'Аудит записи в hosts снят' }
else { Write-CgItem 'NOTE' 'Аудит записи в hosts снять не удалось (или его не было)' }

& auditpol /set /subcategory:$script:CgGuidProc /success:disable 2>&1 | Out-Null
try { Remove-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit' -Name 'ProcessCreationIncludeCmdLine_Enabled' -ErrorAction SilentlyContinue } catch { }
Write-CgItem 'OK' 'Журнал запуска программ выключен'

Write-CgLog 'INFO' 'Автозащита выключена'
Write-Host ''
Write-Host '  Автозащита выключена. Журналы и улики сохранены.' -ForegroundColor Green
exit 0
