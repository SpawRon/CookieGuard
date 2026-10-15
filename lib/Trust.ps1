# ============================================================
#  CookieGuard - Trust.ps1
#  Список доверенных: то, про что вы уже разобрались.
#
#  Зачем. Инструмент намеренно подозрителен, и это правильно
#  ровно один раз. Если он каждый день кричит «КРИТИЧНО» на
#  программу, которую вы сами поставили и решили оставить, —
#  вы перестанете читать находки вообще, и настоящую тревогу
#  пропустите. Доверие — это не «выключить проверку», а
#  «я разобрался, больше не спрашивай».
#
#  ПОЧЕМУ ОДНОГО ОТПЕЧАТКА МАЛО.
#  Раньше доверие привязывалось только к отпечатку файла (или,
#  если отпечаток не сняли, к точному пути). Для обновляемой
#  программы это не работает вообще: claude.exe живёт сразу
#  в трёх местах
#      %LOCALAPPDATA%\Programs\...        — установленная копия
#      %USERPROFILE%\.local\bin\...       — копия командной строки
#      C:\Program Files\WindowsApps\...   — копия из магазина
#  и после каждого обновления меняет и папку, и отпечаток.
#  Пользователь жал «Доверять», запись сохранялась — и назавтра
#  программа снова в находках. Доверие выглядело сломанным,
#  потому что и было сломанным.
#
#  Поэтому у доверия к файлу теперь есть ОБЛАСТЬ:
#      exact      этот самый файл (отпечаток + путь)
#      program    эта программа любого издателя-владельца:
#                 совпали имя файла И действующая подпись
#      publisher  всё, что подписал этот издатель
#      folder     всё внутри этой папки
#
#  Область «program» и «publisher» опираются на ДЕЙСТВУЮЩУЮ
#  подпись: подделать её нельзя, не имея закрытого ключа
#  издателя. Поэтому доверие не превращается в дыру — в отличие
#  от доверия по одному имени файла, которым вредонос
#  воспользовался бы за секунду, назвавшись claude.exe.
#
#  Область «folder» таких гарантий не даёт и потому в интерфейсе
#  предлагается последней и с прямым предупреждением.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

function Get-CgTrustPath { Join-Path (Get-CgDir 'state') 'trusted.json' }

function Get-CgTrustList {
    $p = Get-CgTrustPath
    if (-not (Test-Path -LiteralPath $p)) { return @() }
    try {
        $raw = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json
        # ConvertFrom-Json на "[]" отдаёт $null, а @($null) — это массив
        # из одного пустого элемента, а не пустой массив. Без отсева
        # этот фантом попадал бы обратно в файл при каждом сохранении.
        return @($raw) | Where-Object { $null -ne $_ }
    } catch { return @() }
}

function Save-CgTrustList {
    param($List)
    try {
        $arr = @($List)
        # Пустой массив ConvertTo-Json отдаёт как $null, а не как "[]".
        # Без этой ветки снятие последнего доверия молча не сохранялось бы,
        # и запись возвращалась бы после перезапуска.
        if ($arr.Count -eq 0) {
            $json = '[]'
        } else {
            $json = $arr | ConvertTo-Json -Depth 5
            if ($null -eq $json) { $json = '[]' }
            elseif (-not $json.TrimStart().StartsWith('[')) { $json = "[$json]" }
        }
        [IO.File]::WriteAllText((Get-CgTrustPath), $json, [Text.UTF8Encoding]::new($true))
        Reset-CgTrustCache
        return $true
    } catch { return $false }
}

# кэш на время одного прохода проверки — файл читается один раз
$script:CgTrustCache = $null
$script:CgTrustRules = $null

function Reset-CgTrustCache {
    $script:CgTrustCache = $null
    $script:CgTrustRules = $null
}

