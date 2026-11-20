@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ativar-proxy.ps1" %*
echo.
pause
