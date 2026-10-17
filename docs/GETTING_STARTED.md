# Getting Started with DigitalVault

## 🚀 Quick Start (5 Minutes)

### Step 1: Test Smart Contracts

```bash
cd digitalvault-contracts

# Install dependencies (if not already done)
npm install

# Compile contracts ✅ ALREADY TESTED
npx hardhat compile

# Run tests
npx hardhat test

# Start local blockchain
npx hardhat node
```

In another terminal:
```bash
# Deploy contracts locally
cd digitalvault-contracts
npx hardhat run scripts/deploy.js --network localhost

# Note: Contract addresses will be saved to deployments.json
```

### Step 2: Start Backend Services

```bash
cd digitalvault-backend

# Install dependencies
npm install

# Set up environment
cp .env.example .env

# Edit .env and add:
# - PINATA_API_KEY (get from pinata.cloud)
# - PINATA_SECRET_KEY
# - RPC_URL (use http://127.0.0.1:8545 for local)

# Start all services with Docker
docker-compose up -d

# Or start individually:
npm run start:ipfs        # Port 3000
npm run start:indexer     # Port 3001
npm run start:coordinator # Port 3002
npm run start:notifications # Port 3003

# Check health
curl http://localhost:3000/health
curl http://localhost:3001/health
```

### Step 3: Run Mobile App

```bash
cd digitalvault-mobile

# Install Flutter dependencies
flutter pub get

# Run code generation (for Riverpod)
flutter pub run build_runner build --delete-conflicting-outputs

# Update contract addresses
# Edit lib/core/constants/contract_addresses.dart with addresses from deployments.json

# Run app
flutter run

# Or run on specific device
flutter devices
flutter run -d <device-id>
```

---

## 📋 Complete Testing Walkthrough

### Test 1: Content Upload Flow

1. **Start all services** (contracts + backend + mobile)

2. **Create wallet in mobile app**
   - Open app
   - Create new wallet
   - Save seed phrase securely
   - Set PIN/biometric

3. **Upload content**
   - Select content type (Poetry/Journal/Photo/Video)
   - Create content
   - Set access model
   - Pay gas fee
   - Verify on blockchain

4. **Verify in backend**
   ```bash
   curl "http://localhost:3001/api/contents?limit=10"
   ```

### Test 2: Marketplace Flow

1. **Create listing**
   - Select content
   - Set price in VLTC
   - Choose listing type
   - Submit transaction

2. **Browse marketplace**
   - View available listings
   - Filter by type/price
   - View preview

3. **Purchase content**
   - Approve VLTC spending
   - Purchase listing
   - Decrypt and view content

### Test 3: Storage Provider

1. **Register as provider**
   ```javascript
   // Via mobile app or direct contract call
   await storageProvider.registerProvider(
     ipfsNodeId,
     storageCapacityGB,
     stakeAmount
   );
   ```

2. **Verify registration**
   ```bash
   curl "http://localhost:3001/api/providers"
   ```

---

## 🧪 Testing Commands Reference

### Smart Contracts

```bash
# Compile
npx hardhat compile

# Test
npx hardhat test
npx hardhat test test/VaultToken.test.js  # Specific test

# Coverage
npx hardhat coverage

# Gas report
REPORT_GAS=true npx hardhat test

# Console (for debugging)
npx hardhat console --network localhost

# Verify contract (after deployment to testnet)
npx hardhat verify --network baseSepolia <CONTRACT_ADDRESS> "constructor args"
```

### Mobile App

```bash
# Run tests
flutter test

# Run specific test
flutter test test/services/web3_service_test.dart

# Integration tests
flutter test integration_test

# Build APK (Android)
flutter build apk --release

# Build iOS
flutter build ios --release

# Analyze code
flutter analyze

# Format code
flutter format .
```

### Backend Services

```bash
# Test IPFS upload
curl -X POST http://localhost:3000/api/ipfs/upload \
  -F "file=@test-file.txt" \
  -F 'metadata={"name":"Test Content"}'

# Test content retrieval
curl http://localhost:3000/api/ipfs/content/<CID>

# Test indexer
curl "http://localhost:3001/api/contents?limit=5"
curl "http://localhost:3001/api/listings"
curl "http://localhost:3001/api/analytics/overview"

# View logs
docker-compose logs -f ipfs-gateway
docker-compose logs -f metadata-indexer

# Restart service
docker-compose restart ipfs-gateway

# Stop all
docker-compose down
```

---

## 🔧 Configuration Guide

### 1. Pinata Setup (Required for IPFS)

1. Go to https://pinata.cloud
2. Sign up for free account
3. Go to API Keys section
4. Create new key with pinning permissions
5. Add to `digitalvault-backend/.env`:
   ```
   PINATA_API_KEY=your_key_here
   PINATA_SECRET_KEY=your_secret_here
   ```

