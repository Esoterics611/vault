# PRE Proxy Network - Architecture Design

**Service:** PRE Proxy Network
**Week:** 8-9
**Purpose:** Proxy re-encryption service for secure content ownership transfer

---

## Overview

The PRE Proxy Network enables secure content ownership transfer without exposing plaintext content keys. This service handles:
1. Capsule storage (encrypted content keys)
2. Re-encryption operations (transform capsules for new owners)
3. On-chain grant verification (ensure authorized transfers)
4. Threshold cryptography (M-of-N proxy signatures)

---

## Architecture Decision: Single Proxy (MVP)

**Decision:** Start with a single proxy service, designed for future multi-proxy expansion.

### Why Single Proxy for MVP?
1. **Faster Development:** 2 weeks vs 6+ weeks
2. **Simpler Testing:** Easier to validate functionality
3. **Lower Complexity:** No consensus/coordination needed
4. **Sufficient Security:** Testnet validation phase
5. **Easy Migration:** Architecture supports adding proxies later

### Multi-Proxy Future Design:
```
                    ┌─────────────────┐
                    │   Marketplace   │
                    └────────┬────────┘
                             │
                    ┌────────▼────────┐
                    │  Proxy Gateway  │ (Distributes requests)
                    └────────┬────────┘
                             │
          ┌──────────────────┼──────────────────┐
          │                  │                  │
    ┌─────▼──────┐    ┌─────▼──────┐    ┌─────▼──────┐
    │  Proxy 1   │    │  Proxy 2   │    │  Proxy 3   │
    │  (2-of-3)  │    │  (2-of-3)  │    │  (2-of-3)  │
    └────────────┘    └────────────┘    └────────────┘
```

**For Week 8 MVP:**
```
    ┌─────────────────┐
    │   Marketplace   │
    └────────┬────────┘
             │
    ┌────────▼────────┐
    │  Single Proxy   │
    │   (Threshold    │
    │    capable)     │
    └─────────────────┘
```

---

## Technology Stack

### Core Dependencies
- **Node.js** - Runtime environment
- **Express** - REST API framework
- **PostgreSQL** - Capsule & metadata storage
- **Ethers.js** - Blockchain interaction
- **Umbral (WASM)** - PRE cryptography library

### Umbral Integration Options

**Option A: umbral-pre npm package (RECOMMENDED)**
```javascript
npm install @nucypher/umbral-pre
```
- Pure JavaScript/WASM
- Works in Node.js
- Pre-compiled binaries
- ~2MB package size
- **Tradeoff:** Slightly slower than native

**Option B: Native Rust binding (FUTURE)**
```bash
npm install @nucypher/umbral-pre-node
```
- Native Rust performance
- Requires compilation
- Platform-specific builds
- **Tradeoff:** More complex deployment

**Decision for Week 8:** Use Option A (npm package) for faster development.

---

## Database Schema

### Capsules Table
```sql
CREATE TABLE capsules (
  id SERIAL PRIMARY KEY,
  content_id INTEGER NOT NULL UNIQUE,
  owner_address VARCHAR(42) NOT NULL,
  capsule_data BYTEA NOT NULL,
  capsule_hash VARCHAR(66) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  accessed_at TIMESTAMP,
  access_count INTEGER DEFAULT 0,
  INDEX idx_content_id (content_id),
  INDEX idx_owner (owner_address)
);
```

### Re-encryption Requests Table
```sql
CREATE TABLE reencryption_requests (
  id SERIAL PRIMARY KEY,
  content_id INTEGER NOT NULL,
  from_address VARCHAR(42) NOT NULL,
  to_address VARCHAR(42) NOT NULL,
  grant_id INTEGER,
  kfrag_hash VARCHAR(66),
  status VARCHAR(20) DEFAULT 'pending',
  created_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP,
  error_message TEXT,
  INDEX idx_content_id (content_id),
  INDEX idx_status (status)
);
```

---

## API Endpoints

### 1. Store Capsule
```http
POST /api/proxy/capsules
Content-Type: application/json

{
  "contentId": 1,
  "ownerAddress": "0x...",
  "capsuleData": "0x...",  // hex-encoded capsule
  "capsuleHash": "0x...",
  "signature": "0x..."     // owner signature for verification
}

Response 201:
{
  "success": true,
  "contentId": 1,
  "capsuleHash": "0x...",
  "stored": true
}
```

**Security:**
- Verify signature matches ownerAddress
- Check content exists on-chain
- Validate capsule format
- Rate limit: 100 uploads/day per address

