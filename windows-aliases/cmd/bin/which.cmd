@echo off
:: which NAME  - shows doskey macros, then executables on PATH
if "%~1"=="" (echo usage: which NAME 1>&2 & exit /b 2)
doskey /macros | findstr /b /i /c:"%~1=" && exit /b 0
where "%~1" 2>nul || (echo which: no %~1 in PATH 1>&2 & exit /b 1)