### 2. Firebase Setup (Optional - for notifications)

1. Go to https://firebase.google.com
2. Create new project
3. Add Android/iOS apps
4. Download google-services.json / GoogleService-Info.plist
5. Add to mobile app
6. Get service account credentials
7. Add to `digitalvault-backend/.env`:
   ```
   FIREBASE_PROJECT_ID=your_project_id
   FIREBASE_PRIVATE_KEY=your_private_key
   FIREBASE_CLIENT_EMAIL=your_client_email
   ```

### 3. Base Sepolia Testnet

1. Get testnet ETH from faucet:
   - https://www.coinbase.com/faucets/base-ethereum-sepolia-faucet

2. Configure in `digitalvault-contracts/.env`:
   ```
   PRIVATE_KEY=your_private_key_here
   BASE_SEPOLIA_RPC=https://sepolia.base.org
   ```

3. Deploy:
   ```bash
   npx hardhat run scripts/deploy.js --network baseSepolia
   ```

---

## 🐛 Troubleshooting

### Issue: Contracts won't compile
```bash
# Clear cache and rebuild
npx hardhat clean
rm -rf cache artifacts
npx hardhat compile
```

### Issue: Mobile app won't connect to contracts
1. Check contract addresses in `lib/core/constants/contract_addresses.dart`
2. Verify local blockchain is running (`npx hardhat node`)
3. Check RPC URL in Web3Service
4. Ensure ABI files are correct

### Issue: IPFS upload fails
1. Verify Pinata API keys in .env
2. Check file size (max 100MB)
3. Ensure ipfs-gateway service is running
4. Check logs: `docker-compose logs ipfs-gateway`

### Issue: Database connection error
1. Ensure PostgreSQL is running: `docker-compose ps`
2. Check credentials in .env
3. Wait for PostgreSQL to fully start (30 seconds)
4. Check logs: `docker-compose logs postgres`

### Issue: Flutter dependencies error
```bash
# Clean and reinstall
flutter clean
rm pubspec.lock
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

---

## 📚 Additional Resources

### Documentation
- [Project Spec](PROJECT_SPEC.md) - Complete specification
- [Implementation Summary](IMPLEMENTATION_SUMMARY.md) - What's been built
- [Verification Report](VERIFICATION_REPORT.md) - Build verification

### Component READMEs
- [Smart Contracts README](digitalvault-contracts/README.md)
- [Mobile App README](digitalvault-mobile/README.md)
- [Backend Services README](digitalvault-backend/README.md)

### External Docs
- Hardhat: https://hardhat.org/docs
- Flutter: https://docs.flutter.dev
- OpenZeppelin: https://docs.openzeppelin.com
- Base L2: https://docs.base.org
- Pinata: https://docs.pinata.cloud

---

## 🎯 Development Workflow

### Daily Development Loop

```bash
# Morning: Start services
cd digitalvault-contracts && npx hardhat node &
cd digitalvault-backend && docker-compose up -d

# Development: Make changes and test
# ... edit code ...
npx hardhat compile && npx hardhat test
flutter test
npm test

# Evening: Stop services
docker-compose down
# Kill hardhat node process
```

### Feature Development

1. **Plan**
   - Review PROJECT_SPEC.md
   - Identify requirements
   - Design implementation

2. **Implement**
   - Write code (contracts/mobile/backend)
   - Follow existing patterns
   - Add comments and documentation

3. **Test**
   - Write unit tests
   - Write integration tests
   - Manual testing

4. **Deploy**
   - Deploy to local network
   - Test end-to-end
   - Deploy to testnet

---

## ✅ Success Checklist

### You're Ready to Proceed When:
- [ ] All contracts compile successfully ✅ DONE
- [ ] Local blockchain running
- [ ] Backend services healthy
- [ ] Mobile app connects to local contracts
- [ ] Can create test wallet
- [ ] Can upload test content
- [ ] Can browse marketplace
- [ ] Database storing events

### Ready for Testnet When:
- [ ] All local tests passing
- [ ] Integration tests complete
- [ ] UI/UX mostly complete
- [ ] Error handling robust
- [ ] Have testnet ETH

### Ready for Mainnet When:
- [ ] Security audit complete ⚠️ MANDATORY
- [ ] Bug bounty program active
- [ ] Comprehensive test coverage
- [ ] Load testing complete
- [ ] Monitoring operational
- [ ] Legal compliance verified

---

## 🚀 Let's Go!

You're now ready to start development on DigitalVault. The foundation is solid, the architecture is sound, and all the pieces are in place.

**Start with:**
```bash
cd digitalvault-contracts
npx hardhat node
```

Then in another terminal:
```bash
npx hardhat run scripts/deploy.js --network localhost
```

**Happy building! 🎉**

---
**Questions?** Review the README files in each directory for detailed component documentation.
