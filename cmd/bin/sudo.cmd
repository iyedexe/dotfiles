@echo off
:: sudo CMD...  - run elevated (gsudo if installed, else a UAC prompt in a new window)
where gsudo >nul 2>&1 && (gsudo %* & exit /b %ERRORLEVEL%)
if "%~1"=="" (powershell -NoProfile -Command "Start-Process cmd -Verb RunAs" & exit /b)
powershell -NoProfile -Command "Start-Process cmd -Verb RunAs -ArgumentList '/k cd /d \"%CD%\" ^&^& %*'"
