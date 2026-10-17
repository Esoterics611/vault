#!/bin/bash

# DigitalVault Local Development Restart Script
# This script starts Hardhat node, deploys contracts, and updates backend .env

set -e  # Exit on error

echo "╔════════════════════════════════════════╗"
echo "║   DigitalVault Local Restart Script   ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Check if Hardhat node is already running
echo -e "${YELLOW}[1/4] Checking for existing Hardhat node...${NC}"
if lsof -Pi :8545 -sTCP:LISTEN -t >/dev/null 2>&1 ; then
    echo "⚠️  Hardhat node already running on port 8545"
    echo "   Kill it? (y/n)"
    read -r response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        kill $(lsof -t -i:8545) 2>/dev/null || true
        sleep 2
        echo "✅ Stopped existing Hardhat node"
    else
        echo "❌ Cannot proceed with node already running. Exiting."
        exit 1
    fi
else
    echo "✅ Port 8545 is available"
fi

# Step 2: Start Hardhat node in background
echo ""
echo -e "${YELLOW}[2/4] Starting Hardhat node...${NC}"
cd digitalvault-contracts
npx hardhat node > hardhat-node.log 2>&1 &
HARDHAT_PID=$!
echo "🚀 Hardhat node started (PID: $HARDHAT_PID)"
echo "   Log file: digitalvault-contracts/hardhat-node.log"

# Wait for node to be ready
echo "   Waiting for node to be ready..."
sleep 3

# Check if node is running
if ! kill -0 $HARDHAT_PID 2>/dev/null; then
    echo "❌ Hardhat node failed to start. Check hardhat-node.log"
    exit 1
fi
echo "✅ Hardhat node is running at http://127.0.0.1:8545"

# Step 3: Deploy contracts
echo ""
echo -e "${YELLOW}[3/4] Deploying contracts...${NC}"
npx hardhat run scripts/deploy.js --network localhost

if [ $? -ne 0 ]; then
    echo "❌ Contract deployment failed"
    kill $HARDHAT_PID 2>/dev/null || true
    exit 1
fi
echo "✅ All contracts deployed successfully"

# Step 4: Update backend .env
echo ""
echo -e "${YELLOW}[4/4] Updating backend .env file...${NC}"
cd ..

# Read contract addresses from deployments.json
VAULT_TOKEN=$(node -p "require('./digitalvault-contracts/deployments.json').VaultToken")
CONTENT_REGISTRY=$(node -p "require('./digitalvault-contracts/deployments.json').ContentRegistry")
MARKETPLACE=$(node -p "require('./digitalvault-contracts/deployments.json').Marketplace")
STORAGE_PROVIDER=$(node -p "require('./digitalvault-contracts/deployments.json').StorageProvider")
REWARD_DISTRIBUTOR=$(node -p "require('./digitalvault-contracts/deployments.json').RewardDistributor")
DAO_GOVERNOR=$(node -p "require('./digitalvault-contracts/deployments.json').DAOGovernor")
TIMELOCK=$(node -p "require('./digitalvault-contracts/deployments.json').TimelockController")
ACCESS_CONTROL=$(node -p "require('./digitalvault-contracts/deployments.json').ContentAccessControl")
SOCIAL_VERIFICATION=$(node -p "require('./digitalvault-contracts/deployments.json').SocialVerification")
PRESALE=$(node -p "require('./digitalvault-contracts/deployments.json').PresaleContract")
AIRDROP=$(node -p "require('./digitalvault-contracts/deployments.json').AirdropDistributor")

# Update .env file
sed -i.bak \
    -e "s|RPC_URL=.*|RPC_URL=http://127.0.0.1:8545|" \
    -e "s|CONTENT_REGISTRY_ADDRESS=.*|CONTENT_REGISTRY_ADDRESS=$CONTENT_REGISTRY|" \
    -e "s|MARKETPLACE_ADDRESS=.*|MARKETPLACE_ADDRESS=$MARKETPLACE|" \
    -e "s|STORAGE_PROVIDER_ADDRESS=.*|STORAGE_PROVIDER_ADDRESS=$STORAGE_PROVIDER|" \
    -e "s|VAULT_TOKEN_ADDRESS=.*|VAULT_TOKEN_ADDRESS=$VAULT_TOKEN|" \
    -e "s|REWARD_DISTRIBUTOR_ADDRESS=.*|REWARD_DISTRIBUTOR_ADDRESS=$REWARD_DISTRIBUTOR|" \
    -e "s|DAO_GOVERNOR_ADDRESS=.*|DAO_GOVERNOR_ADDRESS=$DAO_GOVERNOR|" \
    -e "s|TIMELOCK_CONTROLLER_ADDRESS=.*|TIMELOCK_CONTROLLER_ADDRESS=$TIMELOCK|" \
    -e "s|CONTENT_ACCESS_CONTROL_ADDRESS=.*|CONTENT_ACCESS_CONTROL_ADDRESS=$ACCESS_CONTROL|" \
    -e "s|SOCIAL_VERIFICATION_ADDRESS=.*|SOCIAL_VERIFICATION_ADDRESS=$SOCIAL_VERIFICATION|" \
    -e "s|PRESALE_CONTRACT_ADDRESS=.*|PRESALE_CONTRACT_ADDRESS=$PRESALE|" \
    -e "s|AIRDROP_DISTRIBUTOR_ADDRESS=.*|AIRDROP_DISTRIBUTOR_ADDRESS=$AIRDROP|" \
    digitalvault-backend/.env

echo "✅ Backend .env updated with new contract addresses"

# Final summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 Setup Complete! 🎉         ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo "📊 System Status:"
echo "   ✅ Hardhat node running (PID: $HARDHAT_PID)"
echo "   ✅ 11 contracts deployed"
echo "   ✅ Backend .env configured"
echo ""
echo "📝 Contract Addresses:"
echo "   VaultToken:           $VAULT_TOKEN"
echo "   ContentRegistry:      $CONTENT_REGISTRY"
echo "   Marketplace:          $MARKETPLACE"
echo "   StorageProvider:      $STORAGE_PROVIDER"
echo "   RewardDistributor:    $REWARD_DISTRIBUTOR"
echo "   DAOGovernor:          $DAO_GOVERNOR"
echo ""
echo "🚀 Next Steps:"
echo "   1. Start backend:  cd digitalvault-backend && npm start"
echo "   2. Start mobile:   cd digitalvault-mobile && flutter run"
echo ""
echo "⚠️  To stop Hardhat node: kill $HARDHAT_PID"
echo "    Or use: pkill -f 'hardhat node'"
echo ""
echo "📄 Hardhat logs: digitalvault-contracts/hardhat-node.log"
echo ""
