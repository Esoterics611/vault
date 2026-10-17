# ReKeyRegistry Smart Contract Documentation

**Contract:** ReKeyRegistry.sol
**Version:** 1.0.0
**Network:** Base L2 (Sepolia Testnet)
**License:** MIT

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Data Structures](#data-structures)
4. [Functions](#functions)
5. [Events](#events)
6. [Access Control](#access-control)
7. [Security](#security)
8. [Integration Guide](#integration-guide)
9. [Examples](#examples)

---

## Overview

### Purpose

ReKeyRegistry manages **Proxy Re-encryption (PRE)** grants for secure content ownership transfer in the DigitalVault ecosystem. It stores cryptographic hashes on-chain while actual re-encryption keys remain off-chain in the PRE Proxy Network.

### Key Features

- ✅ **Grant Management:** Create, verify, use, and revoke re-encryption grants
- ✅ **Expiration Control:** 7-day default expiration (configurable)
- ✅ **Threshold Cryptography:** Support for M-of-N schemes (e.g., 2-of-3)
- ✅ **Batch Operations:** Create multiple grants in one transaction
- ✅ **Access Control:** Owner-based permissions via OpenZeppelin
- ✅ **Reentrancy Protection:** Secured with ReentrancyGuard
- ✅ **Event Logging:** Full transparency for off-chain indexing

### PRE Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. SELLER: Creates grant with kfrag hash                    │
│    ├─> Stores: contentId, buyer, kfragHash, threshold      │
│    └─> Emits: GrantCreated event                           │
├─────────────────────────────────────────────────────────────┤
│ 2. PROXY NETWORK: Verifies kfrag hash matches blockchain   │
│    ├─> Calls: verifyKfragHash(contentId, hash)            │
│    └─> Performs re-encryption if valid                     │
├─────────────────────────────────────────────────────────────┤
│ 3. BUYER: Marks grant as used after successful transfer     │
│    ├─> Calls: markGrantUsed(contentId)                     │
│    └─> Grant becomes inactive (one-time use)               │
└─────────────────────────────────────────────────────────────┘
```

---

## Architecture

### Contract Inheritance

```solidity
ReKeyRegistry
    ├─> Ownable (OpenZeppelin)
    └─> ReentrancyGuard (OpenZeppelin)
```

### Storage Layout

```solidity
mapping(uint256 => ReKeyGrant) public grants;              // contentId => grant
mapping(address => uint256[]) private grantsBySeller;      // seller => contentIds
mapping(address => uint256[]) private grantsByBuyer;       // buyer => contentIds
```

### Constants

```solidity
uint256 public constant DEFAULT_EXPIRATION = 7 days;
```

---

## Data Structures

### ReKeyGrant Struct

```solidity
struct ReKeyGrant {
    uint256 contentId;      // Content being transferred
    address seller;         // Original owner creating grant
    address buyer;          // Designated recipient
    bytes32 kfragHash;      // Hash of re-encryption key fragments
    uint8 threshold;        // M in M-of-N threshold (e.g., 2)
    uint8 totalShares;      // N in M-of-N threshold (e.g., 3)
    uint256 createdAt;      // Timestamp of grant creation
    uint256 expiresAt;      // Expiration timestamp
    bool isActive;          // False if revoked
    bool isUsed;            // True after successful transfer
}
```

**Field Descriptions:**

- **contentId:** Unique identifier for the content (from ContentRegistry)
- **seller:** Address of the content owner creating the grant
- **buyer:** Address of the user who can redeem this grant
- **kfragHash:** Keccak256 hash of the re-encryption key fragments
- **threshold:** Minimum number of proxy nodes needed (M in M-of-N)
- **totalShares:** Total number of key fragments generated (N in M-of-N)
- **createdAt:** Block timestamp when grant was created
- **expiresAt:** Timestamp when grant expires (createdAt + 7 days)
- **isActive:** False if seller revoked the grant
- **isUsed:** True after buyer successfully uses the grant

---

## Functions

### Core Functions

#### createGrant

```solidity
function createGrant(
    uint256 _contentId,
    address _buyer,
    bytes32 _kfragHash,
    uint8 _threshold,
    uint8 _totalShares
) external nonReentrant
```

**Description:** Creates a new re-encryption grant.

**Access:** Public (seller)

**Parameters:**
- `_contentId`: Content ID from ContentRegistry
- `_buyer`: Address of the buyer/recipient
- `_kfragHash`: Hash of the re-encryption key fragments
- `_threshold`: M in M-of-N (minimum nodes needed)
- `_totalShares`: N in M-of-N (total fragments)

**Requirements:**
- Grant must not already exist for this contentId
- Buyer address must be valid (not zero address)
- Cannot grant to self
- Kfrag hash must be non-zero
- Threshold must be positive
- Threshold must not exceed totalShares
- TotalShares must not exceed 10

**Emits:** `GrantCreated`

**Example:**
```solidity
reKeyRegistry.createGrant(
    12345,                                           // contentId
    0x1234567890123456789012345678901234567890,     // buyer
    0xabcdef...,                                     // kfragHash
    2,                                               // threshold (2-of-3)
    3                                                // totalShares
);
```

---

#### batchCreateGrants

```solidity
function batchCreateGrants(
    uint256[] calldata _contentIds,
    address[] calldata _buyers,
    bytes32[] calldata _kfragHashes,
    uint8[] calldata _thresholds,
    uint8[] calldata _totalShares
) external nonReentrant
```

**Description:** Creates multiple grants in a single transaction.

**Access:** Public (seller)

**Parameters:** Arrays of grant parameters (all must be same length)

**Requirements:**
- Arrays must not be empty
- Arrays must have matching lengths
- Maximum 50 grants per batch
- Each grant must satisfy `createGrant()` requirements

**Gas Savings:** ~20% for 10+ grants

**Emits:** `GrantCreated` (multiple times)

**Example:**
```solidity
reKeyRegistry.batchCreateGrants(
    [1, 2, 3],                      // contentIds
    [buyer1, buyer2, buyer3],       // buyers
    [hash1, hash2, hash3],          // kfragHashes
    [2, 2, 2],                      // thresholds
    [3, 3, 3]                       // totalShares
);
```

---

#### markGrantUsed

```solidity
function markGrantUsed(uint256 _contentId) external nonReentrant
```

**Description:** Marks a grant as used after successful transfer.

**Access:** Buyer only

**Parameters:**
- `_contentId`: Content ID of the grant

**Requirements:**
- Grant must exist
- Caller must be the buyer
- Grant must be active (not revoked)
- Grant must not be already used
- Grant must not be expired

**Emits:** `GrantUsed`

**Example:**
```solidity
reKeyRegistry.connect(buyer).markGrantUsed(12345);
```

---

#### revokeGrant

```solidity
function revokeGrant(uint256 _contentId) external nonReentrant
```

**Description:** Revokes an unused grant.

**Access:** Seller only

**Parameters:**
- `_contentId`: Content ID of the grant

**Requirements:**
- Grant must exist
- Caller must be the seller
- Grant must be active
- Grant must not be already used

**Emits:** `GrantRevoked`

**Example:**
```solidity
reKeyRegistry.connect(seller).revokeGrant(12345);
```

---

### Query Functions (View)

#### isGrantActive

```solidity
function isGrantActive(uint256 _contentId) external view returns (bool)
```

**Description:** Checks if a grant is currently valid.

**Returns:** True if grant exists, is active, not used, and not expired.

**Gas:** ~3,000 (view function)

---

#### verifyGrant

```solidity
function verifyGrant(uint256 _contentId) external view returns (ReKeyGrant memory)
```

**Description:** Gets complete grant information.

**Returns:** Full ReKeyGrant struct

**Gas:** ~5,000 (view function)

---

#### getGrant

```solidity
function getGrant(uint256 _contentId) external view returns (
    address seller,
    address buyer,
    bytes32 kfragHash,
    uint8 threshold,
    uint8 totalShares,
    uint256 expiresAt,
    bool isActive,
    bool isUsed
)
```

**Description:** Gets grant details as individual fields.

**Returns:** Tuple of grant fields

---

#### getGrantsBySeller

```solidity
function getGrantsByBuyer(address _buyer) external view returns (uint256[] memory)
```

**Description:** Gets all grant IDs for a buyer (including expired/used).

**Returns:** Array of contentIds

---

#### getActiveGrantsByBuyer

```solidity
function getActiveGrantsByBuyer(address _buyer) external view returns (uint256[] memory)
```

**Description:** Gets only active grants for a buyer.

**Returns:** Array of contentIds (filtered for active only)

---

#### getActiveGrantsBySeller

```solidity
function getActiveGrantsBySeller(address _seller) external view returns (uint256[] memory)
```

**Description:** Gets only active grants for a seller.

**Returns:** Array of contentIds (filtered for active only)

---

#### grantExists

```solidity
function grantExists(uint256 _contentId) external view returns (bool)
```

**Description:** Checks if a grant exists.

**Returns:** True if grant exists

---

#### verifyKfragHash

```solidity
function verifyKfragHash(uint256 _contentId, bytes32 _kfragHash) external view returns (bool)
```

**Description:** Verifies if a kfrag hash matches the recorded hash.

**Returns:** True if hash matches

**Use Case:** Proxy network verifies kfrag before re-encryption

---

## Events

### GrantCreated

```solidity
event GrantCreated(
    uint256 indexed contentId,
    address indexed seller,
    address indexed buyer,
    bytes32 kfragHash,
    uint8 threshold,
    uint8 totalShares,
    uint256 expiresAt
);
```

**Emitted:** When a new grant is created

---

### GrantUsed

```solidity
event GrantUsed(
    uint256 indexed contentId,
    address indexed buyer,
    uint256 timestamp
);
```

**Emitted:** When buyer marks grant as used

---

### GrantRevoked

```solidity
event GrantRevoked(
    uint256 indexed contentId,
    address indexed seller,
    uint256 timestamp
);
```

**Emitted:** When seller revokes an unused grant

---

## Access Control

| Function | Access | Modifier |
|----------|--------|----------|
| `createGrant()` | Public | nonReentrant |
| `batchCreateGrants()` | Public | nonReentrant |
| `markGrantUsed()` | Buyer only | nonReentrant |
| `revokeGrant()` | Seller only | nonReentrant |
| All view functions | Public | view |
| Owner functions | Owner only | onlyOwner |

---

## Security

### Protections

1. **Reentrancy Guard:** All state-changing functions protected
2. **Access Control:** Buyer/seller restrictions enforced
3. **One-time Use:** Grants cannot be reused
4. **Expiration:** Automatic 7-day expiration
5. **Validation:** Comprehensive input validation

### Attack Vectors Mitigated

- ✅ **Reentrancy:** ReentrancyGuard on all state changes
- ✅ **Replay:** Grants marked as used after consumption
- ✅ **Unauthorized Access:** Buyer/seller checks
- ✅ **Invalid State:** Validation on all inputs
- ✅ **Duplicate Grants:** Prevents overwriting existing grants

### Audit Status

- ⏳ **Internal Review:** Complete (Week 2)
- ⏳ **External Audit:** Scheduled (Week 6)
- ⏳ **Bug Bounty:** Post-mainnet

---

## Integration Guide

### For Marketplace Contract

```solidity
import "./ReKeyRegistry.sol";

contract Marketplace {
    ReKeyRegistry public reKeyRegistry;

    function purchaseListing(uint256 listingId) external payable {
        // ... marketplace logic ...

        // Create re-encryption grant for buyer
        reKeyRegistry.createGrant(
            contentId,
            msg.sender,  // buyer
            kfragHash,
            2,           // 2-of-3 threshold
            3
        );

        // ... transfer payment ...
    }
}
```

### For PRE Proxy Network (Off-chain)

```javascript
// 1. Listen for GrantCreated events
reKeyRegistry.on("GrantCreated", async (contentId, seller, buyer, kfragHash) => {
    // 2. Verify we have matching kfrags
    const storedKfrags = await kfragStore.get(contentId);
    const computedHash = ethers.keccak256(ethers.concat(storedKfrags));

    if (computedHash !== kfragHash) {
        console.error("Kfrag hash mismatch!");
        return;
    }

    // 3. Perform re-encryption when buyer requests
    const reencryptedCapsule = await performReencryption(
        storedKfrags,
        buyer.publicKey
    );

    // 4. Return reencrypted capsule to buyer
});
```

### For Mobile App (Flutter)

```dart
// Create grant after purchase
await web3Service.createReKeyGrant(
  contentId: 12345,
  buyer: buyerAddress,
  kfragHash: kfragHash,
  threshold: 2,
  totalShares: 3,
);

// Check if grant is active before requesting re-encryption
bool isActive = await web3Service.isGrantActive(contentId);
if (isActive) {
  // Request re-encryption from proxy network
  final capsule = await preService.requestReencryption(contentId);

  // Decrypt with buyer's private key
  final decryptedKey = await preService.decrypt(capsule);

  // Mark grant as used
  await web3Service.markGrantUsed(contentId);
}
```

---

## Examples

### Complete Flow Example

```solidity
// Step 1: Seller creates grant
reKeyRegistry.connect(seller).createGrant(
    123,                // contentId
    buyerAddress,       // buyer
    kfragHash,          // hash of key fragments
    2,                  // 2-of-3 threshold
    3
);

// Step 2: Check grant is active
bool active = await reKeyRegistry.isGrantActive(123);
// Returns: true

// Step 3: Buyer requests re-encryption (off-chain)
// Proxy network verifies kfrag hash
bool hashValid = await reKeyRegistry.verifyKfragHash(123, kfragHash);
// Returns: true

// Step 4: Buyer marks grant as used after successful transfer
reKeyRegistry.connect(buyer).markGrantUsed(123);

// Step 5: Grant is no longer active
bool stillActive = await reKeyRegistry.isGrantActive(123);
// Returns: false (already used)
```

### Batch Grant Example

```solidity
// Seller creates 10 grants in one transaction
uint256[] memory contentIds = new uint256[](10);
address[] memory buyers = new address[](10);
bytes32[] memory kfragHashes = new bytes32[](10);
uint8[] memory thresholds = new uint8[](10);
uint8[] memory totalShares = new uint8[](10);

for (uint256 i = 0; i < 10; i++) {
    contentIds[i] = 1000 + i;
    buyers[i] = buyerAddresses[i];
    kfragHashes[i] = computedHashes[i];
    thresholds[i] = 2;
    totalShares[i] = 3;
}

reKeyRegistry.batchCreateGrants(
    contentIds,
    buyers,
    kfragHashes,
    thresholds,
    totalShares
);
```

---

## Testing

**Test Coverage:** 47/47 tests passing

Run tests:
```bash
npx hardhat test test/ReKeyRegistry.test.js
```

See: [Test Documentation](../test/ReKeyRegistry.test.js)

---

## Deployment

Deploy to testnet:
```bash
npx hardhat run scripts/deploy-rekey-registry.js --network baseSepolia
```

Deploy all contracts:
```bash
npx hardhat run scripts/deploy-all.js --network baseSepolia
```

---

## License

MIT License - See LICENSE file

---

**Document Version:** 1.0.0
**Last Updated:** January 14, 2026
**Next Review:** Week 6 (Integration Testing)
