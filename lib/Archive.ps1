# ============================================================
#  CookieGuard - Archive.ps1
#  Заглянуть внутрь архива, не доверяя его содержимому.
#
#  Зачем вообще. Вредонос почти никогда не приезжает голым .exe:
#  его кладут в архив, и часто под пароль — именно чтобы ни
#  почта, ни антивирус, ни облачная проверка не увидели, что
#  внутри. Поэтому программа, которая умеет проверять только
#  отдельный файл, разбирается ровно с тем случаем, которого
#  на практике не бывает.
#
#  Как здесь безопасно. Содержимое распаковывается в НОВУЮ пустую
#  папку во временном каталоге и там же удаляется; ничего не
#  запускается и не открывается — только считается отпечаток.
#  Пароль живёт в памяти одного вызова и на диск не попадает.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$script:CgArchiveExt = @(
    '.zip', '.7z', '.rar', '.tar', '.gz', '.tgz', '.bz2', '.xz', '.cab',
    '.arj', '.lzh', '.lha', '.iso', '.wim', '.z', '.zipx'
)

function Test-CgArchive {
    param([string]$Path)
    if (-not $Path) { return $false }
    return ($script:CgArchiveExt -contains ([IO.Path]::GetExtension($Path)).ToLowerInvariant())
}

# ------------------------------------------------------------
#  7-Zip: единственный способ открыть .7z и .rar и вообще
#  единственный, который понимает пароль. Ищем, но не требуем:
#  без него .zip без пароля всё равно разберём силами .NET.
# ------------------------------------------------------------
$script:Cg7z = $null
function Get-Cg7Zip {
    if ($null -ne $script:Cg7z) { return $script:Cg7z }
    $cands = @(
        "$env:ProgramFiles\7-Zip\7z.exe",
        "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
        "$env:ProgramFiles\7-Zip-Zstandard\7z.exe",
        "$env:LOCALAPPDATA\Programs\7-Zip\7z.exe"
    )
    foreach ($c in $cands) { if (Test-Path -LiteralPath $c) { $script:Cg7z = $c; return $c } }
    $cmd = Get-Command '7z.exe' -ErrorAction SilentlyContinue
    if ($cmd) { $script:Cg7z = $cmd.Source; return $script:Cg7z }
    $script:Cg7z = ''
    return ''
}

