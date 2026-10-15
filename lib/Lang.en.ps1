# ============================================================
#  Английский словарь интерфейса (см. lib\Lang.ps1)
#
#  Строка: русский текст, табуляция, английский. \n — перевод
#  строки. {0}, {1} — подставляемые значения: ключ годится и как
#  строка формата для -f, и как шаблон для готовой строки.
#  Загружается только в английском режиме.
# ============================================================

$script:CgLangEnText = @'
# ---- frag-xaml.txt ----
# Разметка окон: lib\Ui.MainXaml.ps1, Ui.Dialogs.ps1, Ui.Inspector.ps1, Ui.ScanBox.ps1
Найти в разделах и находках	Search sections and findings
Свернуть столбец разделов	Collapse the sections column
Проверить систему	Scan system
Проверить файл или папку	Check a file or folder
Запустить монитор	Start monitor
Обзор	Overview
Защита	Protection
Проверка файлов	File check
НАБЛЮДЕНИЕ	WATCH
Монитор	Monitor
Находки	Findings
Процессы	Processes
Расширения	Extensions
Автозапуск	Autostart
Запуски	Launches
РАЗБОР	REVIEW
Карантин	Quarantine
Доверенные	Trusted
Журнал	Log
01 — ОБЗОР	01 — OVERVIEW
Состояние наблюдения и итог последней проверки.	Monitoring status and the result of the last scan.
Исправить всё	Fix all
Разобрать находки  →	Review findings  →
КРИТИЧНО	CRITICAL
разберите первыми	review these first
ВНИМАНИЕ	WARNING
посмотрите, когда будет время	look when you have time
В КАРАНТИНЕ	IN QUARANTINE
вернуть можно байт в байт	can be restored byte for byte
проверки ещё не было	no scan yet
СОСТОЯНИЕ	STATUS
ЧТО СДЕЛАТЬ СЕЙЧАС	WHAT TO DO NOW
Перетащите файл или папку в любое место этого окна — программа сама распакует архив, спросит пароль и решит, что отправлять на VirusTotal.	Drop a file or folder anywhere in this window — the program unpacks archives itself, asks for a password and decides what to send to VirusTotal.
Перейти	Go
Отчёты, улики и справка	Reports, evidence and help
Сохранённые проверки, подробности по каждой тревоге и описание программы.	Saved scans, details of every alert and a description of the program.
Отчёты	Reports
Улики	Evidence
Справка	Help
02 — ЗАЩИТА	02 — PROTECTION
Что программа делает постоянно, без вашего участия.	What the program does all the time, without you.
Аудит доступа к cookie	Cookie access auditing
Windows записывает, какая программа открыла базу cookie или паролей.	Windows records which program opened the cookie or password database.
Журнал запуска программ	Process launch log
Без него не видно, кто запустил процесс и с какой командной строкой.	Without it you can't see who started a process and with what command line.
Включить	Turn on
Постоянная защита	Always-on protection
Сразу прятать подтверждённое вредоносное	Quarantine confirmed malware right away
Только для файлов, которые VirusTotal уже знает как вредоносные: 5 и более детектов. Остальное — всегда с вашего согласия.	Only for files VirusTotal already knows as malicious: 5 or more detections. Everything else — always with your consent.
ПРОВЕРКИ	CHECKS
Эталон системы	System baseline
Снять заново	Take again
Сверить	Compare
Проверить файлы	Check files
Ключ	Key
Получить ключ	Get a key
Безопасный сёрфинг через фильтрующий DNS	Safe browsing via filtering DNS
Вернуть	Restore
Проверить	Check
ОБНОВЛЕНИЕ	UPDATE
Версия программы	Program version
Обновить	Update
Ключ GitHub	GitHub token
ЕСЛИ ЧТО-ТО НЕ ВКЛЮЧАЕТСЯ	IF SOMETHING WON'T TURN ON
Разобраться, что мешает	Find out what's blocking it
Проверит права, политику аудита, службы, журнал безопасности и файлы браузеров — и назовёт причину, по которой переключатель не поддаётся.	Checks rights, audit policy, services, the security log and browser files — and names the reason a switch won't stay on.
03 — ПРОВЕРКА ФАЙЛОВ	03 — FILE CHECK
Бросьте файл или папку в любое место окна. Архив программа распакует сама, пароль спросит, подписанное известным издателем пропустит.	Drop a file or folder anywhere in the window. Archives are unpacked automatically, passwords asked for, and files signed by a known publisher skipped.
Выбрать файлы	Choose files
Выбрать папку	Choose folder
Очистить	Clear
заглядывать в архивы	look inside archives
Проверить на VirusTotal	Check on VirusTotal
Пусто	Empty
Перетащите сюда файл или папку	Drop a file or folder here
Или нажмите «Выбрать файлы». Наружу уходит только отпечаток SHA-256 — сам файл никуда не загружается.	Or press “Choose files”. Only the SHA-256 fingerprint leaves this computer — the file itself is never uploaded.
УРОВЕНЬ	LEVEL
ФАЙЛ	FILE
РАЗМЕР	SIZE
ЧТО ЭТО	WHAT IT IS
ПОДПИСЬ	SIGNATURE
ВЕРДИКТ	VERDICT
04 — МОНИТОР	04 — MONITOR
Кто трогает cookie и пароли	Who touches cookies and passwords
Живые события: кто прямо сейчас обращается к cookie и паролям.	Live events: who is accessing cookies and passwords right now.
показывать обычные обращения браузера	show the browser's normal access
ВРЕМЯ	TIME
ТИП	TYPE
СОБЫТИЕ	EVENT
ПРОЦЕСС	PROCESS
05 — НАХОДКИ	05 — FINDINGS
Итог проверки системы. Щёлкните строку — справа появится разбор.	Result of the system scan. Click a row to see its analysis on the right.
Сохранить отчёт	Save report
только важное	important only
Важное	Important
Все	All
РАЗДЕЛ	SECTION
НАХОДКА	FINDING
06 — ПРОЦЕССЫ	06 — PROCESSES
Что сейчас запущено, кем подписано и откуда взялось.	What is running now, who signed it and where it came from.
только подозрительные	suspicious only
РИСК	RISK
ИМЯ	NAME
ПУТЬ	PATH
07 — РАСШИРЕНИЯ	07 — EXTENSIONS
Расширения браузеров	Browser extensions
Расширение с правом читать все сайты видит ваши сессии так же, как вы.	An extension allowed to read all sites sees your sessions just as you do.
Перепроверить в магазине	Recheck in the store
Открыть в магазине	Open in store
БРАУЗЕР	BROWSER
НАЗВАНИЕ	NAME
ПРАВА	PERMISSIONS
ПЕРЕПРОВЕРКА	RECHECK
08 — АВТОЗАПУСК	08 — AUTOSTART
Реестр, папки автозагрузки, задачи планировщика и службы.	Registry, startup folders, scheduled tasks and services.
КОМАНДА	COMMAND
09 — ЗАПУСКИ	09 — LAUNCHES
История запусков	Launch history
Что запускалось за последние часы и кто это запустил.	What was started in the last hours and who started it.
только необычные	unusual only
ПРОГРАММА	PROGRAM
ЗАПУЩЕНА ИЗ	STARTED BY
10 — КАРАНТИН	10 — QUARANTINE
Спрятанные файлы. Запустить их нельзя, вернуть — можно, байт в байт.	Hidden files. They can't run, but can be restored byte for byte.
Восстановить	Restore
Удалить насовсем	Delete permanently
Папка карантина	Quarantine folder
В КАРАНТИНЕ С	QUARANTINED ON
ПРИЧИНА	REASON
БЫЛ ПО ПУТИ	ORIGINAL PATH
11 — ДОВЕРЕННЫЕ	11 — TRUSTED
То, про что вы уже разобрались. Столбец «действует на» показывает, насколько широко.	Things you have already looked into. The “applies to” column shows how broadly.
Снять доверие	Revoke trust
ОБЛАСТЬ	SCOPE
ДЕЙСТВУЕТ НА	APPLIES TO
ДОБАВЛЕНО	ADDED
12 — ЖУРНАЛ	12 — LOG
Что программа делала и когда.	What the program did and when.
Папка журналов	Logs folder
ПОДРОБНОСТИ	DETAILS
ЧТО МОЖНО СДЕЛАТЬ	WHAT YOU CAN DO
Доверять	Trust
В проводнике	In Explorer
Искать в сети	Search the web
Спросить у ИИ	Ask an AI
Копировать	Copy
Разобрать	Analyze
ЧТО ИСПРАВИТЬ	WHAT TO FIX
НЕОБРАТИМОЕ	IRREVERSIBLE
Завершить процесс	End process
В карантин	Quarantine
Обезвредить	Neutralize
Готов	Ready
Сохранить	Save
Отмена	Cancel
Больше про это не спрашивать	Don't ask about this again
НА ЧТО РАСПРОСТРАНЯЕТСЯ	WHAT IT COVERS
ПОЧЕМУ ОСТАВЛЯЕТЕ — ЗАМЕТКА СЕБЕ	WHY YOU'RE KEEPING IT — A NOTE TO YOURSELF
Отметить всё	Select all
Снять всё	Clear all
Исправить	Fix
Разбор находки	Finding analysis
Выберите строку слева — здесь появятся подробности.	Select a row on the left — details will appear here.
Разбор ничего не меняет: он только читает реестр, файлы и список процессов.	Analysis changes nothing: it only reads the registry, files and the process list.
Копировать карту	Copy map
Сохранить в файл	Save to file
Закрыть	Close

