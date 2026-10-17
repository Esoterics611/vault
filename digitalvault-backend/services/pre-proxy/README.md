# PRE Proxy Network Service

Secure proxy re-encryption service for DigitalVault content ownership transfers using Umbral threshold cryptography.

## Overview

The PRE Proxy Network service enables secure content ownership transfer without exposing the underlying encrypted content. It uses the Umbral Proxy Re-Encryption (PRE) scheme to transform capsules from one owner's key to another's.

### Key Features

- **Secure Re-encryption**: Transform encrypted content ownership without decryption
- **On-chain Verification**: All operations verify grants on ReKeyRegistry smart contract
- **Threshold Cryptography**: M-of-N scheme for enhanced security (e.g., 2-of-3)
- **Rate Limiting**: Protection against DOS attacks
- **PostgreSQL Storage**: Persistent capsule storage with indexing
- **Docker Support**: Containerized deployment with docker-compose
- **Health Monitoring**: Detailed health checks for service, database, and blockchain

## Architecture

```
┌─────────────┐
│   Client    │
│  (Buyer)    │
└──────┬──────┘
       │
       │ 1. Request re-encryption
       │    (with grant ID)
       ▼
┌─────────────────────────────────┐
│   PRE Proxy Network Service     │
│                                  │
│  ┌──────────────────────────┐  │
│  │  1. Verify Grant         │  │
│  │     (ReKeyRegistry)      │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │  2. Retrieve Capsule     │  │
│  │     (PostgreSQL)         │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │  3. Re-encrypt Capsule   │  │
│  │     (Umbral PRE)         │  │
│  └──────────────────────────┘  │
│  ┌──────────────────────────┐  │
│  │  4. Return New Capsule   │  │
│  │     + cfrags             │  │
│  └──────────────────────────┘  │
└─────────────────────────────────┘
```

## Prerequisites

- Node.js 18+
- PostgreSQL 15+
- Access to Base Sepolia testnet RPC
- Deployed smart contracts (ContentRegistry, ReKeyRegistry)

## Installation

### Local Development

```bash
# Navigate to service directory
cd services/pre-proxy

# Install dependencies
npm install

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env

# Create logs directory
mkdir logs

# Start PostgreSQL (if not using Docker)
# Make sure PostgreSQL is running on localhost:5432

# Start the service
npm run dev
```

### Docker Deployment

```bash
# Navigate to service directory
cd services/pre-proxy

# Copy environment template
cp .env.example .env

# Edit .env with your configuration
nano .env

# Build and start services
docker-compose up -d

# View logs
docker-compose logs -f pre-proxy

# Stop services
docker-compose down
```

## Configuration

Edit `.env` file with your settings:

```bash
# Server Configuration
PORT=3001
NODE_ENV=production

# Database Configuration
DB_HOST=localhost
DB_PORT=5432
DB_NAME=digitalvault_pre
DB_USER=postgres
DB_PASSWORD=your_secure_password

# Blockchain Configuration (Base Sepolia)
RPC_URL=https://sepolia.base.org
CHAIN_ID=84532
CONTENT_REGISTRY_ADDRESS=0xd469e2AA709bb01ab409eBb762c655FC641C41f0
REKEY_REGISTRY_ADDRESS=0xBC835256b0D08DFeD09c7cE3B07eD945C6e243aA

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000  # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100
RATE_LIMIT_REENCRYPT_MAX=50

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# CORS
CORS_ORIGIN=*

# Security
MAX_CAPSULE_SIZE=1048576  # 1MB
```

## API Endpoints

### Health Checks

#### GET /api/proxy/health
Basic health check.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-16T10:00:00.000Z",
  "service": "PRE Proxy Network",
  "version": "1.0.0",
  "uptime": 3600
}
```

#### GET /api/proxy/health/detailed
Detailed health check with database and blockchain status.

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2026-01-16T10:00:00.000Z",
  "checks": {
    "service": "healthy",
    "database": "healthy",
    "blockchain": "healthy",
    "blockNumber": 36500000
  },
  "uptime": 3600
}
```