### 2. Get Capsule
```http
GET /api/proxy/capsules/:contentId/:ownerAddress

Response 200:
{
  "success": true,
  "contentId": 1,
  "ownerAddress": "0x...",
  "capsuleData": "0x...",
  "capsuleHash": "0x..."
}
```

**Security:**
- Public endpoint (capsules are encrypted anyway)
- Rate limit: 1000 requests/day per IP
- Log all accesses for monitoring

### 3. Request Re-encryption
```http
POST /api/proxy/reencrypt
Content-Type: application/json

{
  "contentId": 1,
  "fromAddress": "0x...",   // current owner
  "toAddress": "0x...",     // new owner
  "kfragHash": "0x...",     // from on-chain grant
  "threshold": 2,
  "totalShares": 3,
  "signature": "0x..."      // marketplace signature
}

Response 200:
{
  "success": true,
  "contentId": 1,
  "newCapsuleData": "0x...",
  "newCapsuleHash": "0x...",
  "cfrags": ["0x...", "0x..."]  // threshold fragments
}
```

**Security:**
- Verify grant exists on-chain (ReKeyRegistry.verifyGrant)
- Check grant is active and not expired
- Verify marketplace signature
- Rate limit: 50 re-encryptions/day per address
- Log all re-encryption operations

### 4. Health Check
```http
GET /api/proxy/health

Response 200:
{
  "status": "healthy",
  "service": "pre-proxy",
  "version": "1.0.0",
  "uptime": 3600,
  "database": "connected",
  "blockchain": "connected"
}
```

---

## Security Model

### Threat Model

**What the Proxy CAN do:**
- Store encrypted capsules
- Transform capsules for authorized recipients
- See metadata (content IDs, addresses, timestamps)

**What the Proxy CANNOT do:**
- Read plaintext content (capsules are encrypted)
- Decrypt content keys
- Transfer ownership without on-chain grant
- Re-encrypt for unauthorized recipients

### Attack Vectors & Mitigations

**1. Unauthorized Re-encryption**
- **Attack:** Request re-encryption without valid grant
- **Mitigation:** Verify grant on-chain before re-encrypting

**2. Replay Attacks**
- **Attack:** Reuse old re-encryption requests
- **Mitigation:** Check grant.isUsed status on-chain

**3. DOS Attacks**
- **Attack:** Flood service with requests
- **Mitigation:** Rate limiting (express-rate-limit)

**4. Data Tampering**
- **Attack:** Modify stored capsules
- **Mitigation:** Store capsule hash, verify before serving

**5. Signature Forgery**
- **Attack:** Fake owner signatures
- **Mitigation:** Verify signatures using ethers.js

---

## On-Chain Integration

### Contract Interactions

**ReKeyRegistry (Read)**
```javascript
// Verify grant exists and is valid
const grant = await reKeyRegistry.verifyGrant(contentId);
// Check:
// - grant.contentId != 0
// - grant.isActive == true
// - grant.isUsed == false
// - grant.expiresAt > now
// - grant.kfragHash == requestedHash
```

**ContentRegistry (Read)**
```javascript
// Verify content exists
const content = await contentRegistry.getContentInfo(contentId);
// Check:
// - content.usesPRE == true
// - content.isActive == true
// - content.owner == fromAddress
```

### Blockchain Connection

**RPC Endpoint:** Base Sepolia (testnet)
```
https://sepolia.base.org
```

**Contracts:** Use deployed addresses from Week 7
```javascript
const CONTRACTS = {
  ContentRegistry: "0xd469e2AA709bb01ab409eBb762c655FC641C41f0",
  ReKeyRegistry: "0xBC835256b0D08DFeD09c7cE3B07eD945C6e243aA"
};
```

---

## Umbral PRE Operations

### 1. Generate KFrags (Off-chain - done by seller)
```javascript
const umbral = require('@nucypher/umbral-pre');

// Seller generates re-encryption key fragments
const sellerSecretKey = umbral.SecretKey.fromBytes(sellerSK);
const buyerPublicKey = umbral.PublicKey.fromBytes(buyerPK);

const kfrags = umbral.generateKFrags(
  sellerSecretKey,
  buyerPublicKey,
  2, // threshold
  3, // total shares
  true, // sign fragments
  true  // prove correctness
);

// Hash kfrags for on-chain verification
const kfragHash = ethers.keccak256(
  ethers.concat(kfrags.map(k => k.toBytes()))
);
```

