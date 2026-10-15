# ============================================================
#  CookieGuard - Inspect.ps1
#  «Куда это ведёт»: карта находки.
#
#  Главная претензия к антивирусам в том, что они показывают
#  вердикт и прячут основание. «Обнаружено: Trojan.Generic» —
#  и дальше делай что хочешь. Человек не видит ни что это за
#  файл, ни откуда он взялся, ни что он тянет за собой.
#
#  Здесь наоборот. Находка — это всегда следствие; разбор
#  показывает причину целиком и ровно в том виде, в каком она
#  лежит на диске и в реестре:
#
#    ключ реестра   — все значения и все подветки, а если
#                     значение похоже на путь, рядом сразу
#                     встаёт сам файл с подписью;
#    папка          — каждый файл внутри, с подписью и
#                     размером, и отдельно те, что исполняются;
#    расширение     — манифест, объявленные права и те места
#                     в скриптах, где оно лезет в сеть и на диск;
#    запись запуска — файл, на который она указывает, и запущен
#                     ли он прямо сейчас.
#
#  И для любого объекта — «кто его сейчас держит»: процессы с
#  этим путём, их сетевые соединения, записи автозапуска и
#  задачи, которые на него ссылаются.
#
#  ЧЕГО ЗДЕСЬ НЕТ. Разбор не угадывает намерений. Он не пишет
#  «это вирус» — он показывает, из чего состоит объект и что с
#  ним связано, а вывод делает человек. Там, где знание
#  получено наблюдением (процесс запущен, соединение открыто),
#  так и сказано; где это лишь признак — сказано, что признак.
#
#  ГРАНИЦЫ ОБХОДА. Рекурсия ограничена: иначе разбор папки
#  Adobe ушёл бы в десятки тысяч файлов и окно повисло бы.
#  Когда предел достигнут, об этом написано в самом дереве, а
#  не скрыто.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$script:CgInspMaxDepth   = 4
$script:CgInspMaxFiles   = 300
$script:CgInspMaxSubkeys = 120
$script:CgInspMaxValues  = 60

# PSPath вида «Microsoft.PowerShell.Core\Registry::HKEY_...» прекрасно
# работает в Get-Item, но читать его человеку невозможно. Для обхода
# берём PSPath, для показа — короткую форму.
function ConvertTo-CgRegDisplay {
    param([string]$Path)
    # Обычный Replace, а не -replace: в префиксе есть обратная
    # косая черта, а в регулярном выражении она съедает следующую
    # букву и превращает шаблон в невалидный.
    $p = "$Path".Replace('Microsoft.PowerShell.Core\Registry::', '')
    $p = $p -replace '^HKEY_CURRENT_USER',  'HKCU:'
    $p = $p -replace '^HKEY_LOCAL_MACHINE', 'HKLM:'
    $p = $p -replace '^HKEY_CLASSES_ROOT',  'HKCR:'
    $p = $p -replace '^HKEY_USERS',         'HKU:'
    if (-not $p) { $p = "$Path" }
    return $p
}

function New-CgNode {
    param(
        [string]$Kind, [string]$Title, [string]$Detail = '',
        [string]$Severity = 'INFO', [string]$Path = ''
    )
    return [PSCustomObject]@{
        Kind     = $Kind
        Title    = $Title
        Detail   = $Detail
        Severity = $Severity
        Path     = $Path
        Children = (New-Object System.Collections.ArrayList)
    }
}

function Add-CgNode {
    param($Parent, $Child)
    if ($Parent -and $Child) { $null = $Parent.Children.Add($Child) }
    return $Child
}