# ---- frag-main.txt ----
# CookieGuard.ps1
Аудит доступа к файлам	File access auditing
включён	on
Windows записывает, кто открывает cookie	Windows records who opens cookies
аудит: вкл	audit: on
выключен	off
Без него не видно, кто брал cookie	Without it you can't see who took cookies
аудит: выкл	audit: off
Антивирус	Antivirus
работает	running
{0} · базы: {1} дн.	{0} · signatures: {1} d old
{0} · базы устарели	{0} · signatures out of date
Включите защиту в реальном времени	Turn on real-time protection
{0} установлен, но не защищает	{0} is installed but not protecting
неизвестно	unknown
Не удалось опросить Defender	Couldn't query Defender
Исключения Defender	Defender exclusions
Defender сейчас в запасе, но эти места он не проверит	Defender is on standby now, but it won't scan these places
Исключения антивируса	Antivirus exclusions
Эти места Defender не проверяет	Defender doesn't scan these places
Под наблюдением	Watched
{0} файлов	{0} files
снят в {0}	taken at {0}
не снят	not taken
Изменения в системе не отслеживаются	System changes aren't tracked
Последняя проверка	Last scan
{0} критичных, {1} внимание	{0} critical, {1} warning
не выполнялась	never run
Нажмите «Проверить систему»	Press “Scan system”
администратор	administrator
без прав администратора	no administrator rights
Проверки ещё не было — нажмите «Проверить систему».	No scan yet — press “Scan system”.
{0} {1} разбора	{0} {1} review
критичная находка ждёт	critical finding awaits
критичные находки ждут	critical findings await
критичных находок ждут	critical findings await
Критичного нет	Nothing critical
Всё чисто	All clear
Проверка {0} в {1}.	Scanned on {0} at {1}.
Эталон снят {0} в {1}.	Baseline taken on {0} at {1}.
находка	finding
находки	findings
находок	findings
ТРЕБУЕТ ВНИМАНИЯ	NEEDS ATTENTION
ЗАМЕТКА	NOTE
НОРМА	OK
СВЕДЕНИЯ	INFO
Нечего исправлять	Nothing to fix
Похоже, это уже исправлено.	Looks like this is already fixed.
… и ещё {0}	… and {0} more
Исправление отменено	Fix cancelled
Исправляю...	Fixing...
Не исправлено	Not fixed
Исправить не удалось	Couldn't fix
Это обратимо: запись отката {0} лежит в папке undo рядом с журналами.	This is reversible: undo record {0} is in the undo folder next to the logs.
Исправлено	Fixed
Не удалось открыть ссылку: {0}	Couldn't open the link: {0}
У выбранной строки нет пути к файлу	The selected row has no file path
Открыто в проводнике: {0}	Opened in Explorer: {0}
Файла нет, открыта папка: {0}	The file is gone; opened its folder: {0}
Путь не найден: {0}	Path not found: {0}
Сначала выберите строку	Select a row first
Нечего искать	Nothing to search for
Скопировать запрос	Copy query
Запрос скопирован	Query copied
Запрос: {0}	Query: {0}
Считаю SHA256...	Computing SHA256...
Не удалось получить хеш — у строки нет файла на диске	Couldn't get a hash — the row has no file on disk
Открыт VirusTotal по отпечатку: {0}	Opened VirusTotal for hash: {0}
Спрашиваю VirusTotal...	Asking VirusTotal...
VirusTotal не ответил	VirusTotal didn't answer
VirusTotal не принял ключ — задайте его заново в разделе «Защита»	VirusTotal rejected the key — set it again on the “Protection” page
Превышен предел запросов VirusTotal, попробуйте через минуту	VirusTotal request limit exceeded, try again in a minute
Этот файл VirusTotal неизвестен.	VirusTotal doesn't know this file.
Значит, он редкий. Для самодельного файла это норма, для скачанной программы — повод задуматься.	So it's rare. That's normal for a home-made file; for a downloaded program it's a reason to think twice.
VirusTotal: файл неизвестен	VirusTotal: file unknown
Вредоносным считают: {0} из {1} ({2}%)	Flagged as malicious by: {0} of {1} ({2}%)
Подозрительным: {0}	Suspicious: {0}
Классификация: {0}	Classification: {0}
Отчёт: {0}	Report: {0}
VirusTotal: {0} из {1} движков считают файл вредоносным	VirusTotal: {0} of {1} engines flag the file as malicious
Разбираю находку на своём компьютере с Windows. Объясни простыми словами, опасно ли это и что делать.	I'm looking into a finding on my Windows computer. Explain in plain words whether it's dangerous and what to do.
Находка: {0}	Finding: {0}
Уровень: {0}	Level: {0}
Путь: {0}	Path: {0}
Подробности:	Details:
[...текст обрезан для ссылки. Полная версия — в буфере обмена, вставьте Ctrl+V]	[...text trimmed for the link. The full version is on the clipboard, paste it with Ctrl+V]
Вопрос передан вместе с данными. Полный текст также в буфере (Ctrl+V).	The question was sent along with the data. The full text is also on the clipboard (Ctrl+V).
Только скопировать вопрос	Just copy the question
Вопрос с подробностями скопирован в буфер	Question with details copied to the clipboard
Подробности скопированы в буфер	Details copied to the clipboard
доверенных записей: {0}	trusted entries: {0}
Отменено	Cancelled
Не удалось добавить в доверенные	Couldn't add to Trusted
ДОВЕРЕНО ВАМИ	TRUSTED BY YOU
ДОВЕРЕНО ВАМИ: {0}	TRUSTED BY YOU: {0}
доверено вами	trusted by you
Выберите запись	Select an entry
Снять доверие?	Revoke trust?
Запись снова начнёт попадать в находки.	The entry will show up in findings again.
Снять	Revoke
сетевых подключений не найдено	no network connections found
включён: {0}	on: {0}
включён частично ({0} из {1})	partly on ({0} of {1})
выключен (сейчас: {0})	off (now: {0})
Выберите набор DNS	Choose a DNS set
Включить безопасный сёрфинг?	Turn on safe browsing?
Вредоносные домены перестанут разрешаться в адрес — во всей системе. Прежние настройки сохранятся, кнопка «Вернуть» их восстановит.	Malicious domains will stop resolving — system-wide. Your previous settings are saved; the “Restore” button brings them back.
Переключаю DNS...	Switching DNS...
Возвращаю DNS...	Restoring DNS...
Проверяю фильтрацию...	Checking filtering...
--- Проверка безопасного сёрфинга ---	--- Safe browsing check ---
Фильтрация работает	Filtering works
Фильтрация НЕ обнаружена — подробности ниже	Filtering NOT detected — details below
У выбранной строки нет процесса с PID	The selected row has no process with a PID
Процесс уже не работает	The process is no longer running
Завершить процесс и все дочерние?	End the process and all its children?
Несохранённые данные этой программы пропадут.	Unsaved data in this program will be lost.
Завершить	End
вручную из окна	manually from the window
У выбранной строки нет файла	The selected row has no file
Файл не найден на диске	File not found on disk
Файл будет обратимо спрятан. Вернуть его можно в разделе «Карантин».	The file will be hidden reversibly. You can restore it on the “Quarantine” page.
Это системная папка Windows. Изъятие настоящего системного файла нарушит работу системы — убедитесь, что файл лишний.	This is a Windows system folder. Removing a real system file will break the system — make sure the file doesn't belong there.
Отправить файл в карантин?	Quarantine the file?
Отправляю в карантин...	Quarantining...
Нужен процесс или файл	A process or file is needed
Завершить процесс и изъять файл?	End the process and remove the file?
Карантин обратим: файл можно будет вернуть.	Quarantine is reversible: the file can be restored.
Обезвреживаю...	Neutralizing...
обезврежено вручную	neutralized manually
в карантине: {0}	in quarantine: {0}
Выберите запись в карантине	Select a quarantine entry
Вернуть файл на прежнее место?	Restore the file to its original place?
Если это была угроза — она снова станет активной.	If it was a threat, it will become active again.
Удалить насовсем?	Delete permanently?
Это необратимо: восстановить файл будет нельзя.	This is irreversible: the file can't be restored.
Удалить	Delete
установлен, работает	installed, running
установлен (сердцебиения пока нет)	installed (no heartbeat yet)
не установлен — защита только при открытом окне	not installed — protection only while the window is open
Авто-карантин ВКЛЮЧЁН: файлы, которые VirusTotal уже знает как вредоносные (5+ детектов), будут изыматься без вопросов. Остальное — только с вашего подтверждения.	Auto-quarantine is ON: files VirusTotal already knows as malicious (5+ detections) will be removed without asking. Everything else — only with your confirmation.
Сторож будет стартовать вместе с Windows и работать в фоне. Это не драйвер ядра: противник с правами SYSTEM сможет его снести.	The guard will start with Windows and run in the background. It's not a kernel driver: an attacker with SYSTEM rights can remove it.
Авто-карантин включён — подтверждённое вредоносное изымается без вопросов.	Auto-quarantine is on — confirmed malware is removed without asking.
Включить постоянную защиту?	Turn on always-on protection?
Устанавливаю сторожа...	Installing the guard...
Включение постоянной защиты	Turning on always-on protection
Снимаю сторожа...	Removing the guard...
Выключение постоянной защиты	Turning off always-on protection
Остановить монитор	Stop monitor
монитор: работает	monitor: running
Монитор запущен. Аудит выключен — обращения к cookie видны не будут, включите его в разделе «Защита».	Monitor started. Auditing is off — cookie access won't be visible; turn it on on the “Protection” page.
Монитор запущен — наблюдаю за обращениями к cookie и запуском программ.	Monitor started — watching cookie access and program launches.
монитор: остановлен	monitor: stopped
Монитор остановлен.	Monitor stopped.
Список событий очищен	Event list cleared
запуск	starting
Проверяю систему...	Scanning the system...
Проверяю систему: {0}	Scanning the system: {0}
критично: {0}    внимание: {1}    заметки: {2}    всего проверок: {3}	critical: {0}    warning: {1}    notes: {2}    checks total: {3}
Исправить всё ({0})	Fix all ({0})
Исправлять нечего	Nothing to fix
У оставшихся находок нет безопасного исправления в один щелчок. Откройте находку — справа будет сказано, что с ней делать, или нажмите «Доверять».	The remaining findings have no safe one-click fix. Open a finding — the right pane says what to do with it — or press “Trust”.
все такие находки разом	all such findings at once
— похоже, отключено намеренно; отмечайте, только если это сделали не вы	— looks deliberately disabled; tick it only if you didn't do this
— файла уже нет, запись мёртвая	— the file is gone, the entry is dead
— программа на месте; отмечайте, если она не нужна при старте Windows	— the program is present; tick it if you don't need it at Windows startup
Каждое исправление обратимо: прежнее значение сохраняется в записи отката. Снимите галочку с того, что вы оставили намеренно.	Every fix is reversible: the previous value is kept in an undo record. Untick what you left on purpose.
Остальное ({0}) так не чинится — это файлы и программы, решение по ним за вами.	The rest ({0}) can't be fixed this way — they are files and programs, and the decision is yours.
Исправить сразу: {0}	Fix at once: {0}
Исправляю: {0}	Fixing: {0}
Исправлено: {0} из {1}.	Fixed: {0} of {1}.
Записи отката лежат в папке undo рядом с журналами.	Undo records are in the undo folder next to the logs.
Исправлено: {0} из {1}. Записи отката лежат в папке undo рядом с журналами.	Fixed: {0} of {1}. Undo records are in the undo folder next to the logs.
Исправлено не всё	Not everything was fixed
Готово	Done
Сейчас программа проверит систему заново, чтобы показать, что осталось.	The program will now scan the system again to show what's left.
Сначала выполните проверку	Run a scan first
CookieGuard — отчёт о проверке	CookieGuard — scan report
{0}   компьютер: {1}   пользователь: {2}	{0}   computer: {1}   user: {2}
Отчёт сохранён: {0}	Report saved: {0}
перепроверяю по магазину	rechecking in the store
Подождите, предыдущая операция ещё идёт	Please wait, the previous operation is still running
всего: {0}    подозрительных: {1}	total: {0}    suspicious: {1}
всего: {0}    с доступом к cookie на всех сайтах: {1}	total: {0}    with cookie access on all sites: {1}
записей: {0}    требуют внимания: {1}	entries: {0}    need attention: {1}
записей: {0}    источник: {1}	entries: {0}    source: {1}
Собираю процессы и проверяю подписи...	Collecting processes and checking signatures...
Читаю расширения браузеров...	Reading browser extensions...
Читаю автозапуск...	Reading autostart...
Читаю историю запуска программ...	Reading the program launch history...
Журнал за сегодня пуст.	Today's log is empty.
Перепроверять нечего: критичных расширений нет	Nothing to recheck: no critical extensions
Перепроверяю расширения по магазину...	Rechecking extensions in the store...
Включить журнал запуска программ?	Turn on the process launch log?
Windows начнёт записывать каждый запуск с командной строкой и тем, кто его вызвал. Именно так опознаётся окно, которое мелькнуло и исчезло.	Windows will record every launch with its command line and who started it. That's how you identify a window that flashed and disappeared.
Журнал запуска не включён	Launch log not turned on
Включение журнала запуска программ	Turning on the process launch log
ключ задан    в базе вердиктов: {0}	key set    verdicts in cache: {0}
ключ не задан — проверка недоступна	no key — checking unavailable
снят {0}	taken {0}
Текущий эталон от {0} будет заменён.	The current baseline from {0} will be replaced.
Эталон от {0} будет заменён.	The baseline from {0} will be replaced.
Запомнится автозапуск, расширения, сертификаты, прокси, hosts, исключения антивируса и службы. Снимайте, только когда уверены, что система в порядке.	Autostart, extensions, certificates, proxy, hosts, antivirus exclusions and services will be remembered. Take it only when you're sure the system is clean.
Снять эталон состояния системы?	Take a baseline of the system state?
Снимаю эталон...	Taking a baseline...
Эталон ещё не снят	No baseline yet
Сравнивать не с чем. Сначала нажмите «Снять заново».	Nothing to compare with. Press “Take again” first.
Сверяю систему с эталоном...	Comparing the system with the baseline...
Файл справки не найден	Help file not found
Зарегистрируйтесь, скопируйте API key и нажмите «Задать ключ»	Sign up, copy the API key and press “Key”
Ключ VirusTotal	VirusTotal key
Вставьте API key из профиля на virustotal.com.	Paste the API key from your profile on virustotal.com.
Ключ остаётся на этом компьютере. Наружу уходят только отпечатки файлов, сами файлы — никогда.	The key stays on this computer. Only file hashes leave it — never the files themselves.
Ключ не изменён	Key unchanged
Ключ сохранён. Теперь можно нажать «Проверить через VirusTotal».	Key saved. Now you can press “Check files”.
Нужен ключ VirusTotal	A VirusTotal key is needed
Он бесплатный: virustotal.com, регистрация, профиль, API key. Нажмите «Получить ключ».	It's free: virustotal.com, sign up, profile, API key. Press “Get a key”.
Проверить неподписанные файлы?	Check unsigned files?
Наружу уйдут только отпечатки SHA-256, сами файлы — никогда. Бесплатный ключ даёт 4 запроса в минуту, поэтому на 60 файлов уйдёт около 15 минут. Окном можно пользоваться дальше.	Only SHA-256 hashes leave the computer, never the files. A free key allows 4 requests per minute, so 60 files take about 15 minutes. You can keep using the window.
Проверяю файлы через VirusTotal (это долго из-за ограничений бесплатного ключа)...	Checking files via VirusTotal (slow because of free key limits)...
Выберите расширение	Select an extension
Открыта страница расширения: {0}	Opened the extension page: {0}
{0} — не найден нужный файл	{0} — a required file is missing
Похоже, установка повреждена: переустановите программу.	The installation looks damaged: reinstall the program.
{0} — отменено	{0} — cancelled
{0} — не выполнено	{0} — not done
Windows не дала запустить изменение настроек. Чаще всего это отказ в окне запроса прав.	Windows didn't allow the settings change to run. Most often that's a "No" in the permission prompt.
{0} не удалось	{0} failed
Windows отказала в изменении настройки. Разбор покажет, что именно мешает: прав, политики, служб или файлов браузера.	Windows refused to change the setting. The analysis will show what exactly is in the way: rights, policy, services or browser files.
код возврата {0}	exit code {0}
Разобраться	Find out
{0} — не выполнено (код {1})	{0} — not done (code {1})
{0} — выполнено	{0} — done
Проверяю, что мешает...	Checking what's in the way...
Разбор не удался	Analysis failed
Почему не работает	Why it doesn't work
Нашлось, что мешает	Found what's in the way
Строк, из-за которых настройка не включается: {0}. Они открыты в «Находках» — выберите строку, справа будет сказано, что делать.	Rows that keep the setting from turning on: {0}. They are open in “Findings” — select a row and the right pane says what to do.
Непреодолимых помех не нашлось	Nothing insurmountable found
Всё необходимое на месте. Если настройка всё равно не включается, посмотрите раздел «Журнал» — там записан вывод последней попытки.	Everything needed is in place. If the setting still won't turn on, look at the “Log” page — the output of the last attempt is there.
Включить аудит доступа к cookie?	Turn on cookie access auditing?
Windows начнёт записывать, какая программа открывает Cookies и Login Data. Включится политика аудита файловой системы, журнал безопасности вырастет до 256 МБ. Всё отменяется этим же переключателем.	Windows will record which program opens Cookies and Login Data. The file system audit policy will be enabled and the security log will grow to 256 MB. The same switch undoes everything.
Аудит не включён	Auditing not turned on
Включаю аудит...	Turning on auditing...
Включение аудита	Turning on auditing
Выключаю аудит...	Turning off auditing...
Выключение аудита	Turning off auditing
событий: {0}    критично: {1}    внимание: {2}	events: {0}    critical: {1}    warning: {2}
Ошибка: {0}	Error: {0}
Список процессов обновлён	Process list updated
Перепроверено по магазину: {0}	Rechecked in the store: {0}
Расширения обновлены	Extensions updated
Автозапуск обновлён	Autostart updated
История запусков обновлена	Launch history updated
Эталон снят. Теперь любое изменение автозапуска, расширений, скриптов Adobe, сертификатов и сети будет заметно.	Baseline taken. Now any change to autostart, extensions, Adobe scripts, certificates and network will be noticed.
Эталон	Baseline
Сверка с эталоном: изменений, требующих внимания — {0}	Baseline comparison: changes needing attention — {0}
Сверка с эталоном: ничего не изменилось	Baseline comparison: nothing changed
VirusTotal: запрошено {0}, из базы {1}, с детектами {2}	VirusTotal: requested {0}, from cache {1}, with detections {2}
Проверка закончена: критичных {0}, требуют внимания {1}. Нажмите на строку, чтобы увидеть подробности.	Scan finished: {0} critical, {1} need attention. Click a row to see the details.
Перепроверяю критичные расширения по магазину...	Rechecking critical extensions in the store...
Полная проверка системы: защита, трафик, автозапуск, процессы, расширения, скрипты Adobe, копии баз cookie, сверка с эталоном.	Full system scan: protection, traffic, autostart, processes, extensions, Adobe scripts, cookie database copies, baseline comparison.
Наблюдение в реальном времени: кто обращается к cookie и какие программы запускаются.	Real-time watch: who accesses cookies and which programs start.
Включить аудит Windows на файлы cookie и паролей. После этого видно, КАКАЯ программа их открыла.	Turn on Windows auditing for cookie and password files. Then you can see WHICH program opened them.
Включить журнал запуска программ (событие 4688) с командной строкой — чтобы опознать мелькнувшее окно.	Turn on the process launch log (event 4688) with command lines — to identify a window that flashed by.
Выключить аудит cookie и журнал запусков. Система вернётся в исходное состояние.	Turn off cookie auditing and the launch log. The system returns to its original state.
Запомнить текущее состояние системы как эталон: автозапуск, расширения, сертификаты, прокси, службы.	Remember the current system state as a baseline: autostart, extensions, certificates, proxy, services.
Сравнить систему с эталоном и показать, что изменилось с тех пор.	Compare the system with the baseline and show what changed since.
Проверить неподписанные файлы через VirusTotal (~70 антивирусов). Наружу уходит только отпечаток SHA256, сам файл — никогда.	Check unsigned files via VirusTotal (~70 antivirus engines). Only the SHA256 hash leaves the computer, never the file.
Задать бесплатный API-ключ VirusTotal. Хранится только на этом компьютере.	Set a free VirusTotal API key. It's stored only on this computer.
Открыть страницу, где берут бесплатный ключ VirusTotal.	Open the page where you get a free VirusTotal key.
Постоянная защита: сторож стартует вместе с Windows, работает в фоне и перезапускается, если его завершат.	Always-on protection: the guard starts with Windows, runs in the background and restarts if it's killed.
Снять постоянную защиту. Наблюдение останется только при открытом окне.	Remove always-on protection. Watching will continue only while the window is open.
Сторож сам отправит в карантин файл, который VirusTotal уже знает как вредоносный (5 и более детектов). Остальное — только с вашего подтверждения.	The guard itself quarantines a file VirusTotal already knows as malicious (5 or more detections). Everything else — only with your confirmation.
Открыть папку с сохранёнными отчётами проверок.	Open the folder with saved scan reports.
Открыть папку с уликами по каждой тревоге (JSON с путями, PID, хешами).	Open the folder with evidence for each alert (JSON with paths, PIDs, hashes).
Открыть подробное описание программы.	Open the detailed program description.
Показать выбранный файл в проводнике.	Show the selected file in Explorer.
Поиск в интернете по отпечатку, имени файла и издателю — не по двум словам, а по приметам, которые действительно что-то находят.	Web search by hash, file name and publisher — not by two words, but by traits that actually find something.
Спросить вердикт VirusTotal по отпечатку выбранного файла.	Ask VirusTotal for a verdict on the selected file's hash.
Передать находку со всеми подробностями в чат с ИИ. Полный текст также попадёт в буфер обмена.	Send the finding with all details to an AI chat. The full text also goes to the clipboard.
Скопировать подробности выбранной строки в буфер обмена.	Copy the selected row's details to the clipboard.
Пометить как разобранное: больше не будет попадать в находки. Программа спросит, насколько широко: только этот файл, эта программа любой версии, весь издатель или вся папка.	Mark as reviewed: it won't show up in findings any more. The program asks how broadly: just this file, this program in any version, the whole publisher or the whole folder.
Страница проверки файлов. Файл или папку можно бросить в любое место окна — программа сама распакует архив, спросит пароль и решит, что имеет смысл проверять.	The file check page. Drop a file or folder anywhere in the window — the program unpacks archives itself, asks for a password and decides what's worth checking.
Перейти к проверке файлов. Файл можно просто бросить в окно.	Go to the file check. You can simply drop a file into the window.
Исправить разом всё, что программа умеет исправлять сама. Покажет список с галочками — снимите те, что оставили намеренно. Каждое исправление обратимо.	Fix at once everything the program can fix itself. Shows a checklist — untick what you left on purpose. Every fix is reversible.
Исправить разом всё, что программа умеет исправлять сама. Покажет список с галочками.	Fix at once everything the program can fix itself. Shows a checklist.
Спросить магазин Chrome/Edge, что он знает о критичных расширениях: есть ли оно там и сколько у него пользователей. Наружу уходит только номер расширения.	Ask the Chrome/Edge store what it knows about critical extensions: whether it's listed and how many users it has. Only the extension ID leaves the computer.
Спросить VirusTotal о файлах из списка. Наружу уходит только отпечаток SHA-256, сам файл — никогда.	Ask VirusTotal about the files in the list. Only the SHA-256 hash leaves the computer, never the file.
Распаковывать архивы и проверять то, что внутри. Для архива под паролем программа спросит пароль.	Unpack archives and check what's inside. For a password-protected archive the program asks for the password.
Аудит доступа к файлам Windows: запись о том, какая программа открыла базу cookie или паролей. Без него главную задачу программы выполнить нечем.	Windows file access auditing: a record of which program opened the cookie or password database. Without it the program can't do its main job.
Сторож стартует вместе с Windows, работает в фоне и перезапускается, если его завершат. Это не драйвер ядра: противник с правами SYSTEM сможет его снести.	The guard starts with Windows, runs in the background and restarts if it's killed. It's not a kernel driver: an attacker with SYSTEM rights can remove it.
Разделы программы. Нижние три — для разбора: что спрятано, чему вы доверяете, что программа делала.	Program sections. The bottom three are for review: what's hidden, what you trust, what the program did.
Проверяет предпосылки: права, политику аудита, групповую политику поверх неё, службы, журнал безопасности, антивирус и файлы браузеров. Отвечает, почему переключатель не поддаётся.	Checks the prerequisites: rights, audit policy, group policy on top of it, services, the security log, antivirus and browser files. Tells you why a switch won't stay on.
Спросить GitHub, вышла ли новая версия. Наружу уходит только запрос к api.github.com.	Ask GitHub whether a new version is out. Only a request to api.github.com leaves the computer.
Заменить файлы программы на версию из репозитория — даже если установлена та же самая. Рабочие данные — эталон, доверенные, карантин, журналы — остаются нетронутыми. Ставится только по этой кнопке, никогда само.	Replace the program files with the version from the repository — even if the same one is installed. Working data — baseline, trusted, quarantine, logs — stay untouched. Installs only from this button, never by itself.
Ключ доступа GitHub. Нужен, только если репозиторий приватный. Хранится на этом компьютере, в папке state.	GitHub access token. Needed only if the repository is private. Stored on this computer, in the state folder.
Завершить выбранный процесс вместе со всеми дочерними. Критические процессы Windows программа не трогает.	End the selected process together with all its children. The program doesn't touch critical Windows processes.
Обратимо спрятать файл: запустить его будет нельзя, но можно вернуть в разделе «Карантин».	Hide the file reversibly: it can't be run, but can be restored on the “Quarantine” page.
Завершить процесс И отправить его файл в карантин — одним действием.	End the process AND quarantine its file — in one action.
Вернуть файл из карантина на прежнее место, байт в байт.	Restore the file from quarantine to its original place, byte for byte.
Удалить из карантина окончательно. Это необратимо.	Delete from quarantine for good. This is irreversible.
Открыть папку карантина.	Open the quarantine folder.
Снять доверие — запись снова начнёт попадать в находки.	Revoke trust — the entry will show up in findings again.
Пересобрать список процессов и проверить подписи заново.	Rebuild the process list and recheck signatures.
Перечитать расширения браузеров и их права.	Re-read browser extensions and their permissions.
Открыть страницу выбранного расширения в магазине Chrome.	Open the selected extension's page in the Chrome store.
Перечитать автозапуск: реестр, папки автозагрузки, задачи, службы.	Re-read autostart: registry, startup folders, tasks, services.
Перечитать историю запуска программ.	Re-read the program launch history.
Включить журнал запуска программ, чтобы видеть командную строку и родителя.	Turn on the process launch log to see the command line and the parent.
Показывать только критичное, важное и заметки — скрыть строки «норма».	Show only critical, important and notes — hide “OK” rows.
Показывать только процессы с признаками риска.	Show only processes with risk signs.
Показывать и обычные обращения браузера к своим же cookie.	Also show the browser's normal access to its own cookies.
Показывать только необычные запуски.	Show only unusual launches.
Сохранить находки в текстовый отчёт.	Save findings to a text report.
Очистить список событий монитора.	Clear the monitor event list.
Не удалось сохранить язык: {0}	Couldn't save the language: {0}
Новый язык включится после перезапуска окна.	A new language takes effect after the window restarts.
Перезапустить	Restart
Не удалось перезапустить: {0}	Couldn't restart: {0}
Язык интерфейса · Interface language	Interface language · Язык интерфейса
ИНТЕРФЕЙС	INTERFACE
Развернуть столбец разделов	Expand the sections column
раздел окна	window section
процесс	process
расширение	extension
автозапуск	autostart
доверенное	trusted
Ничего не найдено	Nothing found
Ищем по разделам и по уже собранным таблицам	Searching sections and tables already collected
Собираю карту...	Building the map...
Разбор не собрался	Couldn't build the analysis
программа: {0}\nданные:    {1}\nисточник:  github.com/{2}/{3}, ветка {4}	program: {0}\ndata:      {1}\nsource:    github.com/{2}/{3}, branch {4}
установлено: {0}	installed: {0}
версия не отмечена — нажмите «Проверить»	version not recorded — press “Check”
Спрашиваю GitHub...	Asking GitHub...
проверить не удалось	couldn't check
Не удалось проверить обновления	Couldn't check for updates
установлена последняя версия: {0}	latest version installed: {0}
Обновлений нет — «Обновить» поставит ту же версию заново	No updates — “Update” will reinstall the same version
есть обновление: {0} от {1}	update available: {0} from {1}
Доступно обновление: {0}	Update available: {0}
Не удалось связаться с GitHub	Couldn't reach GitHub
Обновить программу?	Update the program?
Файлы программы будут заменены на версию из репозитория.	The program files will be replaced with the version from the repository.
Переустановить ту же версию?	Reinstall the same version?
Эта версия уже установлена. Файлы программы будут переписаны заново из репозитория — все правки, сделанные в установленной копии, пропадут.	This version is already installed. The program files will be rewritten from the repository — any edits made in the installed copy will be lost.
Переустановить	Reinstall
Модули lib\\*.ps1, которых нет в репозитории, будут удалены.	lib\\*.ps1 modules that aren't in the repository will be deleted.
Эталон, доверенные, карантин и журналы останутся на месте.	Baseline, trusted entries, quarantine and logs stay in place.
После обновления программу нужно перезапустить.	The program needs a restart after the update.
Обновляю...	Updating...
Обновление не установлено	Update not installed
Перезапустите программу, чтобы изменения вступили в силу.	Restart the program for the changes to take effect.
Файлы, занятые работающей программой, останутся прежними: {0}.	Files in use by the running program stay as they were: {0}.
Обновление установлено	Update installed
версия {0}, заменено файлов: {1}	version {0}, files replaced: {1}
Обновление установлено — перезапустите программу	Update installed — restart the program
Ключ доступа GitHub	GitHub access token
Нужен только приватному репозиторию. Если репозиторий открытый, ключ не требуется — оставьте поле пустым.	Needed only for a private repository. If the repository is public, no token is required — leave the field empty.
Токен хранится только на этом компьютере, в папке state, и наружу уходит лишь на api.github.com. Достаточно прав «только чтение» для этого репозитория.	The token is stored only on this computer, in the state folder, and is sent only to api.github.com. Read-only access to this repository is enough.
Ключ GitHub сохранён	GitHub token saved
Ключ GitHub убран	GitHub token removed
Windows записывает, какая программа открывает базу cookie и паролей.	Windows records which program opens the cookie and password database.
Выключен: не видно, кто брал cookie. Это главное, ради чего программа нужна.	Off: you can't see who took cookies. That's the main thing the program is for.
Показать в проводнике	Show in Explorer
Искать в интернете	Search the web
Копировать подробности	Copy details
Копировать ключ	Copy key
Запущено без прав администратора. Включение аудита запросит повышение прав отдельно.	Running without administrator rights. Turning on auditing will ask for elevation separately.
Готов. Начните с «Проверить систему» или включите аудит в разделе «Защита».	Ready. Start with “Scan system” or turn on auditing on the “Protection” page.
Опрашиваю систему...	Querying the system...

