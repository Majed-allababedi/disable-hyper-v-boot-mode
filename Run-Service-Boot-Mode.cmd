@echo off
setlocal
title Service Boot Mode
echo This creates a SEPARATE Windows boot option with Hyper-V and VSM disabled.
echo It does not import any BCD backup. Keep your BitLocker recovery key available.
echo.
echo [1] Create alternate boot mode
echo [2] Remove alternate boot mode created by this script
echo [3] Dry run (no changes)
echo [4] Exit
choice /c 1234 /n /m "Select: "
if errorlevel 4 exit /b 0
if errorlevel 3 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Service-Boot-Mode.ps1" -DryRun
) else if errorlevel 2 (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Service-Boot-Mode.ps1" -Remove
) else (
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Service-Boot-Mode.ps1"
)
echo.
pause
