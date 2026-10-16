@echo off
rem CookieGuard - main window. Runs elevated so file-audit controls work.
title CookieGuard
powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process powershell -Verb RunAs -ArgumentList '-STA','-NoProfile','-ExecutionPolicy','Bypass','-WindowStyle','Hidden','-File','\"%~dp0..\CookieGuard.ps1\"'"
