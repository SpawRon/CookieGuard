# ============================================================
#  CookieGuard - Actions.ps1
#  Активные действия: карантин файла и завершение процесса.
#
#  Два правила, которые здесь соблюдаются жёстко:
#   1. Всё обратимо или подтверждается. Карантин не удаляет файл,
#      а прячет обратимо. Завершение процесса подтверждается в окне.
#   2. Критические процессы Windows не трогаются никогда — иначе
#      система падает в синий экран. Это и защита, и просто
#      здравый смысл.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

# Процессы, завершение которых роняет Windows. Не трогаем ни при каких условиях.
$script:CgNeverKill = @(
    'system', 'idle', 'system idle process', 'registry', 'memory compression', 'secure system',
    'smss.exe', 'csrss.exe', 'wininit.exe', 'winlogon.exe', 'services.exe',
    'lsass.exe', 'lsaiso.exe', 'fontdrvhost.exe'
)

# Папки, где лежат системные файлы: карантин оттуда требует отдельного подтверждения,
# потому что изъятие настоящего системного файла ломает Windows.
function Test-CgSystemPath {
    param([string]$Path)
    $p = (Get-CgNormPath $Path).ToLowerInvariant()
    return ($p -like 'c:\windows\system32\*' -or $p -like 'c:\windows\syswow64\*' -or
            ($p -like 'c:\windows\*' -and $p -notlike '*\temp\*') -or
            $p -like 'c:\program files\windowsapps\*')
}

# ------------------------------------------------------------
#  Завершение процесса (вместе с потомками)
# ------------------------------------------------------------
function Stop-CgProcessTree {
    param([int]$ProcId, [string]$Reason = '')

    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcId" -ErrorAction SilentlyContinue
    if (-not $p) {
        return [PSCustomObject]@{ Ok = $false; Message = 'Процесс уже не существует'; Killed = @() }
    }
    $name = "$($p.Name)".ToLowerInvariant()
    if ($script:CgNeverKill -contains $name -or $ProcId -le 4) {
        return [PSCustomObject]@{ Ok = $false; Message = "Это критический процесс Windows ($($p.Name)) — его завершение обрушит систему. Отказано."; Killed = @() }
    }

    # Собираем дерево: сначала потомки, потом сам процесс.
    # Иначе родитель успеет перезапустить ребёнка.
    $all = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue
    $tree = New-Object System.Collections.ArrayList
    $queue = New-Object System.Collections.Queue
    $queue.Enqueue($ProcId)
    $guard = 0
    while ($queue.Count -gt 0 -and $guard -lt 500) {
        $guard++
        $cur = $queue.Dequeue()
        foreach ($c in ($all | Where-Object { [int]$_.ParentProcessId -eq $cur })) {
            $cn = "$($c.Name)".ToLowerInvariant()
            if ($script:CgNeverKill -contains $cn) { continue }
            if (-not ($tree | Where-Object { $_ -eq [int]$c.ProcessId })) {
                $null = $tree.Add([int]$c.ProcessId)
                $queue.Enqueue([int]$c.ProcessId)
            }
        }
    }
    $null = $tree.Add($ProcId)   # сам процесс — последним

    $killed = @()
    foreach ($id in $tree) {
        try {
            Stop-Process -Id $id -Force -ErrorAction Stop
            $killed += $id
        } catch { }
    }

    Write-CgLog 'WARN' ("Завершён процесс PID $ProcId ($($p.Name)); всего в дереве: $($killed.Count); причина: $Reason")
    if ($killed -contains $ProcId) {
        return [PSCustomObject]@{ Ok = $true; Message = "Завершено процессов: $($killed.Count)"; Killed = $killed; Name = $p.Name; Path = $p.ExecutablePath }
    }
    return [PSCustomObject]@{ Ok = $false; Message = 'Не удалось завершить процесс (нужны права администратора или процесс защищён)'; Killed = $killed }
}

