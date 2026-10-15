# ============================================================
#  CookieGuard - Uninstall.ps1
#  Полное удаление: снимает защиту, возвращает системные
#  настройки, убирает ярлыки и файлы.
#
#  Данные (журналы, улики, карантин) по умолчанию СОХРАНЯЮТСЯ:
#  удалять улики вместе с программой — плохая идея, они могут
#  понадобиться. Удалить их можно ключом -RemoveData.
# ============================================================

[CmdletBinding()]
param([switch]$RemoveData, [switch]$Quiet)

$ErrorActionPreference = 'SilentlyContinue'
$here = $PSScriptRoot
. (Join-Path $here 'lib\Core.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

if (-not (Test-CgAdmin)) {
    Write-Host 'Нужны права администратора.' -ForegroundColor Red
    exit 1
}

Write-CgHead 'Удаление CookieGuard'

# ---- 1. снять постоянную защиту ----
$ug = Join-Path $here 'Uninstall-Guard.ps1'
if (Test-Path -LiteralPath $ug) { & $ug | Out-Null }
Write-CgItem 'OK' 'Постоянная защита снята'

# ---- 2. вернуть системные настройки, которые мы меняли ----
$ua = Join-Path $here 'Uninstall-Audit.ps1'
if (Test-Path -LiteralPath $ua) { & $ua | Out-Null }
Write-CgItem 'OK' 'Аудит доступа к файлам выключен'

try {
    . (Join-Path $here 'lib\SafeDns.ps1')
    if (Test-CgSafeDnsOn) {
        $null = Reset-CgSafeDns
        Write-CgItem 'OK' 'DNS возвращён к прежним настройкам'
    }
} catch { }

# ---- 3. закрыть работающие окна ----
foreach ($p in (Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue)) {
    if ("$($p.CommandLine)" -match 'CookieGuard\.ps1|Guard-Service\.ps1') {
        try { Stop-Process -Id $p.ProcessId -Force } catch { }
    }
}

# ---- 4. ярлыки и запись в списке программ ----
foreach ($lnk in @(
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs\CookieGuard.lnk'),
    (Join-Path ([Environment]::GetFolderPath('CommonDesktopDirectory')) 'CookieGuard.lnk'),
    (Join-Path ([Environment]::GetFolderPath('Desktop')) 'CookieGuard.lnk'))) {
    if (Test-Path -LiteralPath $lnk) { Remove-Item -LiteralPath $lnk -Force }
}
Remove-Item -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\CookieGuard' -Recurse -Force -ErrorAction SilentlyContinue
Write-CgItem 'OK' 'Ярлыки и запись в списке программ удалены'

# ---- 5. данные ----
$dataDir = Join-Path $env:ProgramData 'CookieGuard'
if ($RemoveData) {
    if (Test-Path -LiteralPath $dataDir) {
        Remove-Item -LiteralPath $dataDir -Recurse -Force
        Write-CgItem 'OK' 'Данные удалены'
    }
} else {
    if (Test-Path -LiteralPath $dataDir) {
        Write-CgItem 'NOTE' 'Данные сохранены' "$dataDir`nЗдесь остались журналы, отчёты, улики и карантин. Удалите папку вручную, если они не нужны."
    }
}

# ---- 6. сами файлы программы ----
# Себя удалить нельзя, пока работаем, поэтому чистку доделывает
# отдельная короткая команда уже после нашего выхода.
$inProgramFiles = $here -match '(?i)^[A-Z]:\\Program Files'
if ($inProgramFiles) {
    $cmd = "Start-Sleep -Seconds 2; Remove-Item -LiteralPath '$here' -Recurse -Force -ErrorAction SilentlyContinue"
    Start-Process powershell -ArgumentList '-NoProfile', '-WindowStyle', 'Hidden', '-Command', $cmd -WindowStyle Hidden
    Write-CgItem 'OK' 'Файлы программы будут удалены через пару секунд'
} else {
    Write-CgItem 'NOTE' 'Папка программы оставлена' "$here`nЭто не установленная копия, удалите её вручную, если нужно."
}

Write-Host ''
Write-Host '  CookieGuard удалён. Система возвращена в исходное состояние.' -ForegroundColor Green
Write-Host ''
if (-not $Quiet) { Start-Sleep -Seconds 3 }
