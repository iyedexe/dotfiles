@echo off
:: Remove what install.cmd registered. Clink's own settings are left alone.
reg delete "HKCU\Software\Microsoft\Command Processor" /v AutoRun /f >nul 2>&1
for /f "delims=" %%c in ('where clink.bat 2^>nul') do "%%c" uninstallscripts "%~dp0clink" >nul 2>&1
echo AutoRun removed. Open a new Command Prompt.