# ------------------------------------------------------------
#  Карантин
#
#  Файл не удаляется, а прячется обратимо: байты переписываются
#  простым XOR, чтобы копию нельзя было запустить и чтобы её не
#  трогал антивирус, рядом кладётся запись с исходным путём и
#  хешем. Восстановление возвращает всё как было.
# ------------------------------------------------------------
$script:CgQxorKey = [byte[]](0x43, 0x6F, 0x6F, 0x6B, 0x69, 0x65, 0x47, 0x75, 0x61, 0x72, 0x64)  # "CookieGuard"

function Get-CgQuarantineDir { return (Get-CgDir 'quarantine') }

function Invoke-CgQuarantine {
    param([string]$Path, [string]$Reason = '', [string]$Hash = '')

    $Path = Get-CgNormPath $Path
    if (-not $Path -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return [PSCustomObject]@{ Ok = $false; Message = 'Файл не найден' }
    }
    if (-not (Test-CgAdmin)) {
        return [PSCustomObject]@{ Ok = $false; Message = 'Для карантина нужны права администратора' }
    }

    $fi = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if ($fi.Length -gt 300MB) {
        return [PSCustomObject]@{ Ok = $false; Message = 'Файл слишком большой для карантина (> 300 МБ)' }
    }
    if (-not $Hash) { $Hash = Get-CgHash $Path }

    $qdir = Get-CgQuarantineDir
    $id = (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
    $blob = Join-Path $qdir ("$id.qbin")
    $meta = Join-Path $qdir ("$id.json")

    try {
        # 1. читаем и обратимо «глушим» содержимое
        $bytes = [IO.File]::ReadAllBytes($Path)
        $k = $script:CgQxorKey
        for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = $bytes[$i] -bxor $k[$i % $k.Length] }
        [IO.File]::WriteAllBytes($blob, $bytes)

        # 2. метаданные
        $record = [PSCustomObject]@{
            Id           = $id
            OriginalPath = $Path
            OriginalName = $fi.Name
            Size         = $fi.Length
            Sha256       = $Hash
            Reason       = $Reason
            Created      = $fi.CreationTime.ToString('o')
            Quarantined  = (Get-Date).ToString('o')
            Signer       = (Get-CgSignature $Path).Signer
        }
        $record | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $meta -Encoding UTF8

        # 3. забираем право на удаление, если его не хватает, и удаляем оригинал
        try {
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        } catch {
            & takeown /f "$Path" 2>&1 | Out-Null
            & icacls "$Path" /grant "*S-1-5-32-544:F" 2>&1 | Out-Null   # Администраторы: полный доступ
            Remove-Item -LiteralPath $Path -Force -ErrorAction Stop
        }

        Write-CgLog 'WARN' ("В карантин: $Path (SHA256 $Hash); причина: $Reason; id $id")
        return [PSCustomObject]@{ Ok = $true; Message = "Файл в карантине (id $id)"; Id = $id }
    } catch {
        # откат: если оригинал ещё на месте, карантинные файлы убираем
        Remove-Item -LiteralPath $blob -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $meta -Force -ErrorAction SilentlyContinue
        return [PSCustomObject]@{ Ok = $false; Message = "Не удалось: $($_.Exception.Message)" }
    }
}

