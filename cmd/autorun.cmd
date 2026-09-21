@echo off
:: ============================================================================
:: autorun.cmd - makes cmd.exe feel like a Linux shell.
::
:: Registered by install.cmd as the Command Processor AutoRun, so it runs at
:: the start of every cmd.exe session (including those that run .bat files).
::
:: Gives you:
::   - prompt  [user@host:C:\path]$   in the same colours as .bashrc
::   - doskey aliases (ls, ll, la, cat, clear, pwd, .., export, env, history...)
::   - cmd\bin on PATH with grep, find, head, tail, wc, touch, df, du, free,
::     rm, cp, mkdir, which, ... written as small .cmd scripts
::   - if Clink is installed: Ctrl+R history search, Emacs keys, git branch
::     in the prompt (see clink\README.md)
:: ============================================================================

:: Skip for non-interactive shells spawned with /c (build scripts, tasks) so
:: they start fast and the doskey macros can't change their behaviour.
echo %CMDCMDLINE% | findstr /i /c:"/c" >nul && exit /b 0

set "DOTFILES_CMD=%~dp0"
set "DOTFILES_CMD=%DOTFILES_CMD:~0,-1%"

:: ---------------------------------------------------------------- PATH ---
echo %PATH% | findstr /i /c:"%DOTFILES_CMD%\bin" >nul || set "PATH=%DOTFILES_CMD%\bin;%PATH%"

:: -------------------------------------------------------------- prompt ---
:: $E = ESC, $P = cwd, $$ = $, $S = space. Colours need VT sequences, which
:: install.cmd enables in the registry (Windows Terminal has them always).
prompt $E[32m[$E[0m$E[31m%USERNAME%$E[0m$E[33m@$E[0m$E[32m%COMPUTERNAME%$E[0m:$E[36m$P$E[0m$E[32m]$E[0m $E[32m$$$E[0m$S
title %USERNAME%@%COMPUTERNAME%

:: ------------------------------------------------------------- aliases ---
doskey /macrofile="%DOTFILES_CMD%\macros.doskey"

:: ---------------------------------------------------------------- misc ---
:: less pager like Linux: `more` waits at each page and quits on q
set "DIRCMD=/o:gn"
:: Machine-specific settings that should not be committed.
if exist "%USERPROFILE%\autorun.local.cmd" call "%USERPROFILE%\autorun.local.cmd"
