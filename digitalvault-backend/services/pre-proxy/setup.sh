#!/bin/bash

# PRE Proxy Network - Setup Script
# Automated setup for local development or Docker deployment

set -e

echo "=================================================="
echo "   PRE Proxy Network - Setup Script"
echo "=================================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if .env exists
if [ -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file already exists${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${BLUE}Using existing .env file${NC}"
    else
        cp .env.example .env
        echo -e "${GREEN}✅ Created new .env file${NC}"
    fi
else
    cp .env.example .env
    echo -e "${GREEN}✅ Created .env file${NC}"
fi

echo ""
echo "=================================================="
echo "   Choose Deployment Method"
echo "=================================================="
echo ""
echo "1) Docker (Recommended - Includes PostgreSQL)"
echo "2) Local Development (Requires PostgreSQL installed)"
echo ""
read -p "Enter choice [1-2]: " deployment_choice

case $deployment_choice in
    1)
        echo ""
        echo "=================================================="
        echo "   Docker Deployment"
        echo "=================================================="
        echo ""

        # Check if Docker is installed
        if ! command -v docker &> /dev/null; then
            echo -e "${RED}❌ Docker not found. Please install Docker first.${NC}"
            exit 1
        fi

        if ! command -v docker-compose &> /dev/null; then
            echo -e "${RED}❌ docker-compose not found. Please install docker-compose first.${NC}"
            exit 1
        fi

        echo -e "${GREEN}✅ Docker found${NC}"
        echo -e "${GREEN}✅ docker-compose found${NC}"
        echo ""

        # Prompt for database password
        echo "Please set a secure database password:"
        read -sp "DB_PASSWORD: " db_password
        echo ""

        # Update .env file
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            sed -i '' "s/DB_PASSWORD=your_secure_password_here/DB_PASSWORD=$db_password/" .env
        else
            # Linux
            sed -i "s/DB_PASSWORD=your_secure_password_here/DB_PASSWORD=$db_password/" .env
        fi

        echo -e "${GREEN}✅ Database password set${NC}"
        echo ""

        echo "Starting Docker containers..."
        docker-compose up -d

        echo ""
        echo -e "${GREEN}✅ Services started!${NC}"
        echo ""
        echo "Waiting for services to be ready..."
        sleep 10

        # Check health
        if curl -s http://localhost:3001/api/proxy/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Service is healthy!${NC}"
            echo ""
            echo "Service URL: http://localhost:3001"
            echo ""
            echo "Useful commands:"
            echo "  docker-compose logs -f        # View logs"
            echo "  docker-compose ps             # Check status"
            echo "  docker-compose down           # Stop services"
            echo "  docker-compose restart        # Restart"
        else
            echo -e "${YELLOW}⚠️  Service may still be starting...${NC}"
            echo "Check logs with: docker-compose logs -f"
        fi
        ;;

    2)
        echo ""
        echo "=================================================="
        echo "   Local Development Setup"
        echo "=================================================="
        echo ""

        # Check if Node.js is installed
        if ! command -v node &> /dev/null; then
            echo -e "${RED}❌ Node.js not found. Please install Node.js 18+ first.${NC}"
            exit 1
        fi

        echo -e "${GREEN}✅ Node.js found: $(node --version)${NC}"

        # Check if PostgreSQL is installed
        if ! command -v psql &> /dev/null; then
            echo -e "${RED}❌ PostgreSQL not found. Please install PostgreSQL 15+ first.${NC}"
            exit 1
        fi

        echo -e "${GREEN}✅ PostgreSQL found${NC}"
        echo ""

        # Install dependencies
        echo "Installing Node.js dependencies..."
        npm install
        echo -e "${GREEN}✅ Dependencies installed${NC}"
        echo ""

        # Create logs directory
        mkdir -p logs
        echo -e "${GREEN}✅ Logs directory created${NC}"
        echo ""

        # Database setup
        echo "Setting up PostgreSQL database..."
        read -p "PostgreSQL username [postgres]: " pg_user
        pg_user=${pg_user:-postgres}

        read -sp "PostgreSQL password: " pg_password
        echo ""

        # Create database
        PGPASSWORD=$pg_password psql -h localhost -U $pg_user -c "CREATE DATABASE digitalvault_pre;" 2>/dev/null || echo "Database may already exist"

        if PGPASSWORD=$pg_password psql -h localhost -U $pg_user -d digitalvault_pre -c "SELECT 1;" > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Database ready${NC}"
        else
            echo -e "${RED}❌ Could not connect to database${NC}"
            exit 1
        fi
        echo ""

        # Update .env file
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s/DB_PASSWORD=your_secure_password_here/DB_PASSWORD=$pg_password/" .env
        else
            sed -i "s/DB_PASSWORD=your_secure_password_here/DB_PASSWORD=$pg_password/" .env
        fi

        echo -e "${GREEN}✅ Configuration updated${NC}"
        echo ""

        echo "Starting service in development mode..."
        npm run dev &
        SERVICE_PID=$!

        echo ""
        echo -e "${GREEN}✅ Service started (PID: $SERVICE_PID)${NC}"
        echo ""
        echo "Service URL: http://localhost:3001"
        echo ""
        echo "Useful commands:"
        echo "  npm run dev          # Start with auto-reload"
        echo "  npm start            # Start production mode"
        echo "  npm test             # Run tests"
        echo "  npm run logs         # View logs"
        echo ""
        echo "Press Ctrl+C to stop the service"

        # Wait for service
        sleep 5

        if curl -s http://localhost:3001/api/proxy/health > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Service is healthy!${NC}"
        else
            echo -e "${YELLOW}⚠️  Service may still be starting...${NC}"
        fi

        # Keep script running
        wait $SERVICE_PID
        ;;

    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo "=================================================="
echo "   Setup Complete!"
echo "=================================================="
echo ""
echo "Next steps:"
echo "  1. Test health endpoint: curl http://localhost:3001/api/proxy/health"
echo "  2. Read documentation: cat README.md"
echo "  3. Check QUICKSTART.md for usage examples"
echo ""