function Get-CgQuarantineList {
    $qdir = Get-CgQuarantineDir
    $out = @()
    foreach ($m in (Get-ChildItem -LiteralPath $qdir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
        try {
            $r = Get-Content -LiteralPath $m.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
            $blob = Join-Path $qdir ("$($r.Id).qbin")
            $out += [PSCustomObject]@{
                Id = $r.Id
                Name = $r.OriginalName
                OriginalPath = $r.OriginalPath
                Reason = $r.Reason
                Sha256 = $r.Sha256
                Signer = $r.Signer
                Quarantined = $r.Quarantined
                QuarantinedText = $(try { ([datetime]$r.Quarantined).ToString('dd.MM.yyyy HH:mm') } catch { $r.Quarantined })
                Size = $r.Size
                Exists = (Test-Path -LiteralPath $blob)
                Title = $r.OriginalName
                Path = $r.OriginalPath
                Query = $r.OriginalName
                Detail = "Было: $($r.OriginalPath)`nПричина: $($r.Reason)`nSHA256: $($r.Sha256)`nПодпись: $($r.Signer)`nВ карантине с: $($r.Quarantined)`nРазмер: $([math]::Round($r.Size/1KB)) КБ`nid: $($r.Id)"
                Severity = 'WARN'
            }
        } catch { }
    }
    return @($out | Sort-Object Quarantined -Descending)
}

function Restore-CgQuarantine {
    param([string]$Id, [string]$ToPath = '')
    $qdir = Get-CgQuarantineDir
    $meta = Join-Path $qdir "$Id.json"
    $blob = Join-Path $qdir "$Id.qbin"
    if (-not (Test-Path -LiteralPath $meta) -or -not (Test-Path -LiteralPath $blob)) {
        return [PSCustomObject]@{ Ok = $false; Message = 'Запись карантина не найдена' }
    }
    try {
        $r = Get-Content -LiteralPath $meta -Raw -Encoding UTF8 | ConvertFrom-Json
        $dest = $ToPath
        if (-not $dest) { $dest = $r.OriginalPath }
        $dir = Split-Path -Parent $dest
        if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        $bytes = [IO.File]::ReadAllBytes($blob)
        $k = $script:CgQxorKey
        for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] = $bytes[$i] -bxor $k[$i % $k.Length] }
        [IO.File]::WriteAllBytes($dest, $bytes)

        Remove-Item -LiteralPath $blob -Force -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $meta -Force -ErrorAction SilentlyContinue
        Write-CgLog 'INFO' ("Из карантина восстановлено: $dest (id $Id)")
        return [PSCustomObject]@{ Ok = $true; Message = "Восстановлено: $dest" }
    } catch {
        return [PSCustomObject]@{ Ok = $false; Message = "Не удалось: $($_.Exception.Message)" }
    }
}

function Remove-CgQuarantine {
    param([string]$Id)
    $qdir = Get-CgQuarantineDir
    $meta = Join-Path $qdir "$Id.json"
    $blob = Join-Path $qdir "$Id.qbin"
    $r = $null
    if (Test-Path -LiteralPath $meta) { try { $r = Get-Content -LiteralPath $meta -Raw -Encoding UTF8 | ConvertFrom-Json } catch { } }
    Remove-Item -LiteralPath $blob -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $meta -Force -ErrorAction SilentlyContinue
    Write-CgLog 'WARN' ("Удалено из карантина насовсем: id $Id" + $(if ($r) { " ($($r.OriginalName))" } else { '' }))
    return [PSCustomObject]@{ Ok = $true; Message = 'Удалено из карантина окончательно' }
}

# ------------------------------------------------------------
#  Обезвредить: завершить процесс и отправить его файл в карантин
# ------------------------------------------------------------
function Invoke-CgNeutralize {
    param([int]$ProcId, [string]$Path = '', [string]$Reason = 'обезврежено вручную', [string]$Hash = '')
    $log = @()
    if (-not $Path) {
        $p = Get-CimInstance Win32_Process -Filter "ProcessId=$ProcId" -ErrorAction SilentlyContinue
        if ($p) { $Path = $p.ExecutablePath }
    }
    if ($ProcId -gt 0) {
        $k = Stop-CgProcessTree -ProcId $ProcId -Reason $Reason
        $log += "Процесс: $($k.Message)"
        if (-not $k.Ok -and $k.Message -match 'критический') {
            return [PSCustomObject]@{ Ok = $false; Message = $k.Message; Log = $log }
        }
    }
    Start-Sleep -Milliseconds 400   # дать дескрипторам закрыться
    if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $q = Invoke-CgQuarantine -Path $Path -Reason $Reason -Hash $Hash
        $log += "Файл: $($q.Message)"
        return [PSCustomObject]@{ Ok = $q.Ok; Message = ($log -join '  |  '); Log = $log }
    }
    $log += 'Файл на диске не найден (возможно, процесс работал из удалённого образа)'
    return [PSCustomObject]@{ Ok = $true; Message = ($log -join '  |  '); Log = $log }
}
