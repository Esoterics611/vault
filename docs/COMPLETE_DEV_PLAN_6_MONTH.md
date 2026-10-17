# DigitalVault: Complete 6-Month Development Plan
**Timeline:** 10 hours/week (2 hours Mon-Fri) = ~240 total hours
**Goal:** Fully functional MVP with PRE, backend APIs, mobile app, and DAO features

Last Updated: January 14, 2026

---

## 📊 Time Budget Summary

| Phase | Weeks | Total Hours | Focus Area |
|-------|-------|-------------|------------|
| **Phase 0: Foundation** | 1 week | 10 hours | Setup & Planning |
| **Phase 1: Smart Contracts** | 6 weeks | 60 hours | All 11 contracts + tests |
| **Phase 2: Backend Services** | 6 weeks | 60 hours | 6 services + PRE |
| **Phase 3: Mobile Core** | 8 weeks | 80 hours | Wallet + Content + PRE |
| **Phase 4: Marketplace & DAO** | 4 weeks | 40 hours | Trading + Governance |
| **Phase 5: Testing & Launch** | 1 week | 10 hours | Integration & Deploy |
| **TOTAL** | **26 weeks** | **260 hours** | **Full MVP** |

---

## 🎯 What You'll Build

### Smart Contracts (11 Total)
1. ✅ VaultToken.sol (EXISTS)
2. ✅ ContentRegistry.sol (EXISTS - needs PRE upgrade)
3. ✅ Marketplace.sol (EXISTS - needs PRE integration)
4. ✅ StorageProvider.sol (EXISTS)
5. ✅ RewardDistributor.sol (EXISTS)
6. ✅ DAOGovernor.sol (EXISTS)
7. ✅ ContentAccessControl.sol (EXISTS)
8. ✅ SocialVerification.sol (EXISTS)
9. ✅ PresaleContract.sol (EXISTS)
10. ✅ AirdropDistributor.sol (EXISTS)
11. ❌ **ReKeyRegistry.sol (NEW - PRE management)**

### Backend Services (6 Total)
1. ✅ IPFS Gateway (EXISTS - port 3000)
2. ✅ Metadata Indexer (EXISTS - port 3001)
3. ✅ Storage Coordinator (EXISTS - port 3002)
4. ✅ Notification Service (EXISTS - port 3003)
5. ❌ **PRE Proxy Network (NEW - port 3004)**
6. ❌ **Capsule Store (NEW - port 3005)**

### Mobile App Features
1. ❌ Wallet (Create, Import, Connect)
2. ❌ Content Upload (Poetry, Photo, Video, Journal)
3. ❌ PRE Encryption (Rust FFI + Dart)
4. ❌ Portfolio (My Content, Analytics)
5. ❌ Marketplace (Browse, Purchase with PRE)
6. ❌ **DAO Governance (Proposals, Voting, Delegation)**
7. ❌ Social Sharing (Watermarks)
8. ❌ Rewards (Claim, Stake)

---

## 📅 PHASE 0: Foundation & Setup (Week 1)
**Time: 10 hours** | **Goal: Get environment ready**

### Day 1 (Monday, 2 hours) - Development Environment
- [ ] Install Node.js 18+, npm, Hardhat
- [ ] Install Rust and Cargo (for PRE FFI)
- [ ] Install Flutter SDK 3.16+
- [ ] Install Android Studio + Android SDK
- [ ] Install Xcode (if macOS) or Android emulator
- [ ] Set up VS Code with extensions:
  - Solidity
  - Dart
  - Rust Analyzer
  - Flutter
- [ ] Clone/verify all 3 repos in `C:\code\vault\`

### Day 2 (Tuesday, 2 hours) - Smart Contract Setup
- [ ] Navigate to `digitalvault-contracts/`
- [ ] Run `npm install` (verify dependencies)
- [ ] Create `.env` file:
  ```bash
  PRIVATE_KEY=your_test_private_key
  BASE_SEPOLIA_RPC=https://sepolia.base.org
  BASESCAN_API_KEY=your_basescan_key
  ```
- [ ] Run `npx hardhat compile` (verify all contracts compile)
- [ ] Run `npx hardhat test` (verify existing tests pass)
- [ ] Review contract files to understand existing architecture

### Day 3 (Wednesday, 2 hours) - Backend Setup
- [ ] Navigate to `digitalvault-backend/`
- [ ] Run `npm install` in each service directory
- [ ] Set up PostgreSQL locally (Docker recommended):
  ```bash
  docker run --name vault-postgres -e POSTGRES_PASSWORD=vault123 -p 5432:5432 -d postgres
  ```
- [ ] Create `.env` files for each service
- [ ] Test IPFS Gateway: `cd services/ipfs-gateway && npm start`
- [ ] Verify Pinata API key works (get from pinata.cloud)

### Day 4 (Thursday, 2 hours) - Flutter Setup
- [ ] Navigate to `digitalvault-mobile/`
- [ ] Run `flutter pub get`
- [ ] Review existing files:
  - `lib/main.dart`
  - `lib/app/app.dart`
  - `lib/core/services/web3_service.dart`
  - `lib/core/services/encryption_service.dart`
- [ ] Run `flutter doctor` to verify setup
- [ ] Test on emulator: `flutter run`
- [ ] Verify app launches (even if mostly empty)

### Day 5 (Friday, 2 hours) - Planning & Architecture Review
- [ ] Read `PRE_IMPLEMENTATION_PLAN.md` thoroughly
- [ ] Read `PRE_IMPLEMENTATION_ROADMAP.md`
- [ ] Review `PROJECT_SPEC.md`
- [ ] Create personal dev journal (track daily progress)
- [ ] Set up GitHub projects or Trello board for task tracking
- [ ] **Understand the full architecture before coding**

**Week 1 Deliverable:** ✅ Fully configured development environment

---

## 📅 PHASE 1: Smart Contracts (Weeks 2-7)
**Time: 60 hours** | **Goal: All 11 contracts deployed to testnet**

### Week 2 (10 hours) - ReKeyRegistry.sol (NEW)

**Day 1 (Monday, 2 hours):**
```solidity
// File: contracts/ReKeyRegistry.sol
// Create contract structure
- Define ReKeyGrant struct
- Define events (GrantCreated, GrantVerified, GrantUsed, GrantRevoked)
- Add imports (OpenZeppelin ReentrancyGuard, Ownable)
```

**Day 2 (Tuesday, 2 hours):**
```solidity
// Implement core functions
- createGrant(contentId, seller, buyer, kfragHash, threshold, totalShares)
- verifyGrant(contentId) returns (ReKeyGrant)
- getGrant(contentId) returns (ReKeyGrant)
```

**Day 3 (Wednesday, 2 hours):**
```solidity
// Implement lifecycle functions
- markGrantUsed(contentId) onlySeller or onlyMarketplace
- revokeGrant(contentId) onlySeller
- isGrantActive(contentId) returns (bool)
- Add expiration logic (7 days default)
```

**Day 4 (Thursday, 2 hours):**
```javascript
// File: test/ReKeyRegistry.test.js
- Write Hardhat tests:
  * Should create grant successfully
  * Should prevent duplicate grants
  * Should verify grant correctly
  * Should mark grant as used
  * Should allow seller to revoke unused grant
  * Should prevent revoking used grants
  * Should handle expiration correctly
```

**Day 5 (Friday, 2 hours):**
- [ ] Run tests: `npx hardhat test test/ReKeyRegistry.test.js`
- [ ] Fix any bugs
- [ ] Gas optimization review
- [ ] Add NatSpec comments
- [ ] **Commit: "feat: add ReKeyRegistry contract"**

---

### Week 3 (10 hours) - ContentRegistry.sol PRE Upgrade

**Day 1 (Monday, 2 hours):**
```solidity
// File: contracts/ContentRegistry.sol
// Add PRE fields to Content struct
struct Content {
    // ... existing fields ...
    bytes32 capsuleHash;        // NEW: Hash of PRE capsule
    bytes ownerPublicKey;       // NEW: Owner's PRE public key (33 bytes)
    uint256 capsuleVersion;     // NEW: Version tracking for re-encryption
}
```

**Day 2 (Tuesday, 2 hours):**
```solidity
// Update registerContent function
function registerContent(
    bytes32 contentHash,
    bytes32 metadataHash,
    bytes32 capsuleHash,      // NEW parameter
    bytes calldata ownerPublicKey,  // NEW parameter
    uint256 fileSize,
    ContentType contentType,
    AccessModel accessModel
) external returns (uint256) {
    // ... existing validation ...
    require(capsuleHash != bytes32(0), "Invalid capsule hash");
    require(ownerPublicKey.length == 33, "Invalid public key length");

    // Store with new fields
    content.capsuleHash = capsuleHash;
    content.ownerPublicKey = ownerPublicKey;
    content.capsuleVersion = 1;
}
```

**Day 3 (Wednesday, 2 hours):**
```solidity
// Add new functions for PRE
function updateCapsule(
    uint256 contentId,
    bytes32 newCapsuleHash,
    bytes calldata newOwnerPublicKey
) external {
    require(msg.sender == content.owner, "Not owner");
    content.capsuleHash = newCapsuleHash;
    content.ownerPublicKey = newOwnerPublicKey;
    content.capsuleVersion++;
    emit CapsuleUpdated(contentId, newCapsuleHash, content.capsuleVersion);
}

