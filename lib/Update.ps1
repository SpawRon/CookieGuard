# ============================================================
#  CookieGuard - Update.ps1
#  Обновление программы с GitHub.
#
#  Зачем. Программа живёт на нескольких компьютерах, а правки
#  делаются на одном. Без обновления «тот, другой» компьютер
#  навсегда остаётся со старой версией — в том числе со старыми
#  ошибками, из-за которых отказ выглядел как «ничего не делает».
#
#  ПОЧЕМУ ОБНОВЛЕНИЕ НЕ МОЛЧАЛИВОЕ. Самообновляющаяся программа —
#  это канал, по которому на компьютер приезжает код. Для
#  инструмента безопасности это слишком жирная цель: кто получит
#  доступ к репозиторию, получит и все машины разом. Поэтому:
#    — обновление ставится только по кнопке, никогда само;
#    — скачивается ровно с api.github.com по HTTPS;
#    — архив распаковывается в новую пустую временную папку и
#      НИЧЕГО из него не запускается — файлы только копируются;
#    — перед заменой проверяется, что внутри действительно
#      CookieGuard, а не произвольный архив;
#    — рабочие данные (эталон, доверенные, карантин, журналы)
#      не трогаются никогда.
#  Остаётся доверие к самому репозиторию — и это честная граница,
#  о которой сказано в окне.
# ============================================================

$ErrorActionPreference = 'SilentlyContinue'

$script:CgRepoOwner  = 'SpawRon'
$script:CgRepoName   = 'CookieGuard'
$script:CgRepoBranch = 'main'

function Get-CgVersionPath { Join-Path (Get-CgDir 'state') 'installed-commit.txt' }
function Get-CgTokenPath   { Join-Path (Get-CgDir 'state') 'github-token.txt' }

function Get-CgInstalledCommit {
    $p = Get-CgVersionPath
    if (-not (Test-Path -LiteralPath $p)) { return '' }
    try { return ((Get-Content -LiteralPath $p -Raw -ErrorAction Stop).Trim()) } catch { return '' }
}

function Set-CgInstalledCommit {
    param([string]$Sha)
    try { [IO.File]::WriteAllText((Get-CgVersionPath), "$Sha", [Text.UTF8Encoding]::new($true)); return $true }
    catch { return $false }
}

# Ключ доступа нужен только приватному репозиторию. Лежит рядом с
# остальным состоянием и закрыт .gitignore, как и ключ VirusTotal.
function Get-CgGitHubToken {
    $p = Get-CgTokenPath
    if (-not (Test-Path -LiteralPath $p)) { return '' }
    try { return ((Get-Content -LiteralPath $p -Raw -ErrorAction Stop).Trim()) } catch { return '' }
}

function Set-CgGitHubToken {
    param([string]$Token)
    try {
        [IO.File]::WriteAllText((Get-CgTokenPath), "$Token", [Text.UTF8Encoding]::new($false))
        return $true
    } catch { return $false }
}

function Get-CgUpdateHeaders {
    $h = @{
        'Accept'               = 'application/vnd.github+json'
        'User-Agent'           = 'CookieGuard'
        'X-GitHub-Api-Version' = '2022-11-28'
    }
    $t = Get-CgGitHubToken
    if ($t) { $h['Authorization'] = "Bearer $t" }
    return $h
}

function Initialize-CgTls {
    # PowerShell 5.1 по умолчанию может не предлагать TLS 1.2,
    # а GitHub ничего другого не принимает — без этой строки
    # запрос падает с невнятной ошибкой соединения.
    try {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.SecurityProtocolType]::Tls12 -bor [Net.ServicePointManager]::SecurityProtocol
    } catch { }
}

