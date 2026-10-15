# ============================================================
#  CookieGuard - VirusTotal.ps1
#  Собственная накапливаемая база вердиктов.
#
#  Как это закрывает отсутствие своих сигнатур.
#  Сигнатура — это отпечаток известного вредоноса. Держать свою
#  базу отпечатков бессмысленно: её уже держат десятки компаний.
#  VirusTotal опрашивает их все разом. Мы считаем SHA256 файла,
#  спрашиваем вердикт и СОХРАНЯЕМ его у себя. Со временем
#  накапливается местная база по тем файлам, которые реально
#  есть на этом компьютере, — и повторные проверки идут мгновенно
#  и без сети.
#
#  Граница, которую нельзя переходить: наружу уходит ТОЛЬКО хеш.
#  Файл не отправляется никогда. Хеш — односторонний отпечаток,
#  по нему невозможно восстановить содержимое, и если файл
#  VirusTotal не знает, он просто ответит «не найдено».
#  Поэтому проверять можно даже личные документы — утечки не будет.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

function Get-CgVtKeyPath   { Join-Path (Get-CgDir 'state') 'vt-key.txt' }
function Get-CgVtCachePath { Join-Path (Get-CgDir 'state') 'vt-verdicts.json' }

function Get-CgVtKey {
    $p = Get-CgVtKeyPath
    if (-not (Test-Path -LiteralPath $p)) { return '' }
    try { return (Get-Content -LiteralPath $p -Raw -Encoding UTF8).Trim() } catch { return '' }
}

function Set-CgVtKey {
    param([string]$Key)
    $p = Get-CgVtKeyPath
    [IO.File]::WriteAllText($p, "$Key".Trim(), [Text.UTF8Encoding]::new($false))
    # ключ — личный; закрываем доступ всем, кроме владельца
    try {
        $acl = Get-Acl -LiteralPath $p
        $acl.SetAccessRuleProtection($true, $false)
        $me = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($me, 'FullControl', 'Allow')))
        Set-Acl -LiteralPath $p -AclObject $acl
    } catch { }
}

# ---------- местная база вердиктов ----------

function Get-CgVtCache {
    $p = Get-CgVtCachePath
    $h = @{}
    if (Test-Path -LiteralPath $p) {
        try {
            $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
            foreach ($prop in $raw.PSObject.Properties) { $h[$prop.Name] = $prop.Value }
        } catch { }
    }
    return $h
}

function Save-CgVtCache {
    param($Cache)
    try {
        $o = New-Object PSObject
        foreach ($k in $Cache.Keys) { Add-Member -InputObject $o -NotePropertyName $k -NotePropertyValue $Cache[$k] }
        $json = $o | ConvertTo-Json -Depth 5
        [IO.File]::WriteAllText((Get-CgVtCachePath), $json, [Text.UTF8Encoding]::new($true))
    } catch { }
}

# ---------- запрос ----------

function Invoke-CgVtLookup {
    param([string]$Hash, [string]$Key)
    if (-not $Hash -or -not $Key) { return $null }
    $uri = "https://www.virustotal.com/api/v3/files/$Hash"
    try {
        $r = Invoke-RestMethod -Uri $uri -Headers @{ 'x-apikey' = $Key } -Method Get -TimeoutSec 25 -ErrorAction Stop
        $st = $r.data.attributes.last_analysis_stats
        $total = [int]$st.malicious + [int]$st.suspicious + [int]$st.undetected + [int]$st.harmless
        $names = @()
        if ($r.data.attributes.popular_threat_classification.suggested_threat_label) {
            $names += $r.data.attributes.popular_threat_classification.suggested_threat_label
        }
        return [PSCustomObject]@{
            Status    = 'known'
            Malicious = [int]$st.malicious
            Suspicious = [int]$st.suspicious
            Total     = $total
            Label     = ($names -join ', ')
            Name      = $r.data.attributes.meaningful_name
            Checked   = (Get-Date).ToString('o')
        }
    } catch {
        $code = 0
        try { $code = [int]$_.Exception.Response.StatusCode } catch { }
        if ($code -eq 404) {
            # VirusTotal такого файла не видел. Для самодельного или
            # редкого файла это норма, а не признак чистоты.
            return [PSCustomObject]@{ Status = 'unknown'; Malicious = 0; Suspicious = 0; Total = 0; Label = ''; Name = ''; Checked = (Get-Date).ToString('o') }
        }
        if ($code -eq 401) { return [PSCustomObject]@{ Status = 'badkey'; Malicious = 0; Suspicious = 0; Total = 0; Label = ''; Name = ''; Checked = (Get-Date).ToString('o') } }
        if ($code -eq 429) { return [PSCustomObject]@{ Status = 'ratelimit'; Malicious = 0; Suspicious = 0; Total = 0; Label = ''; Name = ''; Checked = (Get-Date).ToString('o') } }
        return [PSCustomObject]@{ Status = 'error'; Malicious = 0; Suspicious = 0; Total = 0; Label = "$($_.Exception.Message)"; Name = ''; Checked = (Get-Date).ToString('o') }
    }
}