# ------------------------------------------------------------
#  Приведение записи к одному виду
#
#  Записи, сделанные старой версией, знают только Type и Key.
#  Разбираем их здесь, а не при загрузке файла: так старый
#  список продолжает работать, и переписывать его на диске
#  не нужно — пользователь ничего не теряет.
# ------------------------------------------------------------
function ConvertTo-CgTrustEntry {
    param($Raw)
    $type = "$($Raw.Type)"
    if (-not $type) { $type = 'file' }

    $scope  = "$($Raw.Scope)"
    $key    = "$($Raw.Key)"
    $hash   = "$($Raw.Hash)"
    $path   = "$($Raw.Path)"
    $folder = "$($Raw.Folder)"
    $name   = "$($Raw.Name)"
    $signer = "$($Raw.Signer)"

    if ($type -eq 'file') {
        if (-not $scope) { $scope = 'exact' }
        # старая запись: ключ — это либо отпечаток, либо путь
        if (-not $hash -and -not $path -and -not $folder -and $key) {
            if ($key -match '^[0-9A-Fa-f]{64}$') { $hash = $key } else { $path = $key }
        }
        if ($path -and -not $name) { $name = Split-Path -Leaf $path }
    }

    return [PSCustomObject]@{
        Type   = $type
        Scope  = $scope
        Key    = $key
        Hash   = $hash
        Path   = $path
        Folder = $folder
        Name   = $name
        Signer = $signer
        Label  = "$($Raw.Label)"
        Note   = "$($Raw.Note)"
        Added  = "$($Raw.Added)"
    }
}

function Get-CgTrustRules {
    if ($null -ne $script:CgTrustRules) { return $script:CgTrustRules }
    $r = @(Get-CgTrustList | ForEach-Object { ConvertTo-CgTrustEntry $_ })
    $script:CgTrustRules = $r
    return $r
}

# карта точных ключей — только для расширений и находок
function Get-CgTrustMap {
    if ($null -ne $script:CgTrustCache) { return $script:CgTrustCache }
    $m = @{}
    foreach ($t in (Get-CgTrustRules)) {
        if ($t.Type -eq 'file') { continue }
        if (-not $t.Key) { continue }
        $m[("$($t.Type)|$($t.Key)").ToLowerInvariant()] = $t
    }
    $script:CgTrustCache = $m
    return $m
}