# ------------------------------------------------------------
#  Что лежит в репозитории сейчас
# ------------------------------------------------------------
function Get-CgLatestCommit {
    Initialize-CgTls
    $uri = "https://api.github.com/repos/$script:CgRepoOwner/$script:CgRepoName/commits/$script:CgRepoBranch"
    try {
        $r = Invoke-RestMethod -Uri $uri -Headers (Get-CgUpdateHeaders) -Method Get -TimeoutSec 25 -ErrorAction Stop
        $when = $null
        try { $when = [datetime]$r.commit.committer.date } catch { }
        return [PSCustomObject]@{
            Ok      = $true
            Sha     = "$($r.sha)"
            Short   = "$($r.sha)".Substring(0, [Math]::Min(7, "$($r.sha)".Length))
            Date    = $when
            Message = (("$($r.commit.message)" -split "`n")[0])
            Author  = "$($r.commit.author.name)"
            Error   = ''
        }
    } catch {
        $code = 0
        try { $code = [int]$_.Exception.Response.StatusCode } catch { }
        $msg = switch ($code) {
            404 { 'Репозиторий не найден. Если он приватный — нужен ключ доступа GitHub.' }
            401 { 'Ключ доступа GitHub не принят. Задайте его заново.' }
            403 { 'GitHub отказал: либо исчерпан лимит запросов, либо у ключа нет прав на этот репозиторий.' }
            default { "Не удалось связаться с GitHub: $($_.Exception.Message)" }
        }
        return [PSCustomObject]@{ Ok = $false; Sha = ''; Short = ''; Date = $null; Message = ''; Author = ''; Error = $msg }
    }
}

function Test-CgUpdate {
    $cur = Get-CgInstalledCommit
    $latest = Get-CgLatestCommit
    if (-not $latest.Ok) {
        return [PSCustomObject]@{ Ok = $false; HasUpdate = $false; Current = $cur; Latest = $latest; Error = $latest.Error }
    }
    # Пустая отметка means: версию ещё не записывали (первая установка
    # или копия, принесённая вручную). Считаем, что обновление есть —
    # иначе такая копия никогда бы не обновилась.
    $has = ($cur -ne $latest.Sha)
    return [PSCustomObject]@{ Ok = $true; HasUpdate = $has; Current = $cur; Latest = $latest; Error = '' }
}

# ------------------------------------------------------------
#  Установка
#
#  Данные компьютера не трогаем: они принадлежат машине, а не
#  раздаче. Запущенный .exe Windows заменить не даст, и это не
#  беда — он только запускает .ps1 и меняется крайне редко.
# ------------------------------------------------------------
$script:CgUpdateSkip = @('state', 'logs', 'reports', 'evidence', 'quarantine', '.git', '.github', 'obj')

