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
        # «всё семейство» нарочно без имени: подставь сюда имя файла —
        # и правило «всё, что запускает Claude» сузится до одной программы
        $family = ($scope -eq 'parent' -and $key.EndsWith('|*'))
        if ($path -and -not $name -and -not $family) { $name = Split-Path -Leaf $path }
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
        # область «родитель»: чем опознан родитель и чем именно
        ParentKind  = "$($Raw.ParentKind)"
        ParentKey   = "$($Raw.ParentKey)"
        ParentLabel = "$($Raw.ParentLabel)"
        Pattern     = "$($Raw.Pattern)"
        Label  = "$($Raw.Label)"
        Note   = "$($Raw.Note)"
        Added  = "$($Raw.Added)"
    }
}

# ------------------------------------------------------------
#  Путь, переживающий обновление
#
#  claude.exe лежит по пути ...\claude-code\2.1.288\36aa8c97bf86\claude.exe:
#  в нём и номер версии, и случайная папка сборки. Завтра это другой
#  путь, а программа та же. Доверие «только этот файл» на таком пути
#  живёт до первого обновления — то есть бесполезно. Заменяем
#  версионные куски звёздочкой, имя файла оставляем как есть.
# ------------------------------------------------------------
function Get-CgPathPattern {
    param([string]$Path)
    $np = Get-CgNormPath $Path
    if (-not $np) { return '' }
    $parts = $np -split '\\'
    $res = @()
    for ($i = 0; $i -lt $parts.Count; $i++) {
        $s = $parts[$i]
        if ($i -eq $parts.Count - 1) { $res += $s; continue }
        if ($s -match '^\d+(\.\d+)+$')        { $res += '*'; continue }   # 2.1.288
        if ($s -match '^[0-9a-fA-F]{8,}$')    { $res += '*'; continue }   # 36aa8c97bf86
        if ($s -match '\d+\.\d+\.\d+')        { $res += '*'; continue }   # Claude_2.19675.1.0_x64__...
        $res += $s
    }
    return ($res -join '\')
}

# ------------------------------------------------------------
#  Чем опознать родителя
#
#  По порядку надёжности: действующая подпись переживает любое
#  обновление родителя; путь с заменёнными версиями переживает
#  обновление, но не переезд; имя процесса не переживает ничего и
#  подделывается в одну строку — поэтому оно последнее и помечено
#  как слабое.
# ------------------------------------------------------------
function Get-CgParentIdentity {
    param([string]$ParentPath, [string]$ParentName = '')
    $np = Get-CgNormPath $ParentPath
    if ($np) {
        $sig = Get-CgSignature $np
        if ($sig -and $sig.Valid -and $sig.Signer) {
            return [PSCustomObject]@{ Kind = 'sig'; Key = $sig.Signer; Label = "«$($sig.Signer)»"; Weak = $false }
        }
        $pat = Get-CgPathPattern $np
        if ($pat) {
            return [PSCustomObject]@{ Kind = 'pattern'; Key = $pat; Label = $pat; Weak = $false }
        }
    }
    $leaf = $ParentName
    if (-not $leaf -and $np) { $leaf = Split-Path -Leaf $np }
    if ($leaf) {
        return [PSCustomObject]@{ Kind = 'name'; Key = $leaf; Label = "процесса $leaf"; Weak = $true }
    }
    return $null
}

# Интерпретаторы: подписаны Microsoft и запускают что угодно.
# Доверять им «по издателю» — всё равно что не проверять вовсе.
$script:CgInterpreters = @('powershell.exe', 'pwsh.exe', 'cmd.exe', 'wscript.exe', 'cscript.exe',
                           'mshta.exe', 'rundll32.exe', 'regsvr32.exe', 'node.exe', 'python.exe',
                           'conhost.exe', 'bash.exe', 'wsl.exe')

# Кого нельзя считать «хозяином» цепочки процессов. Через проводник,
# службы и планировщик запускается вообще всё; браузер и офис — ровно
# те, чьих детей программа и сторожит. «Доверять всему, что запускает
# explorer.exe» значило бы выключить проверку процессов целиком.
$script:CgNotOwners = @('explorer.exe', 'svchost.exe', 'services.exe', 'wininit.exe', 'winlogon.exe', 'userinit.exe',
                        'taskhostw.exe', 'taskeng.exe', 'sihost.exe', 'runtimebroker.exe', 'dllhost.exe', 'wmiprvse.exe',
                        'chrome.exe', 'msedge.exe', 'brave.exe', 'firefox.exe', 'opera.exe', 'vivaldi.exe', 'browser.exe',
                        'winword.exe', 'excel.exe', 'powerpnt.exe', 'outlook.exe', 'acrobat.exe', 'acrord32.exe',
                        'pythonw.exe', 'py.exe', 'git.exe', 'sh.exe', 'mintty.exe', 'windowsterminal.exe', 'wt.exe',
                        'openconsole.exe', 'code.exe')

# Предки строки: настоящая цепочка, если она собрана, иначе хотя бы
# родитель. Старые строки (из отчёта, из прежней версии) знают только его.
function Get-CgAncestorList {
    param([string]$ParentPath = '', [string]$ParentName = '', $Ancestors = @())
    $a = @(@($Ancestors) | Where-Object { $_ -and ("$($_.Path)" -or "$($_.Name)") })
    if ($a.Count) { return $a }
    if ($ParentPath -or $ParentName) { return @([PSCustomObject]@{ Path = $ParentPath; Name = $ParentName }) }
    return @()
}

# Ближайший предок, которого можно назвать хозяином: тот, кто
# запустил интерпретатор, а не сам интерпретатор и не проводник.
function Get-CgOwnerAncestor {
    param($Ancestors)
    foreach ($a in @($Ancestors)) {
        $leaf = "$($a.Name)".ToLowerInvariant()
        if (-not $leaf -and "$($a.Path)") { $leaf = (Split-Path -Leaf "$($a.Path)").ToLowerInvariant() }
        if (-not $leaf) { continue }
        if ($script:CgInterpreters -contains $leaf) { continue }
        if ($script:CgNotOwners -contains $leaf) { return $null }
        if (-not "$($a.Path)") { return $null }
        return $a
    }
    return $null
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
    param([string]$Path, [string]$Hash = '', [string]$ParentPath = '', [string]$ParentName = '', $Ancestors = @())

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

    # 1a) путь с подстановкой: пережившее обновление доверие
    foreach ($r in $rules) {
        if ($r.Scope -ne 'pathpattern' -or -not $np -or -not $r.Pattern) { continue }
        if ($np -like $r.Pattern.ToLowerInvariant()) { return $r }
    }

    # 1b) родитель: «этот интерпретатор, но только из этих рук».
    #     Считается до чтения файла — нужна лишь подпись родителя,
    #     и та берётся из кеша подписей.
    #     Смотрим всю цепочку предков, а не одного родителя: railway.exe
    #     запускает node.exe, его — cmd.exe, его — Claude, и доверие
    #     «всё, что запускает Claude» обязано дойти до самого низа.
    $byParent = @($rules | Where-Object { $_.Scope -eq 'parent' })
    $chain = @(Get-CgAncestorList $ParentPath $ParentName $Ancestors)
    if ($byParent.Count -and $np -and $chain.Count) {
        $childLeaf = (Split-Path -Leaf $np)
        foreach ($a in $chain) {
            $pIdent = Get-CgParentIdentity "$($a.Path)" "$($a.Name)"
            if (-not $pIdent) { continue }
            foreach ($r in $byParent) {
                if ($r.Name -and $r.Name.ToLowerInvariant() -ne $childLeaf) { continue }
                if ("$($r.ParentKind)" -ne $pIdent.Kind) { continue }
                if ("$($r.ParentKey)".ToLowerInvariant() -ne "$($pIdent.Key)".ToLowerInvariant()) { continue }
                return $r
            }
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
    param([string]$Path, [string]$Hash = '', [string]$ParentPath = '', [string]$ParentName = '', $Ancestors = @())

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

    # Чем опознан родитель и стоит ли предлагать такую область
    $parentOpt = $null
    # Без имени самой программы правило «родитель» не на что вешать:
    # ключ строится из имени потомка. У защищённых процессов путь не
    # читается, и предлагать такую область там нечестно.
    if (($ParentPath -or $ParentName) -and $leaf) {
        $pIdent = Get-CgParentIdentity $ParentPath $ParentName
        if ($pIdent) {
            $pSafe = 'good'
            $pHint = 'Самая узкая область для интерпретатора: powershell.exe останется подозрительным везде, кроме запусков именно из этих рук.'
            if ($pIdent.Weak) {
                $pSafe = 'risky'
                $pHint = 'Родителя удалось опознать только по имени процесса, а имя подделывается в одну строку. Берите, если другого способа нет.'
            }
            $parentOpt = [PSCustomObject]@{
                Scope = 'parent'
                Title = "$leaf, запущенный из $($pIdent.Label)"
                Hint  = $pHint
                Safe  = $pSafe
                ParentPath = $ParentPath; ParentName = $ParentName; AnyChild = $false
            }
        }
    }
    $isInterp = ($leaf -and ($script:CgInterpreters -contains $leaf.ToLowerInvariant()))

    # Всё семейство программы: она сама запускает cmd, node, powershell,
    # и у каждого свой номер процесса. Доверять им по одному — значит
    # нажимать «Доверять» после каждого запуска. Держится на подписи
    # хозяина цепочки, поэтому подделать его не выйдет.
    $familyOpt = $null
    $owner = Get-CgOwnerAncestor (Get-CgAncestorList $ParentPath $ParentName $Ancestors)
    if ($owner) {
        $oIdent = Get-CgParentIdentity "$($owner.Path)" "$($owner.Name)"
        if ($oIdent -and -not $oIdent.Weak) {
            $oLeaf = Split-Path -Leaf "$($owner.Path)"
            $familyOpt = [PSCustomObject]@{
                Scope = 'parent'
                Title = "Всё, что запускает $oLeaf ($($oIdent.Label))"
                Hint  = 'Любой процесс, который запустит эта программа или её потомки, с любым номером. Для помощников вроде Claude, которые сами запускают cmd, node и PowerShell, это верный выбор.'
                Safe  = 'ok'
                ParentPath = "$($owner.Path)"; ParentName = "$($owner.Name)"; AnyChild = $true
            }
        }
    }
    # Интерпретатору и неподписанному файлу верного «по программе» нет —
    # тогда семейство и есть правильный ответ по умолчанию.
    $familyFirst = ($familyOpt -and ($isInterp -or -not $signer))
    if ($familyFirst) { $out += $familyOpt }

    # Для интерпретатора «родитель» — правильный ответ по умолчанию, и
    # потому он идёт первым, раньше издателя: powershell.exe подписан
    # Microsoft, и доверие «по издателю» здесь означает не проверять
    # его больше никогда.
    if ($parentOpt -and $isInterp) { $out += $parentOpt }

    if ($signer -and -not $isInterp) {
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

    if ($parentOpt -and -not $isInterp) { $out += $parentOpt }
    if ($familyOpt -and -not $familyFirst) { $out += $familyOpt }

    # Издателя для интерпретатора предлагаем последним и честно
    # называем, чем это плохо.
    if ($signer -and $isInterp) {
        $out += [PSCustomObject]@{
            Scope = 'publisher'
            Title = "Всё, что подписал «$signer»"
            Hint  = 'Очень широко: это системный интерпретатор, и такое доверие снимет вопросы к нему при любом запуске, кем бы он ни был запущен.'
            Safe  = 'risky'
        }
    }

    # Путь с версией внутри — доверие, переживающее обновление
    $pattern = ''
    if ($np) { $pattern = Get-CgPathPattern $np }
    if ($pattern -and $pattern -ne $np) {
        $out += [PSCustomObject]@{
            Scope = 'pathpattern'
            Title = "Эта программа по пути $pattern"
            Hint  = 'В пути есть номер версии или папка сборки. Такое доверие переживёт обновление программы, но не переезд в другое место.'
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
        [ValidateSet('file', 'extension', 'finding', 'cert')] [string]$Type,
        [string]$Key = '',
        [string]$Label = '',
        [string]$Note = '',
        [ValidateSet('exact', 'program', 'publisher', 'folder', 'parent', 'pathpattern')] [string]$Scope = 'exact',
        [string]$Path = '',
        [string]$Hash = '',
        [string]$Signer = '',
        [string]$Folder = '',
        [string]$ParentPath = '',
        [string]$ParentName = '',
        [string]$Pattern = '',
        [switch]$AnyChild
    )

    $ParentKind = ''
    $ParentKey = ''
    $ParentLabel = ''

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
            'parent' {
                $pIdent = Get-CgParentIdentity $ParentPath $ParentName
                if (-not $pIdent) { return [PSCustomObject]@{ Ok = $false; Message = 'Родителя опознать не удалось — доверять «по родителю» нечему' } }
                if (-not $leaf -and -not $AnyChild) { return [PSCustomObject]@{ Ok = $false; Message = 'Не удалось определить имя программы' } }
                $ParentKind  = $pIdent.Kind
                $ParentKey   = $pIdent.Key
                $ParentLabel = $pIdent.Label
                if ($AnyChild) {
                    $Key = "parent:$($pIdent.Kind)|$($pIdent.Key)|*"
                    $pLeaf = $ParentName
                    if (-not $pLeaf -and $ParentPath) { $pLeaf = Split-Path -Leaf $ParentPath }
                    if (-not $Label) { $Label = "всё, что запускает $pLeaf" }
                    $leaf = ''
                    $np = ''
                } else {
                    $Key = "parent:$($pIdent.Kind)|$($pIdent.Key)|$leaf"
                }
            }
            'pathpattern' {
                if (-not $Pattern) { $Pattern = Get-CgPathPattern $np }
                if (-not $Pattern) { return [PSCustomObject]@{ Ok = $false; Message = 'Не удалось построить путь с подстановкой' } }
                $Key = "pattern:$Pattern"
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
            ParentKind  = $ParentKind
            ParentKey   = $ParentKey
            ParentLabel = $ParentLabel
            Pattern     = $Pattern
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
            'cert'      { return 'Корневой сертификат' }
            'finding'   { return 'Находка' }
            default     { return "$($Entry.Type)" }
        }
    }
    switch ($Entry.Scope) {
        'program'     { return 'Программа (имя + издатель)' }
        'publisher'   { return 'Издатель' }
        'folder'      { return 'Папка' }
        'parent'      { return "Родитель ($($Entry.ParentLabel))" }
        'pathpattern' { return 'Путь без версии' }
        default       { return 'Один файл' }
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
            'parent'    { if ($t.Name) { "$($t.Name), запущенный из $($t.ParentLabel)" } else { "любой процесс, запущенный из $($t.ParentLabel) или его потомков" } }
            'pathpattern' { "файл по пути $($t.Pattern)" }
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
        # уже помеченное не помечаем второй раз: окно применяет доверие
        # к тем же находкам после каждого «Доверять»
        if ("$($f.Title)".EndsWith('  — доверено вами')) { $out += $f; continue }
        $t = $null
        if ($f.Path -or $f.Hash) {
            $pp = ''; $pn = ''; $anc = @()
            if ($f.PSObject.Properties['ParentPath']) { $pp = [string]$f.ParentPath }
            if ($f.PSObject.Properties['ParentName']) { $pn = [string]$f.ParentName }
            if ($f.PSObject.Properties['Ancestors'])  { $anc = @($f.Ancestors) }
            $t = Test-CgTrustedFile ([string]$f.Path) ([string]$f.Hash) $pp $pn $anc
        }
        if (-not $t -and $f.PSObject.Properties['ExtKey'] -and $f.ExtKey) { $t = Test-CgTrusted 'extension' ([string]$f.ExtKey) }
        if (-not $t -and $f.PSObject.Properties['Target'] -and $f.Target -and "$($f.Target.Kind)" -eq 'cert') {
            $t = Test-CgTrusted 'cert' ([string]$f.Target.Thumbprint)
        }
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