# ------------------------------------------------------------
#  Главная проверка: доверен ли этот исполняемый файл
#
#  Порядок проверок выбран по цене: сперва то, что считается
#  из одной строки, и только потом то, ради чего придётся
#  читать файл с диска. На списке из сотен процессов это
#  разница между мгновением и секундами.
# ------------------------------------------------------------
function Test-CgTrustedFile {
    param([string]$Path, [string]$Hash = '')

    $rules = @(Get-CgTrustRules | Where-Object { $_.Type -eq 'file' })
    if (-not $rules.Count) { return $null }

    $np = ''
    if ($Path) { $np = (Get-CgNormPath $Path).ToLowerInvariant() }
    $uh = ''
    if ($Hash) { $uh = $Hash.ToUpperInvariant() }

    # 1) путь и папка — ничего не читаем
    foreach ($r in $rules) {
        if ($r.Scope -eq 'exact' -and $np -and $r.Path) {
            if ($r.Path.ToLowerInvariant() -eq $np) { return $r }
        } elseif ($r.Scope -eq 'folder' -and $np -and $r.Folder) {
            $f = $r.Folder.ToLowerInvariant().TrimEnd('\')
            if ($f -and $np.StartsWith($f + '\')) { return $r }
        }
    }

    # 2) отпечаток — считаем, только если он кому-то из правил нужен
    $byHash = @($rules | Where-Object { $_.Scope -eq 'exact' -and $_.Hash })
    if ($byHash.Count) {
        if (-not $uh -and $Path) { $uh = "$(Get-CgHash $Path)".ToUpperInvariant() }
        if ($uh) {
            foreach ($r in $byHash) {
                if ($r.Hash.ToUpperInvariant() -eq $uh) { return $r }
            }
        }
    }

    # 3) издатель и программа — нужна подпись.
    #    Подпись обязана быть ДЕЙСТВУЮЩЕЙ: иначе доверие к издателю
    #    распространилось бы на файл с отвалившейся или поддельной
    #    подписью, то есть ровно на тот случай, который ищем.
    $bySig = @($rules | Where-Object { $_.Scope -eq 'publisher' -or $_.Scope -eq 'program' })
    if ($bySig.Count -and $Path) {
        $sig = Get-CgSignature $Path
        if ($sig -and $sig.Valid -and $sig.Signer) {
            $sn   = $sig.Signer.ToLowerInvariant()
            $leaf = ''
            if ($np) { $leaf = (Split-Path -Leaf $np) }
            foreach ($r in $bySig) {
                if (-not $r.Signer) { continue }
                if ($r.Signer.ToLowerInvariant() -ne $sn) { continue }
                if ($r.Scope -eq 'publisher') { return $r }
                if ($r.Name -and $r.Name.ToLowerInvariant() -eq $leaf) { return $r }
            }
        }
    }

    return $null
}

# Старый вход, которым пользуются проверки и монитор.
# Для файлов разбирает ключ и уходит в полную проверку — так
# все области доверия работают и в старых местах вызова.
function Test-CgTrusted {
    param([string]$Type, [string]$Key)
    if (-not $Key) { return $null }
    if ($Type -eq 'file') {
        if ($Key -match '^[0-9A-Fa-f]{64}$') { return Test-CgTrustedFile '' $Key }
        return Test-CgTrustedFile $Key
    }
    $m = Get-CgTrustMap
    return $m[("$Type|$Key").ToLowerInvariant()]
}

# Ключ доверия для файла: отпечаток, если он есть, иначе путь.
# Оставлен для совместимости со старыми местами вызова.
function Get-CgTrustKeyForFile {
    param([string]$Path, [string]$Hash = '')
    if ($Hash) { return $Hash }
    if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $h = Get-CgHash $Path
        if ($h) { return $h }
    }
    return (Get-CgNormPath $Path)
}

# ------------------------------------------------------------
#  Какие области доверия вообще имеет смысл предлагать
#  для этого файла — решает интерфейс, считает эта функция.
# ------------------------------------------------------------
function Get-CgTrustOptions {
    param([string]$Path, [string]$Hash = '')

    $out  = @()
    $np   = Get-CgNormPath $Path
    $leaf = ''
    if ($np) { $leaf = Split-Path -Leaf $np }
    $dir = ''
    if ($np) { $dir = Split-Path -Parent $np }

    $sig = $null
    if ($np) { $sig = Get-CgSignature $np }
    $signer = ''
    if ($sig -and $sig.Valid) { $signer = $sig.Signer }

    if ($signer) {
        # Для подписанной программы это правильный ответ по умолчанию:
        # переживает обновление и переезд в другую папку, но не
        # распространяется ни на что чужое.
        $out += [PSCustomObject]@{
            Scope = 'program'
            Title = "Эта программа — $leaf от «$signer»"
            Hint  = 'Любая копия и любое обновление, пока подпись издателя действует. Для обновляемых программ это верный выбор.'
            Safe  = 'good'
        }
        $out += [PSCustomObject]@{
            Scope = 'publisher'
            Title = "Всё, что подписал «$signer»"
            Hint  = 'Шире: любые программы этого издателя. Разумно, если вы ему и так доверяете.'
            Safe  = 'ok'
        }
    }

    $out += [PSCustomObject]@{
        Scope = 'exact'
        Title = 'Только этот файл'
        Hint  = $(if ($signer) {
                    'Самое узкое. После обновления программы доверие перестанет действовать и находка вернётся.'
                } else {
                    'Привязано к отпечатку: подменят файл — доверие само перестанет действовать.'
                })
        Safe  = 'good'
    }

    if ($dir) {
        $out += [PSCustomObject]@{
            Scope = 'folder'
            Title = "Всё в папке $dir"
            Hint  = 'Осторожно: доверие получит и то, что в эту папку положат потом. Берите, только если папка ваша.'
            Safe  = 'risky'
        }
    }

    return @($out)
}

# ------------------------------------------------------------
#  Добавление
# ------------------------------------------------------------
function Add-CgTrust {
    param(
        [ValidateSet('file', 'extension', 'finding')] [string]$Type,
        [string]$Key = '',
        [string]$Label = '',
        [string]$Note = '',
        [ValidateSet('exact', 'program', 'publisher', 'folder')] [string]$Scope = 'exact',
        [string]$Path = '',
        [string]$Hash = '',
        [string]$Signer = '',
        [string]$Folder = ''
    )

    $entry = $null

    if ($Type -eq 'file') {
        $np = Get-CgNormPath $Path
        $leaf = ''
        if ($np) { $leaf = Split-Path -Leaf $np }

        if (-not $Signer -and $np -and ($Scope -eq 'program' -or $Scope -eq 'publisher')) {
            $sig = Get-CgSignature $np
            if ($sig -and $sig.Valid) { $Signer = $sig.Signer }
        }
        if (-not $Hash -and $np -and $Scope -eq 'exact' -and (Test-Path -LiteralPath $np -PathType Leaf)) {
            $Hash = Get-CgHash $np
        }
        if (-not $Folder -and $np -and $Scope -eq 'folder') { $Folder = Split-Path -Parent $np }

        switch ($Scope) {
            'program' {
                if (-not $Signer) { return [PSCustomObject]@{ Ok = $false; Message = 'У файла нет действующей подписи — доверять программе целиком нельзя' } }
                $Key = "program:$Signer|$leaf"
            }
            'publisher' {
                if (-not $Signer) { return [PSCustomObject]@{ Ok = $false; Message = 'У файла нет действующей подписи — доверять издателю нельзя' } }
                $Key = "publisher:$Signer"
            }
            'folder' {
                if (-not $Folder) { return [PSCustomObject]@{ Ok = $false; Message = 'Не удалось определить папку' } }
                $Key = "folder:$Folder"
            }
            default {
                if ($Hash) { $Key = $Hash } elseif ($np) { $Key = $np }
            }
        }

        if (-not $Key) { return [PSCustomObject]@{ Ok = $false; Message = 'Нечего доверять: нет ни отпечатка, ни пути' } }
        if (-not $Label) { if ($leaf) { $Label = $leaf } else { $Label = $Key } }

        $entry = [PSCustomObject]@{
            Type   = 'file'
            Scope  = $Scope
            Key    = $Key
            Hash   = $Hash
            Path   = $np
            Folder = $Folder
            Name   = $leaf
            Signer = $Signer
            Label  = $Label
            Note   = $Note
            Added  = (Get-Date).ToString('o')
        }
    } else {
        if (-not $Key) { return [PSCustomObject]@{ Ok = $false; Message = 'Нечего доверять: нет ключа' } }
        if (-not $Label) { $Label = $Key }
        $entry = [PSCustomObject]@{
            Type   = $Type
            Scope  = ''
            Key    = $Key
            Hash   = ''
            Path   = ''
            Folder = ''
            Name   = ''
            Signer = ''
            Label  = $Label
            Note   = $Note
            Added  = (Get-Date).ToString('o')
        }
    }

    $list = @(Get-CgTrustList | Where-Object { -not ($_.Type -eq $entry.Type -and "$($_.Key)" -eq "$($entry.Key)") })
    $list += $entry
    $null = Save-CgTrustList $list
    Write-CgLog 'INFO' ("Доверено ($($entry.Type)/$($entry.Scope)): $($entry.Label) [$($entry.Key)] $Note")
    return [PSCustomObject]@{ Ok = $true; Message = "Добавлено в доверенные: $($entry.Label)"; Entry = $entry }
}

function Remove-CgTrust {
    param([string]$Type, [string]$Key)
    $list = @(Get-CgTrustList | Where-Object { -not ($_.Type -eq $Type -and "$($_.Key)" -eq "$Key") })
    $null = Save-CgTrustList $list
    Write-CgLog 'INFO' ("Доверие снято ($Type): $Key")
    return [PSCustomObject]@{ Ok = $true; Message = 'Доверие снято' }
}

function Get-CgTrustScopeText {
    param($Entry)
    if ($Entry.Type -ne 'file') {
        switch ($Entry.Type) {
            'extension' { return 'Расширение браузера' }
            'finding'   { return 'Находка' }
            default     { return "$($Entry.Type)" }
        }
    }
    switch ($Entry.Scope) {
        'program'   { return 'Программа (имя + издатель)' }
        'publisher' { return 'Издатель' }
        'folder'    { return 'Папка' }
        default     { return 'Один файл' }
    }
}

function Get-CgTrustView {
    $out = @()
    foreach ($t in (Get-CgTrustRules)) {
        $kindText = Get-CgTrustScopeText $t
        $added = $t.Added
        try { $added = ([datetime]$t.Added).ToString('dd.MM.yyyy HH:mm') } catch { }

        $covers = switch ($t.Scope) {
            'program'   { "любой файл $($t.Name), подписанный «$($t.Signer)»" }
            'publisher' { "любая программа, подписанная «$($t.Signer)»" }
            'folder'    { "всё внутри $($t.Folder)" }
            default     { if ($t.Hash) { "файл с отпечатком $($t.Hash.Substring(0, [Math]::Min(16, $t.Hash.Length)))…" } else { $t.Path } }
        }
        if ($t.Type -ne 'file') { $covers = $t.Key }

        $out += [PSCustomObject]@{
            Severity = 'OK'; Type = $t.Type; Scope = $t.Scope; Kind = $kindText
            Name = $t.Label; Key = $t.Key; Note = $t.Note; AddedText = $added
            Covers = $covers
            Title = $t.Label; Path = $t.Path; Hash = $t.Hash; Query = $t.Label
            Detail = "Что доверено: $($t.Label)`nОбласть: $kindText`nДействует на: $covers`nПричина: $($t.Note)`nДобавлено: $added`n`n" +
                     $(switch ($t.Scope) {
                         'program'   { 'Доверие держится на действующей подписи издателя. Подпись отвалится или файл подменят — доверие перестанет действовать само, даже если имя файла совпадает.' }
                         'publisher' { 'Доверие держится на действующей подписи издателя и охватывает все его программы.' }
                         'folder'    { 'ВНИМАНИЕ: доверие получит и то, что в эту папку положат потом. Снимите его, если папка перестала быть вашей.' }
                         default     { 'Доверие привязано к отпечатку файла. Файл подменят — отпечаток изменится, доверие перестанет действовать само.' }
                     })
        }
    }
    return @($out | Sort-Object Kind, Name)
}

# ------------------------------------------------------------
#  Применение доверия к находкам
# ------------------------------------------------------------
function Set-CgTrustOnFindings {
    param($Findings)
    $out = @()
    foreach ($f in @($Findings)) {
        $t = $null
        if ($f.Path -or $f.Hash) { $t = Test-CgTrustedFile ([string]$f.Path) ([string]$f.Hash) }
        if (-not $t) { $t = Test-CgTrusted 'finding' ("$($f.Area)|$($f.Title)") }
        if ($t) {
            $f.Severity = 'OK'
            $f.Order = 4
            $f.Title = $f.Title + '  — доверено вами'
            $f.Detail = $f.Detail + "`n`n--- ДОВЕРЕНО ---`nВы пометили это как разобранное" + $(if ($t.Note) { ": $($t.Note)" } else { '.' }) +
                        "`nОбласть доверия: " + (Get-CgTrustScopeText $t) + "`nСнять доверие можно в разделе «Доверенные»."
        }
        $out += $f
    }
    return $out
}
