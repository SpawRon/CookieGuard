# ============================================================
#  CookieGuard - Watchdog.ps1
#  Наблюдатель. Раз в минуту проверяет сердцебиение сторожа
#  и, если оно пропало, запускает сторожа заново. Если сняли саму
#  задачу сторожа, а автозащита включена, — ставит её обратно.
#  Намеренно простой и быстрый — отработал и вышел.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Core.ps1')
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Protect.ps1')

if (Test-CgGuardAlive) {
    # Сторож жив, но агенты молчат — значит, его цикл застрял или
    # кто-то его душит. Перекличку сверяет отдельный процесс.
    . (Join-Path (Split-Path -Parent $PSScriptRoot) 'lib\Agents.ps1')
    $r = Get-CgAgentsReport
    $silent = @($r.Agents | Where-Object { $_.Silent })
    if ($r.At -and (-not $r.Fresh -or $silent.Count)) {
        # Сторож моложе пяти минут — ему дают отметиться. Перезапуск не
        # чаще раза в 15 минут: перезапуск по кругу ничего не чинит, а
        # тревог насыпает (так и было, пока перекличка не записывалась).
        $g = Get-CgGuardInfo
        $mark = Join-Path (Get-CgDir 'state') 'watchdog-restart.txt'
        $lastR = [datetime]::MinValue
        try { $lastR = [datetime]::Parse([IO.File]::ReadAllText($mark)) } catch { }
        $young = $false
        try { $young = ((Get-Date) - (Get-Process -Id $g.ProcId -ErrorAction Stop).StartTime).TotalMinutes -lt 5 } catch { }
        if (-not $young -and ((Get-Date) - $lastR).TotalMinutes -ge 15) {
            $who = $(if ($silent.Count) { ($silent | ForEach-Object { $_.Name }) -join ', ' } else { 'все' })
            Write-CgLog 'CRIT' "Наблюдатель: агенты молчат ($who) — перезапускаю сторожа"
            try { [IO.File]::WriteAllText($mark, (Get-Date).ToString('o')) } catch { }
            $null = Restart-CgGuard
        }
    }
    return
}

$s = Get-CgSettings
if (-not (Test-CgTask $script:CgTaskGuard)) {
    if (-not $s.AutoProtect) { return }
    try {
        Register-CgGuardTask -AutoNeutralize:([bool]$s.AutoNeutralize)
        Write-CgLog 'CRIT' 'Наблюдатель: задачу сторожа кто-то снял — поставил обратно'
    } catch {
        Write-CgLog 'WARN' "Наблюдатель: задачу сторожа вернуть не удалось: $($_.Exception.Message)"
    }
}

Write-CgLog 'WARN' 'Наблюдатель: сердцебиение сторожа пропало — поднимаю сторожа'
try {
    Start-ScheduledTask -TaskName $script:CgTaskGuard -ErrorAction Stop
} catch {
    # запасной путь, если задачу сняли и вернуть не вышло: запускаем напрямую
    $guardPs = Join-Path $PSScriptRoot 'Guard-Service.ps1'
    if (Test-Path $guardPs) {
        Start-Process (Get-CgPsExe) -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', "`"$guardPs`"" -WindowStyle Hidden
    }
}