# ---- frag-ui.txt ----
# lib\Ui.Dialogs.ps1, lib\Ui.Inspector.ps1, lib\Ui.ScanBox.ps1, lib\Ui.Actions.ps1
# --- Ui.Dialogs.ps1: default button labels and texts set in code ---
Понятно	Got it
Да	Yes
моя программа, разобрался	my own program, I've checked it
отмечено: {0} из {1}	selected: {0} of {1}
# --- Ui.Actions.ps1: trust prompts ---
Расширение перестанет попадать в находки. Напишите себе на будущее, почему вы его оставляете.	The extension will no longer show up in findings. Leave yourself a note on why you're keeping it.
поставил сам, пользуюсь	installed it myself, I use it
Сертификат перестанет попадать в находки. Если его когда-нибудь подменят, у подмены будет другой отпечаток — и она попадёт.	The certificate will no longer show up in findings. If it is ever swapped, the substitute will have a different thumbprint — and it will show up.
знаю, чей он	I know whose it is
Эта находка перестанет попадать в список.	This finding will no longer show up in the list.
Файла по пути {0} сейчас нет — доверие будет привязано к самой находке.	There is no file at {0} right now — trust will be tied to the finding itself.
разобрался, так и должно быть	checked it, it's supposed to be like this
# --- Ui.Inspector.ps1 ---
Узлов в карте: {0}, из них требующих внимания: {1}	Nodes in the map: {0}, needing attention: {1}
Разбор находки: {0}	Finding analysis: {0}
Карта скопирована в буфер обмена.	Map copied to the clipboard.
Сохранено: {0}	Saved: {0}
Не удалось сохранить: {0}	Couldn't save: {0}
# --- Ui.ScanBox.ps1: status line ---
в списке: {0}    к проверке: {1}    пропущено как безобидное: {2}	in list: {0}    to check: {1}    skipped as harmless: {2}
распаковываю {0}...	unpacking {0}...
считаю отпечаток ({0} из {1}): {2}	computing hash ({0} of {1}): {2}
спрашиваю VirusTotal ({0} из {1}): {2}	asking VirusTotal ({0} of {1}): {2}
начинаю	starting
проверка прервана: {0}	check interrupted: {0}
проверка закончена. Тревожных: {0} — это строки с пометкой CRIT и WARN.	check finished. Alarming: {0} — these are the rows marked CRIT and WARN.
проверка закончена, ничего тревожного не найдено	check finished, nothing alarming found
# --- Ui.ScanBox.ps1: file pickers and dialogs ---
Что проверить	What to check
Все файлы|*.*	All files|*.*
Какую папку проверить	Which folder to check
Архив под паролем	Password-protected archive
Без пароля заглянуть внутрь нельзя. Пароль нужен только для распаковки: он не сохраняется и никуда не передаётся.	Without the password there's no way to look inside. The password is used only to unpack: it is not saved and not sent anywhere.
Открыть	Open
Проверять нечего	Nothing to check
В списке нет файлов, которые имело бы смысл проверять: всё либо данные, либо подписано известным издателем, либо уже доверено вами.	There are no files in the list worth checking: everything is either data, signed by a known publisher, or already trusted by you.
# --- Ui.ScanBox.ps1: grid cells (kind, size, signature, verdict) ---
архив	archive
программа	program
сценарий	script
документ с кодом	document with code
данные	data
неизвестный формат	unknown format
{0} ГБ	{0} GB
{0} МБ	{0} MB
{0} КБ	{0} KB
{0} Б	{0} B
нет подписи	not signed
подпись недействительна: {0}	signature invalid: {0}
подписано известным издателем — проверять незачем	signed by a known publisher — no need to check
слишком большой файл — пропущен	file too large — skipped
данные, не исполняется — пропущен	data, not executable — skipped
архив под паролем — не открыт	password-protected archive — not opened
пароль не подошёл	wrong password
распакован: файлов внутри {0}	unpacked: {0} files inside
не удалось прочитать файл	couldn't read the file
нет ключа VirusTotal — задайте его в разделе «Защита»	no VirusTotal key — set it in the Protection section
нет данных	no data
опасным считают {0} из {1} антивирусов	{0} of {1} antivirus engines flag it as malicious
опасным считают {0} из {1} антивирусов — {2}	{0} of {1} antivirus engines flag it as malicious — {2}
чисто: 0 из {0} антивирусов	clean: 0 of {0} antivirus engines
VirusTotal такого файла не видел	VirusTotal has never seen this file
ключ VirusTotal не принят	VirusTotal key rejected
исчерпана квота ключа — повторите позже	key quota exhausted — try again later
ошибка запроса: {0}	request error: {0}
# --- Ui.ScanBox.ps1: row detail lines ---
Файл: {0}	File: {0}
Размер: {0}	Size: {0}
Изменён: {0}	Modified: {0}
Что это: {0}	What it is: {0}
Подпись: {0}	Signature: {0}
не проверялась	not checked
Из архива: {0}	From archive: {0}
Отпечаток: {0}	Hash: {0}
Вердикт: {0}	Verdict: {0}

