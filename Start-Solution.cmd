rem @echo off
setlocal enabledelayedexpansion

REM ------------------------------------------------------------
REM  Determine the folder name (solution name)
REM ------------------------------------------------------------
set "CurrentDir=%~dp0"
for %%F in ("%CurrentDir:~0,-1%") do set "FolderName=%%~nxF"

REM ------------------------------------------------------------
REM  Find the .slnx file matching the folder name
REM ------------------------------------------------------------
set "SolutionFile=%CurrentDir%%FolderName%.slnx"

if not exist "%SolutionFile%" (
    echo ERROR: Could not find solution file "%FolderName%.slnx"
    echo Make sure the .slnx file has the same name as the folder.
    exit /b 1
)

REM ------------------------------------------------------------
REM  Parse optional parameters
REM ------------------------------------------------------------
set "DryRun="
set "Help="

:parseArgs
if "%~1"=="" goto argsDone

if /I "%~1"=="-DryRun" (
    set "DryRun=-DryRun"
) else if /I "%~1"=="-Help" (
    set "Help=-Help"
)

shift
goto parseArgs

:argsDone

REM ------------------------------------------------------------
REM  Use your REAL script location
REM ------------------------------------------------------------
set "ScriptPath=D:\Oqtane Development\oqtane-ai-playbook\module-playbook-example\sync-governance.ps1"

if not exist "%ScriptPath%" (
    echo ERROR: Could not find script: %ScriptPath%
    exit /b 1
)

REM ------------------------------------------------------------
REM  Run the PowerShell script
REM ------------------------------------------------------------
echo Running governance sync script...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%ScriptPath%" -SolutionPath "%SolutionFile%" %DryRun% %Help%

if errorlevel 1 (
    echo Script reported an error.
    exit /b 1
)

REM ------------------------------------------------------------
REM  Open the solution
REM ------------------------------------------------------------
echo Opening solution: "%SolutionFile%"
start "" "%SolutionFile%"

endlocal
exit /b 0
