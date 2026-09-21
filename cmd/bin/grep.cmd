@echo off
:: grep [-inrvlcE] PATTERN [FILE|DIR ...]   ->  findstr
:: With no FILE it reads stdin (type x | grep foo); -r with no path means "*".
setlocal EnableDelayedExpansion
set "opts=" & set "recurse=0" & set "count=0" & set "regex=0" & set "pat=" & set "files="
:parse
if "%~1"=="" goto run
set "a=%~1"
if "!a:~0,1!"=="-" if not "!a!"=="-" (
    if not "!a:i=!"=="!a!" set "opts=!opts! /I"
    if not "!a:n=!"=="!a!" set "opts=!opts! /N"
    if not "!a:v=!"=="!a!" set "opts=!opts! /V"
    if not "!a:l=!"=="!a!" set "opts=!opts! /M"
    if not "!a:r=!"=="!a!" set "recurse=1"
    if not "!a:c=!"=="!a!" set "count=1"
    if not "!a:e=!"=="!a!" set "regex=1"
    shift & goto parse
)
if not defined pat (
    set "pat=%~1"
) else if exist "%~1\" (
    set files=!files! "%~1\*"
) else (
    set files=!files! "%~1"
)
shift & goto parse
:run
if not defined pat (echo usage: grep [-inrvlcE] PATTERN [FILE...] 1>&2 & exit /b 2)
if "%recurse%"=="1" (
    set "opts=%opts% /S"
    if not defined files set "files=*"
)
if "%regex%"=="1" (set "pq=/R "%pat%"") else (set "pq=/C:"%pat%"")
if "%count%"=="1" (
    findstr %opts% %pq% %files% | find /c /v ""
) else (
    findstr %opts% %pq% %files%
)
endlocal & exit /b %ERRORLEVEL%
