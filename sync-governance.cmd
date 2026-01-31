@echo off
setlocal

echo =========================================
echo Oqtane AI Governance Sync
echo =========================================

REM Resolve script directory
set SCRIPT_DIR=%~dp0

REM PowerShell script path
set PS_SCRIPT=%SCRIPT_DIR%sync-governance.ps1

REM Safety check
if not exist "%PS_SCRIPT%" (
    echo ERROR: sync-governance.ps1 not found.
    echo Expected at: %PS_SCRIPT%
    exit /b 1
)

REM Run PowerShell (bypass execution policy for this run only)
powershell -NoProfile -ExecutionPolicy Bypass -File "%PS_SCRIPT%" %*

if errorlevel 1 (
    echo.
    echo Governance sync failed.
    exit /b 1
)

echo.
echo Governance sync completed successfully.
endlocal