function Get-CgVtRiskPercent {
    param($V)
    if (-not $V -or $V.Status -ne 'known' -or -not $V.Total) { return -1 }
    return [math]::Round((($V.Malicious + $V.Suspicious) * 100.0) / $V.Total)
}

function Get-CgVtSeverity {
    param($V)
    $p = Get-CgVtRiskPercent $V
    if ($p -lt 0) { return 'NOTE' }
    if ($V.Malicious -ge 5) { return 'CRIT' }
    if ($V.Malicious -ge 1) { return 'WARN' }
    if ($V.Suspicious -ge 2) { return 'WARN' }
    return 'OK'
}

# ---------- что имеет смысл проверять ----------
#
# Квота бесплатного ключа — 4 запроса в минуту и 500 в сутки.
# Проверять весь диск бессмысленно и невозможно. Берём только то,
# что реально может оказаться закладкой: неподписанное, лежащее
# в пользовательских папках, в автозапуске или в скриптах Adobe.

function Get-CgVtCandidates {
    param([int]$Max = 120)
    $seen = @{}
    $out = New-Object System.Collections.ArrayList

    function Add-Cand {
        param([string]$Path, [string]$Why)
        if (-not $Path) { return }
        $p = Get-CgNormPath $Path
        if (-not (Test-Path -LiteralPath $p -PathType Leaf)) { return }
        $k = $p.ToLowerInvariant()
        if ($seen.ContainsKey($k)) { return }
        $sig = Get-CgSignature $p
        if ($sig.Trusted) { return }     # подписано издателем, которому верим
        $cls = Get-CgPathClass $p
        if (@('system32', 'windows', 'windowsapps') -contains $cls) { return }
        $seen[$k] = $true
        $null = $out.Add([PSCustomObject]@{ Path = $p; Why = $Why; Signature = ($sig.Status + ' ' + $sig.Signer).Trim() })
    }

    foreach ($p in (Get-CgProcessList)) { if ($p.Path) { Add-Cand $p.Path 'запущенный процесс' } }
    foreach ($a in (Get-CgAutorunList)) { if ($a.Path) { Add-Cand $a.Path 'автозапуск' } }

    $since = (Get-Date).AddDays(-30)
    foreach ($r in @("$env:TEMP", "$env:USERPROFILE\Downloads", "$env:APPDATA", "$env:LOCALAPPDATA", "$env:ProgramData", "$env:PUBLIC")) {
        if (-not (Test-Path -LiteralPath $r)) { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $r -Recurse -Depth 3 -File -Force -ErrorAction SilentlyContinue |
                           Where-Object { $_.Extension -match '^\.(exe|dll|scr|jar|msi)$' -and $_.CreationTime -gt $since })) {
            Add-Cand $file.FullName 'новый исполняемый файл'
            if ($out.Count -ge $Max * 2) { break }
        }
    }
    foreach ($dir in (Get-CgAdobeScriptDirs)) {
        if ($dir -notmatch '(?i)\\AppData\\|\\ProgramData\\|\\(Startup|Shutdown|ScriptUI Panels)$') { continue }
        foreach ($file in (Get-ChildItem -LiteralPath $dir -Recurse -Depth 3 -File -ErrorAction SilentlyContinue |
                           Where-Object { $_.Extension -match '^\.(jsx|jsxbin|js)$' })) {
            Add-Cand $file.FullName 'скрипт Adobe'
        }
    }
    return @($out | Select-Object -First $Max)
}

# ---------- проверка пачки с учётом квоты ----------

