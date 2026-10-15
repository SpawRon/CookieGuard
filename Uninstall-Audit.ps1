# ============================================================
#  CookieGuard - Uninstall-Audit.ps1
#  Снимает аудит, возвращает систему в исходное состояние.
# ============================================================

. (Join-Path $PSScriptRoot 'lib\Core.ps1')
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

if (-not (Test-CgAdmin)) {
    Write-Host 'Нужны права администратора.' -ForegroundColor Red
    exit 1
}

Write-CgHead 'Отключение аудита'

$list = Join-Path (Get-CgDir 'state') 'audited-files.txt'
$paths = @()
if (Test-Path -LiteralPath $list) { $paths = Get-Content -LiteralPath $list -Encoding UTF8 }
# плюс всё, что найдём сейчас — на случай, если список потерялся
$paths += (Get-CgTargetFiles | ForEach-Object { $_.Path })
$paths += ($paths | ForEach-Object { Split-Path -Parent $_ })
$paths = $paths | Where-Object { $_ } | Sort-Object -Unique

$everyone = New-Object System.Security.Principal.SecurityIdentifier 'S-1-1-0'
$n = 0
foreach ($p in $paths) {
    if (-not (Test-Path -LiteralPath $p)) { continue }
    try {
        $acl = Get-Acl -LiteralPath $p -Audit -ErrorAction Stop
        $removed = $false
        foreach ($r in @($acl.GetAuditRules($true, $false, [System.Security.Principal.SecurityIdentifier]))) {
            if ($r.IdentityReference -eq $everyone) {
                $null = $acl.RemoveAuditRule($r)
                $removed = $true
            }
        }
        if ($removed) { Set-Acl -LiteralPath $p -AclObject $acl -ErrorAction Stop; $n++ }
    } catch { }
}
Write-CgItem 'OK' "Правила аудита сняты с объектов: $n"

$fsGuid = '{0CCE921D-69AE-11D9-BED3-505054503030}'
& auditpol /set /subcategory:$fsGuid /success:disable 2>&1 | Out-Null
Write-CgItem 'OK' 'Политика аудита файловой системы выключена'

# журнал запуска программ, если он включался
$pcGuid = '{0CCE922B-69AE-11D9-BED3-505054503030}'
& auditpol /set /subcategory:$pcGuid /success:disable 2>&1 | Out-Null
$k = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System\Audit'
try { Remove-ItemProperty -Path $k -Name 'ProcessCreationIncludeCmdLine_Enabled' -ErrorAction SilentlyContinue } catch { }
Write-CgItem 'OK' 'Журнал запуска программ выключен'
Write-Host ''
Write-Host '  Система возвращена в исходное состояние.' -ForegroundColor Green
