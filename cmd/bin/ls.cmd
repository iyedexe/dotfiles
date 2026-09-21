@echo off
:: ls [-alhR] [path...]   ->  dir
setlocal EnableDelayedExpansion
set "opts=/o:gn" & set "long=0" & set "all=0" & set "paths="
:parse
if "%~1"=="" goto run
set "a=%~1"
if "!a:~0,1!"=="-" (
    if not "!a:l=!"=="!a!" set "long=1"
    if not "!a:a=!"=="!a!" set "all=1"
    if not "!a:R=!"=="!a!" set "opts=!opts! /s"
) else (
    set paths=!paths! "%~1"
)
shift & goto parse
:run
if "%all%"=="1" set "opts=%opts% /a"
if "%long%"=="1" (dir %opts% %paths%) else (dir /w %opts% %paths%)
endlocal
