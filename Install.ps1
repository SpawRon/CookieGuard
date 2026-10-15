# ============================================================
#  CookieGuard - Install.ps1
#  Установка в систему как обычной программы.
#
#  Что делает:
#   - собирает CookieGuard.exe и значок (если ещё не собраны);
#   - копирует программу в C:\Program Files\CookieGuard;
#   - заводит папку данных C:\ProgramData\CookieGuard и закрывает
#     её от записи обычным пользователям;
#   - создаёт ярлыки в меню «Пуск» и, по желанию, на рабочем столе;
#   - регистрирует программу в «Приложения и возможности», чтобы
#     её можно было удалить штатным способом.
#
#  Почему именно Program Files: туда нельзя писать без прав
#  администратора. Значит, вредонос, запущенный от обычного
#  пользователя, не сможет подменить сам инструмент защиты.
#  Ради этого стоит потерпеть запрос прав при установке.
# ============================================================

[CmdletBinding()]
param(
    [string]$Path = (Join-Path $env:ProgramFiles 'CookieGuard'),
    [switch]$DesktopShortcut,
    [switch]$Autostart,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
$src = $PSScriptRoot
. (Join-Path $src 'lib\Core.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

if (-not (Test-CgAdmin)) {
    Write-Host 'Нужны права администратора. Запустите установку от имени администратора.' -ForegroundColor Red
    exit 1
}

$AppName = 'CookieGuard'
$Version = '1.0.0'
$Publisher = 'CookieGuard'
$dataDir = Join-Path $env:ProgramData 'CookieGuard'

Write-CgHead "Установка $AppName $Version"
Write-Host "  Откуда: $src"
Write-Host "  Куда:   $Path"
Write-Host "  Данные: $dataDir"
Write-Host ''

# ---- 1. собрать exe и значок ----
$exeSrc = Join-Path $src 'CookieGuard.exe'
$icoSrc = Join-Path $src 'CookieGuard.ico'
if (-not (Test-Path -LiteralPath $exeSrc) -or -not (Test-Path -LiteralPath $icoSrc)) {
    Write-Host '  Собираю исполняемый файл...' -ForegroundColor DarkGray
    & (Join-Path $src 'build\Build.ps1') | Out-Null
}
if (Test-Path -LiteralPath $exeSrc) { Write-CgItem 'OK' 'Исполняемый файл готов' }
else { Write-CgItem 'WARN' 'Собрать .exe не удалось — ярлыки будут вести на CookieGuard.cmd' }

# ---- 2. остановить то, что сейчас работает ----
foreach ($p in (Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue)) {
    if ("$($p.CommandLine)" -match 'CookieGuard\.ps1|Guard-Service\.ps1') {
        try { Stop-Process -Id $p.ProcessId -Force -ErrorAction Stop } catch { }
    }
}

# ---- 3. скопировать программу ----
# Рабочие данные НЕ копируем: они принадлежат компьютеру, а не раздаче
$skip = @('state', 'logs', 'reports', 'evidence', 'quarantine', '.git', 'build', 'obj')
if (-not (Test-Path -LiteralPath $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }

$copied = 0
$destFull = $Path
try { $destFull = [IO.Path]::GetFullPath($Path).TrimEnd('\') } catch { }

foreach ($item in (Get-ChildItem -LiteralPath $src -Force)) {
    if ($skip -contains $item.Name) { continue }

    # Папку назначения внутрь неё же не копируем, и старую копию
    # программы, оставшуюся внутри исходной папки, — тоже.
    # Без этой проверки установка создавала CookieGuard\CookieGuard\...,
    # а следующая установка удваивала вложенность ещё раз.
    if ($item.PSIsContainer) {
        if ($item.FullName.TrimEnd('\') -ieq $destFull) { continue }
        if (Test-Path -LiteralPath (Join-Path $item.FullName 'CookieGuard.ps1')) {
            Write-CgItem 'NOTE' "Пропущена вложенная копия программы: $($item.Name)"
            continue
        }
    }

    $dest = Join-Path $Path $item.Name
    if ($item.PSIsContainer) {
        # Пофайлово, а не папкой целиком.
        #
        # «Copy-Item -Recurse» в уже существующую папку кладёт её
        # ВНУТРЬ себя: при установке поверх прежней версии вместо
        # замены lib получалось lib\lib, и программа продолжала
        # работать на старых модулях. Первая установка этого не
        # показывает — папки назначения ещё нет, — поэтому ошибка
        # и жила так долго.
        $baseLen = $item.FullName.TrimEnd('\').Length + 1
        foreach ($f in (Get-ChildItem -LiteralPath $item.FullName -Recurse -File -Force)) {
            $rel = $f.FullName.Substring($baseLen)
            $to = Join-Path $dest $rel
            $toDir = Split-Path -Parent $to
            if ($toDir -and -not (Test-Path -LiteralPath $toDir)) {
                New-Item -ItemType Directory -Path $toDir -Force | Out-Null
            }
            Copy-Item -LiteralPath $f.FullName -Destination $to -Force
        }
    } else {
        Copy-Item -LiteralPath $item.FullName -Destination $dest -Force
    }
    $copied++
}
# build нужен, чтобы можно было пересобрать exe после обновления.
# Пофайлово по той же причине, что и выше: -Recurse в существующую
# папку создал бы build\build при повторной установке.
$buildSrc = Join-Path $src 'build'
if (Test-Path -LiteralPath $buildSrc) {
    $buildDst = Join-Path $Path 'build'
    $bLen = $buildSrc.TrimEnd('\').Length + 1
    foreach ($f in (Get-ChildItem -LiteralPath $buildSrc -Recurse -File -Force -ErrorAction SilentlyContinue)) {
        $to = Join-Path $buildDst $f.FullName.Substring($bLen)
        $toDir = Split-Path -Parent $to
        if ($toDir -and -not (Test-Path -LiteralPath $toDir)) {
            New-Item -ItemType Directory -Path $toDir -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Copy-Item -LiteralPath $f.FullName -Destination $to -Force -ErrorAction SilentlyContinue
    }
}
Write-CgItem 'OK' "Файлы скопированы в $Path (элементов: $copied)"

# ---- 4. папка данных с правильными правами ----
if (-not (Test-Path -LiteralPath $dataDir)) { New-Item -ItemType Directory -Path $dataDir -Force | Out-Null }
try {
    # Карантин, список доверенных и эталон не должны меняться
    # обычным пользователем: иначе вредонос без прав админа
    # сам себя «доверит» или вытащит из карантина.
    $acl = Get-Acl -LiteralPath $dataDir
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($sid in @('S-1-5-32-544', 'S-1-5-18')) {   # Администраторы, SYSTEM
        $id = New-Object System.Security.Principal.SecurityIdentifier $sid
        $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
            $id, 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
    }
    $users = New-Object System.Security.Principal.SecurityIdentifier 'S-1-5-32-545'  # Пользователи
    $acl.AddAccessRule((New-Object System.Security.AccessControl.FileSystemAccessRule(
        $users, 'ReadAndExecute', 'ContainerInherit,ObjectInherit', 'None', 'Allow')))
    Set-Acl -LiteralPath $dataDir -AclObject $acl
    Write-CgItem 'OK' 'Папка данных создана, запись разрешена только администратору'
} catch {
    Write-CgItem 'WARN' 'Папку данных создал, но права выставить не удалось' $_.Exception.Message
}

# ---- 4б. перенести уже накопленное при первой установке ----
# Эталон, список доверенных, ключ VirusTotal и база вердиктов копились
# временем и вручную. Терять их при установке нельзя. Но и затирать
# то, что уже есть в системе, тоже нельзя — поэтому только если пусто.
foreach ($d in @('state', 'quarantine', 'reports', 'evidence', 'logs')) {
    $from = Join-Path $src $d
    $to = Join-Path $dataDir $d
    if (-not (Test-Path -LiteralPath $from)) { continue }
    $hasSrc = @(Get-ChildItem -LiteralPath $from -Force -File -Recurse -ErrorAction SilentlyContinue).Count
    if (-not $hasSrc) { continue }
    $hasDst = 0
    if (Test-Path -LiteralPath $to) { $hasDst = @(Get-ChildItem -LiteralPath $to -Force -File -Recurse -ErrorAction SilentlyContinue).Count }
    if ($hasDst) {
        Write-CgItem 'NOTE' "Данные «$d» в системе уже есть — оставляю их, перенос пропущен"
        continue
    }
    if (-not (Test-Path -LiteralPath $to)) { New-Item -ItemType Directory -Path $to -Force | Out-Null }
    Copy-Item -Path (Join-Path $from '*') -Destination $to -Recurse -Force -ErrorAction SilentlyContinue
    Write-CgItem 'OK' "Перенесено из прежней папки: $d ($hasSrc файлов)"
}

# ---- 5. ярлыки ----
$target = Join-Path $Path 'CookieGuard.exe'
if (-not (Test-Path -LiteralPath $target)) { $target = Join-Path $Path 'CookieGuard.cmd' }
$ico = Join-Path $Path 'CookieGuard.ico'

function New-CgShortcut {
    param([string]$LinkPath, [string]$Target, [string]$Icon, [string]$Desc)
    $sh = New-Object -ComObject WScript.Shell
    $lnk = $sh.CreateShortcut($LinkPath)
    $lnk.TargetPath = $Target
    $lnk.WorkingDirectory = Split-Path -Parent $Target
    $lnk.Description = $Desc
    if ($Icon -and (Test-Path -LiteralPath $Icon)) { $lnk.IconLocation = "$Icon,0" }
    $lnk.Save()
}

$startMenu = Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu\Programs'
New-CgShortcut (Join-Path $startMenu 'CookieGuard.lnk') $target $ico 'Наблюдение за доступом к cookie и паролям'
Write-CgItem 'OK' 'Ярлык в меню «Пуск» создан'

if ($DesktopShortcut) {
    $desk = [Environment]::GetFolderPath('CommonDesktopDirectory')
    New-CgShortcut (Join-Path $desk 'CookieGuard.lnk') $target $ico 'Наблюдение за доступом к cookie и паролям'
    Write-CgItem 'OK' 'Ярлык на рабочем столе создан'
}

# ---- 6. регистрация в «Приложения и возможности» ----
try {
    $key = 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\CookieGuard'
    if (-not (Test-Path $key)) { New-Item -Path $key -Force | Out-Null }
    $size = [math]::Round((Get-ChildItem -LiteralPath $Path -Recurse -File | Measure-Object Length -Sum).Sum / 1KB)
    $un = "`"$env:windir\System32\WindowsPowerShell\v1.0\powershell.exe`" -NoProfile -ExecutionPolicy Bypass -File `"$Path\Uninstall.ps1`""
    foreach ($kv in @{
        DisplayName     = $AppName
        DisplayVersion  = $Version
        Publisher       = $Publisher
        InstallLocation = $Path
        DisplayIcon     = $ico
        UninstallString = $un
        QuietUninstallString = "$un -Quiet"
        NoModify        = 1
        NoRepair        = 1
        EstimatedSize   = $size
        URLInfoAbout    = 'https://github.com/'
    }.GetEnumerator()) {
        $type = 'String'
        if ($kv.Value -is [int]) { $type = 'DWord' }
        New-ItemProperty -Path $key -Name $kv.Key -Value $kv.Value -PropertyType $type -Force | Out-Null
    }
    Write-CgItem 'OK' 'Программа зарегистрирована в «Приложения и возможности»'
} catch {
    Write-CgItem 'WARN' 'Не удалось зарегистрировать в списке программ' $_.Exception.Message
}

# ---- 7. автозапуск защиты ----
if ($Autostart) {
    Write-Host ''
    Write-Host '  Включаю постоянную защиту...' -ForegroundColor DarkGray
    & (Join-Path $Path 'Install-Guard.ps1')
}

Write-Host ''
Write-Host "  Установлено: $Path" -ForegroundColor Green
Write-Host '  Запуск: меню «Пуск» → CookieGuard' -ForegroundColor Green
Write-Host '  Удаление: Параметры → Приложения → CookieGuard, либо Uninstall.ps1' -ForegroundColor DarkGray
Write-Host ''
Write-CgLog 'INFO' "Программа установлена в $Path"

if (-not $Quiet) {
    $ans = Read-Host '  Запустить CookieGuard сейчас? (д/н)'
    if ($ans -match '^(д|y)') { Start-Process $target }
}