function Invoke-CgVtScan {
    param(
        [int]$Max = 60,
        [int]$DelaySeconds = 16,      # 4 запроса в минуту у бесплатного ключа
        [int]$RecheckDays = 30,
        [scriptblock]$Progress
    )
    $key = Get-CgVtKey
    if (-not $key) {
        return [PSCustomObject]@{ Error = 'Не задан ключ VirusTotal'; Findings = @(); Checked = 0; FromCache = 0 }
    }
    $cache = Get-CgVtCache
    $cands = Get-CgVtCandidates -Max ($Max * 3)
    $findings = @()
    $checked = 0; $fromCache = 0; $i = 0

    foreach ($c in $cands) {
        $i++
        if ($checked -ge $Max) { break }
        $h = Get-CgHash $c.Path
        if (-not $h) { continue }

        $v = $null
        if ($cache.ContainsKey($h)) {
            $v = $cache[$h]
            $age = 999
            try { $age = ((Get-Date) - [datetime]$v.Checked).TotalDays } catch { }
            # вердикты меняются: то, что вчера было неизвестным, сегодня уже детектируется
            if ($age -le $RecheckDays) { $fromCache++ } else { $v = $null }
        }

        if (-not $v) {
            if ($Progress) { & $Progress ("$($checked + 1) из $Max — $(Split-Path -Leaf $c.Path)") }
            $v = Invoke-CgVtLookup -Hash $h -Key $key
            $checked++
            if ($v.Status -eq 'badkey') {
                return [PSCustomObject]@{ Error = 'VirusTotal не принял ключ'; Findings = $findings; Checked = $checked; FromCache = $fromCache }
            }
            if ($v.Status -eq 'ratelimit') {
                $findings += New-CgFinding 'NOTE' 'VirusTotal' 'Достигнут предел запросов' 'Бесплатный ключ: 4 запроса в минуту и 500 в сутки. Проверка продолжится в следующий раз — уже проверенное сохранено.'
                break
            }
            $cache[$h] = $v
            Save-CgVtCache $cache
            if ($DelaySeconds -gt 0) { Start-Sleep -Seconds $DelaySeconds }
        }

        $sev = Get-CgVtSeverity $v
        $pct = Get-CgVtRiskPercent $v
        if ($sev -eq 'OK') { continue }
        if ($v.Status -eq 'unknown') {
            # неизвестный файл интересен, только если он и так подозрителен
            if ($c.Why -notin @('автозапуск', 'скрипт Adobe')) { continue }
            $findings += New-CgFinding 'NOTE' 'VirusTotal' ('VirusTotal не знает этот файл: {0}' -f (Split-Path -Leaf $c.Path)) (
                "Файл: $($c.Path)`nSHA256: $h`nПочему проверяли: $($c.Why)`nПодпись: $($c.Signature)`n`nНеизвестен — значит, редкий. Для вашего собственного скрипта это норма.`nДля файла, который вы не ставили, — повод разобраться."
            ) $c.Path $h
            continue
        }
        $findings += New-CgFinding $sev 'VirusTotal' (
            '{0} — вредоносным считают {1} из {2} антивирусов ({3}%)' -f (Split-Path -Leaf $c.Path), $v.Malicious, $v.Total, $pct
        ) (
            "Файл: $($c.Path)`nSHA256: $h`nПочему проверяли: $($c.Why)`nПодпись: $($c.Signature)`n" +
            "Вредоносным: $($v.Malicious)   подозрительным: $($v.Suspicious)   всего проверок: $($v.Total)`n" +
            $(if ($v.Label) { "Классификация: $($v.Label)`n" } else { '' }) +
            "Проверено: $($v.Checked)`n`nПодробный отчёт: https://www.virustotal.com/gui/file/$h`n`n" +
            "Важно: один-два детекта из семидесяти — это чаще всего ложное срабатывание,`nособенно у самодельных программ и кейгенов. Пять и больше — уже серьёзно."
        ) $c.Path $h
    }

    Save-CgVtCache $cache
    return [PSCustomObject]@{
        Error = ''; Findings = @($findings); Checked = $checked; FromCache = $fromCache
        Candidates = $cands.Count; CacheSize = $cache.Count
    }
}

function Get-CgVtCacheFindings {
    # то, что уже накоплено — показывается мгновенно, без сети
    $cache = Get-CgVtCache
    $f = @()
    $bad = 0
    foreach ($h in $cache.Keys) {
        $v = $cache[$h]
        if ($v.Status -ne 'known') { continue }
        if ([int]$v.Malicious -lt 1) { continue }
        $bad++
    }
    $f += New-CgFinding 'INFO' 'VirusTotal' ('В местной базе вердиктов: {0} файлов, из них с детектами: {1}' -f $cache.Count, $bad) 'База пополняется при каждой проверке и работает без сети.'
    return $f
}