function getCapsuleInfo(uint256 contentId) external view returns (
    bytes32 capsuleHash,
    bytes memory ownerPublicKey,
    uint256 version
) {
    Content storage content = contents[contentId];
    return (content.capsuleHash, content.ownerPublicKey, content.capsuleVersion);
}
```

**Day 4 (Thursday, 2 hours):**
```javascript
// Update tests: test/ContentRegistry.test.js
- Test registerContent with capsule hash and public key
- Test updateCapsule by owner
- Test getCapsuleInfo returns correct data
- Test capsule version increments
- Test access control (only owner can update)
```

**Day 5 (Friday, 2 hours):**
- [ ] Run all ContentRegistry tests
- [ ] Update deployment script to include new parameters
- [ ] Test migration from old to new schema
- [ ] **Commit: "feat: add PRE support to ContentRegistry"**

---

### Week 4 (10 hours) - Marketplace.sol PRE Integration

**Day 1 (Monday, 2 hours):**
```solidity
// File: contracts/Marketplace.sol
// Add ReKeyRegistry reference
import "./ReKeyRegistry.sol";

ReKeyRegistry public reKeyRegistry;

constructor(address _reKeyRegistry) {
    reKeyRegistry = ReKeyRegistry(_reKeyRegistry);
}
```

**Day 2 (Tuesday, 2 hours):**
```solidity
// Update purchaseListing to require grant
function purchaseListing(
    uint256 listingId,
    bytes calldata buyerPublicKey  // NEW: Buyer's PRE public key
) external nonReentrant {
    // ... existing payment logic ...

    // NEW: Verify re-encryption grant exists
    require(
        reKeyRegistry.isGrantActive(contentId),
        "No active re-encryption grant"
    );

    // Transfer ownership
    contentRegistry.transferOwnership(contentId, msg.sender);

    // Mark grant as used
    reKeyRegistry.markGrantUsed(contentId);

    emit ListingPurchased(listingId, msg.sender, listing.price, buyerPublicKey);
}
```

**Day 3 (Wednesday, 2 hours):**
```solidity
// Add seller approval mechanism
event PurchaseInitiated(uint256 indexed listingId, address buyer, uint256 timestamp);
event SellerApproved(uint256 indexed contentId, bytes32 kfragHash);

mapping(uint256 => address) public pendingBuyers;

function initiatePurchase(uint256 listingId, bytes calldata buyerPublicKey) external {
    // Lock payment in escrow
    // Store pending buyer
    pendingBuyers[listingId] = msg.sender;
    emit PurchaseInitiated(listingId, msg.sender, block.timestamp);
}

function approvePurchase(uint256 listingId, bytes32 kfragHash) external {
    // Only seller can approve
    require(msg.sender == listing.seller, "Not seller");
    // Create grant on ReKeyRegistry
    // Release payment
    // Complete transfer
}
```

**Day 4 (Thursday, 2 hours):**
```javascript
// Update tests: test/Marketplace.test.js
- Test purchase flow with PRE grant
- Test seller approval mechanism
- Test escrow locking and release
- Test grant verification
- Test purchase failure without grant
```

**Day 5 (Friday, 2 hours):**
- [ ] Run all Marketplace tests
- [ ] Integration test: ContentRegistry + ReKeyRegistry + Marketplace
- [ ] Gas optimization
- [ ] **Commit: "feat: integrate PRE with Marketplace"**

---

### Week 5 (10 hours) - DAOGovernor.sol Enhancement

**Current DAO Functions (Review Existing):**
- `propose()` - Create proposal
- `castVote()` - Vote on proposal
- `execute()` - Execute passed proposal

**NEW DAO Functions to Add:**

**Day 1 (Monday, 2 hours):**
```solidity
// Add delegation features
function delegate(address delegatee) external {
    _delegate(msg.sender, delegatee);
    emit DelegateChanged(msg.sender, delegatee);
}

function getDelegates(address account) external view returns (address) {
    return _delegates[account];
}

function getVotingPower(address account) external view returns (uint256) {
    return getVotes(account);
}
```

**Day 2 (Tuesday, 2 hours):**
```solidity
// Add proposal templates
enum ProposalType {
    PARAMETER_CHANGE,
    TREASURY_SPEND,
    EMERGENCY_ACTION,
    PROTOCOL_UPGRADE,
    PARTNERSHIP
}

struct ProposalMetadata {
    ProposalType proposalType;
    string title;
    string description;
    string discussionUrl;
}

mapping(uint256 => ProposalMetadata) public proposalMetadata;

function proposeWithMetadata(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description,
    ProposalType proposalType,
    string memory title,
    string memory discussionUrl
) external returns (uint256) {
    uint256 proposalId = propose(targets, values, calldatas, description);
    proposalMetadata[proposalId] = ProposalMetadata({
        proposalType: proposalType,
        title: title,
        description: description,
        discussionUrl: discussionUrl
    });
    return proposalId;
}
```

**Day 3 (Wednesday, 2 hours):**
```solidity
// Add voting with reason and NFT receipt
event VoteCastWithReason(
    address indexed voter,
    uint256 indexed proposalId,
    uint8 support,
    uint256 weight,
    string reason
);

function castVoteWithReason(
    uint256 proposalId,
    uint8 support,
    string calldata reason
) external returns (uint256) {
    uint256 weight = _castVote(proposalId, msg.sender, support, "");
    emit VoteCastWithReason(msg.sender, proposalId, support, weight, reason);
    return weight;
}

// Add vote history tracking
struct VoteRecord {
    uint256 proposalId;
    uint8 support;
    uint256 weight;
    uint256 timestamp;
}

mapping(address => VoteRecord[]) public voteHistory;
```

**Day 4 (Thursday, 2 hours):**
```solidity
// Add proposal cancellation by creator
function cancel(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    bytes32 descriptionHash
) public returns (uint256) {
    uint256 proposalId = hashProposal(targets, values, calldatas, descriptionHash);
    require(msg.sender == proposalProposer[proposalId], "Not proposer");
    return _cancel(targets, values, calldatas, descriptionHash);
}

// Add treasury management
function getTreasuryBalance() external view returns (uint256) {
    return address(this).balance;
}

function getTreasuryTokenBalance(address token) external view returns (uint256) {
    return IERC20(token).balanceOf(address(this));
}
```

**Day 5 (Friday, 2 hours):**
```javascript
// Test new DAO features: test/DAOGovernor.test.js
- Test delegation
- Test proposal with metadata
- Test voting with reason
- Test vote history tracking
- Test proposal cancellation
- Test treasury queries
```
- [ ] Run tests
- [ ] **Commit: "feat: enhance DAO with delegation and metadata"**

---

### Week 6 (10 hours) - Testing & Optimization

**Day 1 (Monday, 2 hours):**
- [ ] Run full test suite: `npx hardhat test`
- [ ] Check coverage: `npx hardhat coverage`
- [ ] Target: >90% coverage on all contracts

**Day 2 (Tuesday, 2 hours):**
- [ ] Gas optimization pass:
  - Use `uint128` where possible
  - Pack structs efficiently
  - Use `calldata` instead of `memory` for external functions
  - Remove unnecessary storage reads
- [ ] Run gas report: `REPORT_GAS=true npx hardhat test`

**Day 3 (Wednesday, 2 hours):**
- [ ] Security review:
  - Check reentrancy protection
  - Verify access control
  - Review integer overflow (Solidity 0.8+)
  - Check for front-running vulnerabilities
- [ ] Run Slither: `slither .`

**Day 4 (Thursday, 2 hours):**
- [ ] Update deployment script `scripts/deploy.js`:
  ```javascript
  // Deploy all 11 contracts in correct order
  const VaultToken = await deploy("VaultToken");
  const ContentRegistry = await deploy("ContentRegistry");
  const ReKeyRegistry = await deploy("ReKeyRegistry", [ContentRegistry.address]);
  const Marketplace = await deploy("Marketplace", [ContentRegistry.address, ReKeyRegistry.address, VaultToken.address]);
  // ... etc
  ```

**Day 5 (Friday, 2 hours):**
- [ ] Deploy to Base Sepolia testnet:
  ```bash
  npx hardhat run scripts/deploy.js --network baseSepolia
  ```
- [ ] Verify all contracts on Basescan:
  ```bash
  npx hardhat verify --network baseSepolia DEPLOYED_ADDRESS "constructor args"
  ```
- [ ] Save deployed addresses to `deployments/base-sepolia.json`
- [ ] **Commit: "deploy: Base Sepolia testnet deployment"**

---

### Week 7 (10 hours) - Contract Documentation & ABI Generation

**Day 1 (Monday, 2 hours):**
- [ ] Add NatSpec comments to all contracts
- [ ] Generate documentation: `npx hardhat dodoc`

**Day 2 (Tuesday, 2 hours):**
- [ ] Export ABIs for frontend:
  ```bash
  cp artifacts/contracts/VaultToken.sol/VaultToken.json ../digitalvault-mobile/assets/abis/
  cp artifacts/contracts/ContentRegistry.sol/ContentRegistry.json ../digitalvault-mobile/assets/abis/
  # ... all contracts
  ```
- [ ] Generate TypeScript types: `npx hardhat typechain`

**Day 3-5 (Wednesday-Friday, 6 hours):**
- [ ] Create interaction examples for each contract
- [ ] Write deployment guide
- [ ] Update `digitalvault-contracts/README.md` with:
  - Deployed addresses
  - How to interact examples
  - Testing guide
- [ ] **PHASE 1 COMPLETE** ✅

**Phase 1 Deliverables:**
- ✅ 11 fully tested smart contracts
- ✅ >90% test coverage
- ✅ Deployed to Base Sepolia testnet
- ✅ Verified on Basescan
- ✅ ABIs exported for frontend
- ✅ Complete documentation

---

## 📅 PHASE 2: Backend Services (Weeks 8-13)
**Time: 60 hours** | **Goal: 6 production-ready backend services**

### Week 8 (10 hours) - PRE Proxy Network Service

**Day 1 (Monday, 2 hours):**
```bash
cd digitalvault-backend/services
mkdir pre-proxy-network && cd pre-proxy-network
npm init -y
npm install express cors dotenv pg redis @aspect-build/umbral-pre
npm install --save-dev nodemon jest supertest
```

**File structure:**
```
pre-proxy-network/
├── src/
│   ├── index.js              # Express app entry
│   ├── routes/
│   │   └── kfrags.js         # API routes
│   ├── controllers/
│   │   └── kfragController.js
│   ├── services/
│   │   └── umbralService.js   # WASM Umbral wrapper
│   ├── db/
│   │   └── schema.sql         # PostgreSQL schema
│   └── middleware/
│       └── auth.js            # Signature verification
├── tests/
│   └── kfrags.test.js
├── .env.example
└── package.json
```

**Day 2 (Tuesday, 2 hours):**
```sql
-- File: src/db/schema.sql
CREATE TABLE kfrag_grants (
  content_id BIGINT PRIMARY KEY,
  seller_address VARCHAR(42) NOT NULL,
  buyer_address VARCHAR(42) NOT NULL,
  kfrag_hash VARCHAR(66) NOT NULL,
  threshold INTEGER NOT NULL DEFAULT 2,
  total_shares INTEGER NOT NULL DEFAULT 3,
  created_at TIMESTAMP DEFAULT NOW(),
  expires_at TIMESTAMP,
  is_used BOOLEAN DEFAULT false,
  blockchain_tx_hash VARCHAR(66)
);

