# ============================================================
#  CookieGuard - build\Build.ps1
#  Собирает значок и исполняемый файл CookieGuard.exe.
#  Сторонних средств не нужно: компилятор C# входит в .NET
#  Framework, который есть в любой Windows.
# ============================================================

[CmdletBinding()]
param([switch]$SkipIcon)

$ErrorActionPreference = 'Stop'
$proj = Split-Path -Parent $PSScriptRoot
$icon = Join-Path $proj 'CookieGuard.ico'
$exe  = Join-Path $proj 'CookieGuard.exe'

Write-Host ''
Write-Host '  Сборка CookieGuard' -ForegroundColor Cyan
Write-Host ''

# --- значок ---
if (-not $SkipIcon -or -not (Test-Path -LiteralPath $icon)) {
    & (Join-Path $PSScriptRoot 'New-Icon.ps1') -OutPath $icon
}

# --- компилятор ---
$csc = $null
foreach ($c in @(
    "$env:windir\Microsoft.NET\Framework64\v4.0.30319\csc.exe",
    "$env:windir\Microsoft.NET\Framework\v4.0.30319\csc.exe")) {
    if (Test-Path -LiteralPath $c) { $csc = $c; break }
}
if (-not $csc) {
    Write-Host '  Не найден компилятор C# (csc.exe) из .NET Framework.' -ForegroundColor Red
    Write-Host '  Программа будет работать и без .exe — через CookieGuard.cmd.' -ForegroundColor Yellow
    exit 1
}

$src      = Join-Path $PSScriptRoot 'Launcher.cs'
$manifest = Join-Path $PSScriptRoot 'app.manifest'

# /target:winexe — приложение без консоли, поэтому ничего не мигает
$cscArgs = @(
    '/nologo'
    '/target:winexe'
    '/optimize+'
    "/out:$exe"
    "/win32icon:$icon"
    "/win32manifest:$manifest"
    '/reference:System.dll'
    '/reference:System.Windows.Forms.dll'
    $src
)

if (Test-Path -LiteralPath $exe) { Remove-Item -LiteralPath $exe -Force }
$out = & $csc @cscArgs 2>&1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $exe)) {
    Write-Host '  Сборка не удалась:' -ForegroundColor Red
    $out | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    exit 1
}

$size = [math]::Round((Get-Item $exe).Length / 1KB, 1)
Write-Host "  CookieGuard.exe собран ($size КБ)" -ForegroundColor Green
Write-Host '  Значок встроен, запрос прав администратора встроен, консоль не появляется.' -ForegroundColor DarkGray
Write-Host ''
