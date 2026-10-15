# ============================================================
#  CookieGuard - Remedy.ps1
#  «Исправить»: действия, которые убирают саму причину находки.
#
#  Зачем это вообще. До сих пор окно умело только показать и
#  предложить «довериться». Человек видел, что у него включена
#  загрузка неподписанных расширений Adobe в восемнадцати
#  ключах, — и не мог сделать с этим ничего, кроме как закрыть
#  на это глаза. Находка, с которой нельзя ничего сделать,
#  учит не читать находки.
#
#  ТРИ ПРАВИЛА, БЕЗ КОТОРЫХ ЭТОГО ФАЙЛА НЕ БЫЛО БЫ.
#
#  1. Сначала показать, потом делать. У каждого исправления
#     есть Plan — список того, что именно изменится, с точными
#     путями и значениями. Человек читает его до того, как
#     что-то произошло. Инструмент безопасности, который молча
#     правит реестр, ничем не лучше того, что он ищет.
#
#  2. Ничего не удалять насовсем. Значение реестра перед
#     удалением целиком записывается в запись отката; папка не
#     стирается, а переезжает в карантин. «Исправить» должно
#     быть обратимым, иначе им страшно пользоваться — а
#     страшным инструментом не пользуются вовсе.
#
#  3. Чинить по объекту, а не по тексту. Исправление смотрит на
#     Target находки (ключ, значение, папка, задача), а не
#     разбирает Detail. Detail написан для человека и
#     переписывается при любой правке формулировок.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

# ------------------------------------------------------------
#  Записи отката
# ------------------------------------------------------------
function Get-CgUndoDir { return (Get-CgDir 'undo') }

