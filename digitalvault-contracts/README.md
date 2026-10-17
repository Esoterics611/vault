# DigitalVault Smart Contracts

Solidity smart contracts for the DigitalVault decentralized content ownership platform.

## 📦 Contracts

### Core Contracts

1. **VaultToken.sol** - ERC20 utility token (VLTC)
   - Total supply: 1,000,000,000 VLTC
   - Features: Burnable, Pausable, Snapshot, Permit
   - Access control for minting and admin functions

2. **ContentRegistry.sol** - Content ownership registry with PRE
   - Register content with IPFS hashes and PRE capsule hashes
   - Track creators, current owners, and owner PRE public keys
   - Manage access models (Private, Preview, Pay-per-access, For Sale)
   - Support proxy re-encryption for secure ownership transfer
   - View count analytics

3. **ReKeyRegistry.sol** - **NEW** Proxy Re-encryption Key Management
   - Store re-encryption key grants for content transfers
   - Manage threshold cryptography parameters (M-of-N)
   - Verify kfrag hashes for secure re-encryption
   - Track grant lifecycle (active, used, expired)
   - Enable revocable access delegation

4. **Marketplace.sol** - Content trading platform with PRE
   - Full ownership transfers using proxy re-encryption
   - Access key sales with cryptographic guarantees
   - Timed access passes
   - Integrated with ReKeyRegistry for secure transfers
   - Platform fees (2.5%) and creator royalties (5%)

5. **StorageProvider.sol** - Decentralized storage network
   - Provider registration with staking
   - Proof of storage verification
   - Reputation system
   - Reward distribution

6. **RewardDistributor.sol** - Token emission system
   - 4-year emission schedule
   - Liquidity mining rewards (50%)
   - Storage provider rewards (30%)
   - Creator rewards (20%)

### Governance

6. **DAOGovernor.sol** - DAO governance
   - OpenZeppelin Governor-based
   - Voting delay: 1 day
   - Voting period: 7 days
   - Quorum: 4%
   - Timelock: 48 hours

### Supporting Contracts

7. **AccessControl.sol** - Content access management
8. **SocialVerification.sol** - Optional social media linking
9. **PresaleContract.sol** - Token presale with vesting
10. **AirdropDistributor.sol** - Merkle-tree based airdrops

## 🚀 Quick Start

### Installation

```bash
npm install
```

### Compile

```bash
npx hardhat compile
```

### Test

```bash
npx hardhat test
```

### Deploy to Local Network

```bash
# Terminal 1 - Start local node
npx hardhat node

# Terminal 2 - Deploy contracts
npx hardhat run scripts/deploy.js --network localhost
```

### Deploy to Testnet (Base Sepolia)

```bash
# Set environment variables in .env
cp .env.example .env
# Edit .env with your private key and API keys

# Deploy
npx hardhat run scripts/deploy.js --network baseSepolia
```

## 🧪 Testing

Run all tests:
```bash
npx hardhat test
```

Run specific test:
```bash
npx hardhat test test/VaultToken.test.js
```

Check coverage:
```bash
npx hardhat coverage
```

Generate gas report:
```bash
REPORT_GAS=true npx hardhat test
```

## 📊 Token Economics

### Distribution
- **30%** - Presale (300M VLTC)
- **20%** - Airdrops (200M VLTC)
- **30%** - Liquidity Mining (300M VLTC, 4-year emission)
- **10%** - Storage Rewards (100M VLTC, 4-year emission)
- **10%** - Treasury/Team (100M VLTC, 4-year vest)

### Emission Schedule (4 years)
- Year 1: 40% of pool
- Year 2: 30% of pool
- Year 3: 20% of pool
- Year 4: 10% of pool

## 🔐 Security

### Features
- ReentrancyGuard on all state-changing functions
- Pausable emergency stop
- Role-based access control
- OpenZeppelin battle-tested contracts
- Integer overflow protection (Solidity 0.8+)

### Audits
- [ ] Internal audit
- [ ] External audit (CertiK/OpenZeppelin recommended)
- [ ] Bug bounty program on ImmuneFi

## 📝 Contract Interactions

### Register Content
```javascript
const tx = await contentRegistry.registerContent(
  contentHash,      // bytes32 IPFS hash
  metadataHash,     // bytes32 metadata hash
  encryptedKey,     // bytes encrypted AES key
  fileSize,         // uint256 size in bytes
  0,                // ContentType.POETRY
  1                 // AccessModel.PREVIEW_ALLOWED
);
```

### Create Listing
```javascript
const tx = await marketplace.createListing(
  contentId,        // uint256 content ID
  priceInVLTC,      // uint256 price in VLTC
  0,                // ListingType.FULL_OWNERSHIP
  0,                // accessDuration (0 for full ownership)
  1                 // maxKeys (1 for full ownership)
);
```

