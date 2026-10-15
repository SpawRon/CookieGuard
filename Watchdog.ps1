# ============================================================
#  CookieGuard - Watchdog.ps1
#  Наблюдатель. Раз в минуту проверяет сердцебиение сторожа
#  и, если оно пропало, запускает сторожа заново.
#  Намеренно простой и быстрый — отработал и вышел.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path $PSScriptRoot 'lib\Core.ps1')

$hb = Join-Path (Get-CgDir 'state') 'guard-heartbeat.txt'
$alive = $false
if (Test-Path -LiteralPath $hb) {
    try {
        $t = [datetime]::Parse((Get-Content -LiteralPath $hb -Raw))
        if (((Get-Date) - $t).TotalSeconds -lt 90) { $alive = $true }
    } catch { }
}

if ($alive) { return }

Write-CgLog 'WARN' 'Watchdog: сердцебиение сторожа пропало — поднимаю сторожа'
try {
    Start-ScheduledTask -TaskName 'CookieGuard Watcher'
} catch {
    # запасной путь, если задачу сняли: запускаем напрямую
    $guardPs = Join-Path $PSScriptRoot 'Guard-Service.ps1'
    $psExe = Join-Path $env:windir 'System32\WindowsPowerShell\v1.0\powershell.exe'
    if (Test-Path $guardPs) {
        Start-Process $psExe -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$guardPs`"" -WindowStyle Hidden
    }
}
