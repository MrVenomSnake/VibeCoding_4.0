@echo off

NET SESSION >nul 2>&1
if %errorLevel% == 0 (
    goto :admin
) else (
    echo Solicitando privilegios administrativos...
    goto :UACPrompt
)

:UACPrompt
    echo Set UAC = CreateObject^("Shell.Application"^) > "%temp%\getadmin.vbs"
    echo UAC.ShellExecute "%~s0", "", "", "runas", 1 >> "%temp%\getadmin.vbs"
    "%temp%\getadmin.vbs"
    del "%temp%\getadmin.vbs"
    exit /B

:admin
    powershell.exe -ExecutionPolicy Bypass -File "%~dp0VibeCoding_Edition_4.0.ps1"

pause
