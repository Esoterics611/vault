# DigitalVault Backend - Integration Tests

Comprehensive test suite for all DigitalVault backend services.

## Test Structure

```
test/
├── integration/              # Service integration tests
│   ├── services.test.js     # Individual service health & APIs
│   └── service-communication.test.js  # Service-to-service tests
├── e2e/                     # End-to-end workflow tests
│   └── complete-workflow.test.js      # Complete user workflows
└── performance.test.js      # Performance benchmarks
```

## Prerequisites

All services must be running before running tests:

```bash
cd digitalvault-backend
docker-compose up -d
```

Wait for all services to be healthy (check with `docker-compose ps`).

## Running Tests

### Install Dependencies
```bash
cd test
npm install
```

### Run All Tests
```bash
npm test
```

### Run Specific Test Suites
```bash
# Integration tests only
npm run test:integration

# E2E tests only
npm run test:e2e

# Performance benchmarks
mocha performance.test.js
```

### Run Individual Test Files
```bash
# Service health tests
mocha integration/services.test.js

# Service communication tests
mocha integration/service-communication.test.js

# Complete workflows
mocha e2e/complete-workflow.test.js
```

## Test Suites

### 1. Service Health Tests (`integration/services.test.js`)
Tests each service individually:
- Health endpoint checks
- Database connectivity
- Blockchain/Pinata connectivity
- Basic API endpoints
- Statistics queries

**Expected Result:** All 3 services healthy with database connections.

### 2. Service Communication Tests (`integration/service-communication.test.js`)
Tests service-to-service integration:
- PRE Proxy ↔ IPFS Gateway
- DAO Service ↔ IPFS Gateway
- Cross-service network communication
- Content upload and retrieval workflows

**Expected Result:** All services can communicate on shared network.

### 3. End-to-End Workflow Tests (`e2e/complete-workflow.test.js`)
Tests complete user workflows:
- **PRE Workflow:** Upload encrypted content → Store capsule → Verify tracking
- **DAO Workflow:** Create proposal metadata → Store on IPFS → Query proposals
- **Multi-Service:** Verify all services operational together

**Expected Result:** Complete workflows execute successfully.

### 4. Performance Benchmarks (`performance.test.js`)
Measures response times and throughput:
- Health endpoint response times (<200ms)
- Database query performance (<500ms)
- Concurrent request handling (10 concurrent requests)
- Statistics query performance (<300ms)

**Expected Result:** All benchmarks pass performance thresholds.

## Environment Variables

Tests use these environment variables (defaults shown):

```bash
PRE_PROXY_URL=http://localhost:3001
DAO_SERVICE_URL=http://localhost:3002
IPFS_GATEWAY_URL=http://localhost:3000
```

Override for custom deployments:
```bash
PRE_PROXY_URL=http://custom-host:3001 npm test
```

## Test Output

Tests provide detailed console output:
- ✅ Success indicators
- ❌ Failure indicators
- ⚠️  Warnings (skipped tests)
- 📊 Statistics and metrics
- 🎉 Completion messages

## Continuous Integration

To run in CI/CD pipelines:

```bash
# Start services
docker-compose up -d

# Wait for health
timeout 60 bash -c 'until curl -f http://localhost:3000/api/ipfs/health; do sleep 2; done'

# Run tests
cd test && npm install && npm test

# Cleanup
docker-compose down
```

## Troubleshooting

### Services Not Running
```bash
# Check service status
docker-compose ps

# Check logs
docker-compose logs pre-proxy
docker-compose logs dao-service
docker-compose logs ipfs-gateway
```

### Database Connection Failures
```bash
# Check database health
docker-compose ps | grep postgres

# Restart services
docker-compose restart
```

### Tests Timing Out
- Increase timeout in individual tests
- Check network connectivity
- Verify services are not overloaded

### Pinata Tests Failing
- Verify PINATA_API_KEY is set in .env
- Check Pinata account status
- Some tests gracefully skip if Pinata unavailable

## Coverage

Current test coverage:
- **12 API endpoints** tested across PRE Proxy
- **10 API endpoints** tested across DAO Service
- **12 API endpoints** tested across IPFS Gateway
- **2 complete E2E workflows** (PRE content sharing, DAO governance)
- **15+ performance benchmarks**

## Adding New Tests

Follow existing patterns:

```javascript
describe('New Feature Tests', function() {
  this.timeout(30000);

  it('should test new feature', async function() {
    const response = await axios.get(`${SERVICE_URL}/api/endpoint`);
    expect(response.status).to.equal(200);
    expect(response.data).to.have.property('expected');
  });
});
```

## License

MIT
