# ============================================================
#  CookieGuard - AppData.ps1
#  Что лежит в AppData и чьё это.
#
#  AppData — чёрный ящик: сотни папок с невнятными именами, и
#  именно туда ставят себя вредоносы, потому что для записи туда
#  не нужны права администратора. Раздел раскладывает её по полкам:
#  какая папка чья (по подписи программ внутри), сколько весит,
#  когда менялась, есть ли внутри запускаемые файлы и не ведёт ли
#  туда автозапуск.
#
#  Только чтение: ни один файл не открывается на чтение
#  содержимого, кроме проверки подписи у .exe (её делает Windows).
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

# Обход на C#: PowerShell-перебор сотни тысяч файлов шёл минуты,
# а [IO.Directory]::EnumerateFiles обрывается на первой же папке
# без доступа или ссылке-петле («Application Data» → сама Local).
if (-not ('Cg.DirWalk' -as [type])) {
    try { Add-CgType 'Cg.DirWalk' (Read-CgText 'lib\native\DirWalk.cs') } catch { }
}

function Format-CgSize {
    param([int64]$Bytes)
    if ($Bytes -ge 1GB) { return ('{0:N1} ГБ' -f ($Bytes / 1GB)) }
    if ($Bytes -ge 1MB) { return ('{0:N0} МБ' -f ($Bytes / 1MB)) }
    if ($Bytes -ge 1KB) { return ('{0:N0} КБ' -f ($Bytes / 1KB)) }
    return "$Bytes Б"
}

# Пути, на которые ссылается автозапуск: Run-ключи и папка «Автозагрузка».
# Нужны, чтобы отметить папку AppData, из которой что-то стартует с Windows.
function Get-CgAutorunTargets {
    $out = New-Object System.Collections.ArrayList
    foreach ($k in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
                     'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')) {
        try {
            $p = Get-ItemProperty -Path $k -ErrorAction Stop
            foreach ($pr in $p.PSObject.Properties) {
                if ($pr.Name -like 'PS*') { continue }
                $null = $out.Add([PSCustomObject]@{ Name = $pr.Name; Command = [Environment]::ExpandEnvironmentVariables("$($pr.Value)") })
            }
        } catch { }
    }
    $sd = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
    foreach ($f in (Get-ChildItem -LiteralPath $sd -File -ErrorAction SilentlyContinue)) {
        $null = $out.Add([PSCustomObject]@{ Name = $f.Name; Command = $f.FullName })
    }
    try {
        foreach ($t in (Get-ScheduledTask -ErrorAction Stop)) {
            foreach ($a in @($t.Actions)) {
                if ($a.Execute) { $null = $out.Add([PSCustomObject]@{ Name = "задача: $($t.TaskName)"; Command = [Environment]::ExpandEnvironmentVariables("$($a.Execute) $($a.Arguments)") }) }
            }
        }
    } catch { }
    return @($out)
}

# Известные имена папок, которым издатель не нужен для понимания.
$script:CgAppDataKnown = @{
    'microsoft' = 'Microsoft (Windows и Office)'; 'packages' = 'Приложения из Microsoft Store'
    'temp' = 'Временные файлы'; 'google' = 'Google (Chrome и др.)'; 'bravesoftware' = 'Brave'
    'mozilla' = 'Firefox'; 'npm' = 'npm — пакеты Node.js'; 'npm-cache' = 'кеш npm'
    'adobe' = 'Adobe'; 'telegram desktop' = 'Telegram'; 'discord' = 'Discord'; 'claude' = 'Claude (Anthropic)'
    'crashdumps' = 'Аварийные дампы программ'; 'd3dscache' = 'Кеш шейдеров DirectX'; 'nvidia' = 'NVIDIA'
    'nvidia corporation' = 'NVIDIA'; 'programs' = 'Программы, поставленные «только для вас»'
    'connecteddevicesplatform' = 'Windows: связанные устройства'; 'comms' = 'Windows: почта и календарь'
    'steam' = 'Steam'; 'spotify' = 'Spotify'; 'jetbrains' = 'JetBrains'; 'code' = 'Visual Studio Code'
    'pip' = 'Python pip'; 'yandex' = 'Яндекс'; 'opera software' = 'Opera'; 'vivaldi' = 'Vivaldi'
}

