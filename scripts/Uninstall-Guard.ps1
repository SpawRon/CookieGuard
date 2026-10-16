# ============================================================
#  CookieGuard - Uninstall-Guard.ps1
#  Снимает постоянного сторожа и наблюдателя, останавливает их.
# ============================================================

. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Core.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

if (-not (Test-CgAdmin)) {
    Write-Host 'Нужны права администратора.' -ForegroundColor Red
    exit 1
}

Write-CgHead 'Снятие постоянного сторожа'

foreach ($t in @('CookieGuard Watcher', 'CookieGuard Watchdog')) {
    try { Stop-ScheduledTask -TaskName $t -ErrorAction SilentlyContinue } catch { }
    try {
        Unregister-ScheduledTask -TaskName $t -Confirm:$false -ErrorAction Stop
        Write-CgItem 'OK' "Задача снята: $t"
    } catch {
        Write-CgItem 'NOTE' "Задача не найдена: $t"
    }
}

# завершаем работающие экземпляры сторожа
$stopped = 0
foreach ($p in (Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue)) {
    if ("$($p.CommandLine)" -match 'Guard-Service\.ps1') {
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop; $stopped++ } catch { }
    }
}
if ($stopped) { Write-CgItem 'OK' "Остановлено работающих сторожей: $stopped" }

Remove-Item -LiteralPath (Join-Path (Get-CgDir 'state') 'guard-heartbeat.txt') -Force -ErrorAction SilentlyContinue
Write-Host ''
Write-Host '  Сторож снят. Защита в реальном времени теперь работает только при открытом окне.' -ForegroundColor Green
Write-CgLog 'INFO' 'Постоянный сторож снят'