# Склейка командной строки вручную.
#
# ProcessStartInfo.ArgumentList появился только в .NET Core,
# а PowerShell 5.1 работает на .NET Framework — там его нет.
# Поэтому собираем строку сами и по правилам Windows: кавычка
# удваивается обратной косой, а косые перед закрывающей кавычкой
# тоже надо удвоить, иначе она потеряется. Пароль и путь к файлу
# приходят от человека, и обойтись «просто кавычками» нельзя.
function ConvertTo-CgCmdArg {
    param([string]$Value)
    if ($Value -eq '') { return '""' }
    if ($Value -notmatch '[ \t"]') { return $Value }
    $sb = New-Object System.Text.StringBuilder
    $null = $sb.Append('"')
    $slashes = 0
    foreach ($ch in $Value.ToCharArray()) {
        if ($ch -eq '\') { $slashes++; continue }
        if ($ch -eq '"') {
            $null = $sb.Append('\' * ($slashes * 2 + 1)).Append('"')
        } else {
            $null = $sb.Append('\' * $slashes).Append($ch)
        }
        $slashes = 0
    }
    $null = $sb.Append('\' * ($slashes * 2)).Append('"')
    return $sb.ToString()
}

function Invoke-Cg7Zip {
    param([string[]]$ArgList, [int]$TimeoutSec = 180)
    $exe = Get-Cg7Zip
    if (-not $exe) { return [PSCustomObject]@{ Ok = $false; Code = -1; Out = ''; Err = '7-Zip не найден' } }

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [Text.Encoding]::UTF8
    $psi.Arguments = (($ArgList | ForEach-Object { ConvertTo-CgCmdArg $_ }) -join ' ')

    try {
        $p = [Diagnostics.Process]::Start($psi)
        $out = $p.StandardOutput.ReadToEnd()
        $err = $p.StandardError.ReadToEnd()
        if (-not $p.WaitForExit($TimeoutSec * 1000)) {
            try { $p.Kill() } catch { }
            return [PSCustomObject]@{ Ok = $false; Code = -2; Out = $out; Err = 'архив распаковывается слишком долго' }
        }
        return [PSCustomObject]@{ Ok = ($p.ExitCode -eq 0); Code = $p.ExitCode; Out = $out; Err = $err }
    } catch {
        return [PSCustomObject]@{ Ok = $false; Code = -3; Out = ''; Err = "$($_.Exception.Message)" }
    }
}

# ------------------------------------------------------------
#  Зашифрован ли zip — видно из самого файла, без 7-Zip.
#
#  В заголовке каждой записи есть «флаги общего назначения»;
#  младший бит означает «запись зашифрована». Читаем первый
#  локальный заголовок — этого достаточно, чтобы спросить пароль
#  до того, как распаковка упрётся в ошибку.
# ------------------------------------------------------------
function Test-CgZipEncrypted {
    param([string]$Path)
    try {
        $fs = [IO.File]::OpenRead($Path)
        try {
            $b = New-Object byte[] 8
            if ($fs.Read($b, 0, 8) -lt 8) { return $false }
            # PK\003\004 — локальный заголовок записи
            if (-not ($b[0] -eq 0x50 -and $b[1] -eq 0x4B -and $b[2] -eq 0x03 -and $b[3] -eq 0x04)) { return $false }
            $flags = [int]$b[6] -bor ([int]$b[7] -shl 8)
            return (($flags -band 1) -ne 0)
        } finally { $fs.Dispose() }
    } catch { return $false }
}

# ------------------------------------------------------------
#  Что внутри и нужен ли пароль
# ------------------------------------------------------------
function Get-CgArchiveInfo {
    param([string]$Path)

    $res = [PSCustomObject]@{
        Ok = $false; Encrypted = $false; NamesHidden = $false
        Count = 0; Names = @(); Error = ''; Tool = ''
    }

    $ext = ([IO.Path]::GetExtension($Path)).ToLowerInvariant()
    $exe = Get-Cg7Zip

    if ($exe) {
        $res.Tool = '7-Zip'
        # -p с пустым паролем: иначе 7-Zip ждёт ввода и подвисает
        $r = Invoke-Cg7Zip @('l', '-slt', '-p', '--', $Path) 30
        $txt = "$($r.Out)`n$($r.Err)"
        if ($txt -match '(?i)wrong password|cannot open encrypted archive') {
            # зашифрованы даже имена файлов
            $res.Ok = $true; $res.Encrypted = $true; $res.NamesHidden = $true
            return $res
        }
        if (-not $r.Ok -and -not ($txt -match '(?m)^Path = ')) {
            $res.Error = "не удалось прочитать архив (код $($r.Code))"
            return $res
        }
        $names = @()
        $enc = $false
        foreach ($blk in ($txt -split "(?m)^\s*$")) {
            if ($blk -notmatch '(?m)^Path = (.+)$') { continue }
            $n = $matches[1].Trim()
            if ($blk -match '(?m)^Folder = \+') { continue }
            if ($blk -match '(?m)^Attributes = .*D') { continue }
            if ($blk -match '(?m)^Encrypted = \+') { $enc = $true }
            $names += $n
        }
        # первый блок — это сам архив, у него Path = путь к файлу
        $names = @($names | Where-Object { $_ -ne $Path })
        $res.Ok = $true
        $res.Encrypted = $enc
        $res.Names = $names
        $res.Count = $names.Count
        return $res
    }

    # без 7-Zip умеем только zip и только силами .NET
    if ($ext -ne '.zip') {
        $res.Error = "для $ext нужен 7-Zip"
        return $res
    }
    $res.Tool = '.NET'
    if (Test-CgZipEncrypted $Path) {
        $res.Ok = $true; $res.Encrypted = $true
        $res.Error = 'архив под паролем — нужен 7-Zip, встроенными средствами Windows пароль не открыть'
        return $res
    }
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $z = [IO.Compression.ZipFile]::OpenRead($Path)
        try {
            $names = @($z.Entries | Where-Object { $_.Length -gt 0 -or $_.Name } | ForEach-Object { $_.FullName })
            $res.Ok = $true; $res.Names = $names; $res.Count = $names.Count
        } finally { $z.Dispose() }
    } catch {
        $res.Error = "не удалось прочитать архив: $($_.Exception.Message)"
    }
    return $res
}

# ------------------------------------------------------------
#  Распаковка в отдельную пустую папку
# ------------------------------------------------------------
function Expand-CgArchive {
    param([string]$Path, [string]$Password = '')

    $res = [PSCustomObject]@{ Ok = $false; Dir = ''; Error = ''; WrongPassword = $false }

    $dir = Join-Path ([IO.Path]::GetTempPath()) ('CookieGuard-unpack-' + [Guid]::NewGuid().ToString('N').Substring(0, 12))
    try { New-Item -ItemType Directory -Path $dir -Force | Out-Null } catch {
        $res.Error = 'не удалось создать временную папку'
        return $res
    }

    $exe = Get-Cg7Zip
    if ($exe) {
        $pw = '-p'
        if ($Password) { $pw = "-p$Password" }
        # x — с сохранением путей, -y — не спрашивать, -o — куда
        $r = Invoke-Cg7Zip @('x', $pw, '-y', '-bd', "-o$dir", '--', $Path) 300
        $txt = "$($r.Out)`n$($r.Err)"
        if ($txt -match '(?i)wrong password|data error in encrypted file') {
            $res.WrongPassword = $true
            $res.Error = 'пароль не подошёл'
            Remove-CgTempDir $dir
            return $res
        }
        if (-not $r.Ok) {
            $res.Error = "7-Zip вернул ошибку (код $($r.Code))"
            Remove-CgTempDir $dir
            return $res
        }
        $res.Ok = $true; $res.Dir = $dir
        return $res
    }

    if (([IO.Path]::GetExtension($Path)).ToLowerInvariant() -ne '.zip') {
        $res.Error = 'нужен 7-Zip'
        Remove-CgTempDir $dir
        return $res
    }
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        [IO.Compression.ZipFile]::ExtractToDirectory($Path, $dir)
        $res.Ok = $true; $res.Dir = $dir
    } catch {
        $res.Error = "не удалось распаковать: $($_.Exception.Message)"
        Remove-CgTempDir $dir
    }
    return $res
}

function Remove-CgTempDir {
    param([string]$Dir)
    if (-not $Dir) { return }
    # подстраховка: удаляем только то, что сами и создали
    if ($Dir -notmatch 'CookieGuard-unpack-') { return }
    try { Remove-Item -LiteralPath $Dir -Recurse -Force -ErrorAction SilentlyContinue } catch { }
}
