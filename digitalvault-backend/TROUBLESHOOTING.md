# DigitalVault Backend - Troubleshooting Guide

## Services Won't Start

**Issue:** Docker containers fail to start

**Solutions:**
```bash
# Check logs
docker-compose logs

# Rebuild images
docker-compose build --no-cache

# Remove old containers
docker-compose down -v
docker-compose up -d
```

## Database Connection Errors

**Issue:** "Connection refused" or "Database unavailable"

**Solutions:**
```bash
# Check PostgreSQL health
docker-compose ps | grep postgres

# Restart databases
docker-compose restart pre-postgres dao-postgres ipfs-postgres

# Wait for health checks
docker-compose ps
```

## Health Check Failures

**Issue:** Services show as "unhealthy"

**Check:**
```bash
# View detailed health
curl http://localhost:3001/api/proxy/health/detailed

# Check specific components
docker-compose logs pre-proxy | grep ERROR
```

**Common Causes:**
- Missing environment variables
- Invalid RPC_URL or blockchain connectivity
- Pinata credentials invalid
- Database migration failed

## Blockchain Connection Issues

**Issue:** "Cannot connect to RPC"

**Solutions:**
- Verify RPC_URL in .env is correct
- Check network connectivity
- Try alternative RPC provider
- Verify CHAIN_ID matches network

## IPFS/Pinata Errors

**Issue:** Upload fails or Pinata unreachable

**Solutions:**
- Verify PINATA_API_KEY and PINATA_SECRET_KEY in .env
- Check Pinata account status
- Verify API rate limits not exceeded
- Test with: `curl https://api.pinata.cloud/data/testAuthentication`

## Port Conflicts

**Issue:** "Port already in use"

**Solutions:**
```bash
# Find process using port
lsof -i :3000  # or 3001, 3002

# Change ports in docker-compose.yml
ports:
  - "3100:3000"  # External:Internal
```

## Performance Issues

**Issue:** Slow response times

**Check:**
```bash
# Run performance tests
cd test && npm run test performance.test.js

# Check resource usage
docker stats
```

**Solutions:**
- Increase Docker memory allocation
- Scale services horizontally
- Optimize database queries
- Add database indexes

## Test Failures

**Issue:** Integration tests fail

**Debug:**
```bash
# Check services are running
docker-compose ps

# Wait for all services healthy
sleep 10

# Run tests with verbose output
cd test && mocha --reporter spec integration/services.test.js
```

## Common Error Messages

### "File size exceeds limit"
- IPFS upload limit is 100MB by default
- Increase IPFS_MAX_FILE_SIZE in .env

### "Rate limit exceeded"
- Adjust RATE_LIMIT_MAX_REQUESTS
- Implement request queuing
- Scale gateway instances

### "Capsule not found"
- Check CID is correct
- Verify content was successfully pinned
- Check Pinata pin list

## Getting Help

1. Check service logs: `docker-compose logs [service]`
2. Verify environment: `docker-compose config`
3. Test health endpoints
4. Run integration tests
5. Check GitHub issues
