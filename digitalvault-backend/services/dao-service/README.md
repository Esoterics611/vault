# DAO Governance Service

Backend service for DigitalVault DAO governance, enabling proposal creation, voting, and treasury management through a REST API.

## Overview

The DAO Governance service provides a user-friendly API layer on top of the DAOGovernor smart contract, with:
- **Proposal Management**: Query proposals, filter by status, track voting
- **Voting Operations**: Check voting power, vote history, participation
- **Treasury Tracking**: Monitor treasury balance and transaction history
- **Event Monitoring**: Real-time caching of on-chain governance events
- **PostgreSQL Cache**: Fast queries with automatic synchronization

## Features

### Proposal Endpoints
- List all proposals with pagination
- Filter by status (Active, Executed, Defeated, etc.)
- Get proposal details with live blockchain data
- Query proposals by proposer address

### Voting Endpoints
- Get voting power for any address
- Check if address has voted on proposal
- View voting history
- Get all votes for a proposal with totals

### Treasury Endpoints
- Real-time treasury balance (ETH + VLTC)
- Transaction history with filtering
- Treasury statistics and analytics

### Background Processing
- Automatic event monitoring (ProposalCreated, VoteCast, ProposalExecuted)
- Periodic cache refresh every 5 minutes
- Database synchronization with blockchain state

## Quick Start

### Docker (Recommended)

```bash
cd services/dao-service
cp .env.example .env
# Edit .env with your configuration
docker-compose up -d
```

### Local Development

```bash
cd services/dao-service
npm install
cp .env.example .env
# Edit .env
# Set up PostgreSQL database
npm run dev
```

## Configuration

Edit `.env` file:

```bash
# Server
PORT=3002
NODE_ENV=development

# Database
DB_HOST=localhost
DB_PORT=5432
DB_NAME=digitalvault_dao
DB_USER=postgres
DB_PASSWORD=your_secure_password

# Blockchain (Base Sepolia)
RPC_URL=https://sepolia.base.org
CHAIN_ID=84532
DAO_CONTRACT_ADDRESS=0x... # Your deployed DAO contract
VAULT_TOKEN_ADDRESS=0x9583d1643354B9C254586966343D54bCB79970D3

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000  # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100

# Logging
LOG_LEVEL=info
LOG_FORMAT=json

# CORS
CORS_ORIGIN=http://localhost:3000
```

## API Endpoints

### Health

#### GET /api/dao/health
Basic health check.

**Response:**
```json
{
  "status": "healthy",
  "service": "DAO Governance",
  "version": "1.0.0",
  "uptime": 3600
}
```

#### GET /api/dao/health/detailed
Detailed health with database and blockchain status.

### Proposals

#### GET /api/dao/proposals
List all proposals with pagination.

**Query Parameters:**
- `page` (optional): Page number (default: 1)
- `pageSize` (optional): Items per page (default: 20, max: 100)
- `status` (optional): Filter by status (ACTIVE, EXECUTED, DEFEATED, etc.)

**Response:**
```json
{
  "success": true,
  "proposals": [{
    "id": 1,
    "proposer": "0x...",
    "title": "Proposal Title",
    "description": "Full description",
    "proposalType": "GENERAL",
    "status": "ACTIVE",
    "votesFor": "1000000000000000000000",
    "votesAgainst": "500000000000000000000",
    "votesAbstain": "100000000000000000000",
    "startBlock": 1000,
    "endBlock": 2000,
    "executed": false,
    "createdAt": "2026-01-16T10:00:00.000Z"
  }],
  "pagination": {
    "page": 1,
    "pageSize": 20,
    "total": 50,
    "totalPages": 3
  }
}
```

#### GET /api/dao/proposals/active
Get only active proposals.

#### GET /api/dao/proposals/:id
Get proposal details by ID (includes fresh blockchain data).

#### GET /api/dao/proposals/by-address/:address
Get proposals created by specific address.

### Voting

#### GET /api/dao/voting/power/:address
Get voting power for an address.

**Query Parameters:**
- `blockNumber` (optional): Check power at specific block

**Response:**
```json
{
  "success": true,
  "address": "0x...",
  "votingPower": "1000000000000000000000",
  "blockNumber": "current"
}
```

#### GET /api/dao/voting/has-voted/:proposalId/:address
Check if address has voted on proposal.

**Response:**
```json
{
  "success": true,
  "proposalId": 1,
  "address": "0x...",
  "hasVoted": true,
  "vote": {
    "support": 1,
    "supportLabel": "For",
    "votingPower": "1000000000000000000000",
    "txHash": "0x...",
    "votedAt": "2026-01-16T10:00:00.000Z"
  }
}
```

#### GET /api/dao/voting/history/:address
Get voting history for address.

**Query Parameters:**
- `limit` (optional): Max results (default: 50, max: 100)

#### GET /api/dao/voting/proposal/:proposalId
Get all votes for a proposal with totals.

**Response:**
```json
{
  "success": true,
  "proposalId": 1,
  "votes": [{
    "voter": "0x...",
    "support": 1,
    "supportLabel": "For",
    "votingPower": "1000000000000000000000",
    "txHash": "0x...",
    "votedAt": "2026-01-16T10:00:00.000Z"
  }],
  "totals": {
    "for": "5000000000000000000000",
    "against": "2000000000000000000000",
    "abstain": "500000000000000000000",
    "total": "7500000000000000000000"
  },
  "voterCount": 15
}
```