function New-CgUndoRecord {
    param([string]$FixId, [string]$Title, $Items)
    $id = (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
    $rec = [PSCustomObject]@{
        Id    = $id
        FixId = $FixId
        Title = $Title
        When  = (Get-Date).ToString('o')
        Items = @($Items)
    }
    try {
        $p = Join-Path (Get-CgUndoDir) "$id.json"
        $rec | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $p -Encoding UTF8
    } catch { }
    return $rec
}

function Get-CgUndoList {
    $out = @()
    foreach ($m in (Get-ChildItem -LiteralPath (Get-CgUndoDir) -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
        try { $out += (Get-Content -LiteralPath $m.FullName -Raw -Encoding UTF8 | ConvertFrom-Json) } catch { }
    }
    return $out
}

# ------------------------------------------------------------
#  Реестр: прочитать значение вместе с его типом
#
#  Тип обязателен. Записать DWORD обратно строкой — значит
#  вернуть не то, что было, и сломать то, что чинили.
# ------------------------------------------------------------
function Get-CgRegEntry {
    param([string]$Path, [string]$Name)
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        $names = @($item.GetValueNames())
        if ($names -notcontains $Name) { return $null }
        return [PSCustomObject]@{
            Path  = $Path
            Name  = $Name
            Value = $item.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
            Kind  = "$($item.GetValueKind($Name))"
        }
    } catch { return $null }
}

function Restore-CgRegEntry {
    param($Entry)
    if (-not $Entry) { return $false }
    try {
        if (-not (Test-Path -LiteralPath $Entry.Path)) { $null = New-Item -Path $Entry.Path -Force -ErrorAction Stop }
        $kind = "$($Entry.Kind)"
        if (-not $kind -or $kind -eq 'Unknown') { $kind = 'String' }
        $null = New-ItemProperty -LiteralPath $Entry.Path -Name $Entry.Name -Value $Entry.Value -PropertyType $kind -Force -ErrorAction Stop
        return $true
    } catch { return $false }
}

# Нужны ли для этой ветки права администратора
function Test-CgRegNeedsAdmin {
    param([string]$Path)
    return ("$Path" -match '^(?i)(HKLM:|HKEY_LOCAL_MACHINE|HKCR:|HKEY_CLASSES_ROOT)')
}

# ------------------------------------------------------------
#  Шаг плана — одна строка «что изменится»
# ------------------------------------------------------------
function New-CgFixStep {
    param([string]$Text, [string]$Target = '', [string]$From = '', [string]$To = '')
    return [PSCustomObject]@{ Text = $Text; Target = $Target; From = $From; To = $To }
}

# ------------------------------------------------------------
#  Реестр исправлений
# ------------------------------------------------------------
$script:CgFixers = New-Object System.Collections.ArrayList

function Register-CgFixer {
    param(
        [string]$Id, [string]$Title, [string]$Explain,
        [scriptblock]$Match, [scriptblock]$Plan, [scriptblock]$Apply,
        [string]$Button = 'Исправить',
        [switch]$Risky
    )
    $null = $script:CgFixers.Add([PSCustomObject]@{
        Id = $Id; Title = $Title; Explain = $Explain
        Match = $Match; Plan = $Plan; Apply = $Apply
        Button = $Button; Risky = [bool]$Risky
    })
}

# Какие исправления подходят к этой находке
function Get-CgFixers {
    param($Finding)
    if (-not $Finding) { return @() }
    $out = @()
    foreach ($fx in $script:CgFixers) {
        $ok = $false
        try { $ok = [bool](& $fx.Match $Finding) } catch { $ok = $false }
        if ($ok) { $out += $fx }
    }
    return $out
}

function Get-CgFixPlan {
    param($Finding, $Fixer)
    try { return @(& $Fixer.Plan $Finding) } catch { return @() }
}

# Выполнить. Возвращает Ok/Message/Undo/Steps.
function Invoke-CgFix {
    param($Finding, $Fixer)
    $res = [PSCustomObject]@{ Ok = $false; Message = ''; Undo = $null; Done = 0 }
    try {
        $r = & $Fixer.Apply $Finding
        if ($null -eq $r) { $res.Message = 'Исправление ничего не вернуло'; return $res }
        $res.Ok      = [bool]$r.Ok
        $res.Message = "$($r.Message)"
        $res.Undo    = $r.Undo
        $res.Done    = [int]$r.Done
        if ($res.Ok) { Write-CgLog 'INFO' ("Исправление $($Fixer.Id): $($res.Message)") }
        else { Write-CgLog 'WARN' ("Исправление $($Fixer.Id) не удалось: $($res.Message)") }
    } catch {
        $res.Message = "$($_.Exception.Message)"
        Write-CgLog 'WARN' ("Исправление $($Fixer.Id) упало: $($res.Message)")
    }
    return $res
}

# Откат по записи
function Undo-CgFix {
    param([string]$Id)
    $p = Join-Path (Get-CgUndoDir) "$Id.json"
    if (-not (Test-Path -LiteralPath $p)) {
        return [PSCustomObject]@{ Ok = $false; Message = 'Запись отката не найдена' }
    }
    $rec = $null
    try { $rec = Get-Content -LiteralPath $p -Raw -Encoding UTF8 | ConvertFrom-Json } catch { }
    if (-not $rec) { return [PSCustomObject]@{ Ok = $false; Message = 'Запись отката не читается' } }

    $done = 0; $fail = 0
    foreach ($it in @($rec.Items)) {
        switch ("$($it.Type)") {
            'regvalue' {
                if (Restore-CgRegEntry $it.Entry) { $done++ } else { $fail++ }
            }
            'regvalue-deleted' {
                # значения не было вовсе — откат означает «убрать снова»
                try { Remove-ItemProperty -LiteralPath $it.Entry.Path -Name $it.Entry.Name -Force -ErrorAction Stop; $done++ } catch { $fail++ }
            }
            'folder-moved' {
                try {
                    if (Test-Path -LiteralPath $it.To) {
                        $parent = Split-Path -Parent $it.From
                        if ($parent -and -not (Test-Path -LiteralPath $parent)) { $null = New-Item -ItemType Directory -Path $parent -Force }
                        Move-Item -LiteralPath $it.To -Destination $it.From -Force -ErrorAction Stop
                        $done++
                    } else { $fail++ }
                } catch { $fail++ }
            }
            'cert-eku' {
                $st = $null
                try {
                    $st = Open-CgCertStore $it.Location $it.Store
                    $c = Find-CgStoreCert $st $it.Thumbprint
                    $old = $null
                    if ("$($it.Old)") { $old = [Convert]::FromBase64String("$($it.Old)") }
                    if ($c -and [Cg.CertProp]::Set($c.Handle, 9, $old)) { $done++ } else { $fail++ }
                } catch { $fail++ } finally { if ($st) { $st.Close() } }
            }
            'cert-removed' {
                $st = $null
                try {
                    $st = Open-CgCertStore $it.Location $it.Store
                    $c = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2(,[IO.File]::ReadAllBytes($it.File))
                    $st.Add($c)
                    if ("$($it.Old)") {
                        $back = Find-CgStoreCert $st $it.Thumbprint
                        if ($back) { $null = [Cg.CertProp]::Set($back.Handle, 9, [Convert]::FromBase64String("$($it.Old)")) }
                    }
                    $done++
                } catch { $fail++ } finally { if ($st) { $st.Close() } }
            }
            'task-disabled' {
                try { $null = Enable-ScheduledTask -TaskPath $it.TaskPath -TaskName $it.TaskName -ErrorAction Stop; $done++ } catch { $fail++ }
            }
            default { $fail++ }
        }
    }
    if ($done -and -not $fail) {
        Write-CgLog 'INFO' ("Откат $Id выполнен: вернули $done")
        try { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue } catch { }
        return [PSCustomObject]@{ Ok = $true; Message = "Возвращено: $done" }
    }
    return [PSCustomObject]@{ Ok = $false; Message = "Возвращено $done, не вышло $fail" }
}

# ============================================================
#  Конкретные исправления
# ============================================================

# ---- 1. Adobe: выключить загрузку неподписанных расширений ----
#
# Ровно это сочетание — PlayerDebugMode=1 плюс неподписанная
# панель — и есть то, ради чего проверка написана. Выключаем
# не удалением ключа, а значением 0: ключ принадлежит Adobe,
# и сносить его целиком мы не вправе.
Register-CgFixer -Id 'adobe-debug-one' `
    -Title 'Выключить загрузку неподписанных расширений в этой версии' `
    -Explain 'PlayerDebugMode станет 0. Подписанные панели Adobe продолжат работать, неподписанные перестанут загружаться.' `
    -Match {
        param($f)
        $f.Target -and "$($f.Target.Kind)" -eq 'regvalue' -and "$($f.Target.Name)" -eq 'PlayerDebugMode'
    } `
    -Plan {
        param($f)
        @(New-CgFixStep -Text 'Значение реестра' -Target "$($f.Target.Path)\PlayerDebugMode" -From '1' -To '0')
    } `
    -Apply {
        param($f)
        $old = Get-CgRegEntry $f.Target.Path 'PlayerDebugMode'
        # Adobe хранит этот флаг строкой (REG_SZ), а не числом. Запишешь
        # DWORD — и тип поменяется, а сама Adobe своё же значение
        # перестанет понимать. Тип всегда берём тот, что был.
        $kind = 'String'
        if ($old -and "$($old.Kind)") { $kind = "$($old.Kind)" }
        $zero = '0'
        if ($kind -eq 'DWord' -or $kind -eq 'QWord') { $zero = 0 }
        try {
            $null = New-ItemProperty -LiteralPath $f.Target.Path -Name 'PlayerDebugMode' -Value $zero -PropertyType $kind -Force -ErrorAction Stop
        } catch {
            return [PSCustomObject]@{ Ok = $false; Message = "Не удалось записать: $($_.Exception.Message)"; Done = 0 }
        }
        $undo = New-CgUndoRecord 'adobe-debug-one' "PlayerDebugMode в $($f.Target.Path)" @(
            [PSCustomObject]@{ Type = 'regvalue'; Entry = $old }
        )
        return [PSCustomObject]@{ Ok = $true; Message = 'Загрузка неподписанных расширений выключена'; Undo = $undo; Done = 1 }
    }

# ---- 2. Adobe: то же самое разом во всех версиях ----
#
# Ключей CSXS бывает два десятка — по одному на версию пакета.
# Чинить их по одному означает восемнадцать подтверждений
# подряд; на третьем человек перестаёт читать, что подтверждает.
Register-CgFixer -Id 'adobe-debug-all' `
    -Title 'Выключить во всех версиях Adobe сразу' `
    -Explain 'Пройдёт по всем ключам CSXS.* текущего пользователя и выставит PlayerDebugMode = 0.' `
    -Button 'Исправить везде' `
    -Match {
        param($f)
        $f.Target -and "$($f.Target.Kind)" -eq 'regvalue' -and "$($f.Target.Name)" -eq 'PlayerDebugMode'
    } `
    -Plan {
        param($f)
        $steps = @()
        foreach ($k in (Get-ChildItem 'HKCU:\Software\Adobe' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like 'CSXS*' })) {
            $v = (Get-ItemProperty -Path $k.PSPath -Name 'PlayerDebugMode' -ErrorAction SilentlyContinue).PlayerDebugMode
            if ("$v" -eq '1') {
                $steps += New-CgFixStep -Text 'Значение реестра' -Target "HKCU:\Software\Adobe\$($k.PSChildName)\PlayerDebugMode" -From '1' -To '0'
            }
        }
        return $steps
    } `
    -Apply {
        param($f)
        $items = @(); $n = 0
        foreach ($k in (Get-ChildItem 'HKCU:\Software\Adobe' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like 'CSXS*' })) {
            $path = "HKCU:\Software\Adobe\$($k.PSChildName)"
            $v = (Get-ItemProperty -Path $path -Name 'PlayerDebugMode' -ErrorAction SilentlyContinue).PlayerDebugMode
            if ("$v" -ne '1') { continue }
            $old = Get-CgRegEntry $path 'PlayerDebugMode'
            $kind = 'String'
            if ($old -and "$($old.Kind)") { $kind = "$($old.Kind)" }
            $zero = '0'
            if ($kind -eq 'DWord' -or $kind -eq 'QWord') { $zero = 0 }
            try {
                $null = New-ItemProperty -LiteralPath $path -Name 'PlayerDebugMode' -Value $zero -PropertyType $kind -Force -ErrorAction Stop
                $items += [PSCustomObject]@{ Type = 'regvalue'; Entry = $old }
                $n++
            } catch { }
        }
        if (-not $n) { return [PSCustomObject]@{ Ok = $false; Message = 'Ни одного ключа изменить не удалось'; Done = 0 } }
        $undo = New-CgUndoRecord 'adobe-debug-all' 'PlayerDebugMode во всех версиях Adobe' $items
        return [PSCustomObject]@{ Ok = $true; Message = "Выключено в $n ключах"; Undo = $undo; Done = $n }
    }

# ---- 3. Автозапуск: убрать запись из Run ----
Register-CgFixer -Id 'run-remove' `
    -Title 'Убрать запись автозапуска' `
    -Explain 'Значение удаляется из ветки Run. Прежнее значение целиком сохраняется в записи отката, вернуть можно одним действием.' `
    -Match {
        param($f)
        $f.Target -and "$($f.Target.Kind)" -eq 'runvalue'
    } `
    -Plan {
        param($f)
        @(New-CgFixStep -Text 'Удалить значение' -Target "$($f.Target.Path)\$($f.Target.Name)" -From "$($f.Target.Command)" -To '(нет)')
    } `
    -Apply {
        param($f)
        if ((Test-CgRegNeedsAdmin $f.Target.Path) -and -not (Test-CgAdmin)) {
            return [PSCustomObject]@{ Ok = $false; Message = 'Эта ветка реестра общая для всех — нужны права администратора'; Done = 0 }
        }
        $old = Get-CgRegEntry $f.Target.Path $f.Target.Name
        if (-not $old) { return [PSCustomObject]@{ Ok = $false; Message = 'Записи уже нет'; Done = 0 } }
        try {
            Remove-ItemProperty -LiteralPath $f.Target.Path -Name $f.Target.Name -Force -ErrorAction Stop
        } catch {
            return [PSCustomObject]@{ Ok = $false; Message = "Не удалось удалить: $($_.Exception.Message)"; Done = 0 }
        }
        $undo = New-CgUndoRecord 'run-remove' "Автозапуск $($f.Target.Name)" @(
            [PSCustomObject]@{ Type = 'regvalue'; Entry = $old }
        )
        return [PSCustomObject]@{ Ok = $true; Message = "Запись «$($f.Target.Name)» убрана из автозапуска"; Undo = $undo; Done = 1 }
    }

