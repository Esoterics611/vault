# DigitalVault Backend Services

**Status:** ✅ Production-Ready (Week 11 Complete)

Complete backend infrastructure for the DigitalVault decentralized content platform with proxy re-encryption, DAO governance, and IPFS storage.

## 🏗️ Production Architecture (Week 11)

```
                    digitalvault-network
                            │
        ┌───────────────────┼───────────────────┐
        │                   │                   │
┌───────▼────────┐  ┌───────▼────────┐  ┌──────▼─────────┐
│  PRE Proxy     │  │  DAO Service   │  │ IPFS Gateway   │
│  (Week 8-9)    │  │   (Week 9)     │  │  (Week 10)     │
│   Port: 3001   │  │   Port: 3002   │  │   Port: 3000   │
└───────┬────────┘  └───────┬────────┘  └────────┬───────┘
        │                   │                     │
┌───────▼────────┐  ┌───────▼────────┐  ┌────────▼───────┐
│  PostgreSQL    │  │  PostgreSQL    │  │  PostgreSQL    │
│ (pre_db)       │  │  (dao_db)      │  │  (ipfs_db)     │
└────────────────┘  └────────────────┘  └────────────────┘

Legacy Services (--profile legacy):
  - Metadata Indexer, Storage Coordinator, Notification Service
```

## 📦 Production Services (Weeks 8-11)

### 1. PRE Proxy Network (Port 3001) - Week 8-9 ✅

Manages proxy re-encryption for secure content ownership transfers using Umbral PRE.

**Key Features:**
- Distributed key fragment storage (2-of-3 threshold)
- Capsule re-encryption for ownership transfer
- Cannot decrypt content (trustless proxy)
- Blockchain-verified grants
- Auto-cleanup after re-encryption

**Endpoints:**
- `POST /api/proxy/capsules` - Store new capsule
- `POST /api/proxy/reencrypt/:contentId` - Re-encrypt for buyer
- `GET /api/proxy/capsules/:contentId` - Get capsule status
- `GET /api/proxy/stats` - Network statistics
- `GET /api/proxy/health` - Health check

**Tech Stack:** Node.js, Express, PostgreSQL, Umbral WASM, Winston logging

### 2. DAO Governance Service (Port 3002) - Week 9 ✅

Decentralized governance for DigitalVault platform with proposal management and voting.

**Key Features:**
- Proposal lifecycle management
- Vote tracking and execution
- Delegation support
- Quorum and threshold enforcement
- IPFS metadata storage

**Endpoints:**
- `POST /api/dao/proposals` - Create proposal
- `POST /api/dao/vote/:proposalId` - Cast vote
- `GET /api/dao/proposals` - List all proposals
- `GET /api/dao/proposals/:id` - Get proposal details
- `GET /api/dao/stats` - DAO statistics
- `GET /api/dao/health` - Health check

**Tech Stack:** Node.js, Express, PostgreSQL, Web3.js, IPFS integration

### 3. IPFS Gateway v2 (Port 3000) - Week 10 ✅

Production-grade IPFS storage gateway with Pinata integration and comprehensive tracking.

**Key Features:**
- File and JSON uploads to IPFS
- PostgreSQL tracking (uploads, pins, access logs)
- PRE-aware content flagging
- Rate limiting (upload vs retrieval)
- 100MB file size limit
- Pin management and statistics

**Endpoints:**
- `POST /api/ipfs/upload/file` - Upload file
- `POST /api/ipfs/upload/json` - Upload JSON
- `GET /api/ipfs/content/:cid` - Retrieve content
- `GET /api/ipfs/content/:cid/info` - Get metadata
- `GET /api/ipfs/pin/list` - List pins
- `GET /api/ipfs/pin/stats` - Pin statistics
- `DELETE /api/ipfs/pin/:cid` - Unpin content
- `GET /api/ipfs/health` - Health check

**Tech Stack:** Node.js, Express, PostgreSQL, Pinata API, Multer

---

## 📦 Legacy Services (Week 1-6)

### 4. Metadata Indexer (Port 3001 - Legacy)
Indexes blockchain events and provides query API.

**Endpoints:**
- `GET /api/contents` - List contents with filters
- `GET /api/contents/:id` - Get single content
- `GET /api/listings` - List marketplace listings
- `GET /api/transactions/:address` - User transactions
- `GET /api/providers` - List storage providers
- `GET /api/analytics/overview` - Platform analytics