# ------------------------------------------------------------
#  Похоже ли значение на путь к файлу, и какой именно
#
#  В реестре путь почти никогда не лежит в чистом виде: он с
#  аргументами, в кавычках, с %ProgramFiles% внутри. Без этого
#  разбора «значение» и «файл» остались бы разными мирами.
# ------------------------------------------------------------
function Get-CgPathFromValue {
    param($Value)
    $s = "$Value"
    if (-not $s) { return '' }
    $s = $s.Trim()
    if ($s -match '^"([^"]+)"') { $s = $matches[1] }
    $s = [Environment]::ExpandEnvironmentVariables($s)
    if ($s -notmatch '(?i)[a-z]:\\') { return '' }
    foreach ($m in [regex]::Matches($s, '(?i)\.(exe|dll|bat|cmd|vbs|js|ps1|scr|com|msi|jsx)(?=\s|$|"|,)')) {
        $cand = $s.Substring(0, $m.Index + $m.Length)
        if (Test-Path -LiteralPath $cand) { return $cand }
    }
    if (Test-Path -LiteralPath $s) { return $s }
    return ''
}

# ------------------------------------------------------------
#  Файл: подпись, размер, отпечаток
# ------------------------------------------------------------
function Get-CgInspectFile {
    param([string]$Path, [switch]$WithHash)

    $p = Get-CgNormPath $Path
    if (-not $p) { return (New-CgNode 'file' 'Путь пуст' '' 'NOTE') }

    if (-not (Test-Path -LiteralPath $p -PathType Leaf)) {
        return (New-CgNode 'file-missing' (Split-Path -Leaf $p) `
            "Путь: $p`nФайла по этому пути нет. Запись, ведущая в пустоту, — это либо мусор от удалённой программы, либо готовая точка перехвата: кто первым положит туда файл, тот и получит запуск." `
            'WARN' $p)
    }

    $fi  = Get-Item -LiteralPath $p -ErrorAction SilentlyContinue
    $sig = Get-CgSignature $p
    $sev = 'INFO'
    $sigTxt = 'нет данных'
    if ($sig) {
        $sigTxt = "$($sig.Status)"
        if ($sig.Signer) { $sigTxt += " — $($sig.Signer)" }
        if ($sig.Status -eq 'NotSigned') { $sev = 'NOTE' }
        elseif (-not $sig.Valid -and $sig.Status -notin @('Valid', 'UnknownError', 'Error')) { $sev = 'CRIT' }
    }

    $det = "Путь: $p`nРазмер: $([math]::Round($fi.Length / 1KB, 1)) КБ`nИзменён: $($fi.LastWriteTime)`nПодпись: $sigTxt"
    if ($WithHash) {
        $h = Get-CgHash $p
        if ($h) { $det += "`nSHA256: $h" }
    }
    return (New-CgNode 'file' $fi.Name $det $sev $p)
}