# ---- 4. Планировщик: выключить задачу ----
#
# Именно выключить, а не удалить. Удалённую задачу обратно уже
# не соберёшь, а выключенная видна в планировщике и включается
# одним щелчком — в том числе нашим откатом.
Register-CgFixer -Id 'task-disable' `
    -Title 'Выключить задачу планировщика' `
    -Explain 'Задача останется на месте, но перестанет запускаться. Включить обратно можно откатом.' `
    -Match {
        param($f)
        $f.Target -and "$($f.Target.Kind)" -eq 'task'
    } `
    -Plan {
        param($f)
        @(New-CgFixStep -Text 'Выключить задачу' -Target "$($f.Target.Name)" -From 'включена' -To 'выключена')
    } `
    -Apply {
        param($f)
        $full = "$($f.Target.Name)"
        $tp = Split-Path -Parent $full
        if (-not $tp) { $tp = '\' }
        if (-not $tp.EndsWith('\')) { $tp = $tp + '\' }
        $tn = Split-Path -Leaf $full
        try {
            $null = Disable-ScheduledTask -TaskPath $tp -TaskName $tn -ErrorAction Stop
        } catch {
            return [PSCustomObject]@{ Ok = $false; Message = "Не удалось выключить: $($_.Exception.Message)"; Done = 0 }
        }
        $undo = New-CgUndoRecord 'task-disable' "Задача $full" @(
            [PSCustomObject]@{ Type = 'task-disabled'; TaskPath = $tp; TaskName = $tn }
        )
        return [PSCustomObject]@{ Ok = $true; Message = "Задача «$tn» выключена"; Undo = $undo; Done = 1 }
    }

# ---- 5. Снять подмену запуска программы (IFEO) ----
#
# Это та самая запись, которой «ускорители» и «отключалки
# телеметрии» глушат обновления Windows: вместо настоящей
# программы запускается пустышка. Убираем только Debugger,
# сам ключ не трогаем — в нём бывают и законные настройки.
Register-CgFixer -Id 'ifeo-remove' `
    -Title 'Вернуть нормальный запуск программы' `
    -Explain 'Удаляется значение Debugger, которым подменён запуск. Прежнее значение сохраняется в записи отката.' `
    -Match {
        param($f)
        $f.Target -and "$($f.Target.Kind)" -eq 'regvalue' -and "$($f.Target.Name)" -eq 'Debugger'
    } `
    -Plan {
        param($f)
        @(New-CgFixStep -Text 'Удалить подмену' -Target "$($f.Target.Path)\Debugger" -From "$($f.Target.Was)" -To '(нет)')
    } `
    -Apply {
        param($f)
        if (-not (Test-CgAdmin)) {
            return [PSCustomObject]@{ Ok = $false; Message = 'Ветка общая для всех — нужны права администратора'; Done = 0 }
        }
        $old = Get-CgRegEntry $f.Target.Path 'Debugger'
        if (-not $old) { return [PSCustomObject]@{ Ok = $false; Message = 'Подмены уже нет'; Done = 0 } }
        try {
            Remove-ItemProperty -LiteralPath $f.Target.Path -Name 'Debugger' -Force -ErrorAction Stop
        } catch {
            return [PSCustomObject]@{ Ok = $false; Message = "Не удалось: $($_.Exception.Message)"; Done = 0 }
        }
        $undo = New-CgUndoRecord 'ifeo-remove' "Подмена запуска $($f.Target.Program)" @(
            [PSCustomObject]@{ Type = 'regvalue'; Entry = $old }
        )
        return [PSCustomObject]@{ Ok = $true; Message = "Запуск «$($f.Target.Program)» больше не подменяется"; Undo = $undo; Done = 1 }
    }

