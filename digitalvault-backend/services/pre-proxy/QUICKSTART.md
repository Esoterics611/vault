# PRE Proxy Network - Quick Start Guide

Get the PRE Proxy Network service running in 5 minutes.

## Option 1: Docker (Recommended)

### Prerequisites
- Docker 20+
- Docker Compose 2+

### Steps

1. **Navigate to service directory**
```bash
cd services/pre-proxy
```

2. **Copy environment file**
```bash
cp .env.example .env
```

3. **Edit configuration** (Required)
```bash
# Edit .env and set:
# - DB_PASSWORD (create a secure password)
# - RPC_URL (if using different endpoint)
# - Contract addresses are already set for Base Sepolia testnet
nano .env
```

4. **Start services**
```bash
docker-compose up -d
```

5. **Verify service is running**
```bash
# Check health
curl http://localhost:3001/api/proxy/health

# View logs
docker-compose logs -f pre-proxy
```

6. **Test the service**
```bash
# Check detailed health (includes blockchain connectivity)
curl http://localhost:3001/api/proxy/health/detailed
```

That's it! Your PRE Proxy service is now running on `http://localhost:3001`

### Useful Docker Commands

```bash
# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Restart service
docker-compose restart pre-proxy

# View database logs
docker-compose logs postgres

# Access database
docker-compose exec postgres psql -U postgres -d digitalvault_pre

# Remove everything (including data)
docker-compose down -v
```

## Option 2: Local Development

### Prerequisites
- Node.js 18+
- PostgreSQL 15+
- npm or yarn

### Steps

1. **Navigate to service directory**
```bash
cd services/pre-proxy
```

2. **Install dependencies**
```bash
npm install
```

3. **Set up PostgreSQL**
```bash
# Create database
psql -U postgres -c "CREATE DATABASE digitalvault_pre;"

# Test connection
psql -U postgres -d digitalvault_pre -c "SELECT NOW();"
```

4. **Copy environment file**
```bash
cp .env.example .env
```

5. **Edit configuration**
```bash
# Edit .env and set:
# - DB_PASSWORD (your PostgreSQL password)
# - DB_HOST=localhost
# - All other settings as needed
nano .env
```

6. **Create logs directory**
```bash
mkdir logs
```

7. **Start service**
```bash
# Development mode (with auto-reload)
npm run dev

# Production mode
npm start
```

8. **Verify service is running**
```bash
# In another terminal
curl http://localhost:3001/api/proxy/health
```

## Configuration Quick Reference

### Required Settings
```bash
# Database
DB_PASSWORD=your_secure_password_here

# Blockchain (Base Sepolia - already configured)
RPC_URL=https://sepolia.base.org
CONTENT_REGISTRY_ADDRESS=0xd469e2AA709bb01ab409eBb762c655FC641C41f0
REKEY_REGISTRY_ADDRESS=0xBC835256b0D08DFeD09c7cE3B07eD945C6e243aA
```

### Optional Settings
```bash
# Server
PORT=3001                    # Default: 3001
NODE_ENV=development         # development or production

# Database
DB_HOST=localhost            # Default: localhost
DB_PORT=5432                # Default: 5432
DB_NAME=digitalvault_pre    # Default: digitalvault_pre
DB_USER=postgres            # Default: postgres

# Rate Limiting
RATE_LIMIT_WINDOW_MS=900000      # 15 minutes
RATE_LIMIT_MAX_REQUESTS=100      # per window
RATE_LIMIT_REENCRYPT_MAX=50      # per window

# Logging
LOG_LEVEL=info              # error, warn, info, debug
LOG_FORMAT=json             # json or pretty

# Security
CORS_ORIGIN=*               # Comma-separated origins
MAX_CAPSULE_SIZE=1048576    # 1MB
```

## Testing the Service

### Health Checks
```bash
# Basic health
curl http://localhost:3001/api/proxy/health

# Detailed health (includes database and blockchain)
curl http://localhost:3001/api/proxy/health/detailed
```

### Store a Capsule (Example)
```bash
curl -X POST http://localhost:3001/api/proxy/capsules \
  -H "Content-Type: application/json" \
  -d '{
    "contentId": 1,
    "capsuleData": "0x1234567890abcdef",
    "capsuleHash": "0x0000000000000000000000000000000000000000000000000000000000000001"
  }'
```

### Retrieve a Capsule
```bash
curl http://localhost:3001/api/proxy/capsules/1
```

### Request Re-encryption
```bash
curl -X POST http://localhost:3001/api/proxy/reencrypt \
  -H "Content-Type: application/json" \
  -d '{
    "grantId": 1,
    "contentId": 1,
    "grantorAddress": "0x1111111111111111111111111111111111111111",
    "granteeAddress": "0x2222222222222222222222222222222222222222",
    "kfragHash": "0x0000000000000000000000000000000000000000000000000000000000000001",
    "granteePublicKey": "0xabcdef1234567890",
    "threshold": 2,
    "totalShares": 3
  }'
```

## Running Tests

```bash
# Run all tests
npm test

# Run integration tests (service must be running)
npm run test:integration

# Run tests in watch mode (for development)
npm run test:watch
```

## Troubleshooting

### Service won't start
```bash
# Check if port 3001 is already in use
lsof -i :3001  # macOS/Linux
netstat -ano | findstr :3001  # Windows

# Check logs
npm run logs  # Local
docker-compose logs pre-proxy  # Docker
```

### Database connection failed
```bash
# Verify PostgreSQL is running
pg_isready  # Local
docker-compose ps  # Docker

# Check database exists
psql -U postgres -l | grep digitalvault_pre

# Test connection manually
psql -h localhost -U postgres -d digitalvault_pre
```

### Blockchain connection failed
```bash
# Test RPC endpoint
curl -X POST https://sepolia.base.org \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Check if contract addresses are correct
# They should match Week 7 deployment addresses
```

### Umbral library not found
```bash
# Install Umbral package
npm install @nucypher/umbral-pre@^0.7.0

# Rebuild
npm run dev
```

## Next Steps

1. **Read the full documentation**: [README.md](./README.md)
2. **Review architecture**: [ARCHITECTURE.md](./ARCHITECTURE.md)
3. **Deploy to production**: See [README.md - Deployment](./README.md#deployment)
4. **Integrate with frontend**: Use API endpoints in your Flutter app
5. **Monitor the service**: Set up health check monitoring

## Support

- **Documentation**: [README.md](./README.md)
- **Architecture Details**: [ARCHITECTURE.md](./ARCHITECTURE.md)
- **Smart Contracts**: Week 7 deployment in `docs/TESTNET_DEPLOYMENT_SUCCESS.md`
- **Issues**: Report bugs in GitHub Issues

## What's Working

✅ **Service Infrastructure**
- Express REST API server
- PostgreSQL database integration
- Blockchain connectivity (Base Sepolia)
- Health monitoring endpoints

✅ **Capsule Management**
- Store capsules with on-chain verification
- Retrieve capsules by content ID
- Access tracking and metrics

✅ **Re-encryption Operations**
- Grant verification on ReKeyRegistry
- Capsule re-encryption workflow
- Re-encryption history tracking

✅ **Security**
- Rate limiting on all endpoints
- Input validation
- On-chain grant verification

✅ **DevOps**
- Docker containerization
- docker-compose orchestration
- Automated health checks
- Logging infrastructure

## What's Next (Week 9)

- Actual Umbral library integration (replace mock implementation)
- Load testing and optimization
- Enhanced monitoring and alerting
- Multi-proxy coordination (future expansion)

---

**PRE Proxy Network v1.0.0** - Built for DigitalVault Week 8 🚀
