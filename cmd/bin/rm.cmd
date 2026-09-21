@echo off
:: rm [-rf] PATH...   ->  del / rd
setlocal EnableDelayedExpansion
set "recurse=0" & set "force=0" & set "paths="
:parse
if "%~1"=="" goto run
set "a=%~1"
if "!a:~0,1!"=="-" (
    if not "!a:r=!"=="!a!" set "recurse=1"
    if not "!a:f=!"=="!a!" set "force=1"
) else (
    set paths=!paths! "%~1"
)
shift & goto parse
:run
if not defined paths (echo usage: rm [-rf] PATH... 1>&2 & exit /b 2)
set "delopts=/q"
if "%force%"=="1" set "delopts=/q /f"
for %%p in (%paths%) do (
    if exist "%%~p\" (
        if "%recurse%"=="1" (rd /s /q "%%~p") else (echo rm: cannot remove '%%~p': Is a directory 1>&2)
    ) else if exist "%%~p" (
        del %delopts% "%%~p"
    ) else if "%force%"=="0" (
        echo rm: cannot remove '%%~p': No such file or directory 1>&2
    )
)
endlocal
