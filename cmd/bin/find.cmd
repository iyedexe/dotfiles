@echo off
:: find [PATH] [-name|-iname PATTERN] [-type f|d]   ->  dir /s /b
:: Called with a /switch it falls through to the Windows find.exe so
:: existing scripts using  find /c /v ""  keep working.
setlocal EnableDelayedExpansion
set "a=%~1"
if "!a:~0,1!"=="/" ( "%SystemRoot%\System32\find.exe" %* & exit /b !ERRORLEVEL! )
set "path_=." & set "name=*" & set "attr="
if not "%~1"=="" if not "!a:~0,1!"=="-" (set "path_=%~1" & shift)
:parse
if "%~1"=="" goto run
if /i "%~1"=="-name"  (set "name=%~2" & shift & shift & goto parse)
if /i "%~1"=="-iname" (set "name=%~2" & shift & shift & goto parse)
if /i "%~1"=="-type"  (
    if /i "%~2"=="f" set "attr=/a-d"
    if /i "%~2"=="d" set "attr=/ad"
    shift & shift & goto parse
)
echo find: unknown predicate %~1 1>&2 & exit /b 2
:run
dir /s /b %attr% "%path_%\%name%" 2>nul
endlocal
