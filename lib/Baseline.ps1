# ============================================================
#  CookieGuard - Baseline.ps1
#  Снимок-эталон и сравнение с ним.
#
#  Сигнатуры отвечают на вопрос «знаком ли нам этот вредонос».
#  Эталон отвечает на другой: «изменилось ли что-то с тех пор,
#  как было хорошо». Второй вопрос ловит и то, чего ещё нет ни
#  в одной базе, — потому что любой закрепившийся в системе
#  вредонос обязан что-то изменить: добавить автозапуск,
#  подменить скрипт, поставить расширение, развернуть трафик.
#  Молча прижиться ему негде.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

function Get-CgBaselinePath { Join-Path (Get-CgDir 'state') 'baseline.json' }

# ------------------------------------------------------------
#  Снятие снимка
# ------------------------------------------------------------
function New-CgBaselineData {
    param([scriptblock]$Progress)
    function Step { param([string]$T) if ($Progress) { & $Progress $T } }

    $snap = [ordered]@{}

    Step 'автозапуск'
    $autoruns = @{}
    foreach ($a in (Get-CgAutorunList)) {
        $h = ''
        if ($a.Path -and (Test-Path -LiteralPath $a.Path -PathType Leaf)) { $h = Get-CgHash $a.Path }
        $autoruns["$($a.Kind)|$($a.Name)"] = "$($a.Command)||$h"
    }
    $snap.autoruns = $autoruns

    Step 'расширения браузеров'
    $exts = @{}
    foreach ($e in (Get-CgExtensionList)) {
        $exts["$($e.Browser)|$($e.Id)"] = "$($e.Name)||$($e.Version)||$($e.Perms)"
    }
    $snap.extensions = $exts

    Step 'скрипты Adobe'
    $adobe = @{}
    foreach ($dir in (Get-CgAdobeScriptDirs)) {
        foreach ($file in (Get-ChildItem -LiteralPath $dir -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
                           Where-Object { $_.Extension -match '^\.(jsx|jsxbin)$' })) {
            $adobe[$file.FullName] = (Get-CgHash $file.FullName)
        }
    }
    $snap.adobe = $adobe

    Step 'корневые сертификаты'
    $certs = @{}
    foreach ($c in (Get-ChildItem Cert:\LocalMachine\Root -ErrorAction SilentlyContinue)) {
        $certs[$c.Thumbprint] = (Get-CgSignerName $c.Subject)
    }
    $snap.certs = $certs

    Step 'сеть и защита'
    $net = @{}
    $is = Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' -ErrorAction SilentlyContinue
    $net['proxy.enable'] = "$($is.ProxyEnable)"
    $net['proxy.server'] = "$($is.ProxyServer)"
    $net['proxy.pac'] = "$($is.AutoConfigURL)"
    $hostsPath = "$env:windir\System32\drivers\etc\hosts"
    if (Test-Path -LiteralPath $hostsPath) { $net['hosts'] = (Get-CgHash $hostsPath) }
    try {
        $pref = Get-MpPreference -ErrorAction Stop
        $net['defender.exclusions'] = ((@($pref.ExclusionPath) + @($pref.ExclusionProcess)) | Sort-Object) -join ' ; '
    } catch { }
    try {
        $st = Get-MpComputerStatus -ErrorAction Stop
        $net['defender.realtime'] = "$($st.RealTimeProtectionEnabled)"
        $net['defender.tamper'] = "$($st.IsTamperProtected)"
    } catch { }
    $snap.network = $net

    Step 'службы'
    $svc = @{}
    foreach ($s in (Get-CimInstance Win32_Service -ErrorAction SilentlyContinue)) {
        if ($s.StartMode -notin @('Auto', 'Manual')) { continue }
        $p = "$($s.PathName)"
        if ($p -match '(?i)\\windows\\system32\\svchost\.exe') { continue }
        $svc[$s.Name] = "$($s.StartMode)||$p"
    }
    $snap.services = $svc

    Step 'готово'
    return [PSCustomObject]@{
        Created  = (Get-Date).ToString('o')
        Computer = $env:COMPUTERNAME
        User     = $env:USERNAME
        Data     = $snap
    }
}

function Save-CgBaseline {
    param($Baseline)
    try {
        $json = $Baseline | ConvertTo-Json -Depth 8 -Compress
        [IO.File]::WriteAllText((Get-CgBaselinePath), $json, [Text.UTF8Encoding]::new($true))
        return $true
    } catch { return $false }
}

