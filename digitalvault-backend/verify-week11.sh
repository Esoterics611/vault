#!/bin/bash

echo "================================================"
echo "  DigitalVault Week 11 Verification Script"
echo "================================================"
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check files exist
echo "1. Checking configuration files..."
files=(
  "docker-compose.yml"
  ".env.example"
  ".gitignore"
  "DEPLOYMENT.md"
  "TROUBLESHOOTING.md"
  "test/package.json"
  "test/integration/services.test.js"
  "test/integration/service-communication.test.js"
  "test/e2e/complete-workflow.test.js"
  "test/performance.test.js"
  "test/README.md"
  "../docs/WEEK_11_COMPLETION.md"
)

missing=0
for file in "${files[@]}"; do
  if [ -f "$file" ]; then
    echo -e "   ${GREEN}✓${NC} $file"
  else
    echo -e "   ${RED}✗${NC} $file (MISSING)"
    missing=$((missing + 1))
  fi
done

if [ $missing -eq 0 ]; then
  echo -e "${GREEN}   All configuration files present!${NC}"
else
  echo -e "${RED}   $missing file(s) missing!${NC}"
  exit 1
fi
echo ""

# Check .env exists
echo "2. Checking environment setup..."
if [ -f ".env" ]; then
  echo -e "   ${GREEN}✓${NC} .env file exists"
else
  echo -e "   ${YELLOW}⚠${NC}  .env file not found"
  echo "      Run: cp .env.example .env"
  echo "      Then edit .env with your values"
fi
echo ""

# Check Docker
echo "3. Checking Docker availability..."
if command -v docker &> /dev/null; then
  echo -e "   ${GREEN}✓${NC} Docker installed"
  docker --version
else
  echo -e "   ${RED}✗${NC} Docker not found"
  exit 1
fi

if command -v docker-compose &> /dev/null; then
  echo -e "   ${GREEN}✓${NC} Docker Compose installed"
  docker-compose --version
else
  echo -e "   ${RED}✗${NC} Docker Compose not found"
  exit 1
fi
echo ""

# Check if services are running
echo "4. Checking services status..."
if docker-compose ps | grep -q "Up"; then
  echo -e "   ${GREEN}✓${NC} Services are running"
  docker-compose ps
else
  echo -e "   ${YELLOW}⚠${NC}  Services not running"
  echo "      Run: docker-compose up -d"
fi
echo ""

# Check health endpoints
echo "5. Checking service health..."
services=(
  "3001:PRE Proxy"
  "3002:DAO Service"
  "3000:IPFS Gateway"
)

for service in "${services[@]}"; do
  port="${service%%:*}"
  name="${service##*:}"
  
  if curl -sf "http://localhost:$port/api/*/health" > /dev/null 2>&1; then
    echo -e "   ${GREEN}✓${NC} $name (port $port) - Healthy"
  else
    echo -e "   ${YELLOW}⚠${NC}  $name (port $port) - Not responding"
  fi
done
echo ""

# Check test dependencies
echo "6. Checking test setup..."
if [ -d "test/node_modules" ]; then
  echo -e "   ${GREEN}✓${NC} Test dependencies installed"
else
  echo -e "   ${YELLOW}⚠${NC}  Test dependencies not installed"
  echo "      Run: cd test && npm install"
fi
echo ""

echo "================================================"
echo "  Week 11 Verification Complete"
echo "================================================"
echo ""
echo "Next steps:"
echo "  1. Start services: docker-compose up -d"
echo "  2. Install test deps: cd test && npm install"
echo "  3. Run tests: npm test"
echo "  4. Check health: curl http://localhost:3000/api/ipfs/health"
echo ""