CREATE TABLE kfrags (
  id SERIAL PRIMARY KEY,
  content_id BIGINT REFERENCES kfrag_grants(content_id),
  node_id INTEGER NOT NULL,
  kfrag_data BYTEA NOT NULL,
  signature BYTEA,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_kfrags_content ON kfrags(content_id);
CREATE INDEX idx_grants_buyer ON kfrag_grants(buyer_address);
CREATE INDEX idx_grants_seller ON kfrag_grants(seller_address);
```

**Day 3 (Wednesday, 2 hours):**
```javascript
// File: src/services/umbralService.js
const umbral = require('@aspect-build/umbral-pre');

class UmbralService {
  constructor() {
    // Initialize WASM module
    this.umbral = umbral;
  }

  // Perform re-encryption with a single kfrag
  async reencrypt(capsule, kfrag) {
    try {
      const cfrag = this.umbral.reencrypt(capsule, kfrag);
      return cfrag;
    } catch (error) {
      throw new Error(`Re-encryption failed: ${error.message}`);
    }
  }

  // Verify kfrag is valid
  verifyKfrag(kfrag, verifyingKey) {
    return this.umbral.verifyKfrag(kfrag, verifyingKey);
  }
}

module.exports = new UmbralService();
```

**Day 4 (Thursday, 2 hours):**
```javascript
// File: src/routes/kfrags.js
const express = require('express');
const router = express.Router();
const kfragController = require('../controllers/kfragController');
const { verifySeller } = require('../middleware/auth');

// Store kfrags from seller
router.post('/kfrags', verifySeller, kfragController.storeKfrags);

// Perform re-encryption for buyer
router.post('/reencrypt', kfragController.reencrypt);

// Get kfrag status
router.get('/kfrags/:contentId', kfragController.getStatus);

// Delete used kfrags (cleanup)
router.delete('/kfrags/:contentId', kfragController.deleteKfrags);

module.exports = router;
```

**Day 5 (Friday, 2 hours):**
```javascript
// File: src/controllers/kfragController.js
const db = require('../db');
const umbralService = require('../services/umbralService');

exports.storeKfrags = async (req, res) => {
  const { contentId, kfrags, kfragHash, threshold, totalShares } = req.body;
  const sellerAddress = req.user.address; // From auth middleware

  try {
    // Store grant metadata
    await db.query(`
      INSERT INTO kfrag_grants (content_id, seller_address, kfrag_hash, threshold, total_shares)
      VALUES ($1, $2, $3, $4, $5)
    `, [contentId, sellerAddress, kfragHash, threshold, totalShares]);

    // Store individual kfrags (3 nodes)
    for (let i = 0; i < kfrags.length; i++) {
      await db.query(`
        INSERT INTO kfrags (content_id, node_id, kfrag_data)
        VALUES ($1, $2, $3)
      `, [contentId, i + 1, kfrags[i]]);
    }

    res.json({ success: true, message: 'Kfrags stored successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.reencrypt = async (req, res) => {
  const { contentId, capsule } = req.body;

  try {
    // Get 2 out of 3 kfrags (threshold)
    const result = await db.query(`
      SELECT kfrag_data FROM kfrags
      WHERE content_id = $1
      LIMIT 2
    `, [contentId]);

    if (result.rows.length < 2) {
      return res.status(404).json({ error: 'Insufficient kfrags found' });
    }

    // Perform re-encryption with each kfrag
    const cfrags = [];
    for (const row of result.rows) {
      const cfrag = await umbralService.reencrypt(capsule, row.kfrag_data);
      cfrags.push(cfrag);
    }

    res.json({ cfrags });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getStatus = async (req, res) => {
  const { contentId } = req.params;
  const result = await db.query(`
    SELECT * FROM kfrag_grants WHERE content_id = $1
  `, [contentId]);
  res.json(result.rows[0] || null);
};

exports.deleteKfrags = async (req, res) => {
  const { contentId } = req.params;
  await db.query(`DELETE FROM kfrags WHERE content_id = $1`, [contentId]);
  await db.query(`DELETE FROM kfrag_grants WHERE content_id = $1`, [contentId]);
  res.json({ success: true });
};
```

**Weekend:**
- [ ] Write tests for all endpoints
- [ ] Test with mock Umbral data
- [ ] **Commit: "feat: add PRE Proxy Network service"**

---

### Week 9 (10 hours) - Capsule Store Service

**Day 1 (Monday, 2 hours):**
```bash
cd digitalvault-backend/services
mkdir capsule-store && cd capsule-store
npm init -y
npm install express cors dotenv pg ipfs-http-client
npm install --save-dev nodemon jest supertest
```

**Day 2 (Tuesday, 2 hours):**
```sql
-- File: src/db/schema.sql
CREATE TABLE capsules (
  capsule_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  content_id BIGINT NOT NULL,
  owner_address VARCHAR(42) NOT NULL,
  ipfs_cid VARCHAR(100) NOT NULL,
  capsule_hash VARCHAR(66) NOT NULL,
  version INTEGER DEFAULT 1,
  created_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_capsules_content ON capsules(content_id);
CREATE INDEX idx_capsules_owner ON capsules(owner_address);
CREATE INDEX idx_capsules_version ON capsules(content_id, version);
```

**Day 3 (Wednesday, 2 hours):**
```javascript
// File: src/services/ipfsService.js
const { create } = require('ipfs-http-client');

class IPFSService {
  constructor() {
    this.client = create({
      host: 'ipfs.infura.io',
      port: 5001,
      protocol: 'https',
      headers: {
        authorization: `Basic ${Buffer.from(
          process.env.INFURA_PROJECT_ID + ':' + process.env.INFURA_API_SECRET
        ).toString('base64')}`
      }
    });
  }

  async uploadCapsule(capsuleData) {
    const result = await this.client.add(capsuleData);
    return result.cid.toString();
  }

  async getCapsule(cid) {
    const chunks = [];
    for await (const chunk of this.client.cat(cid)) {
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  }
}

module.exports = new IPFSService();
```

**Day 4 (Thursday, 2 hours):**
```javascript
// File: src/controllers/capsuleController.js
const db = require('../db');
const ipfsService = require('../services/ipfsService');
const crypto = require('crypto');

exports.storeCapsule = async (req, res) => {
  const { contentId, capsuleData, ownerAddress } = req.body;

  try {
    // Upload to IPFS
    const ipfsCid = await ipfsService.uploadCapsule(capsuleData);

    // Calculate hash
    const capsuleHash = '0x' + crypto.createHash('sha256').update(capsuleData).digest('hex');

    // Store metadata in DB
    const result = await db.query(`
      INSERT INTO capsules (content_id, owner_address, ipfs_cid, capsule_hash)
      VALUES ($1, $2, $3, $4)
      RETURNING capsule_id, ipfs_cid, capsule_hash
    `, [contentId, ownerAddress, ipfsCid, capsuleHash]);

    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getCapsule = async (req, res) => {
  const { contentId } = req.params;

  try {
    // Get latest capsule for content
    const result = await db.query(`
      SELECT * FROM capsules
      WHERE content_id = $1
      ORDER BY version DESC
      LIMIT 1
    `, [contentId]);

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Capsule not found' });
    }

    const capsule = result.rows[0];

    // Fetch from IPFS
    const capsuleData = await ipfsService.getCapsule(capsule.ipfs_cid);

    res.json({
      ...capsule,
      data: capsuleData.toString('base64')
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.storeReencryptedCapsule = async (req, res) => {
  const { contentId } = req.params;
  const { capsuleData, newOwnerAddress } = req.body;

  try {
    // Get current version
    const current = await db.query(`
      SELECT version FROM capsules WHERE content_id = $1 ORDER BY version DESC LIMIT 1
    `, [contentId]);

    const newVersion = (current.rows[0]?.version || 0) + 1;

    // Upload new capsule to IPFS
    const ipfsCid = await ipfsService.uploadCapsule(capsuleData);
    const capsuleHash = '0x' + crypto.createHash('sha256').update(capsuleData).digest('hex');

    // Store new version
    const result = await db.query(`
      INSERT INTO capsules (content_id, owner_address, ipfs_cid, capsule_hash, version)
      VALUES ($1, $2, $3, $4, $5)
      RETURNING *
    `, [contentId, newOwnerAddress, ipfsCid, capsuleHash, newVersion]);

    res.json(result.rows[0]);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
};

exports.getCapsuleVersions = async (req, res) => {
  const { contentId } = req.params;

  const result = await db.query(`
    SELECT capsule_id, version, owner_address, capsule_hash, created_at
    FROM capsules
    WHERE content_id = $1
    ORDER BY version DESC
  `, [contentId]);

  res.json(result.rows);
};
```

**Day 5 (Friday, 2 hours):**
```javascript
// File: src/routes/capsules.js
const express = require('express');
const router = express.Router();
const capsuleController = require('../controllers/capsuleController');

router.post('/capsules', capsuleController.storeCapsule);
router.get('/capsules/:contentId', capsuleController.getCapsule);
router.post('/capsules/:contentId/reencrypted', capsuleController.storeReencryptedCapsule);
router.get('/capsules/:contentId/versions', capsuleController.getCapsuleVersions);

module.exports = router;
```

**Weekend:**
- [ ] Write integration tests
- [ ] Test with real IPFS (Infura)
- [ ] **Commit: "feat: add Capsule Store service"**

---

### Week 10 (10 hours) - Update Existing Backend Services

**Day 1-2 (Monday-Tuesday, 4 hours):**
**Update IPFS Gateway (port 3000)**
```javascript
// File: services/ipfs-gateway/src/controllers/uploadController.js
// ADD PRE-aware upload handling

exports.uploadWithPRE = async (req, res) => {
  const { encryptedContent, contentType } = req.body;

  // Upload encrypted content to IPFS
  const contentCid = await ipfs.add(encryptedContent);

  // Return CID - capsule will be uploaded separately to Capsule Store
  res.json({
    contentCid: contentCid.cid.toString(),
    message: 'Upload capsule to Capsule Store separately'
  });
};
```

**Day 3-4 (Wednesday-Thursday, 4 hours):**
**Update Metadata Indexer (port 3001)**
```javascript
// File: services/metadata-indexer/src/indexers/contentIndexer.js
// ADD listening for new events from ReKeyRegistry

async function indexReKeyGrantCreated(event) {
  const { contentId, seller, buyer, kfragHash } = event.returnValues;

  await db.query(`
    INSERT INTO rekey_grants (content_id, seller, buyer, kfrag_hash, tx_hash, created_at)
    VALUES ($1, $2, $3, $4, $5, NOW())
  `, [contentId, seller, buyer, kfragHash, event.transactionHash]);
}

// Subscribe to ReKeyRegistry events
reKeyRegistryContract.events.GrantCreated()
  .on('data', indexReKeyGrantCreated)
  .on('error', console.error);
```

**Day 5 (Friday, 2 hours):**
**API Endpoint Updates**
```javascript
// File: services/metadata-indexer/src/routes/contents.js
// ADD PRE-specific endpoints

router.get('/api/contents/:id/capsule', async (req, res) => {
  const result = await db.query(`
    SELECT capsule_hash, owner_public_key, capsule_version
    FROM contents
    WHERE content_id = $1
  `, [req.params.id]);

  res.json(result.rows[0]);
});

router.get('/api/contents/:id/rekey-status', async (req, res) => {
  const result = await db.query(`
    SELECT * FROM rekey_grants
    WHERE content_id = $1 AND is_used = false
    ORDER BY created_at DESC
    LIMIT 1
  `, [req.params.id]);

  res.json(result.rows[0] || { hasActiveGrant: false });
});
```

---

### Week 11 (10 hours) - Backend Integration & Testing

**Day 1 (Monday, 2 hours):**
**Docker Compose setup**
```yaml
# File: digitalvault-backend/docker-compose.yml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_DB: digitalvault
      POSTGRES_USER: vault
      POSTGRES_PASSWORD: vault123
    ports:
      - "5432:5432"
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  ipfs-gateway:
    build: ./services/ipfs-gateway
    ports:
      - "3000:3000"
    depends_on:
      - postgres
    environment:
      DATABASE_URL: postgresql://vault:vault123@postgres:5432/digitalvault

  metadata-indexer:
    build: ./services/metadata-indexer
    ports:
      - "3001:3001"
    depends_on:
      - postgres

  storage-coordinator:
    build: ./services/storage-coordinator
    ports:
      - "3002:3002"

  notification-service:
    build: ./services/notification-service
    ports:
      - "3003:3003"

  pre-proxy-network:
    build: ./services/pre-proxy-network
    ports:
      - "3004:3004"
    depends_on:
      - postgres
      - redis

  capsule-store:
    build: ./services/capsule-store
    ports:
      - "3005:3005"
    depends_on:
      - postgres

volumes:
  postgres_data:
```

**Day 2 (Tuesday, 2 hours):**
- [ ] Test each service individually
- [ ] `docker-compose up ipfs-gateway` → curl test
- [ ] `docker-compose up pre-proxy-network` → curl test
- [ ] `docker-compose up capsule-store` → curl test

**Day 3 (Wednesday, 2 hours):**
**Integration tests**
```javascript
// File: digitalvault-backend/tests/integration/pre-flow.test.js
describe('Complete PRE Flow', () => {
  it('should upload content with capsule and retrieve', async () => {
    // 1. Upload encrypted content to IPFS Gateway
    const contentRes = await request('http://localhost:3000')
      .post('/api/ipfs/upload')
      .send({ encryptedContent: 'test data' });

    // 2. Upload capsule to Capsule Store
    const capsuleRes = await request('http://localhost:3005')
      .post('/api/capsules')
      .send({
        contentId: 1,
        capsuleData: 'mock capsule',
        ownerAddress: '0x123...'
      });

    // 3. Verify capsule stored
    expect(capsuleRes.body.ipfs_cid).toBeDefined();

    // 4. Retrieve capsule
    const retrieveRes = await request('http://localhost:3005')
      .get('/api/capsules/1');

    expect(retrieveRes.body.data).toBeDefined();
  });

  it('should perform re-encryption flow', async () => {
    // 1. Store kfrags
    await request('http://localhost:3004')
      .post('/api/kfrags')
      .send({
        contentId: 1,
        kfrags: ['kfrag1', 'kfrag2', 'kfrag3'],
        kfragHash: '0xabc...',
        threshold: 2,
        totalShares: 3
      });

    // 2. Request re-encryption
    const reencryptRes = await request('http://localhost:3004')
      .post('/api/reencrypt')
      .send({
        contentId: 1,
        capsule: 'original capsule'
      });

    expect(reencryptRes.body.cfrags).toHaveLength(2);
  });
});
```

**Day 4-5 (Thursday-Friday, 4 hours):**
- [ ] Run all backend tests
- [ ] Fix integration issues
- [ ] Performance testing (load test with Artillery)
- [ ] Documentation updates
- [ ] **Commit: "feat: complete backend integration"**

---

### Week 12-13 (20 hours) - Backend Monitoring & Production Prep

**Week 12:**
- [ ] Add logging (Winston/Pino)
- [ ] Add health check endpoints for each service
- [ ] Add Prometheus metrics
- [ ] Set up error tracking (Sentry)
- [ ] Create deployment scripts

**Week 13:**
- [ ] Write API documentation (Swagger/OpenAPI)
- [ ] Create Postman collection for all endpoints
- [ ] Performance optimization
- [ ] Security review (helmet, rate limiting, CORS)
- [ ] **PHASE 2 COMPLETE** ✅

**Phase 2 Deliverables:**
- ✅ 6 production-ready backend services
- ✅ PRE Proxy Network operational
- ✅ Capsule Store operational
- ✅ Docker Compose for local development
- ✅ Complete API documentation
- ✅ Integration tests passing

---

## 📅 PHASE 3: Flutter Mobile App Core (Weeks 14-21)
**Time: 80 hours** | **Goal: Wallet + Content + PRE encryption**

### Week 14 (10 hours) - Rust FFI for PRE

**Day 1 (Monday, 2 hours):**
```bash
cd digitalvault-mobile
mkdir -p native/umbral_ffi
cd native/umbral_ffi
cargo init --lib
```

```toml
# Cargo.toml
[package]
name = "umbral_ffi"
version = "0.1.0"
edition = "2021"

[lib]
crate-type = ["cdylib", "staticlib"]

[dependencies]
umbral-pre = "0.11"
rand = "0.8"
```

**Day 2-3 (Tuesday-Wednesday, 4 hours):**
```rust
// File: native/umbral_ffi/src/lib.rs
use umbral_pre::*;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;

#[repr(C)]
pub struct KeyPair {
    pub secret_key: *mut c_char,
    pub public_key: *mut c_char,
}

#[no_mangle]
pub extern "C" fn umbral_generate_keypair() -> KeyPair {
    let sk = SecretKey::random();
    let pk = PublicKey::from(&sk);

    KeyPair {
        secret_key: CString::new(sk.to_bytes().to_vec()).unwrap().into_raw(),
        public_key: CString::new(pk.to_bytes().to_vec()).unwrap().into_raw(),
    }
}

#[no_mangle]
pub extern "C" fn umbral_encrypt(
    plaintext: *const c_char,
    public_key: *const c_char,
) -> *mut c_char {
    let plaintext = unsafe { CStr::from_ptr(plaintext).to_bytes() };
    let pk_bytes = unsafe { CStr::from_ptr(public_key).to_bytes() };
    let pk = PublicKey::from_bytes(pk_bytes).unwrap();

    let (capsule, ciphertext) = encrypt(&pk, plaintext).unwrap();

    // Serialize capsule + ciphertext
    let result = format!("{}|{}",
        hex::encode(capsule.to_bytes()),
        hex::encode(ciphertext)
    );

    CString::new(result).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn umbral_generate_kfrags(
    secret_key: *const c_char,
    public_key_bob: *const c_char,
    threshold: u8,
    shares: u8,
) -> *mut c_char {
    let sk_bytes = unsafe { CStr::from_ptr(secret_key).to_bytes() };
    let pk_bob_bytes = unsafe { CStr::from_ptr(public_key_bob).to_bytes() };

    let sk = SecretKey::from_bytes(sk_bytes).unwrap();
    let pk_bob = PublicKey::from_bytes(pk_bob_bytes).unwrap();

    let kfrags = generate_kfrags(&sk, &pk_bob, &Signer::new(&sk), threshold, shares);

    // Serialize kfrags
    let kfrags_hex: Vec<String> = kfrags.iter()
        .map(|kf| hex::encode(kf.to_bytes()))
        .collect();

    CString::new(kfrags_hex.join(",")).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn umbral_reencrypt(
    capsule: *const c_char,
    kfrag: *const c_char,
) -> *mut c_char {
    let capsule_hex = unsafe { CStr::from_ptr(capsule).to_str().unwrap() };
    let kfrag_hex = unsafe { CStr::from_ptr(kfrag).to_str().unwrap() };

    let capsule = Capsule::from_bytes(&hex::decode(capsule_hex).unwrap()).unwrap();
    let kfrag = KeyFrag::from_bytes(&hex::decode(kfrag_hex).unwrap()).unwrap();

    let cfrag = reencrypt(&capsule, &kfrag);

    CString::new(hex::encode(cfrag.to_bytes())).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn umbral_decrypt_original(
    secret_key: *const c_char,
    capsule: *const c_char,
    ciphertext: *const c_char,
) -> *mut c_char {
    let sk_bytes = unsafe { CStr::from_ptr(secret_key).to_bytes() };
    let capsule_hex = unsafe { CStr::from_ptr(capsule).to_str().unwrap() };
    let ciphertext_hex = unsafe { CStr::from_ptr(ciphertext).to_str().unwrap() };

    let sk = SecretKey::from_bytes(sk_bytes).unwrap();
    let capsule = Capsule::from_bytes(&hex::decode(capsule_hex).unwrap()).unwrap();
    let ciphertext = hex::decode(ciphertext_hex).unwrap();

    let plaintext = decrypt_original(&sk, &capsule, &ciphertext).unwrap();

    CString::new(plaintext).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn umbral_decrypt_reencrypted(
    secret_key: *const c_char,
    public_key_alice: *const c_char,
    capsule: *const c_char,
    cfrags: *const c_char,
    ciphertext: *const c_char,
) -> *mut c_char {
    let sk_bytes = unsafe { CStr::from_ptr(secret_key).to_bytes() };
    let pk_alice_bytes = unsafe { CStr::from_ptr(public_key_alice).to_bytes() };
    let capsule_hex = unsafe { CStr::from_ptr(capsule).to_str().unwrap() };
    let cfrags_hex = unsafe { CStr::from_ptr(cfrags).to_str().unwrap() };
    let ciphertext_hex = unsafe { CStr::from_ptr(ciphertext).to_str().unwrap() };

    let sk = SecretKey::from_bytes(sk_bytes).unwrap();
    let pk_alice = PublicKey::from_bytes(pk_alice_bytes).unwrap();
    let capsule = Capsule::from_bytes(&hex::decode(capsule_hex).unwrap()).unwrap();
    let ciphertext = hex::decode(ciphertext_hex).unwrap();

    // Parse cfrags (comma-separated)
    let cfrags: Vec<CapsuleFrag> = cfrags_hex.split(',')
        .map(|hex| CapsuleFrag::from_bytes(&hex::decode(hex).unwrap()).unwrap())
        .collect();

    let plaintext = decrypt_reencrypted(
        &sk,
        &pk_alice,
        &capsule,
        &cfrags,
        &ciphertext
    ).unwrap();

    CString::new(plaintext).unwrap().into_raw()
}

#[no_mangle]
pub extern "C" fn umbral_free_string(s: *mut c_char) {
    if !s.is_null() {
        unsafe { CString::from_raw(s) };
    }
}
```

**Day 4 (Thursday, 2 hours):**
**Build for Android**
```bash
# Install cross-compilation targets
rustup target add aarch64-linux-android
rustup target add armv7-linux-androideabi
rustup target add i686-linux-android
rustup target add x86_64-linux-android

# Install cargo-ndk
cargo install cargo-ndk

# Build
cargo ndk -t arm64-v8a -t armeabi-v7a -t x86 -t x86_64 -o ../android/src/main/jniLibs build --release
```

**Day 5 (Friday, 2 hours):**
**Build for iOS**
```bash
# Install targets
rustup target add aarch64-apple-ios
rustup target add x86_64-apple-ios

# Build
cargo build --target aarch64-apple-ios --release
cargo build --target x86_64-apple-ios --release

# Create universal binary
lipo -create \
  target/aarch64-apple-ios/release/libumbral_ffi.a \
  target/x86_64-apple-ios/release/libumbral_ffi.a \
  -output ../ios/libumbral_ffi.a
```

---

### Week 15 (10 hours) - Dart FFI Bindings

**Day 1-2 (Monday-Tuesday, 4 hours):**
```dart
// File: lib/core/crypto/umbral_bindings.dart
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// Load native library
final DynamicLibrary _lib = Platform.isAndroid
    ? DynamicLibrary.open('libumbral_ffi.so')
    : DynamicLibrary.process();

// Define C struct for KeyPair
class KeyPair extends Struct {
  external Pointer<Utf8> secretKey;
  external Pointer<Utf8> publicKey;
}

// Define FFI functions
final Pointer<KeyPair> Function() _generateKeyPair = _lib
    .lookup<NativeFunction<Pointer<KeyPair> Function()>>('umbral_generate_keypair')
    .asFunction();

final Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>) _encrypt = _lib
    .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)>>('umbral_encrypt')
    .asFunction();

final Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, int, int) _generateKfrags = _lib
    .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Uint8, Uint8)>>('umbral_generate_kfrags')
    .asFunction();

final Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>) _reencrypt = _lib
    .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)>>('umbral_reencrypt')
    .asFunction();

final Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>) _decryptOriginal = _lib
    .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>>('umbral_decrypt_original')
    .asFunction();

final Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>) _decryptReencrypted = _lib
    .lookup<NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>)>>('umbral_decrypt_reencrypted')
    .asFunction();

final void Function(Pointer<Utf8>) _freeString = _lib
    .lookup<NativeFunction<Void Function(Pointer<Utf8>)>>('umbral_free_string')
    .asFunction();

// Dart wrapper class
class UmbralBindings {
  static (String secretKey, String publicKey) generateKeyPair() {
    final keyPairPtr = _generateKeyPair();
    final keyPair = keyPairPtr.ref;

    final sk = keyPair.secretKey.toDartString();
    final pk = keyPair.publicKey.toDartString();

    // Free memory
    _freeString(keyPair.secretKey);
    _freeString(keyPair.publicKey);

    return (sk, pk);
  }

  static String encrypt(String plaintext, String publicKey) {
    final plaintextPtr = plaintext.toNativeUtf8();
    final pkPtr = publicKey.toNativeUtf8();

    final resultPtr = _encrypt(plaintextPtr, pkPtr);
    final result = resultPtr.toDartString();

    calloc.free(plaintextPtr);
    calloc.free(pkPtr);
    _freeString(resultPtr);

    return result;
  }

  static List<String> generateKfrags(
    String secretKey,
    String publicKeyBob,
    int threshold,
    int shares,
  ) {
    final skPtr = secretKey.toNativeUtf8();
    final pkBobPtr = publicKeyBob.toNativeUtf8();

    final resultPtr = _generateKfrags(skPtr, pkBobPtr, threshold, shares);
    final result = resultPtr.toDartString();

    calloc.free(skPtr);
    calloc.free(pkBobPtr);
    _freeString(resultPtr);

    return result.split(',');
  }

  static String reencrypt(String capsule, String kfrag) {
    final capsulePtr = capsule.toNativeUtf8();
    final kfragPtr = kfrag.toNativeUtf8();

    final resultPtr = _reencrypt(capsulePtr, kfragPtr);
    final result = resultPtr.toDartString();

    calloc.free(capsulePtr);
    calloc.free(kfragPtr);
    _freeString(resultPtr);

    return result;
  }

  static String decryptOriginal(
    String secretKey,
    String capsule,
    String ciphertext,
  ) {
    final skPtr = secretKey.toNativeUtf8();
    final capsulePtr = capsule.toNativeUtf8();
    final ctPtr = ciphertext.toNativeUtf8();

    final resultPtr = _decryptOriginal(skPtr, capsulePtr, ctPtr);
    final result = resultPtr.toDartString();

    calloc.free(skPtr);
    calloc.free(capsulePtr);
    calloc.free(ctPtr);
    _freeString(resultPtr);

    return result;
  }

  static String decryptReencrypted(
    String secretKey,
    String publicKeyAlice,
    String capsule,
    List<String> cfrags,
    String ciphertext,
  ) {
    final skPtr = secretKey.toNativeUtf8();
    final pkAlicePtr = publicKeyAlice.toNativeUtf8();
    final capsulePtr = capsule.toNativeUtf8();
    final cfragsPtr = cfrags.join(',').toNativeUtf8();
    final ctPtr = ciphertext.toNativeUtf8();

    final resultPtr = _decryptReencrypted(skPtr, pkAlicePtr, capsulePtr, cfragsPtr, ctPtr);
    final result = resultPtr.toDartString();

    calloc.free(skPtr);
    calloc.free(pkAlicePtr);
    calloc.free(capsulePtr);
    calloc.free(cfragsPtr);
    calloc.free(ctPtr);
    _freeString(resultPtr);

    return result;
  }
}
```

**Day 3-5 (Wednesday-Friday, 6 hours):**
```dart
// File: lib/core/crypto/pre_service.dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:bip32/bip32.dart' as bip32;
import 'umbral_bindings.dart';

class PREService {
  final _storage = const FlutterSecureStorage();

  // Generate PRE keypair from wallet seed
  Future<(String secretKey, String publicKey)> generateKeyPairFromSeed(String mnemonic) async {
    // Derive from BIP-32 path: m/44'/60'/0'/1/0 (different from wallet key)
    final seed = bip39.mnemonicToSeed(mnemonic);
    final root = bip32.BIP32.fromSeed(seed);
    final child = root.derivePath("m/44'/60'/0'/1/0");

    // Use child private key as seed for PRE key generation
    final preKeyPair = UmbralBindings.generateKeyPair();

    // Store public key only (never store private key)
    await _storage.write(key: 'pre_public_key', value: preKeyPair.$2);

    return preKeyPair;
  }

  // Encrypt content and create capsule
  Future<Map<String, dynamic>> encryptContent(
    String contentKey, // AES-256 key (32 bytes hex)
    String ownerPublicKey,
  ) async {
    // Encrypt the AES key with PRE
    final result = UmbralBindings.encrypt(contentKey, ownerPublicKey);

    // Parse result: "capsule_hex|ciphertext_hex"
    final parts = result.split('|');

    return {
      'capsule': parts[0],
      'encryptedKey': parts[1],
    };
  }

  // Decrypt as owner
  Future<String> decryptAsOwner(
    String secretKey,
    String capsule,
    String encryptedKey,
  ) async {
    final contentKey = UmbralBindings.decryptOriginal(
      secretKey,
      capsule,
      encryptedKey,
    );
    return contentKey;
  }

  // Generate re-encryption key fragments for transfer
  Future<List<String>> generateReEncryptionKeyFragments(
    String sellerSecretKey,
    String buyerPublicKey, {
    int threshold = 2,
    int shares = 3,
  }) async {
    final kfrags = UmbralBindings.generateKfrags(
      sellerSecretKey,
      buyerPublicKey,
      threshold,
      shares,
    );
    return kfrags;
  }

  // Decrypt re-encrypted content (as buyer)
  Future<String> decryptReEncrypted(
    String buyerSecretKey,
    String sellerPublicKey,
    String capsule,
    List<String> cfrags,
    String encryptedKey,
  ) async {
    final contentKey = UmbralBindings.decryptReencrypted(
      buyerSecretKey,
      sellerPublicKey,
      capsule,
      cfrags,
      encryptedKey,
    );
    return contentKey;
  }
}
```

**Weekend:**
- [ ] Write unit tests for PREService
- [ ] Test on Android emulator
- [ ] Test on iOS simulator
- [ ] **Commit: "feat: add PRE FFI and Dart service"**

---

### Week 16 (10 hours) - Wallet Implementation

**Day 1-2 (Monday-Tuesday, 4 hours):**
```dart
// File: lib/features/wallet/services/wallet_service.dart
import 'package:web3dart/web3dart.dart';
import 'package:bip39/bip39.dart' as bip39;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class WalletService {
  final _storage = const FlutterSecureStorage();
  Web3Client? _client;
  Credentials? _credentials;

  Future<void> initialize(String rpcUrl) async {
    _client = Web3Client(rpcUrl, Client());
  }

  // Create new wallet
  Future<String> createWallet() async {
    final mnemonic = bip39.generateMnemonic();
    await _storage.write(key: 'mnemonic', value: mnemonic);

    _credentials = EthPrivateKey.fromHex(
      bip39.mnemonicToSeedHex(mnemonic).substring(0, 64)
    );

    return mnemonic;
  }

  // Import wallet from mnemonic
  Future<void> importWallet(String mnemonic) async {
    if (!bip39.validateMnemonic(mnemonic)) {
      throw Exception('Invalid mnemonic');
    }

    await _storage.write(key: 'mnemonic', value: mnemonic);

    _credentials = EthPrivateKey.fromHex(
      bip39.mnemonicToSeedHex(mnemonic).substring(0, 64)
    );
  }

  // Get address
  Future<String> getAddress() async {
    if (_credentials == null) {
      final mnemonic = await _storage.read(key: 'mnemonic');
      if (mnemonic != null) {
        await importWallet(mnemonic);
      } else {
        throw Exception('No wallet found');
      }
    }

    final address = await _credentials!.extractAddress();
    return address.hex;
  }

  // Get balance
  Future<EtherAmount> getBalance() async {
    final address = await _credentials!.extractAddress();
    return await _client!.getBalance(address);
  }

  // Send transaction
  Future<String> sendTransaction({
    required String to,
    required BigInt value,
    BigInt? gasPrice,
    int? gasLimit,
  }) async {
    final txHash = await _client!.sendTransaction(
      _credentials!,
      Transaction(
        to: EthereumAddress.fromHex(to),
        value: EtherAmount.inWei(value),
        gasPrice: gasPrice != null ? EtherAmount.inWei(gasPrice) : null,
        maxGas: gasLimit,
      ),
      chainId: 84532, // Base Sepolia
    );

    return txHash;
  }
}
```

**Day 3-5 (Wednesday-Friday, 6 hours):**
**Create wallet UI screens**
```dart
// File: lib/features/wallet/presentation/pages/create_wallet_page.dart
import 'package:flutter/material.dart';

class CreateWalletPage extends StatefulWidget {
  @override
  State<CreateWalletPage> createState() => _CreateWalletPageState();
}

class _CreateWalletPageState extends State<CreateWalletPage> {
  String? _mnemonic;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    if (_mnemonic == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Create Wallet')),
        body: Center(
          child: ElevatedButton(
            onPressed: _generateMnemonic,
            child: Text('Generate Seed Phrase'),
          ),
        ),
      );
    }

    if (!_confirmed) {
      return Scaffold(
        appBar: AppBar(title: Text('Save Seed Phrase')),
        body: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Write down these 12 words in order:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              _buildMnemonicGrid(),
              SizedBox(height: 20),
              Text(
                '⚠️ Never share this with anyone!',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
              Spacer(),
              ElevatedButton(
                onPressed: () => setState(() => _confirmed = true),
                child: Text('I have written it down'),
              ),
            ],
          ),
        ),
      );
    }

    return _VerifySeedPhrasePage(
      mnemonic: _mnemonic!,
      onVerified: () {
        // Save wallet and navigate to home
      },
    );
  }

  Future<void> _generateMnemonic() async {
    final walletService = context.read<WalletService>();
    final mnemonic = await walletService.createWallet();
    setState(() => _mnemonic = mnemonic);
  }

  Widget _buildMnemonicGrid() {
    final words = _mnemonic!.split(' ');
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 3,
      ),
      itemCount: words.length,
      itemBuilder: (context, index) {
        return Card(
          child: Center(
            child: Text(
              '${index + 1}. ${words[index]}',
              style: TextStyle(fontSize: 14),
            ),
          ),
        );
      },
    );
  }
}
```

---

### Week 17 (10 hours) - Content Upload with PRE

*Due to length constraints, I'll provide a detailed checklist for remaining weeks:*

**Files to create:**
- `lib/features/content/services/content_upload_service.dart`
- `lib/features/content/services/symmetric_crypto.dart`
- `lib/features/content/presentation/pages/upload_page.dart`

**Implementation:**
- [ ] Generate random AES-256 key
- [ ] Encrypt content with AES-GCM
- [ ] Encrypt AES key with PRE → create capsule
- [ ] Upload encrypted content to IPFS
- [ ] Upload capsule to Capsule Store
- [ ] Register on ContentRegistry smart contract

---

### Week 18-19 (20 hours) - Portfolio & Content Viewing

**Features:**
- [ ] Fetch user's content from Metadata Indexer
- [ ] Display content cards with thumbnails
- [ ] View content detail page
- [ ] Decrypt capsule with owner's PRE key
- [ ] Decrypt content with AES key
- [ ] Display decrypted content

---

### Week 20-21 (20 hours) - Social Sharing & Rewards

**Features:**
- [ ] Generate watermarked previews
- [ ] Share to Instagram/Twitter
- [ ] Claim staking rewards
- [ ] Display earnings analytics

**PHASE 3 COMPLETE** ✅

---

## 📅 PHASE 4: Marketplace & DAO (Weeks 22-25)
**Time: 40 hours** | **Goal: Full trading + governance**

### Week 22-23 (20 hours) - Marketplace with PRE Transfer

**Complete purchase flow:**
1. Buyer initiates purchase → includes PRE public key
2. Payment locked in escrow
3. Seller approves → generates kfrags
4. Seller distributes kfrags to proxy network
5. Buyer requests re-encryption
6. Proxies return cfrags (2-of-3)
7. Buyer combines cfrags → new capsule
8. Buyer uploads new capsule
9. Payment released to seller
10. Transfer complete ✓

**Files to create:**
- `lib/features/marketplace/services/marketplace_service.dart`
- `lib/features/marketplace/services/pre_transfer_service.dart`
- `lib/features/marketplace/presentation/pages/browse_page.dart`
- `lib/features/marketplace/presentation/pages/purchase_page.dart`
- `lib/features/marketplace/presentation/widgets/approve_purchase_dialog.dart`

---

### Week 24-25 (20 hours) - DAO Governance UI

**Enhanced DAO Features:**

#### 1. **Proposal Browsing**
```dart
// Display all proposals with filters
- Active proposals
- Closed proposals
- My proposals
- By type (Parameter Change, Treasury, Emergency, etc.)
```

#### 2. **Proposal Detail Page**
```dart
- Title and full description
- Proposer address
- Proposal type badge
- Current vote counts (For, Against, Abstain)
- Voting deadline countdown
- Discussion link (opens in browser)
- "Vote" button (if active)
- Execution status (if passed)
```

#### 3. **Create Proposal Screen**
```dart
class CreateProposalPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Proposal')),
      body: Form(
        child: Column(
          children: [
            // Proposal type selector
            DropdownButton<ProposalType>(
              items: [
                DropdownMenuItem(value: ProposalType.PARAMETER_CHANGE, child: Text('Parameter Change')),
                DropdownMenuItem(value: ProposalType.TREASURY_SPEND, child: Text('Treasury Spend')),
                DropdownMenuItem(value: ProposalType.EMERGENCY_ACTION, child: Text('Emergency Action')),
                DropdownMenuItem(value: ProposalType.PROTOCOL_UPGRADE, child: Text('Protocol Upgrade')),
                DropdownMenuItem(value: ProposalType.PARTNERSHIP, child: Text('Partnership')),
              ],
            ),

            // Title field
            TextFormField(
              decoration: InputDecoration(labelText: 'Proposal Title'),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),

            // Description field (markdown supported)
            TextFormField(
              decoration: InputDecoration(labelText: 'Description'),
              maxLines: 10,
            ),

            // Discussion URL (optional)
            TextFormField(
              decoration: InputDecoration(labelText: 'Discussion URL'),
            ),

            // For TREASURY_SPEND: recipient address and amount
            if (selectedType == ProposalType.TREASURY_SPEND) ...[
              TextFormField(
                decoration: InputDecoration(labelText: 'Recipient Address'),
              ),
              TextFormField(
                decoration: InputDecoration(labelText: 'Amount (VLTC)'),
                keyboardType: TextInputType.number,
              ),
            ],

            // Submit button
            ElevatedButton(
              onPressed: _submitProposal,
              child: Text('Submit Proposal'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitProposal() async {
    final daoService = context.read<DAOService>();

    // Encode proposal actions
    final targets = []; // Contract addresses to call
    final values = [];  // ETH values to send
    final calldatas = []; // Encoded function calls

    if (selectedType == ProposalType.TREASURY_SPEND) {
      targets.add(vaultTokenAddress);
      values.add(BigInt.zero);
      calldatas.add(
        // Encode transfer(recipient, amount)
        transferFunction.encodeCall([recipientAddress, amount])
      );
    }

    // Submit to smart contract
    await daoService.proposeWithMetadata(
      targets: targets,
      values: values,
      calldatas: calldatas,
      description: description,
      proposalType: selectedType,
      title: title,
      discussionUrl: discussionUrl,
    );
  }
}
```

#### 4. **Voting Interface**
```dart
class VotingDialog extends StatelessWidget {
  final Proposal proposal;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Cast Your Vote'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Voting power: ${userVotingPower} VLTC'),
          SizedBox(height: 20),

          // Vote options
          ElevatedButton(
            onPressed: () => _vote(VoteType.FOR),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: Text('✓ Vote FOR'),
          ),
          ElevatedButton(
            onPressed: () => _vote(VoteType.AGAINST),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('✗ Vote AGAINST'),
          ),
          ElevatedButton(
            onPressed: () => _vote(VoteType.ABSTAIN),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey),
            child: Text('○ Abstain'),
          ),

          SizedBox(height: 20),

          // Optional: add reason
          TextField(
            decoration: InputDecoration(
              labelText: 'Reason (optional)',
              hintText: 'Explain your vote...',
            ),
            maxLines: 3,
            onChanged: (v) => reason = v,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
      ],
    );
  }

  Future<void> _vote(VoteType vote) async {
    final daoService = context.read<DAOService>();

    if (reason.isNotEmpty) {
      await daoService.castVoteWithReason(
        proposalId: proposal.id,
        support: vote.index,
        reason: reason,
      );
    } else {
      await daoService.castVote(
        proposalId: proposal.id,
        support: vote.index,
      );
    }

    Navigator.pop(context);
    // Show success message
  }
}
```

#### 5. **Delegation Page**
```dart
class DelegationPage extends StatefulWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Delegate Voting Power')),
      body: Column(
        children: [
          // Your voting power
          Card(
            child: ListTile(
              title: Text('Your Voting Power'),
              trailing: Text('${userVotingPower} VLTC'),
            ),
          ),

          // Current delegate (if any)
          if (currentDelegate != null)
            Card(
              child: ListTile(
                title: Text('Delegated to'),
                subtitle: Text(currentDelegate!),
                trailing: IconButton(
                  icon: Icon(Icons.cancel),
                  onPressed: _removeDelegate,
                ),
              ),
            ),

          SizedBox(height: 20),

          // Delegate to address
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Delegate Address',
                    hintText: '0x...',
                  ),
                  controller: _addressController,
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _delegate,
                  child: Text('Delegate'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _delegate() async {
    final daoService = context.read<DAOService>();
    await daoService.delegate(_addressController.text);
    // Refresh state
  }
}
```

#### 6. **Vote History**
```dart
class VoteHistoryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Vote History')),
      body: FutureBuilder<List<VoteRecord>>(
        future: daoService.getVoteHistory(userAddress),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return CircularProgressIndicator();

          final votes = snapshot.data!;

          return ListView.builder(
            itemCount: votes.length,
            itemBuilder: (context, index) {
              final vote = votes[index];
              return Card(
                child: ListTile(
                  title: Text(vote.proposalTitle),
                  subtitle: Text(
                    'Voted ${vote.support == 0 ? "AGAINST" : vote.support == 1 ? "FOR" : "ABSTAIN"} • ${vote.weight} VLTC',
                  ),
                  trailing: Text(_formatDate(vote.timestamp)),
                  onTap: () {
                    // Navigate to proposal detail
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
```

#### 7. **Treasury Dashboard**
```dart
class TreasuryPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('DAO Treasury')),
      body: Column(
        children: [
          // Treasury balance
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  Text('Treasury Balance', style: TextStyle(fontSize: 18)),
                  SizedBox(height: 10),
                  Text(
                    '${treasuryBalance} VLTC',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '≈ \$${treasuryUsdValue}',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),

          // Recent treasury transactions
          Expanded(
            child: ListView.builder(
              itemCount: treasuryTxs.length,
              itemBuilder: (context, index) {
                final tx = treasuryTxs[index];
                return ListTile(
                  leading: Icon(
                    tx.type == 'IN' ? Icons.arrow_downward : Icons.arrow_upward,
                    color: tx.type == 'IN' ? Colors.green : Colors.red,
                  ),
                  title: Text(tx.description),
                  subtitle: Text(_formatDate(tx.timestamp)),
                  trailing: Text('${tx.amount} VLTC'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
```

**DAOService Implementation:**
```dart
// File: lib/features/dao/services/dao_service.dart
import 'package:web3dart/web3dart.dart';

class DAOService {
  final Web3Client client;
  final DeployedContract governorContract;

  // Fetch all proposals
  Future<List<Proposal>> getProposals({ProposalFilter? filter}) async {
    // Query blockchain or indexer API
    // Return list of proposals
  }

  // Get proposal detail
  Future<Proposal> getProposal(BigInt proposalId) async {
    // Fetch from contract
  }

  // Create proposal with metadata
  Future<String> proposeWithMetadata({
    required List<String> targets,
    required List<BigInt> values,
    required List<String> calldatas,
    required String description,
    required ProposalType proposalType,
    required String title,
    String? discussionUrl,
  }) async {
    final function = governorContract.function('proposeWithMetadata');

    final txHash = await client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: governorContract,
        function: function,
        parameters: [targets, values, calldatas, description, proposalType.index, title, discussionUrl ?? ''],
      ),
      chainId: 84532,
    );

    return txHash;
  }

  // Cast vote
  Future<String> castVote({
    required BigInt proposalId,
    required int support, // 0 = Against, 1 = For, 2 = Abstain
  }) async {
    final function = governorContract.function('castVote');

    final txHash = await client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: governorContract,
        function: function,
        parameters: [proposalId, support],
      ),
      chainId: 84532,
    );

    return txHash;
  }

  // Cast vote with reason
  Future<String> castVoteWithReason({
    required BigInt proposalId,
    required int support,
    required String reason,
  }) async {
    final function = governorContract.function('castVoteWithReason');

    final txHash = await client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: governorContract,
        function: function,
        parameters: [proposalId, support, reason],
      ),
      chainId: 84532,
    );

    return txHash;
  }

  // Delegate voting power
  Future<String> delegate(String delegatee) async {
    final function = governorContract.function('delegate');

    final txHash = await client.sendTransaction(
      credentials,
      Transaction.callContract(
        contract: governorContract,
        function: function,
        parameters: [EthereumAddress.fromHex(delegatee)],
      ),
      chainId: 84532,
    );

    return txHash;
  }

  // Get voting power
  Future<BigInt> getVotingPower(String address) async {
    final function = governorContract.function('getVotingPower');

    final result = await client.call(
      contract: governorContract,
      function: function,
      params: [EthereumAddress.fromHex(address)],
    );

    return result[0] as BigInt;
  }

  // Get vote history
  Future<List<VoteRecord>> getVoteHistory(String address) async {
    // Query from indexer API or parse events
  }

  // Execute proposal (after it passes)
  Future<String> executeProposal(BigInt proposalId) async {
    final function = governorContract.function('execute');
    // ... implementation
  }
}
```

**PHASE 4 COMPLETE** ✅

---

## 📅 PHASE 5: Testing & Launch (Week 26)
**Time: 10 hours** | **Goal: Production deployment**

### Day 1-2 (Monday-Tuesday, 4 hours) - Integration Testing
- [ ] End-to-end test: wallet → upload → sell → transfer
- [ ] Test DAO flow: create proposal → vote → execute
- [ ] Test all error scenarios
- [ ] Fix critical bugs

### Day 3 (Wednesday, 2 hours) - Performance & Security
- [ ] App performance profiling
- [ ] Check for memory leaks
- [ ] Security review (private key handling)
- [ ] Penetration testing

### Day 4 (Thursday, 2 hours) - Deployment Prep
- [ ] Update all environment variables for production
- [ ] Deploy backend services to AWS/GCP
- [ ] Point mobile app to production backend
- [ ] Create production builds (Android APK + iOS IPA)

### Day 5 (Friday, 2 hours) - Launch! 🚀
- [ ] Deploy smart contracts to Base Mainnet
- [ ] Publish app to Google Play (internal testing)
- [ ] Publish app to TestFlight (iOS beta)
- [ ] Create launch announcement
- [ ] Monitor for issues

**LAUNCH COMPLETE** 🎉

---

## 📊 Weekly Schedule Template

**Monday (2 hours):**
- 7:00-9:00 PM or your preferred time
- Focus: Smart contracts or new features

**Tuesday (2 hours):**
- 7:00-9:00 PM
- Focus: Backend services

**Wednesday (2 hours):**
- 7:00-9:00 PM
- Focus: Mobile UI implementation

**Thursday (2 hours):**
- 7:00-9:00 PM
- Focus: Testing & integration

**Friday (2 hours):**
- 7:00-9:00 PM
- Focus: Bug fixes & documentation

**Weekend (Optional):**
- Catch-up or learning time
- Research new features
- Code review

---

## 🎯 Success Metrics (Month 6)

### Technical Milestones
- ✅ 11 smart contracts deployed to Base Mainnet
- ✅ 6 backend services in production
- ✅ Mobile app published (TestFlight/Internal Testing)
- ✅ >90% test coverage on smart contracts
- ✅ <2 second app load time
- ✅ <$0.01 average transaction cost on Base L2

### Feature Completeness
- ✅ Wallet (create, import, connect)
- ✅ Content upload with PRE encryption
- ✅ Content viewing (decrypt)
- ✅ Marketplace (browse, purchase)
- ✅ PRE-based ownership transfer
- ✅ DAO governance (propose, vote, delegate)
- ✅ Rewards (claim, stake)
- ✅ Social sharing

### User Experience
- ✅ Onboarding flow <3 minutes
- ✅ Content upload <30 seconds
- ✅ Ownership transfer <1 minute
- ✅ Intuitive UI/UX (no blockchain jargon)
- ✅ Works offline (view cached content)

---

## 📝 Daily Development Log Template

Create a file: `dev-journal.md`

```markdown
# Dev Journal

## Week 1

### Monday, Jan 15
**Time:** 2 hours
**Tasks:**
- [x] Installed Rust and Cargo
- [x] Set up Flutter SDK
- [x] Verified hardhat compilation
**Blockers:** None
**Tomorrow:** Set up PostgreSQL and backend services

### Tuesday, Jan 16
**Time:** 2 hours
**Tasks:**
- [x] Set up PostgreSQL docker
- [ ] IPFS Gateway test (failed - API key issue)
**Blockers:** Pinata API key not working
**Tomorrow:** Fix Pinata key, test IPFS upload

... continue for each day
```

---

## 🚨 Risk Management

### Common Blockers & Solutions

| Blocker | Solution |
|---------|----------|
| **Rust FFI build fails** | Check NDK path, update Cargo.toml, use exact toolchain versions |
| **Flutter hot reload stops working** | Run `flutter clean && flutter pub get` |
| **Smart contract gas too high** | Use `uint128` instead of `uint256`, pack structs, use `calldata` |
| **Backend 500 errors** | Check PostgreSQL connection, verify environment variables |
| **App crashes on real device** | Check Logcat (Android) or Xcode console (iOS), enable debugging |
| **PRE encryption fails** | Verify native library loaded, check FFI bindings, test with mock data first |
| **Transaction fails on testnet** | Check gas limit, verify contract address, ensure sufficient test ETH |
| **DAO proposal creation fails** | Verify voting power > threshold, check proposal parameters |

### When You're Stuck (>30 min)
1. **Read error messages carefully** - often they tell you exactly what's wrong
2. **Google the exact error** - someone has probably solved it
3. **Check official docs** - Hardhat, Flutter, Umbral docs
4. **Ask ChatGPT/Claude** - paste error + context
5. **Take a break** - fresh eyes find bugs faster
6. **Skip it temporarily** - move to next task, come back tomorrow

---

## 🎓 Learning Resources

### Week-by-Week Learning

**Weeks 1-7 (Smart Contracts):**
- Hardhat docs: https://hardhat.org/docs
- OpenZeppelin contracts: https://docs.openzeppelin.com/contracts
- Solidity by example: https://solidity-by-example.org/

**Weeks 8-13 (Backend):**
- Express.js guide: https://expressjs.com/en/guide/routing.html
- PostgreSQL tutorial: https://www.postgresql.org/docs/
- Umbral PRE spec: https://github.com/nucypher/umbral-doc

**Weeks 14-21 (Mobile):**
- Flutter docs: https://docs.flutter.dev/
- Rust FFI guide: https://doc.rust-lang.org/nomicon/ffi.html
- web3dart: https://pub.dev/packages/web3dart

**Weeks 22-26 (Integration):**
- Base L2 docs: https://docs.base.org/
- React to issues as they arise

---

## 🏆 Celebration Checkpoints

### Week 7
🎉 **Smart Contracts Complete!**
- Reward: Take weekend off OR start learning Flutter early

### Week 13
🎉 **Backend Complete!**
- Reward: Order pizza, watch crypto documentary

### Week 21
🎉 **Core App Done!**
- Reward: Show friends/family the demo

### Week 26
🚀 **FULL LAUNCH!**
- Reward: You built a complete DApp in 6 months! Celebrate big! 🍾

---

## 📞 Support & Community

**When you need help:**
- Base Discord: https://discord.gg/base
- Flutter Discord: https://discord.gg/flutter
- Stack Overflow (tag: solidity, flutter, rust)
- GitHub issues on respective repos

**Stay motivated:**
- Share progress on Twitter/X
- Join Web3 builder communities
- Document your journey (blog/vlog)

---

## ✅ Pre-Flight Checklist (Week 0)

Before starting Week 1:
- [ ] All development tools installed
- [ ] GitHub account created
- [ ] Daily dev journal template ready
- [ ] 2-hour time block scheduled Mon-Fri
- [ ] Backup strategy in place (GitHub + local)
- [ ] Understand the full architecture (read all docs)
- [ ] Realistic expectations set (6 months is tight but doable)
- [ ] Support system informed (family/roommates know you're busy evenings)

---

**You've got this! 💪**

From zero to deployed DApp in 26 weeks, 2 hours at a time. The key is consistency—show up every night, make progress, and don't skip days. Good luck! 🚀
