# Changelog

## Unreleased

### Fewer false alarms
- **Findings → Audit**: an antivirus or the Windows Search indexer reading `Local State` or the
  cookie database is no longer CRITICAL. ESET, Defender, Kaspersky, Avast, AVG, Bitdefender and
  Malwarebytes are recognised by process name *and* a valid signature from that vendor.
- **Findings → Autorun**: CookieGuard's own `Watcher` and `Watchdog` tasks are no longer CRITICAL.
  They are recognised by the exact command line pointing at this installation; anything added to it
  still raises the alarm.
- **Monitor → debug port**: one row per browser launch instead of one per Chrome child process
  (a single headless render produced dozens). A browser with a debug port on a fresh, empty
  profile — automated tests, Playwright, page renderers — is now a note. A profile whose cookie,
  password or key files were copied in (written earlier than created) is CRITICAL, like your real
  profile; a reused automation profile stays a warning.

## 3.1.0 — 2026-10-16

### Faster
- The window opens instantly and no longer freezes for 4–5 seconds after it appears. Slow system
  queries (antivirus, protection parts, DNS, guard task, watched files) now run in a background
  thread, and the first paint uses a snapshot from the previous run (`state\probe-cache.xml`).
- Opening **Protection** takes ~30 ms instead of 1.6 s.
- The app's own C# helpers are compiled once and cached in `cache\` instead of on every launch.
  A cached library only loads if its owner is Administrators, SYSTEM or the current user.

### Ad blocker
- **Choose filter lists**: EasyList, RuAdList, EasyPrivacy, Peter Lowe (default), plus AdGuard Base,
  AdGuard Russian, Fanboy's Annoyance and Anti-Adblock. **Your own list by URL** (https only).
- **Generic hiding rules** (`##.ad-banner`, about 13,000 in the default lists) now work. A page
  reports its class and id names, and gets back only the matching rules.
- More rule options are converted: `$redirect`, `$all`, `$denyallow`, `$method`, `$generichide`,
  site exceptions `#@#`.
- Room for 4 × 29,000 network rules instead of 29,000.
- **Self-update**: the app syncs the extension folder on every start and stamps a build. The
  extension checks the stamp every minute and reloads itself.

### Icon
- New icon drawn per size: crisp at 16 px in the tray and on the taskbar. Classic bitmap frames
  up to 64 px, PNG at 256 px. The tray loads the 16 px frame instead of shrinking the 32 px one.

### Repository
- Window markup moved to `ui\*.xaml`, C# helpers to `lib\native\*.cs`, and the English dictionary to
  `lib\lang\en.tsv`. Each now lives in its own format instead of inside PowerShell strings.
- Scripts moved to `scripts\`, and `УСТАНОВИТЬ.cmd` renamed to `Setup.cmd`. Installed copies migrate
  on their own: on first start the app points both scheduled tasks and the uninstall entry at
  `scripts\` and removes the old root copies.
- English README, Russian README and full manual in `docs\GUIDE.ru.md`, changelog, security policy,
  issue templates, CI.

## 3.0 — 2026-10-16
- Protection 3.0: one switch for everything, tiles with live state, **Fix all**.
- Watch agents, network checkpoints, AppData map.
- `hosts` audit with author and line-by-line diff; shadow path.
- English interface.