function Get-CgBaseline {
    $p = Get-CgBaselinePath
    if (-not (Test-Path -LiteralPath $p)) { return $null }
    try { return (Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { return $null }
}

function Test-CgBaselineExists { return (Test-Path -LiteralPath (Get-CgBaselinePath)) }

function Get-CgBaselineDate {
    $b = Get-CgBaseline
    if (-not $b) { return $null }
    try { return [datetime]$b.Created } catch { return $null }
}

# ------------------------------------------------------------
#  Сравнение
# ------------------------------------------------------------

# Сравниваются два разных типа: свежий снимок — это хеш-таблица,
# а загруженный из файла — PSCustomObject (так его отдаёт ConvertFrom-Json).
# У хеш-таблицы PSObject.Properties возвращает Keys/Values/Count, а вовсе
# не записи, поэтому разбирать их одинаково нельзя.
function ConvertTo-CgMap {
    param($Obj)
    $h = @{}
    if ($null -eq $Obj) { return $h }
    if ($Obj -is [System.Collections.IDictionary]) {
        foreach ($k in $Obj.Keys) { $h["$k"] = "$($Obj[$k])" }
        return $h
    }
    foreach ($p in $Obj.PSObject.Properties) { $h[$p.Name] = "$($p.Value)" }
    return $h
}

$script:CgBaselineSections = @(
    @{ Key = 'autoruns';   Title = 'Автозапуск';            AddSev = 'CRIT'; ChgSev = 'CRIT'; DelSev = 'NOTE' },
    @{ Key = 'extensions'; Title = 'Расширение браузера';   AddSev = 'WARN'; ChgSev = 'NOTE'; DelSev = 'NOTE' },
    @{ Key = 'adobe';      Title = 'Скрипт Adobe';          AddSev = 'CRIT'; ChgSev = 'CRIT'; DelSev = 'NOTE' },
    @{ Key = 'certs';      Title = 'Корневой сертификат';   AddSev = 'CRIT'; ChgSev = 'WARN'; DelSev = 'NOTE' },
    @{ Key = 'network';    Title = 'Сеть и защита';         AddSev = 'WARN'; ChgSev = 'WARN'; DelSev = 'WARN' },
    @{ Key = 'services';   Title = 'Служба';                AddSev = 'WARN'; ChgSev = 'WARN'; DelSev = 'NOTE' }
)

function Compare-CgBaseline {
    param([scriptblock]$Progress)
    $f = @()
    $base = Get-CgBaseline
    if (-not $base) {
        $f += New-CgFinding 'NOTE' 'Эталон' 'Эталон не снят' 'Нажмите «Снять эталон», когда будете уверены, что система в порядке. После этого программа начнёт замечать любое изменение автозапуска, расширений, скриптов Adobe, сертификатов и настроек сети — даже если такого вредоноса ещё нет ни в одной антивирусной базе.'
        return $f
    }

    $now = New-CgBaselineData -Progress $Progress
    $changes = 0

    foreach ($sec in $script:CgBaselineSections) {
        $old = ConvertTo-CgMap $base.Data.($sec.Key)
        $new = ConvertTo-CgMap $now.Data.($sec.Key)

        foreach ($k in $new.Keys) {
            if (-not $old.ContainsKey($k)) {
                $changes++
                $f += New-CgFinding $sec.AddSev 'Эталон' ('ПОЯВИЛОСЬ — {0}: {1}' -f $sec.Title, $k) (
                    "Чего раньше не было:`n$k`n`nЗначение:`n$($new[$k])`n`nЭталон снят: $($base.Created)`n`nЕсли вы в это время что-то устанавливали — всё в порядке, обновите эталон.`nЕсли нет — разбирайтесь именно с этим."
                ) (Get-CgBaselinePathHint $k $new[$k])
            } elseif ($old[$k] -ne $new[$k]) {
                $changes++
                $f += New-CgFinding $sec.ChgSev 'Эталон' ('ИЗМЕНИЛОСЬ — {0}: {1}' -f $sec.Title, $k) (
                    "Было:`n$($old[$k])`n`nСтало:`n$($new[$k])`n`nЭталон снят: $($base.Created)"
                ) (Get-CgBaselinePathHint $k $new[$k])
            }
        }
        foreach ($k in $old.Keys) {
            if (-not $new.ContainsKey($k)) {
                $changes++
                $f += New-CgFinding $sec.DelSev 'Эталон' ('ИСЧЕЗЛО — {0}: {1}' -f $sec.Title, $k) (
                    "Было в эталоне, сейчас нет:`n$k`n`nЗначение:`n$($old[$k])`n`nОбычно это удаление программы. Но так же выглядит и отключение защиты."
                )
            }
        }
    }

    if (-not $changes) {
        $f += New-CgFinding 'OK' 'Эталон' ('С момента снятия эталона ничего не изменилось ({0})' -f ([datetime]$base.Created).ToString('dd.MM.yyyy HH:mm')) 'Автозапуск, расширения, скрипты Adobe, сертификаты, прокси и службы — всё как было.'
    } else {
        $f += New-CgFinding 'INFO' 'Эталон' ('Изменений с момента эталона: {0}' -f $changes) ('Эталон снят: ' + ([datetime]$base.Created).ToString('dd.MM.yyyy HH:mm'))
    }
    return $f
}

# путь к файлу, если его видно в ключе или значении — чтобы работали кнопки
function Get-CgBaselinePathHint {
    param([string]$Key, [string]$Value)
    if ($Key -match '^[A-Za-z]:\\') { return $Key }
    if ($Value -match '([A-Za-z]:\\[^|";]+\.(exe|dll|jsx|jsxbin|cmd|bat|ps1|vbs|js))') { return $matches[1] }
    return ''
}