### Capsule Storage

#### POST /api/proxy/capsules
Store a new capsule.

**Request Body:**
```json
{
  "contentId": 1,
  "capsuleData": "0x...",
  "capsuleHash": "0x..."
}
```

**Response:**
```json
{
  "success": true,
  "capsule": {
    "id": 1,
    "contentId": 1,
    "createdAt": "2026-01-16T10:00:00.000Z",
    "updatedAt": "2026-01-16T10:00:00.000Z"
  }
}
```

#### GET /api/proxy/capsules/:contentId
Retrieve a capsule by content ID.

**Response:**
```json
{
  "success": true,
  "capsule": {
    "id": 1,
    "contentId": 1,
    "ownerAddress": "0x...",
    "capsuleData": "0x...",
    "capsuleHash": "0x...",
    "createdAt": "2026-01-16T10:00:00.000Z",
    "accessCount": 5
  }
}
```

### Re-encryption

#### POST /api/proxy/reencrypt
Perform proxy re-encryption with grant verification.

**Request Body:**
```json
{
  "grantId": 1,
  "contentId": 1,
  "grantorAddress": "0x...",
  "granteeAddress": "0x...",
  "kfragHash": "0x...",
  "granteePublicKey": "0x...",
  "threshold": 2,
  "totalShares": 3
}
```

**Response:**
```json
{
  "success": true,
  "reencryption": {
    "grantId": 1,
    "contentId": 1,
    "newCapsule": "0x...",
    "newCapsuleHash": "0x...",
    "cfrags": [
      {"index": 0, "data": "0x..."},
      {"index": 1, "data": "0x..."},
      {"index": 2, "data": "0x..."}
    ],
    "threshold": 2,
    "totalShares": 3
  }
}
```

#### GET /api/proxy/reencrypt/history/:contentId
Get re-encryption history for a content item.

**Response:**
```json
{
  "success": true,
  "contentId": 1,
  "requests": [
    {
      "grantId": 1,
      "fromAddress": "0x...",
      "toAddress": "0x...",
      "kfragHash": "0x...",
      "newCapsuleHash": "0x...",
      "status": "completed",
      "createdAt": "2026-01-16T10:00:00.000Z",
      "completedAt": "2026-01-16T10:00:05.000Z"
    }
  ]
}
```

## Testing

```bash
# Run all tests
npm test

# Run integration tests
npm run test:integration

# Run tests in watch mode
npm run test:watch
```

### Test Environment Variables

For integration tests, set:
```bash
TEST_BASE_URL=http://localhost:3001
TEST_CONTENT_ID=1  # Known content ID on testnet
```

## Database Schema

### capsules
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
  access_count INTEGER DEFAULT 0
);
```

### reencryption_requests
```sql
CREATE TABLE reencryption_requests (
  id SERIAL PRIMARY KEY,
  grant_id INTEGER NOT NULL,
  content_id INTEGER NOT NULL,
  from_address VARCHAR(42) NOT NULL,
  to_address VARCHAR(42) NOT NULL,
  kfrag_hash VARCHAR(66) NOT NULL,
  new_capsule_hash VARCHAR(66) NOT NULL,
  status VARCHAR(20) NOT NULL DEFAULT 'pending',
  tx_hash VARCHAR(66),
  created_at TIMESTAMP DEFAULT NOW(),
  completed_at TIMESTAMP
);
```

## Security Considerations

### Grant Verification
Every re-encryption operation verifies:
1. Grant exists on ReKeyRegistry
2. Grant has not expired
3. Grant has not been used
4. kfragHash matches on-chain record
5. Grantor is the content owner

### Rate Limiting
- Global: 100 requests / 15 minutes
- Re-encryption: 50 requests / 15 minutes

### Access Control
- No authentication required (operations are verified on-chain)
- Each re-encryption requires valid grant from blockchain
- Proxy cannot decrypt content (only transform capsules)

## Monitoring

### Logs
Logs are written to:
- `logs/combined.log` - All logs
- `logs/error.log` - Error logs only
- Console output (stdout)

View logs:
```bash
# Local
npm run logs