# ------------------------------------------------------------
#  Кто сейчас держит этот путь
#
#  Это и есть разница между «подозрительно выглядит» и
#  «работает прямо сейчас». Процесс, соединение и задача —
#  наблюдаемые факты, а не признаки.
# ------------------------------------------------------------
function Get-CgInspectUsage {
    param([string]$Path)

    $node = New-CgNode 'usage' 'Что с этим связано сейчас' '' 'INFO' $Path
    $p = Get-CgNormPath $Path
    if (-not $p) { return $node }
    $leaf = Split-Path -Leaf $p

    # --- процессы ---
    $procs = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
               Where-Object { $_.ExecutablePath -and (Get-CgNormPath $_.ExecutablePath) -ieq $p })
    if ($procs.Count) {
        foreach ($pr in $procs) {
            $n = Add-CgNode $node (New-CgNode 'process' ("Запущен: {0} (PID {1})" -f $pr.Name, $pr.ProcessId) `
                ("Командная строка: $($pr.CommandLine)`nРодитель: PID $($pr.ParentProcessId)") 'WARN' $p)

            # соединения этого процесса — куда он ходит
            $conns = @(Get-NetTCPConnection -OwningProcess $pr.ProcessId -State Established -ErrorAction SilentlyContinue)
            foreach ($c in ($conns | Select-Object -First 10)) {
                $null = Add-CgNode $n (New-CgNode 'net' ("Соединение: {0}:{1}" -f $c.RemoteAddress, $c.RemotePort) '' 'NOTE')
            }
        }
    } else {
        $null = Add-CgNode $node (New-CgNode 'none' 'Сейчас не запущен' '' 'OK')
    }

    # --- автозапуск, ссылающийся на этот путь ---
    foreach ($hive in @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
                        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
                        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
                        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce')) {
        $it = Get-Item -LiteralPath $hive -ErrorAction SilentlyContinue
        if (-not $it) { continue }
        foreach ($vn in @($it.GetValueNames())) {
            $v = "$($it.GetValue($vn))"
            # Сравниваем разобранный путь, а не подстроку: иначе
            # SecurityHealthSystray.exe считается упоминанием systray.exe.
            $vp = Get-CgPathFromValue $v
            $same = $false
            if ($vp) {
                if ((Get-CgNormPath $vp) -ieq $p) { $same = $true }
                elseif ((Split-Path -Leaf $vp) -ieq $leaf) { $same = $true }
            }
            if ($same) {
                $null = Add-CgNode $node (New-CgNode 'autorun' ("Автозапуск: $vn") "Где: $hive`nКоманда: $v" 'WARN' $hive)
            }
        }
    }

    # --- задачи планировщика ---
    foreach ($t in (Get-ScheduledTask -ErrorAction SilentlyContinue)) {
        foreach ($a in @($t.Actions)) {
            $ap = "$($a.Execute)"
            $hit = $false
            if ($ap) {
                if ((Get-CgNormPath ($ap.Trim('"'))) -ieq $p) { $hit = $true }
                elseif ((Split-Path -Leaf ($ap.Trim('"'))) -ieq $leaf) { $hit = $true }
            }
            if ($hit) {
                $null = Add-CgNode $node (New-CgNode 'task' ("Задача: $($t.TaskPath)$($t.TaskName)") `
                    ("Состояние: $($t.State)`nЗапускает: $($a.Execute) $($a.Arguments)") 'WARN')
            }
        }
    }
    return $node
}

# ------------------------------------------------------------
#  Ключ реестра целиком: значения и подветки
# ------------------------------------------------------------
function Get-CgInspectRegKey {
    param([string]$Path, [int]$Depth = 0, [string]$Highlight = '')

    $key = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $key) {
        return (New-CgNode 'regkey-missing' (ConvertTo-CgRegDisplay $Path) 'Ключа нет' 'NOTE' (ConvertTo-CgRegDisplay $Path))
    }

    $disp = ConvertTo-CgRegDisplay $Path
    $node = New-CgNode 'regkey' (Split-Path -Leaf $disp) "Ключ: $disp" 'INFO' $disp

    # --- значения ---
    $vals = @($key.GetValueNames())
    $i = 0
    foreach ($vn in $vals) {
        if ($i -ge $script:CgInspMaxValues) {
            $null = Add-CgNode $node (New-CgNode 'limit' ("…ещё значений: {0}" -f ($vals.Count - $i)) 'Показаны не все: предел обхода' 'NOTE')
            break
        }
        $i++
        $raw  = $key.GetValue($vn, $null, 'DoNotExpandEnvironmentNames')
        $kind = "$($key.GetValueKind($vn))"
        $shown = $vn
        if (-not $shown) { $shown = '(по умолчанию)' }
        $sev = 'INFO'
        if ($Highlight -and $vn -ieq $Highlight) { $sev = 'CRIT' }

        $vnode = Add-CgNode $node (New-CgNode 'regvalue' ("{0} = {1}" -f $shown, $raw) "Тип: $kind`nКлюч: $disp" $sev $disp)

        # значение, которое на самом деле путь — показываем сам файл
        $fp = Get-CgPathFromValue $raw
        if ($fp) { $null = Add-CgNode $vnode (Get-CgInspectFile $fp) }
    }

    # --- подветки ---
    if ($Depth -lt $script:CgInspMaxDepth) {
        $subs = @(Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue)
        $j = 0
        foreach ($s in $subs) {
            if ($j -ge $script:CgInspMaxSubkeys) {
                $null = Add-CgNode $node (New-CgNode 'limit' ("…ещё подветок: {0}" -f ($subs.Count - $j)) 'Показаны не все: предел обхода' 'NOTE')
                break
            }
            $j++
            $null = Add-CgNode $node (Get-CgInspectRegKey $s.PSPath ($Depth + 1) $Highlight)
        }
    } elseif (@(Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue).Count) {
        $null = Add-CgNode $node (New-CgNode 'limit' '…глубже не разбирали' "Предел глубины $($script:CgInspMaxDepth)" 'NOTE')
    }
    return $node
}