# ---- frag-checks.txt ----
# lib\Checks.ps1
# --- Areas / categories ---
Брандмауэр	Firewall
Прокси	Proxy
Сертификаты	Certificates
Сеть	Network
Браузер	Browser
Копии	Copies
Права	Permissions
Новые файлы	New files
Аудит	Audit
# --- Autorun kinds ---
Реестр	Registry
Папка автозагрузки	Startup folder
Задача	Task
Служба	Service
Планировщик: {0}	Task Scheduler: {0}
Служба: {0}	Service: {0}
# --- Full scan progress steps ---
Защита Windows	Windows protection
Перехват трафика	Traffic interception
Сетевые соединения	Network connections
Запуск браузеров	Browser launch
Скрипты Adobe	Adobe scripts
Копии баз cookie	Cookie database copies
История обращений	Access history
Сверка с эталоном	Comparing with baseline
магазин: {0} ({1} из {2})	store: {0} ({1} of {2})
# --- Defender ---
Антивирус {0} установлен, но не защищает	Antivirus {0} is installed but not protecting
Он зарегистрирован в Windows, но его защита в реальном времени выключена. Включите её или удалите программу.	It is registered in Windows, but its real-time protection is off. Turn it on or uninstall the program.
Защита в реальном времени включена	Real-time protection is on
Защиту обеспечивает другой антивирус: {0}	Protection is provided by another antivirus: {0}
Windows штатно отключает Defender, когда работает сторонний антивирус.	Windows turns Defender off by design when a third-party antivirus is running.
У антивируса {0} устарели базы	Antivirus {0} has outdated signatures
Обновите его базы — защита есть, но она не знает про новое.	Update its signatures — protection is there, but it doesn't know about new threats.
Защита в реальном времени ВЫКЛЮЧЕНА	Real-time protection is OFF
Основная защита не работает. Включите её в "Безопасность Windows".	Main protection is not working. Turn it on in "Windows Security".
Защита от подделки настроек включена	Tamper protection is on
Защита от подделки настроек выключена	Tamper protection is off
Без неё вредонос сможет отключить антивирус сам.	Without it, malware can turn off the antivirus by itself.
Базы не обновлялись {0} дн.	Signatures not updated for {0} days
Базы свежие ({0} дн.)	Signatures are up to date ({0} days)
Поведенческий анализ выключен	Behavior monitoring is off
Возможно, установлен другой антивирус.	Another antivirus may be installed.
Заданы исключения антивируса: {0} шт.	Antivirus exclusions set: {0}
Папки:	Folders:
Расширения: {0}	Extensions: {0}
Процессы: {0}	Processes: {0}
Всё, что лежит в этих местах, антивирус НЕ проверяет. Если вы их не добавляли — это следы вмешательства.	The antivirus does NOT scan anything in these locations. If you didn't add them, this is a sign of tampering.
Исключений антивируса нет	No antivirus exclusions
В настройках принудительно отключён мониторинг	Monitoring is forcibly disabled in settings
Профиль {0}: включён	Profile {0}: on
Профиль {0}: ВЫКЛЮЧЕН	Profile {0}: OFF
# --- Traffic / proxy / hosts ---
Включён прокси-сервер для всего трафика	A proxy server is enabled for all traffic
Адрес прокси: {0}	Proxy address: {0}
Слушает программа: {0}	Listening program: {0}
Через эту программу идёт весь трафик браузеров — она видит всё. Убедитесь, что ставили её сами.	All browser traffic goes through this program — it sees everything. Make sure you installed it yourself.
Прокси не настроен	No proxy configured
Задан скрипт автонастройки прокси (PAC)	A proxy auto-config script (PAC) is set
Это классический способ незаметно завернуть трафик на чужой сервер.	This is a classic way to quietly route traffic to someone else's server.
Скрипт автонастройки прокси (PAC) не задан	No proxy auto-config script (PAC) is set
Задан системный прокси WinHTTP	A system WinHTTP proxy is set
Это прокси для системных служб и обновлений, отдельно от браузерного.	This is the proxy for system services and updates, separate from the browser one.
Системный прокси WinHTTP не задан	No system WinHTTP proxy is set
В файле hosts есть перенаправления: {0} шт.	The hosts file has redirects: {0}
Файл hosts без посторонних перенаправлений	The hosts file has no foreign redirects
# --- Root certificates ---
Посторонних корневых сертификатов не найдено	No foreign root certificates found
Нестандартный корневой сертификат: {0} — {1}	Non-standard root certificate: {0} — {1}
Нестандартный корневой сертификат: {0}	Non-standard root certificate: {0}
срок истёк	expired
трафик читать не может	cannot read traffic
антивирус ESET	ESET antivirus
антивирус Касперского	Kaspersky antivirus
антивирус Avast/AVG	Avast/AVG antivirus
антивирус или фильтр рекламы	antivirus or ad filter
отладочный прокси	debugging proxy
сертификат разработчика	developer certificate
программа на этом компьютере	a program on this computer
драйвер USB-устройства	USB device driver
подпись программ или драйверов	program or driver signing
Это сертификат вашего антивируса ESET. Им он проверяет защищённые сайты на вирусы: открывает HTTPS, смотрит и запечатывает обратно.	This is your ESET antivirus certificate. ESET uses it to scan secure sites for viruses: it opens HTTPS, inspects it and seals it back.
Это нормально, пока ESET установлен и вы ему доверяете. Если ESET удалён, а сертификат остался — его стоит убрать.	This is fine as long as ESET is installed and you trust it. If ESET was uninstalled but the certificate remains, remove it.
Сертификат антивируса Касперского для проверки защищённых сайтов.	Kaspersky antivirus certificate for scanning secure sites.
Нормально, пока антивирус установлен. Остался после удаления — уберите.	Fine while the antivirus is installed. Left over after uninstalling — remove it.
Сертификат Avast/AVG для проверки HTTPS («Веб-экран»).	Avast/AVG certificate for HTTPS scanning ("Web Shield").
Нормально, пока антивирус установлен.	Fine while the antivirus is installed.
Сертификат защитной программы, которая проверяет или фильтрует защищённые сайты. Ради этого она и читает HTTPS.	Certificate of a security program that scans or filters secure sites. That is why it reads HTTPS.
Нормально, пока эта программа установлена и нужна вам.	Fine as long as this program is installed and you need it.
Сертификат отладочного прокси (Fiddler, Charles, mitmproxy, Burp). Такие программы ставят его, чтобы показать разработчику содержимое HTTPS.	Certificate of a debugging proxy (Fiddler, Charles, mitmproxy, Burp). Such programs install it to show a developer the contents of HTTPS.
Пока он стоит, эта программа может читать весь ваш защищённый трафик. Если вы сейчас ничего не отлаживаете — его стоит убрать.	While it is installed, this program can read all your secure traffic. If you're not debugging anything right now, remove it.
Сертификат для разработки сайтов на этом компьютере (mkcert, IIS Express, ASP.NET).	Certificate for developing websites on this computer (mkcert, IIS Express, ASP.NET).
Опасен, только если его закрытый ключ утечёт. Не занимаетесь разработкой — уберите.	Dangerous only if its private key leaks. If you don't do development, remove it.
Сертификат, которым установленная программа (Battle.net, Razer и подобные) открывает защищённое соединение между сайтом в браузере и собой на этом же компьютере.	Certificate an installed program (Battle.net, Razer and the like) uses to open a secure connection between a website in the browser and itself on this same computer.
Ключ у этой программы, и сама она трафик не читает. Но ограничений у сертификата нет: если ключ украдут, им можно подделать любой сайт. Пользуетесь программой — доверьте; удалили — уберите. Ограничивать назначение не стоит: связь сайта с программой перестанет работать.	The key belongs to this program, and the program itself doesn't read traffic. But the certificate has no restrictions: if the key is stolen, it can be used to fake any website. If you use the program, trust it; if you removed it, remove the certificate. Don't restrict its purpose: the link between the website and the program will stop working.
Похоже на самодельный сертификат установщика драйвера USB-устройства (Zadig/libwdi, загрузчики микроконтроллеров, Universal ADB для Android). Им установщик подписал драйвер, чтобы Windows его приняла.	Looks like a self-made certificate from a USB device driver installer (Zadig/libwdi, microcontroller bootloaders, Universal ADB for Android). The installer signed the driver with it so Windows would accept it.
Обычно его ставят программы для прошивки плат и телефонов. Уже установленный драйвер продолжит работать и без этого сертификата; понадобится он, только если драйвер придётся ставить заново.	It is usually installed by programs for flashing boards and phones. An already installed driver keeps working without this certificate; it is only needed if the driver has to be reinstalled.
Сертификат разрешён только для подписи программ или драйверов. Такие ставят установщики драйверов и самодельных программ, чтобы Windows приняла их подпись.	The certificate is allowed only for signing programs or drivers. Such certificates are installed by driver and homemade program installers so Windows accepts their signature.
Читать трафик он не может. Если не помните, что ставили, — его можно убрать: уже установленное продолжит работать.	It cannot read traffic. If you don't remember installing it, you can remove it: what is already installed will keep working.
Программа не узнаёт этот сертификат. Его поставил кто-то из установленных программ или вы сами.	The program doesn't recognize this certificate. It was installed by one of your programs or by you.
Найдите в интернете имя из строки «Кому выдан». Если это ваша программа — ограничьте назначение или доверьте. Если имя ничего не говорит — уберите (копия сохранится).	Search the web for the name in the "Issued to" line. If it's your program, restrict its purpose or trust it. If the name means nothing to you, remove it (a copy will be kept).
любые (ограничений нет)	any (no restrictions)
никакие — сертификат выключен	none — the certificate is disabled
Нет. Срок действия истёк, Windows им больше не пользуется.	No. It has expired; Windows no longer uses it.
Нет. Он разрешён только для: {0}. Подделать им сайт Windows не позволит, сколько бы его ни пытались.	No. It is allowed only for: {0}. Windows won't let it be used to fake a website, no matter how hard anyone tries.
Да, и для этого он и стоит: так антивирус проверяет защищённые сайты.	Yes, and that's why it is installed: this is how the antivirus scans secure sites.
Да. Ограничений назначения у него нет: тот, у кого есть его закрытый ключ, может выдать себя за любой сайт, и браузер не заметит подмены.	Yes. It has no purpose restrictions: whoever has its private key can impersonate any website, and the browser won't notice the substitution.
нет — ключ хранится у того, кто выпустил сертификат	no — the key is kept by whoever issued the certificate
да, ключ лежит на этом компьютере — значит, сертификат создала одна из ваших программ	yes, the key is on this computer — so one of your programs created the certificate
«Ограничить назначение» — сертификат останется, но для сайтов Windows перестанет его принимать. Самый безопасный шаг: программы, которым он нужен для подписи драйверов, продолжат работать.	"Restrict purpose" — the certificate stays, but Windows will stop accepting it for websites. The safest step: programs that need it for signing drivers will keep working.
«Убрать сертификат» — он уйдёт из доверенных; копия сохранится, вернуть можно откатом.	"Remove certificate" — it leaves the trusted list; a copy is kept, and you can bring it back with an undo.
«Доверять» — если вы знаете, чей он, и хотите, чтобы программа о нём больше не спрашивала.	"Trust" — if you know whose it is and want the program to stop asking about it.
Кому выдан:   {0}	Issued to:   {0}
Действует до: {0}	Valid until: {0}
Отпечаток:    {0}	Thumbprint:  {0}
Назначения:   {0}	Purposes:    {0}
Закрытый ключ на этом компьютере: {0}	Private key on this computer: {0}
— ЧТО ЭТО ТАКОЕ —	— WHAT IS THIS —
ЧТО ЭТО ТАКОЕ —	WHAT IS THIS —
Корневой сертификат — печать, которой Windows верит без вопросов. Всё, что этой печатью заверено, браузер и система считают подлинным. Поэтому посторонняя печать в этом списке — повод разобраться, но ещё не взлом.	A root certificate is a seal Windows trusts without question. Everything certified with this seal is considered genuine by the browser and the system. So a foreign seal in this list is a reason to look into it, but not yet a breach.
— ЧЕЙ ОН, СКОРЕЕ ВСЕГО ({0}) —	— WHOSE IS IT, MOST LIKELY ({0}) —
ЧЕЙ ОН, СКОРЕЕ ВСЕГО ({0}) —	WHOSE IS IT, MOST LIKELY ({0}) —
— МОЖЕТ ЛИ ОН ЧИТАТЬ ВАШ ЗАЩИЩЁННЫЙ ТРАФИК —	— CAN IT READ YOUR SECURE TRAFFIC —
МОЖЕТ ЛИ ОН ЧИТАТЬ ВАШ ЗАЩИЩЁННЫЙ ТРАФИК —	CAN IT READ YOUR SECURE TRAFFIC —
— БЕЗОПАСНО ЛИ ОСТАВИТЬ —	— IS IT SAFE TO KEEP —
БЕЗОПАСНО ЛИ ОСТАВИТЬ —	IS IT SAFE TO KEEP —
— ЧТО МОЖНО СДЕЛАТЬ —	— WHAT YOU CAN DO —
ЧТО МОЖНО СДЕЛАТЬ —	WHAT YOU CAN DO —
# Localized EKU friendly names Windows returns on Russian systems (single-purpose case only)
Проверка подлинности сервера	Server Authentication
Проверка подлинности клиента	Client Authentication
Подписывание кода	Code Signing
Защищенная электронная почта	Secure Email
Установка штампа времени	Time Stamping
# --- Autorun entries ---
запускается из временной/пользовательской папки	runs from a temporary/user folder
запускается из AppData/ProgramData	runs from AppData/ProgramData
файл без подписи	unsigned file
подпись недействительна ({0})	invalid signature ({0})
в автозапуске интерпретатор или системная утилита	an interpreter or system utility in autostart
скрытая или закодированная команда	hidden or encoded command
скрытый запуск интерпретатора	hidden interpreter launch
запускается со скрытым окном	runs with a hidden window
файл не найден на диске	file not found on disk
Где прописано: {0}	Registered in: {0}
Команда: {0}	Command: {0}
указанная DLL подгружается в КАЖДУЮ запускаемую программу	the specified DLL is loaded into EVERY program that starts
DLL подгружается в каждую 32-битную программу	the DLL is loaded into every 32-bit program
запускается при каждом входе в систему	runs at every sign-in
оболочка рабочего стола	desktop shell
скрытый скрипт при входе	hidden sign-in script
{0} изменён	{0} changed
Ключ: {0}	Key: {0}
Значение: {0}	Value: {0}
Запуск программы заблокирован: {0}	Program launch blocked: {0}
Подставлено: {0}	Substituted: {0}
systray.exe — пустышка Windows. Так программы отключают утилиты для урезания телеметрии.	systray.exe is a Windows dummy. Telemetry-cutting utilities disable programs this way.
Если вы такую ставили — это она. Если нет — разберитесь.	If you installed one, this is it. If not, look into it.
Подменён запуск программы: {0}	Program launch hijacked: {0}
Вместо неё запускается: {0}	Launched instead: {0}
Так блокируют антивирусы и перехватывают запуск программ.	This is how antiviruses get blocked and program launches get hijacked.
Класс: {0}	Class: {0}
Фильтр: {0}	Filter: {0}
Потребитель: {0}	Consumer: {0}
Условие: {0}	Condition: {0}
Запускает: {0}	Runs: {0}
Скрипт: {0}	Script: {0}
Это способ запускать код по событию в обход автозагрузки. Им почти никто не пользуется, кроме вредоносов.	This is a way to run code on an event, bypassing autostart. Almost nobody uses it except malware.
Постоянная подписка WMI: {0}	Permanent WMI subscription: {0}
Посторонних постоянных подписок WMI нет	No foreign permanent WMI subscriptions
Подозрительных точек автозапуска не найдено	No suspicious autostart entries found
# --- Processes ---
Родитель: {0} (PID {1})	Parent: {0} (PID {1})
Цепочка: {0}	Chain: {0}
От имени: {0}	Run as: {0}
Запущен: {0}	Started: {0}
Процессов с признаками риска не найдено	No processes with risk signs found
{0}  (PID {1}, риск {2})	{0}  (PID {1}, risk {2})
# --- Network ---
{0} (PID {1}) выходит в интернет	{0} (PID {1}) connects to the internet
Куда: {0}	Destinations: {0}
Все соединения принадлежат известным подписанным программам	All connections belong to known signed programs
# --- Browser extensions ---
МОЖЕТ ЧИТАТЬ COOKIE НА ЛЮБОМ САЙТЕ — то есть войти в ваши аккаунты от вашего имени.	CAN READ COOKIES ON ANY SITE — meaning it can sign in to your accounts as you.
Имеет доступ к cookie на перечисленных сайтах.	Has access to cookies on the listed sites.
Право debugger — полный контроль над страницей, сильнее любого другого.	The debugger permission means full control over the page, stronger than any other.
Может менять настройки прокси — то есть куда идёт ваш трафик.	Can change proxy settings — that is, where your traffic goes.
Может общаться с программами на компьютере вне браузера.	Can talk to programs on the computer outside the browser.
Поставлено не из магазина (нет адреса обновления) — так ставят и разработчики, и вредоносы. Перепроверить его по магазину нельзя.	Not installed from the store (no update URL) — both developers and malware install extensions this way. It can't be re-checked against the store.
Ещё не перепроверено по магазину — это сделает «Перепроверить» в разделе «Расширения».	Not yet re-checked against the store — "Re-check" in the "Extensions" section will do it.
В магазине такого расширения НЕТ: его сняли с публикации, оно недоступно в вашей стране или его поставили в обход. Снятые расширения — частый след вредоноса; если это ваше и вы знаете, откуда оно, — нажмите «Доверять».	This extension is NOT in the store: it was unpublished, isn't available in your country, or was installed around the store. Removed extensions are a common sign of malware; if it's yours and you know where it came from, click "Trust".
Магазин: «{0}», пользователей: {1}, оценка {2}.	Store: "{0}", users: {1}, rating {2}.
Магазин: «{0}», пользователей: {1}.	Store: "{0}", users: {1}.
Это массовое расширение из магазина: права широкие, потому что без них оно не работает.	This is a widely used store extension: its permissions are broad because it doesn't work without them.
Опасно, только если вы его не ставили.	Dangerous only if you didn't install it.
Известное расширение, но права у него максимальные — держите, только если пользуетесь.	A well-known extension, but its permissions are maximal — keep it only if you use it.
Пользователей мало — проверьте, что ставили его сами.	Few users — make sure you installed it yourself.
Права у расширения прежние — просто вы решили его оставить. Снять доверие: вкладка «Доверенные».	The extension's permissions are unchanged — you just decided to keep it. To revoke trust: the "Trusted" tab.
Браузер: {0}	Browser: {0}
Профили: {0}	Profiles: {0}
Название: {0}	Name: {0}
Версия: {0}	Version: {0}
Опасные права: {0}	Dangerous permissions: {0}
Опасные права:	Dangerous permissions:
Сайты: {0}	Sites: {0}
Сайты:	Sites:
Перепроверка: {0}	Re-check: {0}
Папка: {0}	Folder: {0}
Страница в магазине: {0}	Store page: {0}
Расширений с опасными правами не найдено	No extensions with dangerous permissions found
Пустой ключ расширения в реестре: {0}	Empty extension key in the registry: {0}
Значений нет — ничего не устанавливается, это след от удалённой программы.	It has no values — nothing gets installed; it is a leftover from a removed program.
Расширение ставится через реестр: {0}	Extension installed via the registry: {0}
Источник: {0}	Source: {0}
Так расширения ставят в обход вашего согласия — Chrome подтянет его сам.	This is how extensions get installed without your consent — Chrome will pull it in by itself.
# --- Cookie database copies / permissions ---
Своё хранилище cookie у программы: {0}	Program's own cookie store: {0}
Это не копия браузера — программа на Chromium хранит здесь свои сессии.	This is not a browser copy — a Chromium-based program keeps its own sessions here.
Опасно, только если вы эту программу не ставили.	Dangerous only if you didn't install this program.
Копия базы браузера в неожиданном месте: {0}	Copy of a browser database in an unexpected place: {0}
Размер: {0} КБ	Size: {0} KB
Создан: {0}	Created: {0}
Браузеры и обычные программы сюда такие файлы не кладут.	Browsers and ordinary programs don't put such files here.
Копий баз cookie в подозрительных местах нет (своих хранилищ у программ: {0})	No cookie database copies in suspicious places (programs' own stores: {0})
К файлу cookie открыт доступ для {0}	Cookie file is accessible to {0}
Права: {0}	Rights: {0}
Эти файлы должны быть доступны только вам.	These files should be accessible only to you.
Права на файлы cookie не ослаблены	Cookie file permissions are not weakened
# --- Recently appeared files ---
{0} — {1} новых файлов	{0} — {1} new files
Появились: {0}	Appeared: {0}
Файлы: {0}	Files: {0}
Новых неподписанных программ за 14 дней не найдено	No new unsigned programs in the last 14 days
# --- Cookie access audit history ---
чтение содержимого	reading contents
запись	writing
удаление	deletion
смена прав доступа	permission change
чтение свойств файла	reading file properties
иное ({0})	other ({0})
(неизвестно)	(unknown)
Аудит доступа к файлам выключен — истории обращений нет	File access auditing is off — there is no access history
Нажмите «Включить аудит», чтобы Windows начала записывать, какая программа открывает файлы cookie. Без этого вопрос «кто взял мои cookie» остаётся без ответа.	Click "Enable auditing" so Windows starts recording which program opens cookie files. Without it, the question "who took my cookies" stays unanswered.
Аудит включён, обращений к файлам cookie за {0} дн. не зафиксировано	Auditing is on; no access to cookie files recorded in {0} days
Программа: {0}	Program: {0}
Что делала: {0}	What it did: {0}
Обращений: {0}	Accesses: {0}
Первое: {0}	First: {0}
Последнее: {0}	Last: {0}
Команда запуска: неизвестна — включите «Журнал запуска программ» в разделе «Защита», тогда она будет видна	Launch command: unknown — turn on "Process launch log" in the "Protection" section to see it
Команда запуска: {0}	Launch command: {0}
Файлы ({0}):	Files ({0}):
События:	Events:
... всего {0}, показаны первые 20	... {0} in total, first 20 shown
Проверить самому: Просмотр событий → Журналы Windows → Безопасность → фильтр по коду 4663.	Check it yourself: Event Viewer → Windows Logs → Security → filter by event ID 4663.
{0} — {1}, обращений: {2} (это сам браузер)	{0} — {1}, accesses: {2} (this is the browser itself)
Смена прав доступа — это НЕ чтение ваших cookie. Так выглядит установка аудита.	A permission change is NOT reading your cookies. This is what setting up auditing looks like.
Скорее всего, это сам CookieGuard, когда вы нажали «Включить аудит».	Most likely this is CookieGuard itself, when you clicked "Enable auditing".
{0} менял права доступа к файлам cookie ({1} раз)	{0} changed permissions on cookie files ({1} times)
{0} — {1}, обращений: {2}	{0} — {1}, accesses: {2}
Содержимое файла при этом не читалось.	The file contents were not read.
{0} ЧИТАЛ содержимое базы cookie ({1} раз)	{0} READ the contents of the cookie database ({1} times)
У обычной программы нет причин читать содержимое базы cookie браузера.	An ordinary program has no reason to read the contents of a browser's cookie database.
# --- Browser hijack ---
включён отладочный порт — через него можно забрать cookie уже расшифрованными, не трогая файл	debugging port is on — cookies can be taken through it already decrypted, without touching the file
принудительно загружено расширение из папки, в обход магазина	an extension is force-loaded from a folder, bypassing the store
отключена защита между сайтами	cross-site protection is disabled
подменена папка профиля	the profile folder is substituted
снята блокировка базы cookie	the cookie database lock is removed
{0} запущен с опасными ключами (PID {1})	{0} launched with dangerous switches (PID {1})
Процесс: {0}	Process: {0}
Запущен из: {0}	Launched from: {0}
Команда:	Command:
Если вы не запускали браузер вручную с такими ключами — закройте его и разберитесь, кто его так запустил.	If you didn't launch the browser with these switches yourself, close it and find out who launched it this way.
Открыт порт удалённого управления браузером: {0}	Browser remote control port is open: {0}
Слушает: {0}	Listening: {0}
Адрес: {0}	Address: {0}
Через этот порт можно управлять браузером и получать cookie в расшифрованном виде.	Through this port the browser can be controlled and cookies obtained in decrypted form.
Он нужен разработчикам. Если вы ничего не отлаживаете — это не должно быть открыто.	Developers need it. If you aren't debugging anything, it shouldn't be open.
Браузеры запущены обычным образом, портов удалённого управления нет	Browsers are launched normally; no remote control ports
# --- Adobe ---
запускает команды операционной системы	runs operating system commands
выполняет код из другого файла или из строки	executes code from another file or from a string
открывает сетевое соединение напрямую	opens a network connection directly
обращается к сети	accesses the network
вызывает системные утилиты	calls system utilities
текст собирается из кодов символов (приём сокрытия)	text is assembled from character codes (an obfuscation trick)
строки спрятаны за перекодировкой	strings are hidden behind re-encoding
внутри большой блок Base64	contains a large Base64 block
сам обращается к папке автозапуска скриптов	accesses the script autostart folder itself
пишет файлы на диск	writes files to disk
Программы Adobe не найдены — проверять нечего	No Adobe programs found — nothing to check
Найдено программ Adobe: {0}	Adobe programs found: {0}
лежит в папке автозапуска — выполняется сам при каждом старте программы	located in an autostart folder — runs by itself every time the program starts
лежит там, где файл можно подменить без прав администратора	located where the file can be replaced without administrator rights
скомпилированный .jsxbin — прочитать, что он делает, невозможно	compiled .jsxbin — it's impossible to read what it does
появился недавно: {0}	appeared recently: {0}
Оценка: {0}	Score: {0}
Что делать: вспомните, какой плагин вы ставили. Если такого плагина вы не ставили —	What to do: recall which plugin you installed. If you didn't install such a plugin,
уберите файл в карантин кнопкой ниже и перезапустите программу Adobe.	move the file to quarantine with the button below and restart the Adobe program.
Ещё {0} скриптов с признаками риска не показаны	{0} more scripts with risk signs not shown
Проверено скриптов: {0}, помечено: {1}	Scripts checked: {0}, flagged: {1}
Подозрительных скриптов в папках Adobe не найдено	No suspicious scripts found in Adobe folders
Один и тот же скрипт лежит в автозапуске нескольких программ	The same script sits in the autostart of several programs
Копии:	Copies:
Сам себя копирующий скрипт — это поведение червя. Законные плагины так не ставятся.	A self-copying script is worm behavior. Legitimate plugins don't install this way.
Скриптам разрешено писать файлы и выходить в сеть	Scripts are allowed to write files and access the network
Файл настроек: {0}	Settings file: {0}
Это та самая галка «Allow Scripts to Write Files and Access Network».	This is the "Allow Scripts to Write Files and Access Network" checkbox.
Без неё многие плагины не работают — но с ней ЛЮБОЙ скрипт получает диск и сеть.	Many plugins don't work without it — but with it ANY script gets the disk and the network.
Если сейчас вы плагинами не пользуетесь, снимите её:	If you don't use plugins right now, clear it:
Premiere/After Effects → Правка → Настройки → Сценарии и выражения.	Premiere/After Effects → Edit → Preferences → Scripting & Expressions.
Разрешение скриптам на диск и сеть нигде не включено	Script disk and network access is not enabled anywhere
Разрешена загрузка неподписанных расширений ({0})	Loading of unsigned extensions is allowed ({0})
Значение PlayerDebugMode = 1	Value PlayerDebugMode = 1
Adobe обычно грузит только подписанные расширения. Этот режим снимает проверку —	Adobe normally loads only signed extensions. This mode removes the check —
его включают разработчики, а ещё его включают установщики пиратских плагинов,	developers turn it on, and so do installers of pirated plugins,
чтобы протащить своё. Если вы не пишете расширения сами — выключите.	to sneak their stuff in. If you don't write extensions yourself, turn it off.
Загрузка неподписанных расширений выключена	Loading of unsigned extensions is off
только для вас	for you only
для всех пользователей	for all users
Это собственная панель Adobe: подписана и опознана по идентификатору com.adobe.*. Так и должно быть.	This is Adobe's own panel: signed and identified by the com.adobe.* ID. This is as it should be.
Расширение подписано, то есть установлено из готового пакета ZXP, а не подложено в папку. Это не гарантия честности, но подделать подпись без ключа издателя нельзя.	The extension is signed, meaning it was installed from a ready-made ZXP package rather than dropped into the folder. That doesn't guarantee honesty, but a signature can't be faked without the publisher's key.
Подписи нет, но загрузка неподписанных расширений выключена (PlayerDebugMode = 0) — значит, Adobe его НЕ ЗАГРУЖАЕТ. Сейчас оно просто лежит на диске и не работает.	No signature, but loading of unsigned extensions is off (PlayerDebugMode = 0) — so Adobe does NOT LOAD it. Right now it just sits on disk and does nothing.
Подписи нет, И при этом включена загрузка неподписанных расширений. Вот сочетание, ради которого эта проверка и сделана: расширение будет загружено, хотя никто за него не отвечает.	No signature, AND loading of unsigned extensions is on. This is exactly the combination this check exists for: the extension will be loaded although no one vouches for it.
Установлено: {0}	Installed: {0}
Идентификатор: {0}	ID: {0}
Подключается к: {0}	Runs in: {0}
Подпись пакета: есть	Package signature: present
Подпись пакета: нет	Package signature: none
Загрузка неподписанных (PlayerDebugMode): ВКЛЮЧЕНА	Loading unsigned (PlayerDebugMode): ON
Загрузка неподписанных (PlayerDebugMode): выключена	Loading unsigned (PlayerDebugMode): off
Что расширение умеет (вес {0}):	What the extension can do (weight {0}):
Встречено в файлах: {0}	Found in files: {0}
Сами по себе эти вызовы законны — ими пользуются и честные панели. Значение имеет их совокупность вместе с отсутствием подписи.	These calls are legitimate on their own — honest panels use them too. What matters is their combination together with the missing signature.
Обращений к системе и сети внутри не найдено.	No system or network calls found inside.
Что делать: сейчас оно безвредно, потому что не загружается. Но если когда-нибудь включите загрузку неподписанных расширений — оно оживёт. Если такую панель вы не ставили, папку лучше убрать.	What to do: it's harmless right now because it isn't loaded. But if you ever turn on loading of unsigned extensions, it will come alive. If you didn't install such a panel, better remove the folder.
Что делать: ничего. Если панель вам не нужна — удалите её через Creative Cloud, а не из папки.	What to do: nothing. If you don't need the panel, uninstall it via Creative Cloud, not from the folder.
Что делать: вспомните, ставили ли вы такую панель. Если нет — выключите PlayerDebugMode (находка выше), и расширение перестанет загружаться; саму папку можно убрать в карантин.	What to do: recall whether you installed such a panel. If not, turn off PlayerDebugMode (the finding above) and the extension will stop loading; the folder itself can be moved to quarantine.
Расширение Adobe: {0}	Adobe extension: {0}
Расширений Adobe в пользовательских папках нет	No Adobe extensions in user folders
# --- Process launch history ---
запущен из временной или пользовательской папки	launched from a temporary or user folder
интерпретатор или системная утилита	interpreter or system utility
журнал 4688	log 4688
Время: {0}	Time: {0}
Запущена из: {0}	Launched from: {0}
(журнал запуска выключен — командная строка неизвестна)	(launch log is off — command line unknown)
Последний запуск: {0}	Last launch: {0}
Это данные из Prefetch — Windows помнит сам факт запуска, но не команду и не того, кто запустил.	This is Prefetch data — Windows remembers that the program ran, but not the command or who launched it.
Включите журнал запуска программ, чтобы видеть полную картину.	Turn on the process launch log to see the full picture.

# ---- frag-mondiag.txt ----
# lib\Monitor.ps1, lib\Diagnose.ps1, lib\Baseline.ps1, lib\Inspect.ps1, lib\Core.ps1
# ---- Monitor.ps1: tolerated system programs (shown in event titles) ----
Антивирус Windows Defender	Windows Defender antivirus
Индексатор поиска Windows	Windows Search indexer
Ядро Windows	Windows kernel
Фоновая задача Windows	Windows background task
# ---- Monitor.ps1: event kinds ----
Доступ	Access
Процесс	Process
Копия	Copy
# ---- Monitor.ps1: cookie access events ----
{0} читает свои cookie — норма	{0} is reading its own cookies — normal
{0} обращается к данным браузера {1}	{0} is accessing {1} browser data
Процесс: {0} (PID {1})	Process: {0} (PID {1})
Так выглядит импорт закладок и паролей из другого браузера.	This is what importing bookmarks and passwords from another browser looks like.
Если вы сейчас ничего не импортировали — разберитесь.	If you didn't import anything just now, look into it.
{0} ({1}) обратился к {2}	{0} ({1}) accessed {2}
Это ожидаемое поведение системной программы.	This is expected behavior for a system program.
{0} обратился к cookie — доверено вами	{0} accessed cookies — trusted by you
Что делал: {0}	Action: {0}
Вы пометили её доверенной: {0}	You marked it as trusted: {0}
Вы пометили её доверенной.	You marked it as trusted.
данные браузера	browser data
база cookie — активные входы в ваши аккаунты	cookie database — active sign-ins to your accounts
Кто прочитал этот файл, может войти в ваши аккаунты без пароля, пока сессии живы.	Whoever read this file can sign in to your accounts without a password while the sessions are alive.
база сохранённых паролей браузера	the browser's saved password database
Здесь лежат логины и пароли, сохранённые в браузере.	It holds the logins and passwords saved in the browser.
автозаполнение: адреса, карты, формы	autofill: addresses, cards, forms
Здесь данные автозаполнения, включая платёжные.	It holds autofill data, including payment details.
ключ шифрования базы cookie	cookie database encryption key
Без этого файла cookie не расшифровать. Его читают вместе с базой, чтобы раскрыть её.	Cookies can't be decrypted without this file. It is read together with the database to unlock it.
Время:      {0}	Time:       {0}
Что взяли:  {0}	Taken:      {0}
Браузер:    {0}, профиль «{1}»	Browser:    {0}, profile "{1}"
Браузер:    {0}	Browser:    {0}
Файл:       {0}	File:       {0}
Что делал:  {0}	Action:     {0}
Процесс:    {0}	Process:    {0}
Подпись:    {0} {1}	Signature:  {0} {1}
Чем это грозит: {0}	Why it matters: {0}
Запущен из: {0} (PID {1})	Started by: {0} (PID {1})
Работает с: {0}	Running since: {0}
Команда:    {0}	Command:    {0}
Процесс уже завершился — похоже, он взял файл и закрылся.	The process has already exited — it seems it grabbed the file and closed.
Улики сохранены: {0}	Evidence saved: {0}
Смена прав — так выглядит установка аудита, в том числе самим CookieGuard.	A permissions change is what setting up auditing looks like, including by CookieGuard itself.
Посторонняя программа трогала файл cookie: {0} ({1})	A third-party program touched a cookie file: {0} ({1})
ПОСТОРОННЯЯ ПРОГРАММА ЧИТАЕТ БАЗУ COOKIE: {0}	A THIRD-PARTY PROGRAM IS READING THE COOKIE DATABASE: {0}
# ---- Monitor.ps1: new process events ----
Запустился подозрительный процесс: {0} (риск {1})	Suspicious process started: {0} (risk {1})
# ---- Monitor.ps1: cookie database copies ----
ПОЯВИЛАСЬ КОПИЯ БАЗЫ COOKIE ВНЕ ПАПКИ БРАУЗЕРА	A COPY OF THE COOKIE DATABASE APPEARED OUTSIDE THE BROWSER FOLDER
Браузеры не кладут такие файлы сюда. Так делают программы, которые готовят данные к отправке наружу.	Browsers don't put such files here. This is what programs do when preparing data to send out.
# ---- Core.ps1: process risk reasons (shown in Monitor details and process findings) ----
нет пути к исполняемому файлу (процесс скрывает образ)	no path to the executable (the process hides its image)
подпись системного файла повреждена: {0}	system file signature is damaged: {0}
файл без цифровой подписи (но в Program Files)	file has no digital signature (but is in Program Files)
файл без цифровой подписи	file has no digital signature
подписан малоизвестным издателем: {0}	signed by a little-known publisher: {0}
запущен из временной папки (Temp)	launched from a temporary folder (Temp)
запущен прямо из папки Загрузки	launched straight from the Downloads folder
запущен из Public / Корзины	launched from Public / Recycle Bin
запущен из ProgramData	launched from ProgramData
запущен из AppData\\Roaming	launched from AppData\\Roaming
запущен из нетипичной папки в корне диска	launched from an unusual folder at the drive root
имя системного процесса, но файл лежит НЕ в System32: {0}	system process name, but the file is NOT in System32: {0}
двойное расширение в имени файла	double extension in the file name
в имени файла спрятан символ переворота текста (RLO)	the file name hides a text-reversal character (RLO)
PowerShell запущен с командой в Base64 (-EncodedCommand)	PowerShell started with a Base64 command (-EncodedCommand)
расшифровка Base64 прямо в командной строке	Base64 decoding right in the command line
скрытое окно / без профиля	hidden window / no profile
скачивание из сети прямо из командной строки	downloading from the network right from the command line
выполнение строки как кода (IEX)	executing a string as code (IEX)
certutil используется для скачивания/декодирования файла	certutil is used to download/decode a file
bitsadmin качает файл	bitsadmin is downloading a file
mshta выполняет удалённый/встроенный скрипт	mshta is running a remote/inline script
regsvr32 подгружает сторонний скриптлет	regsvr32 is loading a third-party scriptlet
rundll32 грузит DLL из пользовательской папки	rundll32 is loading a DLL from a user folder
системная утилита запущена копией из пользовательской папки	a system utility was launched from a copy in a user folder
офисная программа ({0}) запустила интерпретатор	an Office program ({0}) launched an interpreter
браузер ({0}) запустил помощника расширения — штатный механизм native messaging	the browser ({0}) launched an extension helper — the standard native messaging mechanism
браузер ({0}) запустил интерпретатор	the browser ({0}) launched an interpreter
файл появился недавно: {0}	the file appeared recently: {0}
# ---- Diagnose.ps1: result detail lines ----
Проверка: {0}	Check: {0}
Результат: {0}	Result: {0}
Что делать: {0}	What to do: {0}
# ---- Diagnose.ps1: check names ----
Антивирус на компьютере	Antivirus on this computer
Defender запрещён политикой	Defender disabled by policy
Служба Defender (WinDefend)	Defender service (WinDefend)
Защита Windows в реальном времени	Windows real-time protection
Защита от подделки Defender	Defender tamper protection
Права администратора	Administrator rights
Средство auditpol	auditpol tool
Политика аудита файловой системы	File system audit policy
Аудит запуска программ	Process launch auditing
Групповая политика аудита	Audit group policy
Файлы браузеров	Browser files
Журнал безопасности	Security log
Планировщик заданий	Task Scheduler
Политика выполнения PowerShell	PowerShell execution policy
Папка данных	Data folder
# ---- Diagnose.ps1: result values ----
{0} (работает)	{0} (running)
{0} (не работает)	{0} (not running)
состояние: {0}	state: {0}
работает, базам {0} дн.	running, signatures {0} days old
выключена — место занято другим антивирусом	off — another antivirus has taken its place
выключена, и другого антивируса нет	off, and there is no other antivirus
выключена, а зарегистрированный антивирус не работает	off, and the registered antivirus isn't running
включена	on
выключена	off
не отвечает — работает другой антивирус	not responding — another antivirus is running
не отвечает, и другого антивируса не видно	not responding, and no other antivirus is visible
есть	yes
нет	no
не отвечает	not responding
включена ({0})	on ({0})
включён ({0})	on ({0})
задана на этом компьютере	set on this computer
не перекрывает настройки	does not override the settings
найдено {0} в браузерах: {1}	{0} found in browsers: {1}
не найдено ни одного	none found
доступен, размер {0} МБ	available, size {0} MB
недоступен	unavailable
служба не найдена	service not found
доступна на запись: {0}	writable: {0}
нет записи: {0}	not writable: {0}
# ---- Diagnose.ps1: advice ----
Пока работает сторонний антивирус, Windows намеренно держит Defender выключенным — двум антивирусам в реальном времени нельзя работать вместе. Это не поломка, и включать Defender не нужно.	While a third-party antivirus is running, Windows deliberately keeps Defender off — two real-time antiviruses can't work together. This isn't a fault, and there's no need to turn Defender on.
Сторонний антивирус зарегистрирован, но сам не работает. Защиты сейчас может не быть вовсе: Defender уступил ему место, а он не включён. Либо запустите его, либо удалите — тогда Defender вернётся сам.	A third-party antivirus is registered but isn't running. There may be no protection at all right now: Defender stepped aside for it, and it isn't on. Either start it or uninstall it — then Defender will come back on its own.
Вот почему переключатель не держится: политика выключает защиту заново. Такие ключи ставит либо администратор домена, либо «оптимизатор» или сборка Windows, либо вредонос, которому защита мешает. Если компьютер ваш — удалите эти значения реестра и перезагрузитесь, затем включите защиту в «Безопасность Windows».	This is why the switch won't stay on: the policy turns protection off again. Such keys are set by a domain administrator, by an "optimizer" or a custom Windows build, or by malware that protection gets in the way of. If the computer is yours, delete these registry values and restart, then turn protection on in "Windows Security".
Служба антивируса не работает, а другого антивируса на компьютере нет. Пока она остановлена, защиту включить не получится.	The antivirus service isn't running, and there's no other antivirus on the computer. While it's stopped, protection can't be turned on.
Так и должно быть: защищает {0}.	That's expected: {0} is protecting the computer.
Компьютер сейчас без постоянной защиты. CookieGuard её не заменяет и включить не может — это делается в «Безопасность Windows» → «Защита от вирусов и угроз» → «Управление настройками». Если переключатель там не поддаётся или сам возвращается в «выкл» — смотрите пункты про политику и про защиту от подделки выше.	The computer currently has no real-time protection. CookieGuard doesn't replace it and can't turn it on — that's done in "Windows Security" → "Virus & threat protection" → "Manage settings". If the switch there won't budge or flips back to "Off" by itself, see the policy and tamper protection items above.
Пока она включена, настройки Defender нельзя менять ни программой, ни реестром — только руками в «Безопасность Windows». Это защита, а не неисправность.	While it's on, Defender settings can't be changed by a program or through the registry — only by hand in "Windows Security". This is protection, not a fault.
Без неё отключить антивирус может любая программа с правами администратора — в том числе вредонос. Включается в «Безопасность Windows» → «Защита от вирусов и угроз» → «Управление настройками».	Without it, any program with administrator rights can turn off the antivirus — including malware. Turn it on in "Windows Security" → "Virus & threat protection" → "Manage settings".
Defender отключён в пользу {0}. Это нормально.	Defender is off in favor of {0}. This is normal.
Модуль Defender не удалось опросить, а зарегистрированного антивируса нет. Похоже, защита снята намеренно — либо «оптимизатором», либо вредоносом. Проверьте «Безопасность Windows».	The Defender module couldn't be queried, and no antivirus is registered. Protection appears to have been removed on purpose — either by an "optimizer" or by malware. Check "Windows Security".
Аудит, журнал запусков и сторож меняют настройки Windows и без прав администратора включиться не могут. Закройте окно и запустите CookieGuard.exe (он запросит повышение), либо правой кнопкой по ярлыку — «Запуск от имени администратора».	Auditing, the launch log and the guard change Windows settings and can't be turned on without administrator rights. Close the window and run CookieGuard.exe (it will ask for elevation), or right-click the shortcut → "Run as administrator".
Windows не дала опросить политику аудита: {0}	Windows didn't allow querying the audit policy: {0}
Без auditpol включить аудит доступа к файлам нельзя. Такое бывает на сильно урезанных сборках Windows и в системах под управлением организации.	File access auditing can't be turned on without auditpol. This happens on heavily stripped-down Windows builds and on organization-managed systems.
Это и включает переключатель «Аудит доступа к cookie». Если после включения проверка снова показывает «выключена» — политику перекрывает групповая политика, смотрите следующий пункт.	This is what the "Cookie access auditing" switch turns on. If the check still shows "off" after you turn it on, a group policy is overriding it — see the next item.
Включается кнопкой «Журнал запуска программ» в разделе «Защита».	Turned on with the "Process launch log" button in the "Protection" section.
Политика перезапишет настройки аудита при очередном обновлении (gpupdate, перезагрузка). Если компьютер ваш — удалите этот файл или задайте аудит через «Локальная политика безопасности» (secpol.msc → Конфигурация расширенной политики аудита → Доступ к объектам → Аудит файловой системы).	The policy will overwrite the audit settings on its next refresh (gpupdate, restart). If the computer is yours, delete this file or set auditing in "Local Security Policy" (secpol.msc → Advanced Audit Policy Configuration → Object Access → Audit File System).
Аудит ставится на конкретные файлы — Cookies, Login Data. Если браузер ни разу не запускали или он установлен не туда, где его ищет программа, ставить аудит не на что, и включение заканчивается ничем. Запустите браузер хотя бы раз и повторите.	Auditing is set on specific files — Cookies, Login Data. If the browser has never been started, or it's installed somewhere the program doesn't look, there's nothing to audit and turning it on does nothing. Start the browser at least once and try again.
Без журнала безопасности события аудита читать неоткуда. Проверьте, запущена ли служба «Журнал событий Windows» (EventLog).	Without the Security log there's nowhere to read audit events from. Check that the "Windows Event Log" service (EventLog) is running.
Постоянная защита — это две задачи планировщика. Пока служба «Планировщик заданий» не запущена, переключатель будет возвращаться в положение «выключено».	Always-on protection is two scheduled tasks. Until the "Task Scheduler" service is running, the switch will keep flipping back to "off".
Вспомогательные сценарии запускаются с ключом -ExecutionPolicy Bypass и этой политике не подчиняются, но если политику задаёт домен, запуск может быть заблокирован целиком.	Helper scripts run with -ExecutionPolicy Bypass and aren't subject to this policy, but if the policy is set by a domain, running them may be blocked entirely.
Сюда пишутся эталон, список доверенных и карантин. Без записи почти ничего не сохранится. Запустите программу от имени администратора.	The baseline, the trusted list and quarantine are written here. Without write access almost nothing will be saved. Run the program as administrator.
# ---- Diagnose.ps1: one-line summary (status bar) ----
мешает работе: {0}, под вопросом: {1}	blocking: {0}, questionable: {1}
под вопросом: {0}, непреодолимых помех нет	questionable: {0}, nothing blocking
помех не найдено — всё необходимое на месте	no obstacles found — everything needed is in place
# ---- Baseline.ps1: progress steps ----
расширения браузеров	browser extensions
скрипты Adobe	Adobe scripts
корневые сертификаты	root certificates
сеть и защита	network and protection
службы	services
готово	done
# ---- Baseline.ps1: section titles and area ----
Расширение браузера	Browser extension
Скрипт Adobe	Adobe script
Корневой сертификат	Root certificate
Сеть и защита	Network and protection
# ---- Baseline.ps1: findings ----
Эталон не снят	No baseline taken
Нажмите «Снять эталон», когда будете уверены, что система в порядке. После этого программа начнёт замечать любое изменение автозапуска, расширений, скриптов Adobe, сертификатов и настроек сети — даже если такого вредоноса ещё нет ни в одной антивирусной базе.	Click "Take baseline" when you're sure the system is in good shape. After that the program will notice any change to autostart, extensions, Adobe scripts, certificates and network settings — even if that malware isn't in any antivirus database yet.
ПОЯВИЛОСЬ — {0}: {1}	APPEARED — {0}: {1}
ИЗМЕНИЛОСЬ — {0}: {1}	CHANGED — {0}: {1}
ИСЧЕЗЛО — {0}: {1}	DISAPPEARED — {0}: {1}
Чего раньше не было:	What wasn't there before:
Значение:	Value:
Эталон снят: {0}	Baseline taken: {0}
Если вы в это время что-то устанавливали — всё в порядке, обновите эталон.	If you installed something during this time, all is well — update the baseline.
Если нет — разбирайтесь именно с этим.	If not, this is exactly what to look into.
Было:	Was:
Стало:	Now:
Было в эталоне, сейчас нет:	In the baseline, but gone now:
Обычно это удаление программы. Но так же выглядит и отключение защиты.	Usually this means a program was uninstalled. But disabling protection looks the same.
С момента снятия эталона ничего не изменилось ({0})	Nothing has changed since the baseline was taken ({0})
Автозапуск, расширения, скрипты Adobe, сертификаты, прокси и службы — всё как было.	Autostart, extensions, Adobe scripts, certificates, proxy and services — all as before.
Изменений с момента эталона: {0}	Changes since the baseline: {0}
# ---- Inspect.ps1: analysis tree nodes ----
Путь пуст	Path is empty
Файла по этому пути нет. Запись, ведущая в пустоту, — это либо мусор от удалённой программы, либо готовая точка перехвата: кто первым положит туда файл, тот и получит запуск.	There's no file at this path. An entry pointing to nothing is either leftovers from an uninstalled program or a ready-made hijack point: whoever puts a file there first gets it launched.
Что с этим связано сейчас	What is linked to it right now
Запущен: {0} (PID {1})	Running: {0} (PID {1})
Командная строка: {0}	Command line: {0}
Родитель: PID {0}	Parent: PID {0}
Соединение: {0}:{1}	Connection: {0}:{1}
Сейчас не запущен	Not running right now
Автозапуск: {0}	Autostart: {0}
Где: {0}	Where: {0}
Задача: {0}	Task: {0}
Состояние: {0}	State: {0}
Ключа нет	Key doesn't exist
…ещё значений: {0}	…more values: {0}
Показаны не все: предел обхода	Not all shown: traversal limit
(по умолчанию) = {0}	(default) = {0}
Тип: {0}	Type: {0}
…ещё подветок: {0}	…more subkeys: {0}
…глубже не разбирали	…not analyzed any deeper
Предел глубины {0}	Depth limit {0}
выход в сеть ({0})	network access ({0})
запуск программ ({0})	launching programs ({0})
работа с файлами ({0})	file operations ({0})
системный мост CEP ({0})	CEP system bridge ({0})
выполнение строки как кода ({0})	executing a string as code ({0})
Папки нет	Folder doesn't exist
Файлов здесь: {0}, папок: {1}	Files here: {0}, folders: {1}
Объём файлов здесь: {0} КБ	Size of files here: {0} KB
…файлов больше, чем показано	…more files than shown
Предел обхода	Traversal limit
Найдено в тексте файла	Found in the file's text
Манифест расширения	Extension manifest
Встраивается в: {0}	Embeds into: {0}
Включён Node.js	Node.js enabled
Расширение может работать с файлами и сетью напрямую, минуя ограничения панели.	The extension can work with files and the network directly, bypassing the panel's restrictions.
Общий контекст для всех панелей	Shared context for all panels
Манифест не разобрался	Couldn't parse the manifest
Нечего разбирать	Nothing to analyze
У этой находки нет объекта на диске или в реестре	This finding has no object on disk or in the registry
Разбирать нечего: находка описывает состояние системы, а не предмет.	Nothing to analyze: the finding describes a system state, not an object.
Задача {0} не найдена	Task {0} not found
Задача {0}	Task {0}
Автор: {0}	Author: {0}
Когда: {0}	When: {0}
Служба {0}	Service {0}
Отображается как: {0}	Display name: {0}
Запуск: {0}	Start mode: {0}

# ---- frag-remedy.txt ----
# lib\Remedy.ps1, lib\Trust.ps1, lib\Actions.ps1, lib\Archive.ps1, lib\SafeDns.ps1, lib\VirusTotal.ps1, lib\Update.ps1
#
# ---- Remedy.ps1: fixer buttons ----
Исправить везде	Fix everywhere
Ограничить	Restrict
Убрать	Remove
# ---- Remedy.ps1: fixer titles and explanations ----
Выключить загрузку неподписанных расширений в этой версии	Turn off loading of unsigned extensions in this version
PlayerDebugMode станет 0. Подписанные панели Adobe продолжат работать, неподписанные перестанут загружаться.	PlayerDebugMode will be set to 0. Signed Adobe panels keep working; unsigned ones stop loading.
Выключить во всех версиях Adobe сразу	Turn off in all Adobe versions at once
Пройдёт по всем ключам CSXS.* текущего пользователя и выставит PlayerDebugMode = 0.	Goes through all CSXS.* keys of the current user and sets PlayerDebugMode = 0.
Убрать запись автозапуска	Remove autostart entry
Значение удаляется из ветки Run. Прежнее значение целиком сохраняется в записи отката, вернуть можно одним действием.	The value is deleted from the Run key. The previous value is saved in full in an undo record and can be restored in one step.
Выключить задачу планировщика	Disable scheduled task
Задача останется на месте, но перестанет запускаться. Включить обратно можно откатом.	The task stays in place but stops running. You can re-enable it by undoing.
Вернуть нормальный запуск программы	Restore normal program launch
Удаляется значение Debugger, которым подменён запуск. Прежнее значение сохраняется в записи отката.	The Debugger value that hijacks the launch is deleted. The previous value is saved in an undo record.
Вернуть значение по умолчанию	Restore default value
Ключу возвращается штатное значение Windows. Текущее сохраняется в записи отката.	The key gets its standard Windows value back. The current value is saved in an undo record.
Убрать папку расширения в карантин	Move extension folder to quarantine
Вся папка расширения переносится в карантин целиком — со скриптами, манифестом и ресурсами. Содержимое не удаляется и возвращается откатом.	The whole extension folder is moved to quarantine — scripts, manifest and resources included. Nothing is deleted, and undoing brings it back.
Ограничить назначение сертификата	Restrict certificate purpose
Сертификат останется в системе, но Windows перестанет принимать его для защищённых сайтов: только подпись программ и драйверов. Читать ваш трафик через него станет нельзя. Вернуть можно откатом.	The certificate stays in the system, but Windows will no longer accept it for secure websites: only for signing programs and drivers. It can no longer be used to read your traffic. You can undo this.
Убрать сертификат из доверенных	Remove certificate from trusted
Сертификат уйдёт из списка, которому Windows верит без вопросов. Копия сохранится в папке undo, вернуть можно откатом. Программа, которая его ставила, может попросить его снова — тогда вы будете знать, чья это печать.	The certificate leaves the list Windows trusts unconditionally. A copy is saved in the undo folder, and you can undo this. The program that installed it may ask for it again — then you will know whose seal it is.
# ---- Remedy.ps1: plan steps (fields and lines as composed in the confirm dialog) ----
Значение реестра	Registry value
Удалить значение	Delete value
(нет)	(none)
Выключить задачу	Disable task
Удалить подмену	Remove hijack
Вернуть значение	Restore value
Перенести папку в карантин	Move folder to quarantine
на месте	in place
карантин	quarantine
Внутри	Contents
файлов: {0}, объём: {1} КБ	files: {0}, size: {1} KB
Назначение сертификата	Certificate purpose
любое, включая сайты	any, including websites
только подпись кода	code signing only
Убрать из доверенных корневых	Remove from trusted roots
доверен	trusted
копия в undo	copy in undo
Значение реестра: {0}	Registry value: {0}
Удалить значение: {0}   {1} -> (нет)	Delete value: {0}   {1} -> (none)
Выключить задачу: {0}   включена -> выключена	Disable task: {0}   enabled -> disabled
Удалить подмену: {0}   {1} -> (нет)	Remove hijack: {0}   {1} -> (none)
Вернуть значение: {0}	Restore value: {0}
Перенести папку в карантин: {0}   на месте -> карантин	Move folder to quarantine: {0}   in place -> quarantine
Внутри: файлов: {0}, объём: {1} КБ	Contents: files: {0}, size: {1} KB
Назначение сертификата: {0}   любое, включая сайты -> только подпись кода	Certificate purpose: {0}   any, including websites -> code signing only
Убрать из доверенных корневых: {0}   доверен -> копия в undo	Remove from trusted roots: {0}   trusted -> copy in undo
# ---- Remedy.ps1: fix and undo result messages ----
Исправление ничего не вернуло	The fix returned nothing
Запись отката не найдена	Undo record not found
Запись отката не читается	Undo record cannot be read
Возвращено: {0}	Restored: {0}
Возвращено {0}, не вышло {1}	Restored {0}, failed {1}
Не удалось записать: {0}	Could not write: {0}
Ни одного ключа изменить не удалось	Could not change any key
Выключено в {0} ключах	Turned off in {0} keys
Эта ветка реестра общая для всех — нужны права администратора	This registry branch is shared by all users — administrator rights are required
Записи уже нет	The entry is already gone
Не удалось удалить: {0}	Could not delete: {0}
Запись «{0}» убрана из автозапуска	Entry “{0}” removed from autostart
Не удалось выключить: {0}	Could not disable: {0}
Задача «{0}» выключена	Task “{0}” disabled
Ветка общая для всех — нужны права администратора	The branch is shared by all users — administrator rights are required
Подмены уже нет	The hijack is already gone
Не удалось: {0}	Failed: {0}
Запуск «{0}» больше не подменяется	Launch of “{0}” is no longer hijacked
Нужны права администратора	Administrator rights are required
Значение возвращено	Value restored
Папки уже нет	The folder is already gone
Не удалось перенести: {0}	Could not move: {0}
Папка перенесена в карантин	Folder moved to quarantine
Сертификаты компьютера меняются только с правами администратора	Computer certificates can only be changed with administrator rights
Сертификата уже нет	The certificate is already gone
Windows не дала изменить свойство сертификата	Windows did not allow changing the certificate property
Сертификат «{0}» больше не годится для сайтов	Certificate “{0}” is no longer valid for websites
Сертификат «{0}» убран, копия: {1}	Certificate “{0}” removed, copy: {1}
#
# ---- Trust.ps1: parent label and trust options ----
процесса {0}	process {0}
{0}, запущенный из {1}	{0}, launched by {1}
Всё, что запускает {0} ({1})	Everything launched by {0} ({1})
всё, что запускает {0}	everything launched by {0}
Эта программа — {0} от «{1}»	This program — {0} by “{1}”
Всё, что подписал «{0}»	Everything signed by “{0}”
Эта программа по пути {0}	This program at path {0}
Только этот файл	Only this file
Всё в папке {0}	Everything in folder {0}
Самая узкая область для интерпретатора: powershell.exe останется подозрительным везде, кроме запусков именно из этих рук.	The narrowest scope for an interpreter: powershell.exe stays suspicious everywhere except when launched by exactly this parent.
Родителя удалось опознать только по имени процесса, а имя подделывается в одну строку. Берите, если другого способа нет.	The parent could only be identified by its process name, and a name can be faked in one line. Use only if there is no other way.
Любой процесс, который запустит эта программа или её потомки, с любым номером. Для помощников вроде Claude, которые сами запускают cmd, node и PowerShell, это верный выбор.	Any process this program or its descendants launch, whatever its PID. The right choice for assistants like Claude that launch cmd, node and PowerShell themselves.
Любая копия и любое обновление, пока подпись издателя действует. Для обновляемых программ это верный выбор.	Any copy and any update, as long as the publisher's signature is valid. The right choice for programs that update themselves.
Шире: любые программы этого издателя. Разумно, если вы ему и так доверяете.	Broader: any program from this publisher. Sensible if you already trust them.
Очень широко: это системный интерпретатор, и такое доверие снимет вопросы к нему при любом запуске, кем бы он ни был запущен.	Very broad: this is a system interpreter, and such trust silences it on every launch, no matter who started it.
В пути есть номер версии или папка сборки. Такое доверие переживёт обновление программы, но не переезд в другое место.	The path contains a version number or build folder. This trust survives a program update, but not a move to another location.
Самое узкое. После обновления программы доверие перестанет действовать и находка вернётся.	The narrowest. After the program updates, the trust stops applying and the finding comes back.
Привязано к отпечатку: подменят файл — доверие само перестанет действовать.	Tied to the file hash: if the file is replaced, the trust stops applying on its own.
Осторожно: доверие получит и то, что в эту папку положат потом. Берите, только если папка ваша.	Careful: anything placed in this folder later will be trusted too. Use only if the folder is yours.
# ---- Trust.ps1: add/remove messages ----
У файла нет действующей подписи — доверять программе целиком нельзя	The file has no valid signature — the whole program cannot be trusted
У файла нет действующей подписи — доверять издателю нельзя	The file has no valid signature — the publisher cannot be trusted
Не удалось определить папку	Could not determine the folder
Родителя опознать не удалось — доверять «по родителю» нечему	Could not identify the parent — nothing to trust “by parent”
Не удалось определить имя программы	Could not determine the program name
Не удалось построить путь с подстановкой	Could not build a wildcard path
Нечего доверять: нет ни отпечатка, ни пути	Nothing to trust: no hash and no path
Нечего доверять: нет ключа	Nothing to trust: no key
Добавлено в доверенные: {0}	Added to trusted: {0}
Доверие снято	Trust revoked
# ---- Trust.ps1: kinds shown in the Trusted grid ----
Находка	Finding
Программа (имя + издатель)	Program (name + publisher)
Издатель	Publisher
Папка	Folder
Родитель ({0})	Parent ({0})
Путь без версии	Versionless path
Один файл	Single file
# ---- Trust.ps1: "covers" texts ----
любой файл {0}, подписанный «{1}»	any file {0} signed by “{1}”
любая программа, подписанная «{0}»	any program signed by “{0}”
всё внутри {0}	everything inside {0}
любой процесс, запущенный из {0} или его потомков	any process launched by {0} or its descendants
файл по пути {0}	file at path {0}
файл с отпечатком {0}…	file with hash {0}…
# ---- Trust.ps1: Trusted detail pane ----
Что доверено: {0}	Trusted item: {0}
Область: {0}	Scope: {0}
Действует на: {0}	Applies to: {0}
Причина: {0}	Reason: {0}
Причина:	Reason:
Добавлено: {0}	Added: {0}
Доверие держится на действующей подписи издателя. Подпись отвалится или файл подменят — доверие перестанет действовать само, даже если имя файла совпадает.	Trust relies on the publisher's valid signature. If the signature breaks or the file is replaced, the trust stops applying on its own, even if the file name matches.
Доверие держится на действующей подписи издателя и охватывает все его программы.	Trust relies on the publisher's valid signature and covers all of their programs.
ВНИМАНИЕ: доверие получит и то, что в эту папку положат потом. Снимите его, если папка перестала быть вашей.	WARNING: anything placed in this folder later will be trusted too. Revoke it if the folder is no longer yours.
Доверие привязано к отпечатку файла. Файл подменят — отпечаток изменится, доверие перестанет действовать само.	Trust is tied to the file hash. If the file is replaced, the hash changes and the trust stops applying on its own.
# ---- Trust.ps1: trust applied to findings ----
{0}  — доверено вами	{0}  — trusted by you
--- ДОВЕРЕНО ---	--- TRUSTED ---
Вы пометили это как разобранное: {0}	You marked this as reviewed: {0}
Вы пометили это как разобранное.	You marked this as reviewed.
Область доверия: {0}	Trust scope: {0}
Снять доверие можно в разделе «Доверенные».	You can revoke trust in the “Trusted” section.
#
# ---- Actions.ps1: process termination ----
Процесс уже не существует	The process no longer exists
Это критический процесс Windows ({0}) — его завершение обрушит систему. Отказано.	This is a critical Windows process ({0}) — terminating it would crash the system. Refused.
Завершено процессов: {0}	Processes terminated: {0}
Не удалось завершить процесс (нужны права администратора или процесс защищён)	Could not terminate the process (administrator rights required or the process is protected)
# ---- Actions.ps1: quarantine ----
Файл не найден	File not found
Для карантина нужны права администратора	Quarantine requires administrator rights
Файл слишком большой для карантина (> 300 МБ)	The file is too large for quarantine (> 300 MB)
Файл в карантине (id {0})	File quarantined (id {0})
Запись карантина не найдена	Quarantine record not found
Восстановлено: {0}	Restored: {0}
Удалено из карантина окончательно	Permanently deleted from quarantine
Было: {0}	Original location: {0}
В карантине с: {0}	Quarantined since: {0}
# ---- quarantine / termination reasons (passed from CookieGuard.ps1 and Guard-Service.ps1, stored and shown in Quarantine) ----
авто: VirusTotal {0} детектов	auto: VirusTotal, {0} detections
# ---- Actions.ps1: neutralize ----
Процесс: {0}  |  {1}	Process: {0}  |  {1}
Файл на диске не найден (возможно, процесс работал из удалённого образа)	File not found on disk (the process may have been running from a deleted image)
#
# ---- Archive.ps1 ----
7-Zip не найден	7-Zip not found
архив распаковывается слишком долго	the archive is taking too long to unpack
не удалось прочитать архив (код {0})	could not read the archive (code {0})
для {0} нужен 7-Zip	{0} requires 7-Zip
архив под паролем — нужен 7-Zip, встроенными средствами Windows пароль не открыть	the archive is password-protected — 7-Zip is needed, Windows' built-in tools cannot open a password
не удалось прочитать архив: {0}	could not read the archive: {0}
не удалось создать временную папку	could not create a temporary folder
7-Zip вернул ошибку (код {0})	7-Zip returned an error (code {0})
нужен 7-Zip	7-Zip is required
не удалось распаковать: {0}	could not unpack: {0}
#
# ---- SafeDns.ps1: profiles ----
AdGuard DNS — реклама, трекеры и вредоносное	AdGuard DNS — ads, trackers and malware
Ближе всего к тому, что делает расширение AdGuard, но без прав на ваши сайты.	Closest to what the AdGuard extension does, but without access to your sites.
AdGuard Family — то же плюс взрослый контент	AdGuard Family — the same plus adult content
То же самое, дополнительно режет сайты для взрослых.	The same, and also blocks adult sites.
Quad9 — только вредоносное, рекламу не трогает	Quad9 — malware only, leaves ads alone
Самый осторожный вариант: блокирует вредоносные домены и почти не даёт ложных срабатываний.	The most cautious option: blocks malicious domains with almost no false positives.
Cloudflare — вредоносное, быстрый	Cloudflare — malware, fast
Блокирует вредоносные домены, рекламу не трогает.	Blocks malicious domains, leaves ads alone.
# ---- SafeDns.ps1: state and messages ----
автоматически (от роутера)	automatic (from the router)
Неизвестный набор DNS	Unknown DNS set
Фильтрующий DNS включён на подключениях: {0}	Filtering DNS enabled on connections: {0}
DNS возвращён как было на подключениях: {0}	DNS restored to previous settings on connections: {0}
# ---- SafeDns.ps1: filtering test result ----
Проверить не удалось: даже обычный домен example.com не разрешается.	Check failed: even the ordinary domain example.com does not resolve.
Либо нет сети, либо запросы имён перехватывает что-то другое (VPN, прокси).	Either there is no network, or something else (VPN, proxy) is intercepting name lookups.
Это НЕ значит, что фильтр работает.	This does NOT mean the filter works.
Контроль: example.com -> {0} (сеть и DNS работают)	Control: example.com -> {0} (network and DNS work)
doubleclick.net: заблокирован — реклама и слежка фильтруются	doubleclick.net: blocked — ads and tracking are filtered
doubleclick.net: разрешается в {0} — реклама НЕ фильтруется	doubleclick.net: resolves to {0} — ads are NOT filtered
Сейчас выбран: {0}	Currently selected: {0}
Блокировку вредоносных доменов проверить отдельным запросом нельзя — её обеспечивает выбранный сервис, и видно это только по факту срабатывания.	Blocking of malicious domains cannot be tested with a single query — the chosen service provides it, and it only shows when it actually triggers.
Фильтрующий DNS не включён.	Filtering DNS is not enabled.
ВНИМАНИЕ: включён прокси ({0}). Браузер может спрашивать адреса через него, и тогда системный DNS-фильтр обходится. Настройте фильтрацию в самой программе-прокси.	WARNING: a proxy is enabled ({0}). The browser may resolve addresses through it, bypassing the system DNS filter. Set up filtering in the proxy program itself.
#
# ---- VirusTotal.ps1 ----
Не задан ключ VirusTotal	VirusTotal key is not set
VirusTotal не принял ключ	VirusTotal rejected the key
{0} из {1} — {2}	{0} of {1} — {2}
запущенный процесс	running process
новый исполняемый файл	new executable
скрипт Adobe	Adobe script
Достигнут предел запросов	Request limit reached
Бесплатный ключ: 4 запроса в минуту и 500 в сутки. Проверка продолжится в следующий раз — уже проверенное сохранено.	Free key: 4 requests per minute and 500 per day. The check will continue next time — what has been checked is saved.
VirusTotal не знает этот файл: {0}	VirusTotal does not know this file: {0}
Почему проверяли: {0}	Why checked: {0}
Неизвестен — значит, редкий. Для вашего собственного скрипта это норма.	Unknown means rare. For your own script that is normal.
Для файла, который вы не ставили, — повод разобраться.	For a file you did not install, it is a reason to look into it.
{0} — вредоносным считают {1} из {2} антивирусов ({3}%)	{0} — {1} of {2} antivirus engines consider it malicious ({3}%)
Вредоносным: {0}   подозрительным: {1}   всего проверок: {2}	Malicious: {0}   suspicious: {1}   total checks: {2}
Проверено: {0}	Checked: {0}
Подробный отчёт: {0}	Full report: {0}
Важно: один-два детекта из семидесяти — это чаще всего ложное срабатывание,	Important: one or two detections out of seventy are most often a false positive,
особенно у самодельных программ и кейгенов. Пять и больше — уже серьёзно.	especially for home-made programs and keygens. Five or more is serious.
В местной базе вердиктов: {0} файлов, из них с детектами: {1}	Local verdict database: {0} files, with detections: {1}
База пополняется при каждой проверке и работает без сети.	The database grows with every check and works offline.
#
# ---- Update.ps1 ----
Репозиторий не найден. Если он приватный — нужен ключ доступа GitHub.	Repository not found. If it is private, a GitHub access token is required.
Ключ доступа GitHub не принят. Задайте его заново.	The GitHub access token was not accepted. Set it again.
GitHub отказал: либо исчерпан лимит запросов, либо у ключа нет прав на этот репозиторий.	GitHub refused: either the request limit is exhausted, or the token has no access to this repository.
Не удалось связаться с GitHub: {0}	Could not reach GitHub: {0}
Скачиваю обновление с GitHub...	Downloading the update from GitHub...
Распаковываю...	Unpacking...
Заменяю файлы программы...	Replacing program files...
Архив обновления выглядит не так, как ожидалось	The update archive does not look as expected
В архиве нет файла {0} — обновление отменено	The archive has no file {0} — update cancelled
Не удалось заменить ни одного файла — нет прав на папку программы	Could not replace any file — no permission on the program folder

# ---- frag-extra.txt ----
# Дополнения после проверочного прогона
Критично	Critical
Внимание	Warning
[Реестр] {0}	[Registry] {0}
[Папка автозагрузки] {0}	[Startup folder] {0}
[Задача] {0}	[Task] {0}
[Служба] {0}	[Service] {0}
Проверяет системные компоненты Windows	Windows System Component Verification
Проверка драйверов оборудования Windows	Windows Hardware Driver Verification
Шифрующая файловая система (EFS)	Encrypting File System (EFS)
Подписывание списка доверия Майкрософт	Microsoft Trust List Signing
Вход со смарт-картой	Smart Card Logon
Все политики выдачи	All issuance policies
Все политики применения	All application policies
Удаленный рабочий стол	Remote Desktop
Удалённый рабочий стол	Remote Desktop

# ---- отдельные предложения из записей выше (собраны автоматически) ----
Только для файлов, которые VirusTotal уже знает как вредоносные: 5 и более детектов.	Only for files VirusTotal already knows as malicious: 5 or more detections.
Остальное — всегда с вашего согласия.	Everything else — always with your consent.
Бросьте файл или папку в любое место окна.	Drop a file or folder anywhere in the window.
Архив программа распакует сама, пароль спросит, подписанное известным издателем пропустит.	Archives are unpacked automatically, passwords asked for, and files signed by a known publisher skipped.
Или нажмите «Выбрать файлы».	Or press “Choose files”.
Наружу уходит только отпечаток SHA-256 — сам файл никуда не загружается.	Only the SHA-256 fingerprint leaves this computer — the file itself is never uploaded.
Итог проверки системы.	Result of the system scan.
Щёлкните строку — справа появится разбор.	Click a row to see its analysis on the right.
Спрятанные файлы.	Hidden files.
Запустить их нельзя, вернуть — можно, байт в байт.	They can't run, but can be restored byte for byte.
То, про что вы уже разобрались.	Things you have already looked into.
Столбец «действует на» показывает, насколько широко.	The “applies to” column shows how broadly.
Значит, он редкий.	So it's rare.
Для самодельного файла это норма, для скачанной программы — повод задуматься.	That's normal for a home-made file; for a downloaded program it's a reason to think twice.
Разбираю находку на своём компьютере с Windows.	I'm looking into a finding on my Windows computer.
Объясни простыми словами, опасно ли это и что делать.	Explain in plain words whether it's dangerous and what to do.
[...текст обрезан для ссылки.	[...text trimmed for the link.
Полная версия — в буфере обмена, вставьте Ctrl+V]	The full version is on the clipboard, paste it with Ctrl+V]
Вопрос передан вместе с данными.	The question was sent along with the data.
Полный текст также в буфере (Ctrl+V).	The full text is also on the clipboard (Ctrl+V).
Вредоносные домены перестанут разрешаться в адрес — во всей системе.	Malicious domains will stop resolving — system-wide.
Прежние настройки сохранятся, кнопка «Вернуть» их восстановит.	Your previous settings are saved; the “Restore” button brings them back.
Файл будет обратимо спрятан.	The file will be hidden reversibly.
Вернуть его можно в разделе «Карантин».	You can restore it on the “Quarantine” page.
Это системная папка Windows.	This is a Windows system folder.
Изъятие настоящего системного файла нарушит работу системы — убедитесь, что файл лишний.	Removing a real system file will break the system — make sure the file doesn't belong there.
Авто-карантин ВКЛЮЧЁН: файлы, которые VirusTotal уже знает как вредоносные (5+ детектов), будут изыматься без вопросов.	Auto-quarantine is ON: files VirusTotal already knows as malicious (5+ detections) will be removed without asking.
Остальное — только с вашего подтверждения.	Everything else — only with your confirmation.
Сторож будет стартовать вместе с Windows и работать в фоне.	The guard will start with Windows and run in the background.
Это не драйвер ядра: противник с правами SYSTEM сможет его снести.	It's not a kernel driver: an attacker with SYSTEM rights can remove it.
Монитор запущен.	Monitor started.
Аудит выключен — обращения к cookie видны не будут, включите его в разделе «Защита».	Auditing is off — cookie access won't be visible; turn it on on the “Protection” page.
У оставшихся находок нет безопасного исправления в один щелчок.	The remaining findings have no safe one-click fix.
Откройте находку — справа будет сказано, что с ней делать, или нажмите «Доверять».	Open a finding — the right pane says what to do with it — or press “Trust”.
Каждое исправление обратимо: прежнее значение сохраняется в записи отката.	Every fix is reversible: the previous value is kept in an undo record.
Снимите галочку с того, что вы оставили намеренно.	Untick what you left on purpose.
Windows начнёт записывать каждый запуск с командной строкой и тем, кто его вызвал.	Windows will record every launch with its command line and who started it.
Именно так опознаётся окно, которое мелькнуло и исчезло.	That's how you identify a window that flashed and disappeared.
Запомнится автозапуск, расширения, сертификаты, прокси, hosts, исключения антивируса и службы.	Autostart, extensions, certificates, proxy, hosts, antivirus exclusions and services will be remembered.
Снимайте, только когда уверены, что система в порядке.	Take it only when you're sure the system is clean.
Сравнивать не с чем.	Nothing to compare with.
Сначала нажмите «Снять заново».	Press “Take again” first.
Ключ остаётся на этом компьютере.	The key stays on this computer.
Наружу уходят только отпечатки файлов, сами файлы — никогда.	Only file hashes leave it — never the files themselves.
Ключ сохранён.	Key saved.
Теперь можно нажать «Проверить через VirusTotal».	Now you can press “Check files”.
Он бесплатный: virustotal.com, регистрация, профиль, API key.	It's free: virustotal.com, sign up, profile, API key.
Нажмите «Получить ключ».	Press “Get a key”.
Наружу уйдут только отпечатки SHA-256, сами файлы — никогда.	Only SHA-256 hashes leave the computer, never the files.
Бесплатный ключ даёт 4 запроса в минуту, поэтому на 60 файлов уйдёт около 15 минут.	A free key allows 4 requests per minute, so 60 files take about 15 minutes.
Окном можно пользоваться дальше.	You can keep using the window.
Windows не дала запустить изменение настроек.	Windows didn't allow the settings change to run.
Чаще всего это отказ в окне запроса прав.	Most often that's a "No" in the permission prompt.
Windows отказала в изменении настройки.	Windows refused to change the setting.
Разбор покажет, что именно мешает: прав, политики, служб или файлов браузера.	The analysis will show what exactly is in the way: rights, policy, services or browser files.
Всё необходимое на месте.	Everything needed is in place.
Если настройка всё равно не включается, посмотрите раздел «Журнал» — там записан вывод последней попытки.	If the setting still won't turn on, look at the “Log” page — the output of the last attempt is there.
Windows начнёт записывать, какая программа открывает Cookies и Login Data.	Windows will record which program opens Cookies and Login Data.
Включится политика аудита файловой системы, журнал безопасности вырастет до 256 МБ.	The file system audit policy will be enabled and the security log will grow to 256 MB.
Всё отменяется этим же переключателем.	The same switch undoes everything.
Эталон снят.	Baseline taken.
Теперь любое изменение автозапуска, расширений, скриптов Adobe, сертификатов и сети будет заметно.	Now any change to autostart, extensions, Adobe scripts, certificates and network will be noticed.
Включить аудит Windows на файлы cookie и паролей.	Turn on Windows auditing for cookie and password files.
После этого видно, КАКАЯ программа их открыла.	Then you can see WHICH program opened them.
Выключить аудит cookie и журнал запусков.	Turn off cookie auditing and the launch log.
Система вернётся в исходное состояние.	The system returns to its original state.
Проверить неподписанные файлы через VirusTotal (~70 антивирусов).	Check unsigned files via VirusTotal (~70 antivirus engines).
Наружу уходит только отпечаток SHA256, сам файл — никогда.	Only the SHA256 hash leaves the computer, never the file.
Задать бесплатный API-ключ VirusTotal.	Set a free VirusTotal API key.
Хранится только на этом компьютере.	It's stored only on this computer.
Снять постоянную защиту.	Remove always-on protection.
Наблюдение останется только при открытом окне.	Watching will continue only while the window is open.
Сторож сам отправит в карантин файл, который VirusTotal уже знает как вредоносный (5 и более детектов).	The guard itself quarantines a file VirusTotal already knows as malicious (5 or more detections).
Передать находку со всеми подробностями в чат с ИИ.	Send the finding with all details to an AI chat.
Полный текст также попадёт в буфер обмена.	The full text also goes to the clipboard.
Пометить как разобранное: больше не будет попадать в находки.	Mark as reviewed: it won't show up in findings any more.
Программа спросит, насколько широко: только этот файл, эта программа любой версии, весь издатель или вся папка.	The program asks how broadly: just this file, this program in any version, the whole publisher or the whole folder.
Страница проверки файлов.	The file check page.
Файл или папку можно бросить в любое место окна — программа сама распакует архив, спросит пароль и решит, что имеет смысл проверять.	Drop a file or folder anywhere in the window — the program unpacks archives itself, asks for a password and decides what's worth checking.
Перейти к проверке файлов.	Go to the file check.
Файл можно просто бросить в окно.	You can simply drop a file into the window.
Исправить разом всё, что программа умеет исправлять сама.	Fix at once everything the program can fix itself.
Покажет список с галочками — снимите те, что оставили намеренно.	Shows a checklist — untick what you left on purpose.
Каждое исправление обратимо.	Every fix is reversible.
Покажет список с галочками.	Shows a checklist.
Спросить магазин Chrome/Edge, что он знает о критичных расширениях: есть ли оно там и сколько у него пользователей.	Ask the Chrome/Edge store what it knows about critical extensions: whether it's listed and how many users it has.
Наружу уходит только номер расширения.	Only the extension ID leaves the computer.
Спросить VirusTotal о файлах из списка.	Ask VirusTotal about the files in the list.
Наружу уходит только отпечаток SHA-256, сам файл — никогда.	Only the SHA-256 hash leaves the computer, never the file.
Распаковывать архивы и проверять то, что внутри.	Unpack archives and check what's inside.
Для архива под паролем программа спросит пароль.	For a password-protected archive the program asks for the password.
Аудит доступа к файлам Windows: запись о том, какая программа открыла базу cookie или паролей.	Windows file access auditing: a record of which program opened the cookie or password database.
Без него главную задачу программы выполнить нечем.	Without it the program can't do its main job.
Сторож стартует вместе с Windows, работает в фоне и перезапускается, если его завершат.	The guard starts with Windows, runs in the background and restarts if it's killed.
Разделы программы.	Program sections.
Нижние три — для разбора: что спрятано, чему вы доверяете, что программа делала.	The bottom three are for review: what's hidden, what you trust, what the program did.
Проверяет предпосылки: права, политику аудита, групповую политику поверх неё, службы, журнал безопасности, антивирус и файлы браузеров.	Checks the prerequisites: rights, audit policy, group policy on top of it, services, the security log, antivirus and browser files.
Отвечает, почему переключатель не поддаётся.	Tells you why a switch won't stay on.
Спросить GitHub, вышла ли новая версия.	Ask GitHub whether a new version is out.
Наружу уходит только запрос к api.github.com.	Only a request to api.github.com leaves the computer.
Заменить файлы программы на версию из репозитория — даже если установлена та же самая.	Replace the program files with the version from the repository — even if the same one is installed.
Рабочие данные — эталон, доверенные, карантин, журналы — остаются нетронутыми.	Working data — baseline, trusted, quarantine, logs — stay untouched.
Ставится только по этой кнопке, никогда само.	Installs only from this button, never by itself.
Ключ доступа GitHub.	GitHub access token.
Нужен, только если репозиторий приватный.	Needed only if the repository is private.
Хранится на этом компьютере, в папке state.	Stored on this computer, in the state folder.
Завершить выбранный процесс вместе со всеми дочерними.	End the selected process together with all its children.
Критические процессы Windows программа не трогает.	The program doesn't touch critical Windows processes.
Удалить из карантина окончательно.	Delete from quarantine for good.
Это необратимо.	This is irreversible.
Эта версия уже установлена.	This version is already installed.
Файлы программы будут переписаны заново из репозитория — все правки, сделанные в установленной копии, пропадут.	The program files will be rewritten from the repository — any edits made in the installed copy will be lost.
Нужен только приватному репозиторию.	Needed only for a private repository.
Если репозиторий открытый, ключ не требуется — оставьте поле пустым.	If the repository is public, no token is required — leave the field empty.
Токен хранится только на этом компьютере, в папке state, и наружу уходит лишь на api.github.com.	The token is stored only on this computer, in the state folder, and is sent only to api.github.com.
Достаточно прав «только чтение» для этого репозитория.	Read-only access to this repository is enough.
Выключен: не видно, кто брал cookie.	Off: you can't see who took cookies.
Это главное, ради чего программа нужна.	That's the main thing the program is for.
Запущено без прав администратора.	Running without administrator rights.
Включение аудита запросит повышение прав отдельно.	Turning on auditing will ask for elevation separately.
Готов.	Ready.
Начните с «Проверить систему» или включите аудит в разделе «Защита».	Start with “Scan system” or turn on auditing on the “Protection” page.
Расширение перестанет попадать в находки.	The extension will no longer show up in findings.
Напишите себе на будущее, почему вы его оставляете.	Leave yourself a note on why you're keeping it.
Сертификат перестанет попадать в находки.	The certificate will no longer show up in findings.
Если его когда-нибудь подменят, у подмены будет другой отпечаток — и она попадёт.	If it is ever swapped, the substitute will have a different thumbprint — and it will show up.
Без пароля заглянуть внутрь нельзя.	Without the password there's no way to look inside.
Пароль нужен только для распаковки: он не сохраняется и никуда не передаётся.	The password is used only to unpack: it is not saved and not sent anywhere.
Он зарегистрирован в Windows, но его защита в реальном времени выключена.	It is registered in Windows, but its real-time protection is off.
Включите её или удалите программу.	Turn it on or uninstall the program.
Основная защита не работает.	Main protection is not working.
Включите её в "Безопасность Windows".	Turn it on in "Windows Security".
Всё, что лежит в этих местах, антивирус НЕ проверяет.	The antivirus does NOT scan anything in these locations.
Если вы их не добавляли — это следы вмешательства.	If you didn't add them, this is a sign of tampering.
Через эту программу идёт весь трафик браузеров — она видит всё.	All browser traffic goes through this program — it sees everything.
Убедитесь, что ставили её сами.	Make sure you installed it yourself.
Это сертификат вашего антивируса ESET.	This is your ESET antivirus certificate.
Им он проверяет защищённые сайты на вирусы: открывает HTTPS, смотрит и запечатывает обратно.	ESET uses it to scan secure sites for viruses: it opens HTTPS, inspects it and seals it back.
Это нормально, пока ESET установлен и вы ему доверяете.	This is fine as long as ESET is installed and you trust it.
Если ESET удалён, а сертификат остался — его стоит убрать.	If ESET was uninstalled but the certificate remains, remove it.
Остался после удаления — уберите.	Left over after uninstalling — remove it.
Сертификат защитной программы, которая проверяет или фильтрует защищённые сайты.	Certificate of a security program that scans or filters secure sites.
Ради этого она и читает HTTPS.	That is why it reads HTTPS.
Сертификат отладочного прокси (Fiddler, Charles, mitmproxy, Burp).	Certificate of a debugging proxy (Fiddler, Charles, mitmproxy, Burp).
Такие программы ставят его, чтобы показать разработчику содержимое HTTPS.	Such programs install it to show a developer the contents of HTTPS.
Пока он стоит, эта программа может читать весь ваш защищённый трафик.	While it is installed, this program can read all your secure traffic.
Если вы сейчас ничего не отлаживаете — его стоит убрать.	If you're not debugging anything right now, remove it.
Опасен, только если его закрытый ключ утечёт.	Dangerous only if its private key leaks.
Не занимаетесь разработкой — уберите.	If you don't do development, remove it.
Ключ у этой программы, и сама она трафик не читает.	The key belongs to this program, and the program itself doesn't read traffic.
Но ограничений у сертификата нет: если ключ украдут, им можно подделать любой сайт.	But the certificate has no restrictions: if the key is stolen, it can be used to fake any website.
Пользуетесь программой — доверьте; удалили — уберите.	If you use the program, trust it; if you removed it, remove the certificate.
Ограничивать назначение не стоит: связь сайта с программой перестанет работать.	Don't restrict its purpose: the link between the website and the program will stop working.
Похоже на самодельный сертификат установщика драйвера USB-устройства (Zadig/libwdi, загрузчики микроконтроллеров, Universal ADB для Android).	Looks like a self-made certificate from a USB device driver installer (Zadig/libwdi, microcontroller bootloaders, Universal ADB for Android).
Им установщик подписал драйвер, чтобы Windows его приняла.	The installer signed the driver with it so Windows would accept it.
Обычно его ставят программы для прошивки плат и телефонов.	It is usually installed by programs for flashing boards and phones.
Уже установленный драйвер продолжит работать и без этого сертификата; понадобится он, только если драйвер придётся ставить заново.	An already installed driver keeps working without this certificate; it is only needed if the driver has to be reinstalled.
Сертификат разрешён только для подписи программ или драйверов.	The certificate is allowed only for signing programs or drivers.
Такие ставят установщики драйверов и самодельных программ, чтобы Windows приняла их подпись.	Such certificates are installed by driver and homemade program installers so Windows accepts their signature.
Читать трафик он не может.	It cannot read traffic.
Если не помните, что ставили, — его можно убрать: уже установленное продолжит работать.	If you don't remember installing it, you can remove it: what is already installed will keep working.
Программа не узнаёт этот сертификат.	The program doesn't recognize this certificate.
Его поставил кто-то из установленных программ или вы сами.	It was installed by one of your programs or by you.
Найдите в интернете имя из строки «Кому выдан».	Search the web for the name in the "Issued to" line.
Если это ваша программа — ограничьте назначение или доверьте.	If it's your program, restrict its purpose or trust it.
Если имя ничего не говорит — уберите (копия сохранится).	If the name means nothing to you, remove it (a copy will be kept).
Нет.	No.
Срок действия истёк, Windows им больше не пользуется.	It has expired; Windows no longer uses it.
Да.	Yes.
Ограничений назначения у него нет: тот, у кого есть его закрытый ключ, может выдать себя за любой сайт, и браузер не заметит подмены.	It has no purpose restrictions: whoever has its private key can impersonate any website, and the browser won't notice the substitution.
«Ограничить назначение» — сертификат останется, но для сайтов Windows перестанет его принимать.	"Restrict purpose" — the certificate stays, but Windows will stop accepting it for websites.
Самый безопасный шаг: программы, которым он нужен для подписи драйверов, продолжат работать.	The safest step: programs that need it for signing drivers will keep working.
Корневой сертификат — печать, которой Windows верит без вопросов.	A root certificate is a seal Windows trusts without question.
Всё, что этой печатью заверено, браузер и система считают подлинным.	Everything certified with this seal is considered genuine by the browser and the system.
Поэтому посторонняя печать в этом списке — повод разобраться, но ещё не взлом.	So a foreign seal in this list is a reason to look into it, but not yet a breach.
systray.exe — пустышка Windows.	systray.exe is a Windows dummy.
Так программы отключают утилиты для урезания телеметрии.	Telemetry-cutting utilities disable programs this way.
Если вы такую ставили — это она.	If you installed one, this is it.
Если нет — разберитесь.	If not, look into it.
Это способ запускать код по событию в обход автозагрузки.	This is a way to run code on an event, bypassing autostart.
Им почти никто не пользуется, кроме вредоносов.	Almost nobody uses it except malware.
Поставлено не из магазина (нет адреса обновления) — так ставят и разработчики, и вредоносы.	Not installed from the store (no update URL) — both developers and malware install extensions this way.
Перепроверить его по магазину нельзя.	It can't be re-checked against the store.
В магазине такого расширения НЕТ: его сняли с публикации, оно недоступно в вашей стране или его поставили в обход.	This extension is NOT in the store: it was unpublished, isn't available in your country, or was installed around the store.
Снятые расширения — частый след вредоноса; если это ваше и вы знаете, откуда оно, — нажмите «Доверять».	Removed extensions are a common sign of malware; if it's yours and you know where it came from, click "Trust".
Права у расширения прежние — просто вы решили его оставить.	The extension's permissions are unchanged — you just decided to keep it.
Снять доверие: вкладка «Доверенные».	To revoke trust: the "Trusted" tab.
Нажмите «Включить аудит», чтобы Windows начала записывать, какая программа открывает файлы cookie.	Click "Enable auditing" so Windows starts recording which program opens cookie files.
Без этого вопрос «кто взял мои cookie» остаётся без ответа.	Without it, the question "who took my cookies" stays unanswered.
Смена прав доступа — это НЕ чтение ваших cookie.	A permission change is NOT reading your cookies.
Так выглядит установка аудита.	This is what setting up auditing looks like.
Он нужен разработчикам.	Developers need it.
Если вы ничего не отлаживаете — это не должно быть открыто.	If you aren't debugging anything, it shouldn't be open.
Что делать: вспомните, какой плагин вы ставили.	What to do: recall which plugin you installed.
Если такого плагина вы не ставили —	If you didn't install such a plugin,
Сам себя копирующий скрипт — это поведение червя.	A self-copying script is worm behavior.
Законные плагины так не ставятся.	Legitimate plugins don't install this way.
Adobe обычно грузит только подписанные расширения.	Adobe normally loads only signed extensions.
Этот режим снимает проверку —	This mode removes the check —
чтобы протащить своё.	to sneak their stuff in.
Если вы не пишете расширения сами — выключите.	If you don't write extensions yourself, turn it off.
Это собственная панель Adobe: подписана и опознана по идентификатору com.adobe.*.	This is Adobe's own panel: signed and identified by the com.adobe.* ID.
Так и должно быть.	This is as it should be.
Расширение подписано, то есть установлено из готового пакета ZXP, а не подложено в папку.	The extension is signed, meaning it was installed from a ready-made ZXP package rather than dropped into the folder.
Это не гарантия честности, но подделать подпись без ключа издателя нельзя.	That doesn't guarantee honesty, but a signature can't be faked without the publisher's key.
Подписи нет, но загрузка неподписанных расширений выключена (PlayerDebugMode = 0) — значит, Adobe его НЕ ЗАГРУЖАЕТ.	No signature, but loading of unsigned extensions is off (PlayerDebugMode = 0) — so Adobe does NOT LOAD it.
Сейчас оно просто лежит на диске и не работает.	Right now it just sits on disk and does nothing.
Подписи нет, И при этом включена загрузка неподписанных расширений.	No signature, AND loading of unsigned extensions is on.
Вот сочетание, ради которого эта проверка и сделана: расширение будет загружено, хотя никто за него не отвечает.	This is exactly the combination this check exists for: the extension will be loaded although no one vouches for it.
Сами по себе эти вызовы законны — ими пользуются и честные панели.	These calls are legitimate on their own — honest panels use them too.
Значение имеет их совокупность вместе с отсутствием подписи.	What matters is their combination together with the missing signature.
Что делать: сейчас оно безвредно, потому что не загружается.	What to do: it's harmless right now because it isn't loaded.
Но если когда-нибудь включите загрузку неподписанных расширений — оно оживёт.	But if you ever turn on loading of unsigned extensions, it will come alive.
Если такую панель вы не ставили, папку лучше убрать.	If you didn't install such a panel, better remove the folder.
Что делать: ничего.	What to do: nothing.
Если панель вам не нужна — удалите её через Creative Cloud, а не из папки.	If you don't need the panel, uninstall it via Creative Cloud, not from the folder.
Что делать: вспомните, ставили ли вы такую панель.	What to do: recall whether you installed such a panel.
Если нет — выключите PlayerDebugMode (находка выше), и расширение перестанет загружаться; саму папку можно убрать в карантин.	If not, turn off PlayerDebugMode (the finding above) and the extension will stop loading; the folder itself can be moved to quarantine.
Без этого файла cookie не расшифровать.	Cookies can't be decrypted without this file.
Его читают вместе с базой, чтобы раскрыть её.	It is read together with the database to unlock it.
Браузеры не кладут такие файлы сюда.	Browsers don't put such files here.
Так делают программы, которые готовят данные к отправке наружу.	This is what programs do when preparing data to send out.
Пока работает сторонний антивирус, Windows намеренно держит Defender выключенным — двум антивирусам в реальном времени нельзя работать вместе.	While a third-party antivirus is running, Windows deliberately keeps Defender off — two real-time antiviruses can't work together.
Это не поломка, и включать Defender не нужно.	This isn't a fault, and there's no need to turn Defender on.
Сторонний антивирус зарегистрирован, но сам не работает.	A third-party antivirus is registered but isn't running.
Защиты сейчас может не быть вовсе: Defender уступил ему место, а он не включён.	There may be no protection at all right now: Defender stepped aside for it, and it isn't on.
Либо запустите его, либо удалите — тогда Defender вернётся сам.	Either start it or uninstall it — then Defender will come back on its own.
Вот почему переключатель не держится: политика выключает защиту заново.	This is why the switch won't stay on: the policy turns protection off again.
Такие ключи ставит либо администратор домена, либо «оптимизатор» или сборка Windows, либо вредонос, которому защита мешает.	Such keys are set by a domain administrator, by an "optimizer" or a custom Windows build, or by malware that protection gets in the way of.
Если компьютер ваш — удалите эти значения реестра и перезагрузитесь, затем включите защиту в «Безопасность Windows».	If the computer is yours, delete these registry values and restart, then turn protection on in "Windows Security".
Служба антивируса не работает, а другого антивируса на компьютере нет.	The antivirus service isn't running, and there's no other antivirus on the computer.
Пока она остановлена, защиту включить не получится.	While it's stopped, protection can't be turned on.
Компьютер сейчас без постоянной защиты.	The computer currently has no real-time protection.
CookieGuard её не заменяет и включить не может — это делается в «Безопасность Windows» → «Защита от вирусов и угроз» → «Управление настройками».	CookieGuard doesn't replace it and can't turn it on — that's done in "Windows Security" → "Virus & threat protection" → "Manage settings".
Если переключатель там не поддаётся или сам возвращается в «выкл» — смотрите пункты про политику и про защиту от подделки выше.	If the switch there won't budge or flips back to "Off" by itself, see the policy and tamper protection items above.
Пока она включена, настройки Defender нельзя менять ни программой, ни реестром — только руками в «Безопасность Windows».	While it's on, Defender settings can't be changed by a program or through the registry — only by hand in "Windows Security".
Это защита, а не неисправность.	This is protection, not a fault.
Без неё отключить антивирус может любая программа с правами администратора — в том числе вредонос.	Without it, any program with administrator rights can turn off the antivirus — including malware.
Включается в «Безопасность Windows» → «Защита от вирусов и угроз» → «Управление настройками».	Turn it on in "Windows Security" → "Virus & threat protection" → "Manage settings".
Модуль Defender не удалось опросить, а зарегистрированного антивируса нет.	The Defender module couldn't be queried, and no antivirus is registered.
Похоже, защита снята намеренно — либо «оптимизатором», либо вредоносом.	Protection appears to have been removed on purpose — either by an "optimizer" or by malware.
Проверьте «Безопасность Windows».	Check "Windows Security".
Аудит, журнал запусков и сторож меняют настройки Windows и без прав администратора включиться не могут.	Auditing, the launch log and the guard change Windows settings and can't be turned on without administrator rights.
Закройте окно и запустите CookieGuard.exe (он запросит повышение), либо правой кнопкой по ярлыку — «Запуск от имени администратора».	Close the window and run CookieGuard.exe (it will ask for elevation), or right-click the shortcut → "Run as administrator".
Без auditpol включить аудит доступа к файлам нельзя.	File access auditing can't be turned on without auditpol.
Такое бывает на сильно урезанных сборках Windows и в системах под управлением организации.	This happens on heavily stripped-down Windows builds and on organization-managed systems.
Это и включает переключатель «Аудит доступа к cookie».	This is what the "Cookie access auditing" switch turns on.
Если после включения проверка снова показывает «выключена» — политику перекрывает групповая политика, смотрите следующий пункт.	If the check still shows "off" after you turn it on, a group policy is overriding it — see the next item.
Политика перезапишет настройки аудита при очередном обновлении (gpupdate, перезагрузка).	The policy will overwrite the audit settings on its next refresh (gpupdate, restart).
Если компьютер ваш — удалите этот файл или задайте аудит через «Локальная политика безопасности» (secpol.msc → Конфигурация расширенной политики аудита → Доступ к объектам → Аудит файловой системы).	If the computer is yours, delete this file or set auditing in "Local Security Policy" (secpol.msc → Advanced Audit Policy Configuration → Object Access → Audit File System).
Аудит ставится на конкретные файлы — Cookies, Login Data.	Auditing is set on specific files — Cookies, Login Data.
Если браузер ни разу не запускали или он установлен не туда, где его ищет программа, ставить аудит не на что, и включение заканчивается ничем.	If the browser has never been started, or it's installed somewhere the program doesn't look, there's nothing to audit and turning it on does nothing.
Запустите браузер хотя бы раз и повторите.	Start the browser at least once and try again.
Без журнала безопасности события аудита читать неоткуда.	Without the Security log there's nowhere to read audit events from.
Проверьте, запущена ли служба «Журнал событий Windows» (EventLog).	Check that the "Windows Event Log" service (EventLog) is running.
Постоянная защита — это две задачи планировщика.	Always-on protection is two scheduled tasks.
Пока служба «Планировщик заданий» не запущена, переключатель будет возвращаться в положение «выключено».	Until the "Task Scheduler" service is running, the switch will keep flipping back to "off".
Сюда пишутся эталон, список доверенных и карантин.	The baseline, the trusted list and quarantine are written here.
Без записи почти ничего не сохранится.	Without write access almost nothing will be saved.
Запустите программу от имени администратора.	Run the program as administrator.
Нажмите «Снять эталон», когда будете уверены, что система в порядке.	Click "Take baseline" when you're sure the system is in good shape.
После этого программа начнёт замечать любое изменение автозапуска, расширений, скриптов Adobe, сертификатов и настроек сети — даже если такого вредоноса ещё нет ни в одной антивирусной базе.	After that the program will notice any change to autostart, extensions, Adobe scripts, certificates and network settings — even if that malware isn't in any antivirus database yet.
Обычно это удаление программы.	Usually this means a program was uninstalled.
Но так же выглядит и отключение защиты.	But disabling protection looks the same.
Файла по этому пути нет.	There's no file at this path.
Запись, ведущая в пустоту, — это либо мусор от удалённой программы, либо готовая точка перехвата: кто первым положит туда файл, тот и получит запуск.	An entry pointing to nothing is either leftovers from an uninstalled program or a ready-made hijack point: whoever puts a file there first gets it launched.
PlayerDebugMode станет 0.	PlayerDebugMode will be set to 0.
Подписанные панели Adobe продолжат работать, неподписанные перестанут загружаться.	Signed Adobe panels keep working; unsigned ones stop loading.
Значение удаляется из ветки Run.	The value is deleted from the Run key.
Прежнее значение целиком сохраняется в записи отката, вернуть можно одним действием.	The previous value is saved in full in an undo record and can be restored in one step.
Задача останется на месте, но перестанет запускаться.	The task stays in place but stops running.
Включить обратно можно откатом.	You can re-enable it by undoing.
Удаляется значение Debugger, которым подменён запуск.	The Debugger value that hijacks the launch is deleted.
Прежнее значение сохраняется в записи отката.	The previous value is saved in an undo record.
Ключу возвращается штатное значение Windows.	The key gets its standard Windows value back.
Текущее сохраняется в записи отката.	The current value is saved in an undo record.
Вся папка расширения переносится в карантин целиком — со скриптами, манифестом и ресурсами.	The whole extension folder is moved to quarantine — scripts, manifest and resources included.
Содержимое не удаляется и возвращается откатом.	Nothing is deleted, and undoing brings it back.
Сертификат останется в системе, но Windows перестанет принимать его для защищённых сайтов: только подпись программ и драйверов.	The certificate stays in the system, but Windows will no longer accept it for secure websites: only for signing programs and drivers.
Читать ваш трафик через него станет нельзя.	It can no longer be used to read your traffic.
Вернуть можно откатом.	You can undo this.
Сертификат уйдёт из списка, которому Windows верит без вопросов.	The certificate leaves the list Windows trusts unconditionally.
Копия сохранится в папке undo, вернуть можно откатом.	A copy is saved in the undo folder, and you can undo this.
Программа, которая его ставила, может попросить его снова — тогда вы будете знать, чья это печать.	The program that installed it may ask for it again — then you will know whose seal it is.
Родителя удалось опознать только по имени процесса, а имя подделывается в одну строку.	The parent could only be identified by its process name, and a name can be faked in one line.
Берите, если другого способа нет.	Use only if there is no other way.
Любой процесс, который запустит эта программа или её потомки, с любым номером.	Any process this program or its descendants launch, whatever its PID.
Для помощников вроде Claude, которые сами запускают cmd, node и PowerShell, это верный выбор.	The right choice for assistants like Claude that launch cmd, node and PowerShell themselves.
Любая копия и любое обновление, пока подпись издателя действует.	Any copy and any update, as long as the publisher's signature is valid.
Для обновляемых программ это верный выбор.	The right choice for programs that update themselves.
Шире: любые программы этого издателя.	Broader: any program from this publisher.
Разумно, если вы ему и так доверяете.	Sensible if you already trust them.
В пути есть номер версии или папка сборки.	The path contains a version number or build folder.
Такое доверие переживёт обновление программы, но не переезд в другое место.	This trust survives a program update, but not a move to another location.
Самое узкое.	The narrowest.
После обновления программы доверие перестанет действовать и находка вернётся.	After the program updates, the trust stops applying and the finding comes back.
Осторожно: доверие получит и то, что в эту папку положат потом.	Careful: anything placed in this folder later will be trusted too.
Берите, только если папка ваша.	Use only if the folder is yours.
Доверие держится на действующей подписи издателя.	Trust relies on the publisher's valid signature.
Подпись отвалится или файл подменят — доверие перестанет действовать само, даже если имя файла совпадает.	If the signature breaks or the file is replaced, the trust stops applying on its own, even if the file name matches.
ВНИМАНИЕ: доверие получит и то, что в эту папку положат потом.	WARNING: anything placed in this folder later will be trusted too.
Снимите его, если папка перестала быть вашей.	Revoke it if the folder is no longer yours.
Доверие привязано к отпечатку файла.	Trust is tied to the file hash.
Файл подменят — отпечаток изменится, доверие перестанет действовать само.	If the file is replaced, the hash changes and the trust stops applying on its own.
Бесплатный ключ: 4 запроса в минуту и 500 в сутки.	Free key: 4 requests per minute and 500 per day.
Проверка продолжится в следующий раз — уже проверенное сохранено.	The check will continue next time — what has been checked is saved.
Неизвестен — значит, редкий.	Unknown means rare.
Для вашего собственного скрипта это норма.	For your own script that is normal.
особенно у самодельных программ и кейгенов.	especially for home-made programs and keygens.
Пять и больше — уже серьёзно.	Five or more is serious.
Репозиторий не найден.	Repository not found.
Если он приватный — нужен ключ доступа GitHub.	If it is private, a GitHub access token is required.
Ключ доступа GitHub не принят.	The GitHub access token was not accepted.
Задайте его заново.	Set it again.
'@
