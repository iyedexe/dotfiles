@echo off
:: wpath [PATH] - absolute Windows path (handy for pasting into other tools)
if "%~1"=="" (echo %CD%) else (echo %~f1)