# ------------------------------------------------------------
#  Что скрипт делает: сеть, диск, запуск процессов
#
#  Это не анализ поведения, а честный grep по исходнику. Он
#  отвечает на вопрос «а оно вообще умеет лезть в сеть?» —
#  для расширения, у которого нет подписи, это и есть главный
#  вопрос.
# ------------------------------------------------------------
$script:CgInspSigns = @(
    @{ Rx = '(?i)XMLHttpRequest|\bfetch\s*\(|WebSocket|\.ajax\s*\(';          What = 'выход в сеть' },
    @{ Rx = '(?i)require\s*\(\s*[''"]child_process|\.exec\s*\(|spawn\s*\(';   What = 'запуск программ' },
    @{ Rx = '(?i)require\s*\(\s*[''"]fs[''"]|writeFile|readFile|\.unlink\s*\('; What = 'работа с файлами' },
    @{ Rx = '(?i)cep\.process|cep\.fs|__adobe_cep__';                          What = 'системный мост CEP' },
    @{ Rx = '(?i)eval\s*\(|new\s+Function\s*\(|atob\s*\(';                     What = 'выполнение строки как кода' }
)

function Get-CgInspectScript {
    param([string]$Path)
    $hits = @()
    try {
        $txt = Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
        if (-not $txt) { return $hits }
        foreach ($s in $script:CgInspSigns) {
            $m = [regex]::Matches($txt, $s.Rx)
            if ($m.Count) { $hits += ("{0} ({1})" -f $s.What, $m.Count) }
        }
    } catch { }
    return $hits
}

# ------------------------------------------------------------
#  Папка целиком
# ------------------------------------------------------------
function Get-CgInspectFolder {
    param([string]$Path, [int]$Depth = 0, [ref]$Budget)

    if (-not $Budget) {
        $b = $script:CgInspMaxFiles
        $Budget = [ref]$b
    }

    $di = Get-Item -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $di) { return (New-CgNode 'folder-missing' $Path 'Папки нет' 'NOTE' $Path) }

    $files = @(Get-ChildItem -LiteralPath $Path -File -Force -ErrorAction SilentlyContinue)
    $dirs  = @(Get-ChildItem -LiteralPath $Path -Directory -Force -ErrorAction SilentlyContinue)
    $total = 0
    foreach ($x in $files) { $total += $x.Length }

    $node = New-CgNode 'folder' $di.Name `
        ("Путь: $Path`nФайлов здесь: $($files.Count), папок: $($dirs.Count)`nОбъём файлов здесь: $([math]::Round($total / 1KB, 1)) КБ") `
        'INFO' $Path

    foreach ($fl in $files) {
        if ($Budget.Value -le 0) {
            $null = Add-CgNode $node (New-CgNode 'limit' '…файлов больше, чем показано' 'Предел обхода' 'NOTE')
            return $node
        }
        $Budget.Value = $Budget.Value - 1

        $fn = Get-CgInspectFile $fl.FullName
        # исполняемое и скрипты — то, ради чего папку и смотрят
        if ($fl.Extension -match '(?i)^\.(js|jsx|vbs|ps1|bat|cmd|html|htm)$') {
            foreach ($h in (Get-CgInspectScript $fl.FullName)) {
                $null = Add-CgNode $fn (New-CgNode 'behaviour' $h 'Найдено в тексте файла' 'WARN' $fl.FullName)
                if ($fn.Severity -eq 'INFO') { $fn.Severity = 'NOTE' }
            }
        }
        $null = Add-CgNode $node $fn
    }

    if ($Depth -lt $script:CgInspMaxDepth) {
        foreach ($d in $dirs) {
            $null = Add-CgNode $node (Get-CgInspectFolder $d.FullName ($Depth + 1) $Budget)
        }
    } elseif ($dirs.Count) {
        $null = Add-CgNode $node (New-CgNode 'limit' '…глубже не разбирали' '' 'NOTE')
    }
    return $node
}