# ---- 6. Вернуть изменённый ключ входа в систему ----
Register-CgFixer -Id 'regvalue-restore' `
    -Title 'Вернуть значение по умолчанию' `
    -Explain 'Ключу возвращается штатное значение Windows. Текущее сохраняется в записи отката.' `
    -Match {
        param($f)
        $f.Target -and "$($f.Target.Kind)" -eq 'regvalue' -and "$($f.Target.Restore)" -and "$($f.Target.Name)" -ne 'PlayerDebugMode'
    } `
    -Plan {
        param($f)
        @(New-CgFixStep -Text 'Вернуть значение' -Target "$($f.Target.Path)\$($f.Target.Name)" -From "$($f.Target.Was)" -To "$($f.Target.Restore)")
    } `
    -Apply {
        param($f)
        if ((Test-CgRegNeedsAdmin $f.Target.Path) -and -not (Test-CgAdmin)) {
            return [PSCustomObject]@{ Ok = $false; Message = 'Нужны права администратора'; Done = 0 }
        }
        $old = Get-CgRegEntry $f.Target.Path $f.Target.Name
        try {
            $null = New-ItemProperty -LiteralPath $f.Target.Path -Name $f.Target.Name -Value $f.Target.Restore -PropertyType String -Force -ErrorAction Stop
        } catch {
            return [PSCustomObject]@{ Ok = $false; Message = "Не удалось: $($_.Exception.Message)"; Done = 0 }
        }
        $undo = New-CgUndoRecord 'regvalue-restore' "$($f.Target.Path)\$($f.Target.Name)" @(
            [PSCustomObject]@{ Type = 'regvalue'; Entry = $old }
        )
        return [PSCustomObject]@{ Ok = $true; Message = 'Значение возвращено'; Undo = $undo; Done = 1 }
    }

# ---- 7. Убрать папку расширения целиком ----
#
# «Вместе со всеми ветками» — это и есть папка: манифест,
# скрипты, ресурсы. Не удаляем, а переносим в карантин: если
# выяснится, что панель нужна, её вернут на место.
function Get-CgFolderQuarantineDir { return (Get-CgDir 'quarantine') }

Register-CgFixer -Id 'folder-quarantine' `
    -Title 'Убрать папку расширения в карантин' `
    -Explain 'Вся папка расширения переносится в карантин целиком — со скриптами, манифестом и ресурсами. Содержимое не удаляется и возвращается откатом.' `
    -Button 'В карантин' -Risky `
    -Match {
        param($f)
        $f.Target -and "$($f.Target.Kind)" -eq 'folder' -and "$($f.Target.Path)" -and (Test-Path -LiteralPath "$($f.Target.Path)" -PathType Container)
    } `
    -Plan {
        param($f)
        $p = "$($f.Target.Path)"
        $files = @(Get-ChildItem -LiteralPath $p -Recurse -File -Force -ErrorAction SilentlyContinue)
        $size = 0
        foreach ($x in $files) { $size += $x.Length }
        @(
            New-CgFixStep -Text 'Перенести папку в карантин' -Target $p -From 'на месте' -To 'карантин'
            New-CgFixStep -Text 'Внутри' -Target ("файлов: {0}, объём: {1} КБ" -f $files.Count, [math]::Round($size / 1KB))
        )
    } `
    -Apply {
        param($f)
        $src = "$($f.Target.Path)"
        if (-not (Test-Path -LiteralPath $src -PathType Container)) {
            return [PSCustomObject]@{ Ok = $false; Message = 'Папки уже нет'; Done = 0 }
        }
        $id = (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
        $dst = Join-Path (Get-CgFolderQuarantineDir) ("folder-$id")
        try {
            Move-Item -LiteralPath $src -Destination $dst -Force -ErrorAction Stop
        } catch {
            return [PSCustomObject]@{ Ok = $false; Message = "Не удалось перенести: $($_.Exception.Message)"; Done = 0 }
        }
        $undo = New-CgUndoRecord 'folder-quarantine' "Папка $src" @(
            [PSCustomObject]@{ Type = 'folder-moved'; From = $src; To = $dst }
        )
        return [PSCustomObject]@{ Ok = $true; Message = 'Папка перенесена в карантин'; Undo = $undo; Done = 1 }
    }

# ---- 8. Корневой сертификат: сузить назначение ----
#
# Сертификат не удаляется: ему оставляется подпись кода, а право
# заверять сайты снимается. Ровно этого хватает установщикам
# драйверов, ради которых такие сертификаты обычно и ставят, и
# ровно этого не хватает, чтобы подделать сайт. Прежнее свойство
# сохраняется в записи отката байт в байт.
function Open-CgCertStore {
    param([string]$Location = 'LocalMachine', [string]$Store = 'Root')
    $st = New-Object System.Security.Cryptography.X509Certificates.X509Store($Store, $Location)
    $st.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    return $st
}

function Find-CgStoreCert {
    param($Store, [string]$Thumbprint)
    foreach ($c in $Store.Certificates) { if ($c.Thumbprint -eq $Thumbprint) { return $c } }
    return $null
}

Register-CgFixer -Id 'cert-restrict' `
    -Title 'Ограничить назначение сертификата' `
    -Explain 'Сертификат останется в системе, но Windows перестанет принимать его для защищённых сайтов: только подпись программ и драйверов. Читать ваш трафик через него станет нельзя. Вернуть можно откатом.' `
    -Button 'Ограничить' `
    -Match {
        param($f)
        $f.Target -and "$($f.Target.Kind)" -eq 'cert' -and $f.Target.CanTls
    } `
    -Plan {
        param($f)
        @(New-CgFixStep -Text 'Назначение сертификата' -Target "$($f.Target.Name) ($($f.Target.Thumbprint))" -From 'любое, включая сайты' -To 'только подпись кода')
    } `
    -Apply {
        param($f)
        if (-not (Test-CgAdmin)) { return [PSCustomObject]@{ Ok = $false; Message = 'Сертификаты компьютера меняются только с правами администратора'; Done = 0 } }
        $st = $null
        try {
            $st = Open-CgCertStore $f.Target.Location $f.Target.Store
            $c = Find-CgStoreCert $st $f.Target.Thumbprint
            if (-not $c) { return [PSCustomObject]@{ Ok = $false; Message = 'Сертификата уже нет'; Done = 0 } }
            $old = [Cg.CertProp]::Get($c.Handle, 9)
            $oids = New-Object System.Security.Cryptography.OidCollection
            $null = $oids.Add((New-Object System.Security.Cryptography.Oid '1.3.6.1.5.5.7.3.3'))
            $ext = New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension($oids, $false)
            if (-not [Cg.CertProp]::Set($c.Handle, 9, $ext.RawData)) {
                return [PSCustomObject]@{ Ok = $false; Message = 'Windows не дала изменить свойство сертификата'; Done = 0 }
            }
            $undo = New-CgUndoRecord 'cert-restrict' "Назначение сертификата $($f.Target.Name)" @(
                [PSCustomObject]@{ Type = 'cert-eku'; Location = $f.Target.Location; Store = $f.Target.Store
                                   Thumbprint = $f.Target.Thumbprint; Old = $(if ($old) { [Convert]::ToBase64String($old) } else { '' }) }
            )
            return [PSCustomObject]@{ Ok = $true; Message = "Сертификат «$($f.Target.Name)» больше не годится для сайтов"; Undo = $undo; Done = 1 }
        } catch {
            return [PSCustomObject]@{ Ok = $false; Message = "Не удалось: $($_.Exception.Message)"; Done = 0 }
        } finally { if ($st) { $st.Close() } }
    }

# ---- 9. Корневой сертификат: убрать из доверенных ----
#
# Перед удалением сертификат целиком сохраняется файлом .cer в
# папке undo: откат кладёт его обратно. Закрытого ключа у корня
# в хранилище обычно нет, и терять тут нечего.
Register-CgFixer -Id 'cert-remove' `
    -Title 'Убрать сертификат из доверенных' `
    -Explain 'Сертификат уйдёт из списка, которому Windows верит без вопросов. Копия сохранится в папке undo, вернуть можно откатом. Программа, которая его ставила, может попросить его снова — тогда вы будете знать, чья это печать.' `
    -Button 'Убрать' -Risky `
    -Match {
        param($f)
        $f.Target -and "$($f.Target.Kind)" -eq 'cert'
    } `
    -Plan {
        param($f)
        @(New-CgFixStep -Text 'Убрать из доверенных корневых' -Target "$($f.Target.Subject)" -From 'доверен' -To 'копия в undo')
    } `
    -Apply {
        param($f)
        if (-not (Test-CgAdmin)) { return [PSCustomObject]@{ Ok = $false; Message = 'Сертификаты компьютера меняются только с правами администратора'; Done = 0 } }
        $st = $null
        try {
            $st = Open-CgCertStore $f.Target.Location $f.Target.Store
            $c = Find-CgStoreCert $st $f.Target.Thumbprint
            if (-not $c) { return [PSCustomObject]@{ Ok = $false; Message = 'Сертификата уже нет'; Done = 0 } }
            $file = Join-Path (Get-CgUndoDir) ("cert-{0}.cer" -f $f.Target.Thumbprint)
            [IO.File]::WriteAllBytes($file, $c.RawData)
            $old = [Cg.CertProp]::Get($c.Handle, 9)
            $st.Remove($c)
            $undo = New-CgUndoRecord 'cert-remove' "Сертификат $($f.Target.Name)" @(
                [PSCustomObject]@{ Type = 'cert-removed'; Location = $f.Target.Location; Store = $f.Target.Store
                                   Thumbprint = $f.Target.Thumbprint; File = $file; Old = $(if ($old) { [Convert]::ToBase64String($old) } else { '' }) }
            )
            return [PSCustomObject]@{ Ok = $true; Message = "Сертификат «$($f.Target.Name)» убран, копия: $file"; Undo = $undo; Done = 1 }
        } catch {
            return [PSCustomObject]@{ Ok = $false; Message = "Не удалось: $($_.Exception.Message)"; Done = 0 }
        } finally { if ($st) { $st.Close() } }
    }
