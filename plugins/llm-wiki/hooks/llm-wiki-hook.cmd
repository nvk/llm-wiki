@echo off
setlocal

set "SCRIPT=%~dp0llm_wiki_session.py"

where py >nul 2>nul
if %ERRORLEVEL%==0 (
  py -3 "%SCRIPT%" %*
  exit /b 0
)

where python3 >nul 2>nul
if %ERRORLEVEL%==0 (
  python3 "%SCRIPT%" %*
  exit /b 0
)

where python >nul 2>nul
if %ERRORLEVEL%==0 (
  python "%SCRIPT%" %*
  exit /b 0
)

exit /b 0