### 2. Metadata Indexer (Port 3001)
Indexes blockchain events and provides query API.

**Endpoints:**
- `GET /api/contents` - List contents with filters
- `GET /api/contents/:id` - Get single content
- `GET /api/listings` - List marketplace listings
- `GET /api/transactions/:address` - User transactions
- `GET /api/providers` - List storage providers
- `GET /api/analytics/overview` - Platform analytics

### 3. Storage Coordinator (Port 3002)
Manages storage provider network and proof-of-storage.

**Features:**
- Assign content to providers
- Verify storage proofs
- Monitor provider health
- Rebalance storage

### 4. Notification Service (Port 3003)
Sends push notifications via Firebase.

**Events:**
- Content purchased
- Listing sold
- Rewards claimed
- Governance proposals

### 5. **NEW: PRE Proxy Network (Port 3004)**
Manages proxy re-encryption for secure ownership transfers.

**Endpoints:**
- `POST /api/kfrags` - Store key fragments from seller
- `POST /api/reencrypt` - Perform re-encryption for buyer
- `GET /api/kfrags/:contentId` - Retrieve kfrag status
- `DELETE /api/kfrags/:contentId` - Remove used kfrags

**Features:**
- Distributed re-encryption key fragment storage (threshold 2-of-3)
- Perform Umbral PRE transformations (capsule re-encryption)
- Verify seller signatures before storing kfrags
- Track re-encryption grants tied to blockchain
- Cannot decrypt content (only transform)

### 6. **NEW: Capsule Store (Port 3005)**
Stores PRE capsules (encrypted content keys) on IPFS.

**Endpoints:**
- `POST /api/capsules` - Store new capsule
- `GET /api/capsules/:contentId` - Retrieve capsule
- `POST /api/capsules/:contentId/reencrypted` - Store re-encrypted capsule
- `GET /api/capsules/:contentId/versions` - Get capsule version history

**Features:**
- Pin PRE capsules to IPFS
- Version capsules on ownership transfer
- Verify capsule integrity with blockchain hashes
- Provide fast retrieval for decryption

## 🚀 Quick Start (Week 11)

### Prerequisites
- Docker 20.10+ and Docker Compose 2.0+
- 4GB RAM minimum (8GB recommended)
- Base Sepolia testnet access
- Pinata API credentials

### One-Command Deployment

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env with your values (RPC_URL, contract addresses, Pinata keys, etc.)

# 2. Start entire backend stack
docker-compose up -d

# 3. Verify all services healthy
docker-compose ps
curl http://localhost:3001/api/proxy/health
curl http://localhost:3002/api/dao/health
curl http://localhost:3000/api/ipfs/health

# 4. Run integration tests
cd test && npm install && npm test
```

### Individual Service Development

```bash
# Start specific service
cd services/pre-proxy && npm install && npm run dev
cd services/dao-service && npm install && npm run dev
cd services/ipfs-gateway && npm install && npm run dev
```

### Legacy Services (Optional)

```bash
# Start with legacy services included
docker-compose --profile legacy up -d
```

## ✅ Week 11: Integration & Testing Complete

### What's New

**Complete Backend Integration:**
- Single `docker-compose up -d` command starts entire stack
- All 3 production services orchestrated
- Separate PostgreSQL databases for service isolation
- Shared `digitalvault-network` for service communication
- Docker health checks on all services

**Comprehensive Test Suite:**
- 50+ integration and E2E tests
- Service health verification
- Database connectivity tests
- Service-to-service communication tests
- Performance benchmarks (<200ms health, <500ms queries)
- Complete workflow testing (PRE sharing, DAO governance)

**Production Documentation:**
- Troubleshooting guide ([TROUBLESHOOTING.md](./TROUBLESHOOTING.md))
- Test documentation ([test/README.md](./test/README.md))

**Running Tests:**
```bash
cd test
npm install
npm test  # Runs all integration, E2E, and performance tests
```

---

## 🔧 Configuration

### Environment Variables

```bash
# IPFS / Pinata
PINATA_API_KEY=your_api_key
PINATA_SECRET_KEY=your_secret_key

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=digitalvault
DB_USER=postgres
DB_PASSWORD=password