### Treasury

#### GET /api/dao/treasury/balance
Get current treasury balance.

**Response:**
```json
{
  "success": true,
  "treasury": "0x...",
  "balances": {
    "eth": "1000000000000000000",
    "ethFormatted": "1.0",
    "vltc": "1000000000000000000000",
    "vltcFormatted": "1000.0"
  }
}
```

#### GET /api/dao/treasury/transactions
Get treasury transaction history.

**Query Parameters:**
- `limit` (optional): Max results (default: 50, max: 100)
- `offset` (optional): Pagination offset
- `type` (optional): Filter by DEPOSIT or WITHDRAWAL

#### GET /api/dao/treasury/stats
Get treasury statistics.

## Database Schema

### proposal_cache
Caches proposal data for fast queries.

```sql
CREATE TABLE proposal_cache (
  id SERIAL PRIMARY KEY,
  proposal_id INTEGER NOT NULL UNIQUE,
  proposer_address VARCHAR(42) NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  proposal_type VARCHAR(50) NOT NULL,
  status VARCHAR(20) NOT NULL,
  votes_for NUMERIC(78,0) DEFAULT 0,
  votes_against NUMERIC(78,0) DEFAULT 0,
  votes_abstain NUMERIC(78,0) DEFAULT 0,
  start_block INTEGER NOT NULL,
  end_block INTEGER NOT NULL,
  executed BOOLEAN DEFAULT FALSE,
  execution_tx_hash VARCHAR(66),
  target_contract VARCHAR(42),
  calldata TEXT,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

### vote_cache
Caches vote data.

```sql
CREATE TABLE vote_cache (
  id SERIAL PRIMARY KEY,
  proposal_id INTEGER NOT NULL,
  voter_address VARCHAR(42) NOT NULL,
  support SMALLINT NOT NULL,
  voting_power NUMERIC(78,0) NOT NULL,
  tx_hash VARCHAR(66) NOT NULL,
  block_number INTEGER NOT NULL,
  voted_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(proposal_id, voter_address)
);
```

### treasury_transactions
Tracks treasury transactions.

```sql
CREATE TABLE treasury_transactions (
  id SERIAL PRIMARY KEY,
  tx_hash VARCHAR(66) NOT NULL UNIQUE,
  tx_type VARCHAR(20) NOT NULL,
  amount NUMERIC(78,0) NOT NULL,
  token_address VARCHAR(42) NOT NULL,
  token_symbol VARCHAR(10),
  proposal_id INTEGER,
  from_address VARCHAR(42),
  to_address VARCHAR(42),
  block_number INTEGER NOT NULL,
  timestamp TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT NOW()
);
```

## Event Monitoring

The service automatically monitors these events:

### ProposalCreated
Triggered when new proposal is created.
- Caches proposal details
- Sets status to ACTIVE

### VoteCast
Triggered when user votes.
- Caches vote details
- Updates proposal vote counts

### ProposalExecuted
Triggered when proposal executes.
- Marks proposal as executed
- Records execution transaction hash

## Testing

```bash
# Run all tests
npm test

# Run integration tests
npm run test:integration

# Watch mode
npm run test:watch
```

## Development

### Project Structure
```
dao-service/
├── index.js                 # Main entry point
├── src/
│   ├── blockchain/
│   │   └── dao.js          # Blockchain integration
│   ├── database/
│   │   └── index.js        # Database connection
│   ├── routes/
│   │   ├── health.routes.js
│   │   ├── proposals.routes.js
│   │   ├── voting.routes.js
│   │   └── treasury.routes.js
│   └── utils/
│       └── logger.js       # Winston logger
├── test/
│   └── integration.test.js # Tests
├── Dockerfile
├── docker-compose.yml
└── README.md
```

### Adding Features
1. Create feature branch
2. Add tests in `test/`
3. Implement in `src/`
4. Update documentation
5. Submit pull request

## Deployment

### Production Checklist
- [ ] Set secure DB_PASSWORD
- [ ] Configure production RPC_URL
- [ ] Set appropriate CORS_ORIGIN
- [ ] Use production contract addresses
- [ ] Set LOG_LEVEL=warn or error
- [ ] Configure rate limits appropriately
- [ ] Set up database backups
- [ ] Configure monitoring/alerts

## Troubleshooting

### Service Won't Start
```bash
# Check logs
docker-compose logs dao-service

# Check database
psql -h localhost -U postgres -d digitalvault_dao

# Check blockchain connection
curl https://sepolia.base.org
```

### Database Connection Errors
```bash
# Verify PostgreSQL is running
pg_isready -h localhost -p 5432

# Reset database
psql -U postgres -c "DROP DATABASE IF EXISTS digitalvault_dao;"
psql -U postgres -c "CREATE DATABASE digitalvault_dao;"
```

## License

MIT

## Related Services

- **PRE Proxy Network**: Content re-encryption service
- **IPFS Gateway**: Content storage service (Week 10-11)
- **Metadata Indexer**: Content discovery service (Week 12)

---

**DAO Governance Service v1.0.0** - Built for DigitalVault Week 9 🚀
