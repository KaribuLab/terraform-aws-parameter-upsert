@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0provision.ps1" -Action delete -Version %~1
exit /b %ERRORLEVEL%