# Blockchain
RPC_URL=https://sepolia.base.org
CONTENT_REGISTRY_ADDRESS=0x...
```

See `.env.example` for all variables.

## 📊 Database Schema

### Contents
```sql
CREATE TABLE contents (
  content_id BIGINT PRIMARY KEY,
  content_hash VARCHAR(66),
  metadata_hash VARCHAR(66),
  owner VARCHAR(42),
  creator VARCHAR(42),
  created_at TIMESTAMP,
  file_size BIGINT,
  content_type VARCHAR(20),
  access_model VARCHAR(20),
  view_count INTEGER DEFAULT 0,
  is_active BOOLEAN DEFAULT true
);
```

### Listings
```sql
CREATE TABLE listings (
  listing_id BIGINT PRIMARY KEY,
  content_id BIGINT,
  seller VARCHAR(42),
  price DECIMAL(78,0),
  listing_type VARCHAR(20),
  is_active BOOLEAN DEFAULT true,
  listed_at TIMESTAMP
);
```

### Transactions
```sql
CREATE TABLE transactions (
  tx_hash VARCHAR(66) PRIMARY KEY,
  from_address VARCHAR(42),
  to_address VARCHAR(42),
  content_id BIGINT,
  amount DECIMAL(78,0),
  transaction_type VARCHAR(20),
  timestamp TIMESTAMP,
  status VARCHAR(20)
);
```

### Providers
```sql
CREATE TABLE providers (
  provider_address VARCHAR(42) PRIMARY KEY,
  ipfs_node_id VARCHAR(100),
  staked_amount DECIMAL(78,0),
  storage_capacity BIGINT,
  used_storage BIGINT,
  uptime DECIMAL(10,2),
  reputation_score INTEGER,
  is_active BOOLEAN DEFAULT true
);
```

## 🧪 Testing

```bash
# Run tests
npm test

# Run with coverage
npm test -- --coverage
```

## 📈 Monitoring

### Health Checks
Each service exposes a `/health` endpoint:
- http://localhost:3000/health
- http://localhost:3001/health
- http://localhost:3002/health
- http://localhost:3003/health

### Logs
Services use Winston for structured logging:
```javascript
logger.info('Content uploaded', { cid, size });
logger.error('Upload failed', { error: err.message });
```

## 🔐 Security

### Rate Limiting
- 100 requests per 15 minutes per IP
- Configurable via express-rate-limit

### Input Validation
- Joi schema validation
- express-validator

### File Upload
- Max file size: 100MB
- Encrypted content only
- Multer for multipart handling

## 🚢 Deployment

### Production Checklist
- [ ] Set strong passwords in environment
- [ ] Enable HTTPS/TLS
- [ ] Configure firewall rules
- [ ] Set up monitoring (Datadog, New Relic)
- [ ] Configure log aggregation (ELK stack)
- [ ] Set up database backups
- [ ] Configure CDN for IPFS gateway
- [ ] Enable rate limiting
- [ ] Set up load balancer

### AWS Deployment
```bash
# Build Docker images
docker-compose build

# Tag for ECR
docker tag digitalvault-ipfs-gateway:latest \
  YOUR_ECR_REPO/ipfs-gateway:latest

# Push to ECR
docker push YOUR_ECR_REPO/ipfs-gateway:latest

# Deploy to ECS
aws ecs update-service --cluster digitalvault \
  --service ipfs-gateway --force-new-deployment
```

## 📚 API Documentation

### Upload Content

```bash
curl -X POST http://localhost:3000/api/ipfs/upload \
  -F "file=@encrypted-content.bin" \
  -F 'metadata={"name":"My Poetry","creator":"0x..."}'
```

Response:
```json
{
  "success": true,
  "ipfsHash": "QmX...",
  "size": 123456,
  "timestamp": "2024-01-01T00:00:00Z"
}
```

### Get Contents

```bash
curl http://localhost:3001/api/contents?owner=0x...&limit=10
```

Response:
```json
{
  "success": true,
  "data": [
    {
      "content_id": "1",
      "content_hash": "0x...",
      "owner": "0x...",
      "creator": "0x...",
      "content_type": "POETRY",
      "created_at": "2024-01-01T00:00:00Z"
    }
  ]
}
```

## 🔐 Proxy Re-Encryption Architecture

### System Overview

```
┌──────────────┐       ┌──────────────┐       ┌──────────────┐
│   Seller     │       │ Proxy Nodes  │       │    Buyer     │
│   (Alice)    │       │  (Network)   │       │    (Bob)     │
└──────┬───────┘       └──────┬───────┘       └──────┬───────┘
       │                      │                      │
       │ 1. Generate kfrags   │                      │
       │ ─────────────────────▶                      │
       │    (ReKey_A→B)       │                      │
       │                      │                      │
       │ 2. Distribute kfrags │                      │
       │ ─────────────────────▶                      │
       │    to 3 nodes        │                      │
       │                      │                      │
       │                      │ 3. Request re-encrypt│
       │                      │◀─────────────────────│
       │                      │                      │
       │                      │ 4. Transform capsule │
       │                      │  (2-of-3 nodes)      │
       │                      │ ─────────────────────▶
       │                      │   Return cfrags      │
       │                      │                      │
       │                      │ 5. Decrypt with SK_B │
       │                      │                   ✓  │