# Одна папка верхнего уровня
function Measure-CgAppDataFolder {
    param([string]$Path, [string]$Root, $Autoruns = @(), [int]$BudgetMs = 4000)
    $s = [Cg.DirWalk]::Measure($Path, 12, $BudgetMs)
    $name = Split-Path -Leaf $Path

    # Чья: подпись первых нескольких .exe внутри
    $signers = @{}; $unsigned = 0
    foreach ($e in $s.ExePaths) {
        $sig = Get-CgSignature $e
        if ($sig.Valid -and $sig.Signer) { $signers[$sig.Signer] = 1 + [int]$signers[$sig.Signer] }
        elseif ($sig.Status -eq 'NotSigned') { $unsigned++ }
    }
    $owner = ''
    if ($signers.Count) { $owner = ($signers.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1).Key }
    $known = $script:CgAppDataKnown[$name.ToLowerInvariant()]

    $pl = $Path.ToLowerInvariant().TrimEnd('\') + '\'
    $runs = @($Autoruns | Where-Object { "$($_.Command)".ToLowerInvariant().Contains($pl) })

    $marks = @()
    $sev = 'OK'
    if ($runs.Count) { $marks += 'в автозапуске'; $sev = 'NOTE' }
    if ($s.Exe -and $unsigned) { $marks += ('без подписи: {0}' -f $unsigned); $sev = 'NOTE' }
    $fresh = ($s.LastWrite -gt [datetime]::MinValue -and ((Get-Date).ToUniversalTime() - $s.LastWrite).TotalDays -lt 7)
    if ($fresh) { $marks += 'менялась за неделю' }
    # Программа без подписи, стартующая с Windows из Roaming, — то самое,
    # как устроено большинство воров паролей и майнеров
    if ($runs.Count -and $unsigned -and $Root -eq 'Roaming') { $sev = 'WARN' }
    # Чужое имя: папка «Microsoft…», а внутри неподписанное
    if ($name -match '(?i)^(microsoft|windows|google|intel|nvidia)' -and $unsigned -and -not $signers.Count) { $sev = 'WARN'; $marks += 'имя крупной компании, но подписи нет' }

    return [PSCustomObject]@{
        Root = $Root; Name = $name; Path = $Path
        Owner = $(if ($owner) { $owner } elseif ($known) { $known } else { '' })
        Bytes = [int64]$s.Bytes; Size = (Format-CgSize $s.Bytes); Files = $s.Files; Exe = $s.Exe; Unsigned = $unsigned
        LastWrite = $(if ($s.LastWrite -gt [datetime]::MinValue) { $s.LastWrite.ToLocalTime() } else { $null })
        Autoruns = @($runs | ForEach-Object { $_.Name }); Marks = ($marks -join ' · '); Severity = $sev
        Partial = ($s.Denied -gt 0)
    }
}

# Вся AppData текущего человека. Progress — {param($text)} для окна.
function Get-CgAppDataMap {
    param([scriptblock]$Progress = $null, [string]$ProfileDir = $env:USERPROFILE)
    $autoruns = @(Get-CgAutorunTargets)
    $out = New-Object System.Collections.ArrayList
    foreach ($root in @('Roaming', 'Local', 'LocalLow')) {
        $base = Join-Path (Join-Path $ProfileDir 'AppData') $root
        $dirs = @(Get-ChildItem -LiteralPath $base -Directory -Force -ErrorAction SilentlyContinue |
                  Where-Object { -not ($_.Attributes -band [IO.FileAttributes]::ReparsePoint) })
        $i = 0
        foreach ($d in $dirs) {
            $i++
            if ($Progress) { & $Progress ('{0}: {1} из {2} — {3}' -f $root, $i, $dirs.Count, $d.Name) }
            $null = $out.Add((Measure-CgAppDataFolder $d.FullName $root $autoruns))
        }
    }
    return @($out)
}
