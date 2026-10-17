@echo off
setlocal enabledelayedexpansion

REM DigitalVault Local Development Restart Script (Windows)
REM This script starts Hardhat node, deploys contracts, and updates backend .env

echo ========================================
echo    DigitalVault Local Restart Script
echo ========================================
echo.

REM Step 1: Check if Hardhat node is already running
echo [1/4] Checking for existing Hardhat node...
netstat -ano | findstr :8545 | findstr LISTENING >nul 2>&1
if !errorlevel! equ 0 (
    echo WARNING: Port 8545 is already in use
    echo Kill existing process? (Y/N^)
    set /p response=
    if /i "!response!"=="Y" (
        for /f "tokens=5" %%a in ('netstat -ano ^| findstr :8545 ^| findstr LISTENING') do (
            taskkill /F /PID %%a >nul 2>&1
        )
        timeout /t 2 /nobreak >nul
        echo OK Port 8545 freed
    ) else (
        echo ERROR: Cannot proceed with node already running
        exit /b 1
    )
) else (
    echo OK Port 8545 is available
)

REM Step 2: Start Hardhat node in background
echo.
echo [2/4] Starting Hardhat node...
cd digitalvault-contracts
start /B npx hardhat node > hardhat-node.log 2>&1
echo OK Hardhat node started in background
echo    Log file: digitalvault-contracts\hardhat-node.log

REM Wait for node to be ready
echo    Waiting for node to be ready...
timeout /t 3 /nobreak >nul

REM Check if port is listening
netstat -ano | findstr :8545 | findstr LISTENING >nul 2>&1
if !errorlevel! neq 0 (
    echo ERROR: Hardhat node failed to start. Check hardhat-node.log
    exit /b 1
)
echo OK Hardhat node is running at http://127.0.0.1:8545

REM Step 3: Deploy contracts
echo.
echo [3/4] Deploying contracts...
call npx hardhat run scripts/deploy.js --network localhost

if !errorlevel! neq 0 (
    echo ERROR: Contract deployment failed
    taskkill /F /IM node.exe /FI "WINDOWTITLE eq npx hardhat node*" >nul 2>&1
    exit /b 1
)
echo OK All contracts deployed successfully

REM Step 4: Update backend .env
echo.
echo [4/5] Updating backend .env file...
cd ..

REM Read contract addresses from deployments.json
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').VaultToken"') do set VAULT_TOKEN=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').ContentRegistry"') do set CONTENT_REGISTRY=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').Marketplace"') do set MARKETPLACE=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').StorageProvider"') do set STORAGE_PROVIDER=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').RewardDistributor"') do set REWARD_DISTRIBUTOR=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').DAOGovernor"') do set DAO_GOVERNOR=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').TimelockController"') do set TIMELOCK=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').ContentAccessControl"') do set ACCESS_CONTROL=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').SocialVerification"') do set SOCIAL_VERIFICATION=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').PresaleContract"') do set PRESALE=%%i
for /f "delims=" %%i in ('node -p "require('./digitalvault-contracts/deployments.json').AirdropDistributor"') do set AIRDROP=%%i

REM Create temporary PowerShell script to update .env
echo $envFile = Get-Content 'digitalvault-backend\.env' > update-env.ps1
echo $envFile = $envFile -replace 'RPC_URL=.*', 'RPC_URL=http://127.0.0.1:8545' >> update-env.ps1
echo $envFile = $envFile -replace 'CONTENT_REGISTRY_ADDRESS=.*', 'CONTENT_REGISTRY_ADDRESS=%CONTENT_REGISTRY%' >> update-env.ps1
echo $envFile = $envFile -replace 'MARKETPLACE_ADDRESS=.*', 'MARKETPLACE_ADDRESS=%MARKETPLACE%' >> update-env.ps1
echo $envFile = $envFile -replace 'STORAGE_PROVIDER_ADDRESS=.*', 'STORAGE_PROVIDER_ADDRESS=%STORAGE_PROVIDER%' >> update-env.ps1
echo $envFile = $envFile -replace 'VAULT_TOKEN_ADDRESS=.*', 'VAULT_TOKEN_ADDRESS=%VAULT_TOKEN%' >> update-env.ps1
echo $envFile = $envFile -replace 'REWARD_DISTRIBUTOR_ADDRESS=.*', 'REWARD_DISTRIBUTOR_ADDRESS=%REWARD_DISTRIBUTOR%' >> update-env.ps1
echo $envFile = $envFile -replace 'DAO_GOVERNOR_ADDRESS=.*', 'DAO_GOVERNOR_ADDRESS=%DAO_GOVERNOR%' >> update-env.ps1
echo $envFile = $envFile -replace 'TIMELOCK_CONTROLLER_ADDRESS=.*', 'TIMELOCK_CONTROLLER_ADDRESS=%TIMELOCK%' >> update-env.ps1
echo $envFile = $envFile -replace 'CONTENT_ACCESS_CONTROL_ADDRESS=.*', 'CONTENT_ACCESS_CONTROL_ADDRESS=%ACCESS_CONTROL%' >> update-env.ps1
echo $envFile = $envFile -replace 'SOCIAL_VERIFICATION_ADDRESS=.*', 'SOCIAL_VERIFICATION_ADDRESS=%SOCIAL_VERIFICATION%' >> update-env.ps1
echo $envFile = $envFile -replace 'PRESALE_CONTRACT_ADDRESS=.*', 'PRESALE_CONTRACT_ADDRESS=%PRESALE%' >> update-env.ps1
echo $envFile = $envFile -replace 'AIRDROP_DISTRIBUTOR_ADDRESS=.*', 'AIRDROP_DISTRIBUTOR_ADDRESS=%AIRDROP%' >> update-env.ps1
echo $envFile ^| Set-Content 'digitalvault-backend\.env' >> update-env.ps1

powershell -ExecutionPolicy Bypass -File update-env.ps1
del update-env.ps1

echo OK Backend .env updated with new contract addresses

REM Step 5: Start Docker services
echo.
echo [5/5] Starting Docker services (PostgreSQL, Redis)...
cd digitalvault-backend
docker-compose up -d postgres redis
if !errorlevel! neq 0 (
    echo WARNING: Docker services failed to start
    echo You may need to start them manually: cd digitalvault-backend ^&^& docker-compose up -d
) else (
    echo OK Docker services starting
)
cd ..

REM Final summary
echo.
echo ========================================
echo          Setup Complete!
echo ========================================
echo.
echo System Status:
echo    OK Hardhat node running at http://127.0.0.1:8545
echo    OK 11 contracts deployed
echo    OK Backend .env configured
echo    OK Docker services (PostgreSQL, Redis) starting
echo.
echo Contract Addresses:
echo    VaultToken:           %VAULT_TOKEN%
echo    ContentRegistry:      %CONTENT_REGISTRY%
echo    Marketplace:          %MARKETPLACE%
echo    StorageProvider:      %STORAGE_PROVIDER%
echo    RewardDistributor:    %REWARD_DISTRIBUTOR%
echo    DAOGovernor:          %DAO_GOVERNOR%
echo.
echo Next Steps:
echo    1. Start backend:  cd digitalvault-backend ^&^& npm start
echo    2. Start mobile:   cd digitalvault-mobile ^&^& flutter run
echo.
echo To stop Hardhat node:
echo    taskkill /F /IM node.exe /FI "WINDOWTITLE eq npx*"
echo.
echo Hardhat logs: digitalvault-contracts\hardhat-node.log
echo.

endlocal
