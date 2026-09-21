@echo off
:: wc [-l|-w|-c] [FILE...]    (reads stdin without FILE)
setlocal EnableDelayedExpansion
set "sel=" & set "files="
:parse
if "%~1"=="" goto run
if "%~1"=="-l" (set "sel=Lines" & shift & goto parse)
if "%~1"=="-w" (set "sel=Words" & shift & goto parse)
if "%~1"=="-c" (set "sel=Characters" & shift & goto parse)
if "%~1"=="-m" (set "sel=Characters" & shift & goto parse)
set files=!files! '%~1'
shift & goto parse
:run
if defined files (
    powershell -NoProfile -Command "$sel='%sel%'; foreach ($f in @(%files:' '=','%)) { $m = Get-Content -LiteralPath $f | Measure-Object -Line -Word -Character; if ($sel) { '{0,8} {1}' -f $m.$sel, $f } else { '{0,8}{1,8}{2,8} {3}' -f $m.Lines, $m.Words, $m.Characters, $f } }"
) else (
    powershell -NoProfile -Command "$sel='%sel%'; $m = $input | Measure-Object -Line -Word -Character; if ($sel) { $m.$sel } else { '{0,8}{1,8}{2,8}' -f $m.Lines, $m.Words, $m.Characters }"
)
endlocal