function Install-CgUpdate {
    param([string]$Sha, [scriptblock]$Progress = $null)

    function Say { param([string]$T) if ($Progress) { & $Progress $T } }

    $res = [PSCustomObject]@{ Ok = $false; Copied = 0; Locked = @(); Error = '' }

    Initialize-CgTls
    $root = Get-CgRoot
    $work = Join-Path ([IO.Path]::GetTempPath()) ('CookieGuard-update-' + [Guid]::NewGuid().ToString('N').Substring(0, 10))
    $zip = Join-Path $work 'update.zip'
    $unpack = Join-Path $work 'unpack'

    try {
        $null = New-Item -ItemType Directory -Path $unpack -Force

        Say 'Скачиваю обновление с GitHub...'
        $uri = "https://api.github.com/repos/$script:CgRepoOwner/$script:CgRepoName/zipball/$Sha"
        Invoke-WebRequest -Uri $uri -Headers (Get-CgUpdateHeaders) -OutFile $zip -TimeoutSec 120 -ErrorAction Stop

        Say 'Распаковываю...'
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        [IO.Compression.ZipFile]::ExtractToDirectory($zip, $unpack)

        # GitHub кладёт всё в одну папку вида Owner-Repo-sha
        $top = @(Get-ChildItem -LiteralPath $unpack -Directory)
        if ($top.Count -ne 1) {
            $res.Error = 'Архив обновления выглядит не так, как ожидалось'
            return $res
        }
        $src = $top[0].FullName

        # Проверка, что это действительно CookieGuard, а не что-то ещё.
        # Копировать поверх рабочей установки содержимое произвольного
        # архива нельзя ни при каких обстоятельствах.
        foreach ($must in @('CookieGuard.ps1', 'lib\Core.ps1', 'lib\Checks.ps1')) {
            if (-not (Test-Path -LiteralPath (Join-Path $src $must))) {
                $res.Error = "В архиве нет файла $must — обновление отменено"
                return $res
            }
        }

        Say 'Заменяю файлы программы...'
        $copied = 0
        $locked = New-Object System.Collections.ArrayList

        # Копируем пофайлово, а не папками.
        #
        # «Copy-Item -Recurse» в УЖЕ СУЩЕСТВУЮЩУЮ папку кладёт её
        # внутрь себя: вместо замены lib получалось lib\lib, а сами
        # модули оставались старыми — обновление молча не работало.
        # Та же ловушка однажды породила вложенную копию всего
        # проекта. Перебор файлов с их относительными путями такого
        # поведения не имеет и ведёт себя одинаково всегда.
        $srcLen = $src.TrimEnd('\').Length + 1
        foreach ($f in (Get-ChildItem -LiteralPath $src -Recurse -File -Force)) {
            $rel = $f.FullName.Substring($srcLen)
            $first = ($rel -split '\\')[0]
            if ($script:CgUpdateSkip -contains $first) { continue }

            $dest = Join-Path $root $rel
            try {
                $destDir = Split-Path -Parent $dest
                if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
                    $null = New-Item -ItemType Directory -Path $destDir -Force -ErrorAction Stop
                }
                Copy-Item -LiteralPath $f.FullName -Destination $dest -Force -ErrorAction Stop
                $copied++
            } catch {
                # Запущенный .exe заменить нельзя — это ожидаемо
                $null = $locked.Add($rel)
            }
        }

        # Модуль, удалённый в новой версии, сам собой не исчезнет:
        # копирование только добавляет и заменяет. Оставшийся файл
        # кода — это старая логика, лежащая рядом с новой; для
        # инструмента безопасности лишний .ps1 в lib лучше убрать.
        # Трогаем только lib\*.ps1: всё остальное может принадлежать
        # человеку, а не раздаче.
        $srcLib = Join-Path $src 'lib'
        $dstLib = Join-Path $root 'lib'
        if ((Test-Path -LiteralPath $srcLib) -and (Test-Path -LiteralPath $dstLib)) {
            $fresh = @(Get-ChildItem -LiteralPath $srcLib -Filter *.ps1 -File | ForEach-Object { $_.Name })
            foreach ($old in (Get-ChildItem -LiteralPath $dstLib -Filter *.ps1 -File)) {
                if ($fresh -contains $old.Name) { continue }
                try {
                    Remove-Item -LiteralPath $old.FullName -Force -ErrorAction Stop
                    Write-CgLog 'INFO' ("Обновление: убран устаревший модуль lib\$($old.Name)")
                } catch { }
            }
        }

        $res.Copied = $copied
        $res.Locked = @($locked)
        $res.Ok = ($copied -gt 0)
        if (-not $res.Ok) { $res.Error = 'Не удалось заменить ни одного файла — нет прав на папку программы' }
        else { $null = Set-CgInstalledCommit $Sha }

        # ${Sha} в фигурных скобках обязательно: без них PowerShell
        # читает «$Sha:» как указание области видимости и падает на разборе
        Write-CgLog 'INFO' ("Обновление до ${Sha}: заменено файлов $copied, занято: " + (@($locked) -join ', '))
    } catch {
        $res.Error = "$($_.Exception.Message)"
        Write-CgLog 'WARN' ("Обновление не удалось: $($_.Exception.Message)")
    } finally {
        try { Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue } catch { }
    }

    return $res
}