# ------------------------------------------------------------
#  Манифест расширения Adobe CEP: что оно себе объявило
# ------------------------------------------------------------
function Get-CgInspectCep {
    param([string]$Folder)
    $mf = Join-Path $Folder 'CSXS\manifest.xml'
    if (-not (Test-Path -LiteralPath $mf)) { return $null }
    $node = New-CgNode 'manifest' 'Манифест расширения' "Файл: $mf" 'INFO' $mf
    try {
        [xml]$x = Get-Content -LiteralPath $mf -Raw -ErrorAction Stop
        foreach ($e in @($x.ExtensionManifest.ExtensionList.Extension)) {
            $null = Add-CgNode $node (New-CgNode 'cep-id' ("Идентификатор: $($e.Id)") '' 'INFO')
        }
        $hosts = @()
        foreach ($h in @($x.ExtensionManifest.ExecutionEnvironment.HostList.Host)) { $hosts += "$($h.Name) $($h.Version)" }
        if ($hosts.Count) {
            $null = Add-CgNode $node (New-CgNode 'cep-host' ("Встраивается в: " + ($hosts -join ', ')) '' 'INFO')
        }
        # CEPEngine / node: право ходить мимо песочницы
        $raw = Get-Content -LiteralPath $mf -Raw
        if ($raw -match '(?i)--enable-nodejs') {
            $null = Add-CgNode $node (New-CgNode 'cep-node' 'Включён Node.js' 'Расширение может работать с файлами и сетью напрямую, минуя ограничения панели.' 'CRIT' $mf)
        }
        if ($raw -match '(?i)--mixed-context') {
            $null = Add-CgNode $node (New-CgNode 'cep-mixed' 'Общий контекст для всех панелей' '' 'NOTE' $mf)
        }
    } catch {
        $null = Add-CgNode $node (New-CgNode 'error' 'Манифест не разобрался' "$($_.Exception.Message)" 'NOTE')
    }
    return $node
}

