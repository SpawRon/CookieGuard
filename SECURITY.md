# Security policy

CookieGuard runs with administrator rights and a SYSTEM service, so a bug in it is a security
bug for everyone who installed it. Please report one privately.

## Reporting

Use **[Report a vulnerability](https://github.com/SpawRon/CookieGuard/security/advisories/new)**
(GitHub private advisory). Please don't open a public issue for:

- privilege escalation through the program folder, the data folder or the `cache\` libraries;
- a way to make the guard, the watchdog or an agent stop silently;
- a way to read cookies or passwords without CookieGuard raising an alarm;
- anything that makes the updater install code that isn't from this repository.

A report gets an answer within a few days. A fix is pushed to `main`, and installed copies pick it
up through **Protection → Program version → Update**.

## Scope and limits

What CookieGuard can and cannot see is described honestly in
[`docs/GUIDE.ru.md`](docs/GUIDE.ru.md). A program that already runs as SYSTEM or in the kernel can
turn off any user-mode protection, this one included. CookieGuard's job is to make sure that never
happens *quietly*.
