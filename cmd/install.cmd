@echo off
:: ============================================================================
:: install.cmd - register autorun.cmd so every cmd.exe session loads it.
::
:: Run once from a Command Prompt (no admin needed, it only writes HKCU):
::     %USERPROFILE%\dotfiles\cmd\install.cmd
::
:: What it does:
::   1. HKCU\Software\Microsoft\Command Processor\AutoRun -> autorun.cmd
::      (and Clink injection first, if Clink is installed)
::   2. HKCU\Console\VirtualTerminalLevel = 1 so the coloured prompt works in
::      the classic console (Windows Terminal doesn't need it)
::   3. If Clink is installed: registers clink\ scripts and sets bash-like
::      history / completion options
:: ============================================================================
setlocal
set "HERE=%~dp0"
set "HERE=%HERE:~0,-1%"
set "AUTORUN=call "%HERE%\autorun.cmd""

set "CLINK="
for /f "delims=" %%c in ('where clink.bat 2^>nul') do if not defined CLINK set "CLINK=%%c"
if defined CLINK (
    echo Clink found: %CLINK%
    set "AUTORUN="%CLINK%" inject --autorun --quiet ^& call "%HERE%\autorun.cmd""
    "%CLINK%" installscripts "%HERE%\clink" >nul
    "%CLINK%" set history.max_lines 10000 >nul
    "%CLINK%" set history.dupe_mode erase_prev >nul
    "%CLINK%" set history.shared true >nul
    "%CLINK%" set match.ignore_case relaxed >nul
    "%CLINK%" set autosuggest.enable true >nul
    "%CLINK%" set clink.logo none >nul
) else (
    echo Clink not found. Ctrl+R history search and the git branch in the
    echo prompt need it:  winget install chrisant996.Clink   then re-run this.
    echo Without it, use F7 ^(history list^) and F8 ^(prefix search^).
)

reg add "HKCU\Software\Microsoft\Command Processor" /v AutoRun /t REG_SZ /d "%AUTORUN%" /f >nul
reg add "HKCU\Console" /v VirtualTerminalLevel /t REG_DWORD /d 1 /f >nul

echo.
echo Installed. AutoRun is now:
reg query "HKCU\Software\Microsoft\Command Processor" /v AutoRun | findstr AutoRun
echo Open a new Command Prompt, or run:  call "%HERE%\autorun.cmd"
endlocal