# ------------------------------------------------------------
#  Точка входа: разобрать находку
# ------------------------------------------------------------
function Get-CgInspection {
    param($Finding)

    if (-not $Finding) { return (New-CgNode 'empty' 'Нечего разбирать' '' 'NOTE') }

    $t = $Finding.Target
    $root = New-CgNode 'root' "$($Finding.Title)" "$($Finding.Detail)" "$($Finding.Severity)"

    # --- без Target разбираем по пути, если он есть ---
    if (-not $t) {
        $p = "$($Finding.Path)"
        if ($p -and (Test-Path -LiteralPath $p -PathType Container)) {
            $null = Add-CgNode $root (Get-CgInspectFolder $p)
            $null = Add-CgNode $root (Get-CgInspectUsage $p)
        } elseif ($p) {
            $null = Add-CgNode $root (Get-CgInspectFile $p -WithHash)
            $null = Add-CgNode $root (Get-CgInspectUsage $p)
        } else {
            $null = Add-CgNode $root (New-CgNode 'none' 'У этой находки нет объекта на диске или в реестре' 'Разбирать нечего: находка описывает состояние системы, а не предмет.' 'NOTE')
        }
        return $root
    }

    switch ("$($t.Kind)") {

        'regvalue' {
            # Весь ключ целиком, с подсветкой того значения, из-за
            # которого находка появилась: человек видит не только
            # «PlayerDebugMode = 1», но и что ещё лежит рядом.
            $null = Add-CgNode $root (Get-CgInspectRegKey "$($t.Path)" 0 "$($t.Name)")
            $fp = Get-CgPathFromValue $t.Was
            if ($fp) {
                $null = Add-CgNode $root (Get-CgInspectFile $fp -WithHash)
                $null = Add-CgNode $root (Get-CgInspectUsage $fp)
            }
        }

        'runvalue' {
            $n = Add-CgNode $root (New-CgNode 'regvalue' ("$($t.Name) = $($t.Command)") "Где прописано: $($t.Path)" 'WARN' "$($t.Path)")
            $fp = "$($t.File)"
            if (-not $fp) { $fp = Get-CgPathFromValue $t.Command }
            if ($fp) {
                $null = Add-CgNode $n (Get-CgInspectFile $fp -WithHash)
                $null = Add-CgNode $root (Get-CgInspectUsage $fp)
            }
        }

        'runfile' {
            $null = Add-CgNode $root (Get-CgInspectFile "$($t.Path)" -WithHash)
            $null = Add-CgNode $root (Get-CgInspectUsage "$($t.Path)")
        }

        'task' {
            $full = "$($t.Name)"
            $tn = Split-Path -Leaf $full
            $tp = Split-Path -Parent $full
            if (-not $tp) { $tp = '\' }
            if (-not $tp.EndsWith('\')) { $tp = $tp + '\' }
            $task = Get-ScheduledTask -TaskPath $tp -TaskName $tn -ErrorAction SilentlyContinue
            if ($task) {
                $tnode = Add-CgNode $root (New-CgNode 'task' "Задача $full" "Состояние: $($task.State)`nАвтор: $($task.Author)" 'WARN')
                foreach ($a in @($task.Actions)) {
                    $an = Add-CgNode $tnode (New-CgNode 'task-action' ("Запускает: $($a.Execute) $($a.Arguments)") '' 'INFO')
                    $fp = Get-CgPathFromValue $a.Execute
                    if (-not $fp) { $fp = "$($a.Execute)" }
                    if ($fp) { $null = Add-CgNode $an (Get-CgInspectFile $fp) }
                }
                foreach ($tr in @($task.Triggers)) {
                    $null = Add-CgNode $tnode (New-CgNode 'task-trigger' ("Когда: $($tr.CimClass.CimClassName -replace 'MSFT_Task','' -replace 'Trigger','')") "$($tr.StartBoundary)" 'INFO')
                }
            } else {
                $null = Add-CgNode $root (New-CgNode 'task-missing' "Задача $full не найдена" '' 'NOTE')
            }
            if ("$($t.File)") { $null = Add-CgNode $root (Get-CgInspectUsage "$($t.File)") }
        }

        'folder' {
            $cep = Get-CgInspectCep "$($t.Path)"
            if ($cep) { $null = Add-CgNode $root $cep }
            $null = Add-CgNode $root (Get-CgInspectFolder "$($t.Path)")
            $null = Add-CgNode $root (Get-CgInspectUsage "$($t.Path)")
        }

        'service' {
            $svc = Get-CimInstance Win32_Service -Filter ("Name='{0}'" -f ($t.Name -replace "'", "''")) -ErrorAction SilentlyContinue
            if ($svc) {
                $sn = Add-CgNode $root (New-CgNode 'service' "Служба $($svc.Name)" "Отображается как: $($svc.DisplayName)`nСостояние: $($svc.State)`nЗапуск: $($svc.StartMode)`nКоманда: $($svc.PathName)" 'WARN')
                $fp = Get-CgPathFromValue $svc.PathName
                if ($fp) { $null = Add-CgNode $sn (Get-CgInspectFile $fp -WithHash) }
            }
        }

        default {
            $p = "$($t.Path)"
            if ($p -and (Test-Path -LiteralPath $p -PathType Container)) { $null = Add-CgNode $root (Get-CgInspectFolder $p) }
            elseif ($p) { $null = Add-CgNode $root (Get-CgInspectFile $p -WithHash) }
            if ($p) { $null = Add-CgNode $root (Get-CgInspectUsage $p) }
        }
    }
    return $root
}

# ------------------------------------------------------------
#  Плоский вид дерева — для окна и для отчёта
# ------------------------------------------------------------
function ConvertTo-CgFlatTree {
    param($Node, [int]$Depth = 0)
    $out = @()
    if (-not $Node) { return $out }
    $out += [PSCustomObject]@{
        Depth    = $Depth
        Kind     = $Node.Kind
        Severity = $Node.Severity
        Title    = $Node.Title
        Detail   = $Node.Detail
        Path     = $Node.Path
        Indent   = ('    ' * $Depth)
    }
    foreach ($c in @($Node.Children)) { $out += ConvertTo-CgFlatTree $c ($Depth + 1) }
    return $out
}
