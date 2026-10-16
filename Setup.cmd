@echo off
rem CookieGuard installer - asks for admin, then installs to Program Files.
title CookieGuard - installation
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-File','\"%~dp0scripts\Install.ps1\"','-DesktopShortcut'"
