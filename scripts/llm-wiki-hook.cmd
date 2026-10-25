@echo off
rem Delayed expansion would eat a literal "!" in this script's own path, so it
rem stays off; the labels keep the interpreter's exit code readable per line.
setlocal EnableExtensions DisableDelayedExpansion

set "SCRIPT=%~dp0llm_wiki_session.py"

where py >nul 2>nul
if %ERRORLEVEL%==0 goto :run_py

where python >nul 2>nul
if %ERRORLEVEL%==0 goto :run_python

where python3 >nul 2>nul
if %ERRORLEVEL%==0 goto :run_python3

rem Session capture is optional. Missing Python must not block Codex itself.
exit /b 0

:run_py
py -3 "%SCRIPT%" %*
exit /b %ERRORLEVEL%

:run_python
python "%SCRIPT%" %*
exit /b %ERRORLEVEL%

:run_python3
python3 "%SCRIPT%" %*
exit /b %ERRORLEVEL%