### Purchase Content
```javascript
// Approve VLTC spending
await vaultToken.approve(marketplaceAddress, price);

// Purchase
await marketplace.purchaseListing(
  listingId,
  newEncryptedKey
);
```

## 🏗️ Architecture

```
┌─────────────────┐
│   VaultToken    │──────┐
└─────────────────┘      │
                         │
┌─────────────────┐      │     ┌──────────────────┐
│ContentRegistry  │      ├────▶│   Marketplace    │
└─────────────────┘      │     └──────────────────┘
                         │
┌─────────────────┐      │
│StorageProvider  │◀─────┤
└─────────────────┘      │
                         │
┌─────────────────┐      │
│RewardDistributor│◀─────┘
└─────────────────┘

         ┌──────────────┐
         │ DAOGovernor  │
         └──────────────┘
                │
         ┌──────▼──────┐
         │  Timelock   │
         └─────────────┘
```

## 🔐 Proxy Re-Encryption (PRE) System

### Architecture Overview

DigitalVault uses **Umbral PRE** (from NuCypher) to enable secure ownership transfers without ever decrypting content:

```
┌─────────────────────────────────────────────────────────────┐
│  CONTENT FLOW WITH PROXY RE-ENCRYPTION                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Alice encrypts content → Capsule_A stored on IPFS      │
│  2. Alice sells to Bob → generates ReKey_A→B               │
│  3. Proxy nodes transform Capsule_A → Capsule_B            │
│  4. Only Bob can decrypt Capsule_B (Alice cannot!)         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Key Contracts for PRE

**ContentRegistry.sol** - Extended with PRE fields:
- `bytes32 capsuleHash` - Hash of encrypted capsule (off-chain storage)
- `bytes ownerPublicKey` - Owner's PRE public key for re-encryption
- `function updateCapsule()` - Update capsule after ownership transfer

**ReKeyRegistry.sol** - NEW contract for re-encryption key management:
- `createGrant()` - Seller creates re-encryption grant for buyer
- `verifyGrant()` - Verify kfrag hash matches blockchain record
- `markGrantUsed()` - Mark grant as consumed after transfer
- `revokeGrant()` - Seller can revoke unused grants

### Data Storage Strategy

| Data Type | Location | Purpose |
|-----------|----------|---------|
| Encrypted Content | IPFS | Immutable, encrypted with AES-256-GCM |
| Content Symmetric Key | Capsule (IPFS) | Encrypted with PRE (Umbral) |
| Capsule Hash | Blockchain | Integrity verification |
| Owner PRE Public Key | Blockchain | Enable re-encryption |
| Re-encryption Key Fragments | Proxy Nodes (Backend) | Transform capsules |

### Security Properties

✅ **Content never decrypted during transfer**
✅ **Proxy nodes cannot read content** (only transform)
✅ **Seller cannot access after transfer** (cryptographic guarantee)
✅ **Threshold scheme** (2-of-3 proxies required)
✅ **True anonymity** - no trusted intermediaries

See `docs/PRE_IMPLEMENTATION_PLAN.md` for complete technical details.

## 🔧 Future Enhancements

### For AI/Developer Reference

#### ContentRegistry Enhancements
- [ ] Add IPFS pinning verification
- [ ] Implement content categories/tags
- [ ] Add content verification badges
- [ ] Support for content collections/series
- [ ] Implement lazy minting for gas optimization
- [x] **Proxy Re-encryption for secure transfers** (See PRE_IMPLEMENTATION_PLAN.md)

#### Marketplace Enhancements
- [ ] Dutch auction support
- [ ] Bundle sales (multiple contents)
- [ ] Subscription models
- [ ] Automatic royalty splits for collaborations
- [ ] Offer/bid system

#### StorageProvider Enhancements
- [ ] Advanced proof-of-storage (Merkle proofs)
- [ ] Geographic redundancy requirements
- [ ] Provider reputation marketplace
- [ ] Automated provider health monitoring
- [ ] Storage capacity marketplace

#### RewardDistributor Enhancements
- [ ] Dynamic reward rates based on TVL
- [ ] Boosted rewards for long-term stakers
- [ ] Gauge voting for reward allocation
- [ ] Creator engagement multipliers
- [ ] Referral reward system

#### Governance Enhancements
- [ ] Snapshot voting for gas-free polls
- [ ] Delegation marketplace
- [ ] Proposal templates
- [ ] Execution simulations
- [ ] Multi-sig proposal sponsors

## 📄 License

MIT

## 🤝 Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Write tests for new features
4. Ensure all tests pass
5. Submit a pull request

## 📞 Support

For questions or issues:
- Open a GitHub issue
- Join our Discord
- Email: dev@digitalvault.app

---
Built with ❤️ for creators