### 2. Re-encrypt Capsule (Proxy operation)
```javascript
// Proxy transforms capsule
const capsule = umbral.Capsule.fromBytes(capsuleData);
const kfrag = umbral.KeyFrag.fromBytes(kfragData);

const cfrag = umbral.reencrypt(capsule, kfrag);

// Return cfrag to buyer
return cfrag.toBytes();
```

### 3. Decrypt (Buyer operation - off-chain)
```javascript
// Buyer combines cfrags and decrypts
const buyerSecretKey = umbral.SecretKey.fromBytes(buyerSK);
const capsule = umbral.Capsule.fromBytes(newCapsuleData);
const cfrags = [cfrag1, cfrag2]; // threshold = 2

const decryptedKey = umbral.decryptReencrypted(
  buyerSecretKey,
  capsule,
  cfrags,
  originalPublicKey
);

// Use decryptedKey to decrypt AES-encrypted content
```

---

## Configuration

### Environment Variables
```bash
# Server
PORT=3001
NODE_ENV=development

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=digitalvault_pre
DB_USER=postgres
DB_PASSWORD=postgres

# Blockchain
RPC_URL=https://sepolia.base.org
CONTENT_REGISTRY=0xd469e2AA709bb01ab409eBb762c655FC641C41f0
REKEY_REGISTRY=0xBC835256b0D08DFeD09c7cE3B07eD945C6e243aA

# Security
RATE_LIMIT_WINDOW=900000  # 15 minutes
RATE_LIMIT_MAX=100        # max requests per window

# Monitoring
LOG_LEVEL=info
```

---

## Error Handling

### Error Codes
```javascript
const ERROR_CODES = {
  INVALID_CAPSULE: { code: 'INVALID_CAPSULE', status: 400 },
  GRANT_NOT_FOUND: { code: 'GRANT_NOT_FOUND', status: 404 },
  GRANT_EXPIRED: { code: 'GRANT_EXPIRED', status: 410 },
  GRANT_USED: { code: 'GRANT_USED', status: 410 },
  UNAUTHORIZED: { code: 'UNAUTHORIZED', status: 401 },
  RATE_LIMIT: { code: 'RATE_LIMIT_EXCEEDED', status: 429 },
  SERVER_ERROR: { code: 'INTERNAL_ERROR', status: 500 }
};
```

---

## Testing Strategy

### Unit Tests
- Capsule storage/retrieval
- Signature verification
- Grant validation logic
- Error handling

### Integration Tests
- End-to-end re-encryption flow
- Blockchain interaction
- Database operations
- Rate limiting

### Load Tests
- 100 concurrent re-encryption requests
- 1000 capsule retrievals/minute
- Database connection pooling

---

## Deployment

### Docker Container
```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production
COPY . .
EXPOSE 3001
CMD ["node", "index.js"]
```

### Docker Compose Integration
```yaml
pre-proxy:
  build: ./services/pre-proxy
  ports:
    - "3001:3001"
  depends_on:
    - postgres
  environment:
    - DB_HOST=postgres
    - RPC_URL=${RPC_URL}
```

---

## Monitoring & Metrics

### Key Metrics
- Capsules stored
- Re-encryptions performed
- Average re-encryption time
- Failed requests (with reasons)
- Active grants verified

### Logging
- Winston for structured logging
- Log levels: error, warn, info, debug
- All re-encryptions logged
- Failed grant verifications logged

---

## Future Enhancements (Post-MVP)

### Multi-Proxy Network
- Proxy discovery protocol
- Consensus mechanism (2-of-3 threshold)
- Proxy reputation system
- Automatic failover

### Performance Optimizations
- Capsule caching (Redis)
- Batch re-encryption
- WebSocket for real-time updates
- CDN for static capsule serving

### Security Enhancements
- Hardware Security Module (HSM) for keys
- Zero-knowledge proofs for privacy
- Proxy rotation for anonymity
- Audit logs for compliance

---

## Week 8-9 Implementation Plan

### Week 8 (Focus: Core Service)
1. ✅ Architecture design (this document)
2. Service structure setup
3. Database schema creation
4. Basic API endpoints
5. Umbral integration
6. Grant verification

### Week 9 (Focus: Testing & Polish)
1. Complete test suite
2. Error handling
3. Rate limiting
4. Docker setup
5. Documentation
6. Load testing

---

**Status:** Architecture Design Complete ✅
**Next:** Implementation (Week 8 Day 2)
**Decision Log:** Single proxy MVP, Umbral npm package, PostgreSQL storage
