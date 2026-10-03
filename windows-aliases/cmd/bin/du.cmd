@echo off
:: du [-s] [PATH]  - size of each item in PATH (or the total with -s)
setlocal
set "summary=0" & set "p=."
:parse
if "%~1"=="" goto run
if "%~1"=="-s"  (set "summary=1" & shift & goto parse)
if "%~1"=="-sh" (set "summary=1" & shift & goto parse)
if "%~1"=="-h"  (shift & goto parse)
set "p=%~1" & shift & goto parse
:run
powershell -NoProfile -Command "$h={param($b) foreach($x in 'B','K','M','G','T'){ if($b -lt 1024){ return ('{0:0.#}{1}' -f $b,$x) }; $b/=1024 }; '{0:0.#}P' -f $b}; $sz={param($q) [double](Get-ChildItem -LiteralPath $q -Recurse -File -Force -EA SilentlyContinue | Measure-Object Length -Sum).Sum}; $p='%p:'=''%'; if ('%summary%' -eq '1') { '{0,8}  {1}' -f (& $h (& $sz $p)), $p } else { Get-ChildItem -LiteralPath $p -Force -EA SilentlyContinue | Sort-Object { -not $_.PSIsContainer }, Name | ForEach-Object { $b = if ($_.PSIsContainer) { & $sz $_.FullName } else { $_.Length }; '{0,8}  {1}' -f (& $h $b), $_.Name }; '{0,8}  total' -f (& $h (& $sz $p)) }"
endlocal
