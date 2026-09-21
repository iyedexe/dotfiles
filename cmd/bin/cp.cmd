@echo off
:: cp [-r] SRC... DST   ->  copy / xcopy
setlocal EnableDelayedExpansion
set "recurse=0" & set "n=0"
:parse
if "%~1"=="" goto run
set "a=%~1"
if "!a:~0,1!"=="-" (
    if not "!a:r=!"=="!a!" set "recurse=1"
) else (
    set /a n+=1
    set "p!n!=%~1"
)
shift & goto parse
:run
if %n% lss 2 (echo usage: cp [-r] SOURCE... DEST 1>&2 & exit /b 2)
set "dst=!p%n%!"
set /a last=n-1
for /l %%i in (1,1,%last%) do (
    set "src=!p%%i!"
    if exist "!src!\" (
        if "%recurse%"=="1" (
            for %%d in ("!src!") do xcopy /e /i /h /y /q "!src!" "!dst!\%%~nxd" >nul
        ) else (
            echo cp: -r not specified; omitting directory '!src!' 1>&2
        )
    ) else (
        copy /y "!src!" "!dst!" >nul
    )
)
endlocal