# Docker
docker-compose logs -f pre-proxy
```

### Health Checks
- Service health: `GET /api/proxy/health`
- Detailed health: `GET /api/proxy/health/detailed`
- Docker health check: Runs every 30 seconds

## Deployment

### Production Checklist

1. **Environment Configuration**
   - [ ] Set secure DB_PASSWORD
   - [ ] Configure production RPC_URL
   - [ ] Set appropriate CORS_ORIGIN
   - [ ] Use production contract addresses
   - [ ] Set LOG_LEVEL=warn or error

2. **Database Setup**
   - [ ] PostgreSQL 15+ installed
   - [ ] Database created
   - [ ] Connection tested
   - [ ] Backups configured

3. **Networking**
   - [ ] Port 3001 accessible
   - [ ] Firewall rules configured
   - [ ] SSL/TLS termination (if needed)

4. **Monitoring**
   - [ ] Log aggregation configured
   - [ ] Health check monitoring
   - [ ] Alert system setup

5. **Security**
   - [ ] Rate limits configured
   - [ ] CORS properly restricted
   - [ ] Logs directory permissions set
   - [ ] Non-root user running service

## Troubleshooting

### Service Won't Start
```bash
# Check logs
npm run logs

# Check database connection
psql -h localhost -U postgres -d digitalvault_pre

# Check blockchain connection
curl https://sepolia.base.org

# Verify environment variables
cat .env
```

### Database Connection Errors
```bash
# Verify PostgreSQL is running
pg_isready -h localhost -p 5432

# Check credentials
psql -h localhost -U postgres -d digitalvault_pre

# Reset database
psql -U postgres -c "DROP DATABASE IF EXISTS digitalvault_pre;"
psql -U postgres -c "CREATE DATABASE digitalvault_pre;"
```

### Blockchain Connection Errors
- Verify RPC_URL is accessible
- Check CHAIN_ID matches network (84532 for Base Sepolia)
- Ensure contract addresses are correct
- Test RPC endpoint: `curl https://sepolia.base.org`

## Development

### Project Structure
```
pre-proxy/
├── index.js                 # Main entry point
├── src/
│   ├── blockchain/          # Blockchain integration
│   │   └── index.js
│   ├── database/            # Database connection
│   │   └── index.js
│   ├── routes/              # API routes
│   │   ├── capsule.routes.js
│   │   ├── health.routes.js
│   │   └── reencrypt.routes.js
│   ├── umbral/              # Umbral PRE operations
│   │   └── index.js
│   └── utils/               # Utilities
│       └── logger.js
├── test/                    # Tests
│   └── integration.test.js
├── logs/                    # Log files
├── Dockerfile               # Docker build
├── docker-compose.yml       # Docker orchestration
├── package.json             # Dependencies
├── .env.example             # Environment template
└── README.md                # This file
```

### Adding Features
1. Create feature branch
2. Add tests in `test/`
3. Implement feature in `src/`
4. Update documentation
5. Submit pull request

## License

MIT License - See LICENSE file for details

## Support

For issues and questions:
- GitHub Issues: [digitalvault-backend/issues](https://github.com/yourusername/digitalvault-backend/issues)
- Documentation: [docs/PRE_PROXY.md](../../docs/PRE_PROXY.md)

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Detailed architecture design
- [Week 7 Deployment](../../../docs/TESTNET_DEPLOYMENT_SUCCESS.md) - Smart contract addresses
- [Smart Contracts](../../../digitalvault-contracts/) - Contract source code
