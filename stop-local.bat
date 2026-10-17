@echo off
echo Stopping DigitalVault local development environment...
echo.

echo [1/1] Stopping Hardhat node...
for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8545 ^| findstr LISTENING') do (
    echo    Killing process PID %%a
    taskkill /F /PID %%a >nul 2>&1
)

timeout /t 1 /nobreak >nul

netstat -ano | findstr :8545 | findstr LISTENING >nul 2>&1
if !errorlevel! equ 0 (
    echo ERROR: Failed to stop Hardhat node
    exit /b 1
) else (
    echo OK Hardhat node stopped
)

echo.
echo All local services stopped!
echo.
echo To restart: restart-local.bat
echo.
