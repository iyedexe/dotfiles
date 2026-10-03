@echo off
:: head [-n N | -N] [FILE]    (reads stdin without FILE)
setlocal
set "n=10" & set "file="
:parse
if "%~1"=="" goto run
if "%~1"=="-n" (set "n=%~2" & shift & shift & goto parse)
set "a=%~1"
if "%a:~0,1%"=="-" (set "n=%a:~1%" & shift & goto parse)
set "file=%~1" & shift & goto parse
:run
if defined file (
    powershell -NoProfile -Command "Get-Content -LiteralPath '%file:'=''%' -TotalCount %n%"
) else (
    powershell -NoProfile -Command "$input | Select-Object -First %n%"
)
endlocal