```

### PRE Proxy Network Details

**Technology Stack:**
- **Umbral PRE** via WASM (`@aspect-build/umbral-pre`)
- Node.js + Express for API
- PostgreSQL for kfrag metadata
- Redis for rate limiting

**Security Model:**
- Threshold: 2-of-3 proxies required
- Proxies store kfrags but **cannot decrypt**
- Seller signature verification required
- Grant tied to blockchain transaction
- Automatic kfrag deletion after use

**Database Schema:**
```sql
CREATE TABLE kfrag_grants (
  content_id BIGINT PRIMARY KEY,
  seller_address VARCHAR(42),
  buyer_address VARCHAR(42),
  kfrag_hash VARCHAR(66),
  threshold INTEGER,
  total_shares INTEGER,
  created_at TIMESTAMP,
  expires_at TIMESTAMP,
  is_used BOOLEAN DEFAULT false
);

CREATE TABLE kfrags (
  grant_id BIGINT,
  node_id INTEGER,
  kfrag_data BYTEA,
  signature BYTEA
);
```

### Capsule Store Details

**Purpose:** Store PRE capsules (encrypted content keys) with versioning

**Storage Flow:**
1. Capsule uploaded to Capsule Store API
2. Pinned to IPFS via Pinata
3. Hash stored on blockchain (ContentRegistry)
4. Versioned when ownership transfers

**Database Schema:**
```sql
CREATE TABLE capsules (
  capsule_id UUID PRIMARY KEY,
  content_id BIGINT,
  owner_address VARCHAR(42),
  ipfs_cid VARCHAR(100),
  capsule_hash VARCHAR(66),
  version INTEGER,
  created_at TIMESTAMP
);
```

## 🔄 Future Enhancements

### For AI/Developer Reference

#### PRE Proxy Network
- [x] **Basic proxy re-encryption** (MVP: 3 centralized nodes)
- [ ] Decentralized proxy network (incentivized nodes)
- [ ] Proxy reputation system
- [ ] Slashing for malicious proxies
- [ ] Dynamic threshold adjustment
- [ ] Geographic distribution requirements

#### Capsule Store
- [x] **IPFS-based capsule storage**
- [ ] Multi-IPFS provider redundancy
- [ ] Capsule compression
- [ ] Automatic garbage collection
- [ ] Backup to Arweave for permanence

#### IPFS Gateway
- [ ] Multi-provider support (beyond Pinata)
- [ ] Content deduplication
- [ ] Automatic content migration
- [ ] CDN integration (Cloudflare, CloudFront)
- [ ] Content compression
- [ ] Virus scanning integration (ClamAV)

#### Metadata Indexer
- [ ] Full-text search (Elasticsearch)
- [ ] Advanced analytics (engagement metrics)
- [ ] Real-time websocket updates
- [ ] GraphQL API
- [ ] Caching layer (Redis)
- [ ] Database read replicas

#### Storage Coordinator
- [ ] Advanced proof-of-storage (zk-SNARKs)
- [ ] Geographic distribution requirements
- [ ] Automatic failover
- [ ] Provider marketplace
- [ ] Performance benchmarking
- [ ] Automated rebalancing

#### Notification Service
- [ ] Email notifications
- [ ] SMS notifications (Twilio)
- [ ] In-app notification center
- [ ] Notification preferences
- [ ] Batch notifications
- [ ] Notification templates

#### General
- [ ] API versioning
- [ ] OpenAPI/Swagger documentation
- [ ] Service mesh (Istio)
- [ ] Distributed tracing (Jaeger)
- [ ] Metrics (Prometheus)
- [ ] CI/CD pipeline
- [ ] Automated testing
- [ ] Load testing (k6, Artillery)

## 📄 License

MIT

---
Built with ❤️ for creators
