#!/bin/bash

# Stop DigitalVault local development environment

echo "Stopping DigitalVault local development environment..."
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo "[1/1] Stopping Hardhat node..."

# Find and kill process on port 8545
if lsof -Pi :8545 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    PID=$(lsof -t -i:8545)
    echo "   Killing process PID $PID"
    kill $PID 2>/dev/null || kill -9 $PID 2>/dev/null
    sleep 1

    # Verify it's stopped
    if lsof -Pi :8545 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
        echo -e "${RED}ERROR: Failed to stop Hardhat node${NC}"
        exit 1
    else
        echo -e "${GREEN}OK Hardhat node stopped${NC}"
    fi
else
    echo "   Hardhat node not running"
fi

echo ""
echo -e "${GREEN}All local services stopped!${NC}"
echo ""
echo "To restart: ./restart-local.sh"
echo ""
