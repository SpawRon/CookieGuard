# ============================================================
#  CookieGuard - Install-Audit.ps1
#  Включает штатный аудит доступа к файлам Windows для баз
#  cookie и паролей браузеров. После этого ядро Windows само
#  записывает в журнал безопасности, КАКОЙ процесс открыл файл.
#  Требуются права администратора.
# ============================================================

[CmdletBinding()]
param(
    [switch]$Full,                 # следить за всеми файлами, а не только Cookies/Login Data
    [int]$SecurityLogMB = 256      # размер журнала безопасности
)

. (Join-Path $PSScriptRoot 'lib\Core.ps1')

try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

if (-not (Test-CgAdmin)) {
    Write-Host 'Нужны права администратора. Запустите CookieGuard.exe — он сам попросит повышение.' -ForegroundColor Red
    exit 1
}

Write-CgHead 'Включение аудита доступа к файлам cookie'

# ---- 1. Политика аудита (GUID не зависит от языка системы) ----
$fsGuid = '{0CCE921D-69AE-11D9-BED3-505054503030}'
Write-Host '  Включаю подкатегорию аудита "File System" (успешный доступ)...'
$r = & auditpol /set /subcategory:$fsGuid /success:enable 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-CgItem 'OK' 'Политика аудита файловой системы включена'
} else {
    Write-CgItem 'CRIT' 'Не удалось включить политику аудита' ($r -join ' ')
    exit 1
}

# ---- 2. Размер журнала безопасности ----
$bytes = $SecurityLogMB * 1MB
& wevtutil sl Security /ms:$bytes 2>&1 | Out-Null
Write-CgItem 'OK' ("Журнал безопасности расширен до $SecurityLogMB МБ (чтобы события не затирались)")

# ---- 3. SACL на файлы ----
$targets = Get-CgTargetFiles
if (-not $Full) {
    $targets = $targets | Where-Object { $_.Path -match '\\(Cookies|Login Data|logins\.json|key4\.db|cookies\.sqlite)$' }
}

if (-not $targets) {
    Write-CgItem 'WARN' 'Не найдено ни одного файла браузера для наблюдения'
    exit 1
}

# Everyone — well-known SID, не зависит от языка системы
$everyone = New-Object System.Security.Principal.SecurityIdentifier 'S-1-1-0'
$rights   = [System.Security.AccessControl.FileSystemRights]'ReadData, WriteData, Delete, TakeOwnership, ChangePermissions'
$flags    = [System.Security.AccessControl.AuditFlags]::Success

$ok = 0; $fail = 0
$watched = New-Object System.Collections.ArrayList

foreach ($t in $targets) {
    try {
        $acl = Get-Acl -LiteralPath $t.Path -Audit -ErrorAction Stop
        $rule = New-Object System.Security.AccessControl.FileSystemAuditRule($everyone, $rights, $flags)
        $acl.AddAuditRule($rule)
        Set-Acl -LiteralPath $t.Path -AclObject $acl -ErrorAction Stop
        $ok++
        $null = $watched.Add($t.Path)
    } catch {
        $fail++
        Write-CgItem 'WARN' ("Не удалось поставить аудит: {0}" -f $t.Path) $_.Exception.Message
    }
}

# ---- 4. SACL с наследованием на папки Network (чтобы новые профили тоже попадали) ----
$dirs = $targets | ForEach-Object { Split-Path -Parent $_.Path } | Sort-Object -Unique
$dirRights = [System.Security.AccessControl.FileSystemRights]'CreateFiles, Delete'
$inherit   = [System.Security.AccessControl.InheritanceFlags]'ObjectInherit'
$prop      = [System.Security.AccessControl.PropagationFlags]::None
foreach ($d in $dirs) {
    try {
        $acl = Get-Acl -LiteralPath $d -Audit -ErrorAction Stop
        $rule = New-Object System.Security.AccessControl.FileSystemAuditRule($everyone, $dirRights, $inherit, $prop, $flags)
        $acl.AddAuditRule($rule)
        Set-Acl -LiteralPath $d -AclObject $acl -ErrorAction Stop
    } catch { }
}

Write-CgItem 'OK' ("Аудит установлен на файлов: $ok" + $(if ($fail) { "  (не удалось: $fail)" } else { '' }))

# сохраняем список для монитора и для отключения
$stateDir = Get-CgDir 'state'
$watched | Set-Content -LiteralPath (Join-Path $stateDir 'audited-files.txt') -Encoding UTF8

Write-Host ''
Write-Host '  Готово. Теперь Windows фиксирует каждое открытие этих файлов.' -ForegroundColor Green
Write-Host '  Откройте CookieGuard и нажмите «Запустить монитор» — события пойдут в реальном времени.' -ForegroundColor Green
Write-Host ''
Write-Host '  Отключить обратно: тот же переключатель в разделе «Защита».' -ForegroundColor DarkGray
Write-Host ''
foreach ($w in $watched) { Write-Host ('    - ' + $w) -ForegroundColor DarkGray }
