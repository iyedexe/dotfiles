@echo off
:: tail [-n N | -N] [-f] [FILE]    (reads stdin without FILE)
setlocal
set "n=10" & set "file=" & set "wait="
:parse
if "%~1"=="" goto run
if "%~1"=="-n" (set "n=%~2" & shift & shift & goto parse)
if "%~1"=="-f" (set "wait=-Wait" & shift & goto parse)
if "%~1"=="-F" (set "wait=-Wait" & shift & goto parse)
set "a=%~1"
if "%a:~0,1%"=="-" (set "n=%a:~1%" & shift & goto parse)
set "file=%~1" & shift & goto parse
:run
if defined file (
    powershell -NoProfile -Command "Get-Content -LiteralPath '%file:'=''%' -Tail %n% %wait%"
) else (
    powershell -NoProfile -Command "$input | Select-Object -Last %n%"
)
endlocal
