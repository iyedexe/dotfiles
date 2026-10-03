@echo off
:: mkdir [-p] DIR...   (md already creates parents; -p is accepted and ignored)
:loop
if "%~1"=="" exit /b 0
if not "%~1"=="-p" if not exist "%~1\" md "%~1"
shift & goto loop
