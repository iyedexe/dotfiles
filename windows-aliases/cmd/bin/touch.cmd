@echo off
:: touch FILE...  - create the file or update its timestamp
:loop
if "%~1"=="" exit /b 0
if exist "%~1" (copy /b "%~1"+,, "%~1" >nul) else (type nul > "%~1")
shift & goto loop
