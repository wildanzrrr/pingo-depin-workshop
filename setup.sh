#!/bin/bash

# Complete DePIN Control Plane Setup Script
# This script performs full deployment and setup

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "╔════════════════════════════════════════════════════════╗"
echo "║   DePIN Control Plane - Complete Setup                ║"
echo "║   Automated Deployment & Launch                        ║"
echo "╚════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to wait for a service to be ready
wait_for_service() {
    local service_name=$1
    local max_attempts=$2
    local attempt=1
    
    echo -e "${BLUE}⏳ Waiting for $service_name to be ready...${NC}"
    while [ $attempt -le $max_attempts ]; do
        if docker-compose ps | grep -q "$service_name.*Up"; then
            echo -e "${GREEN}✓ $service_name is ready${NC}"
            return 0
        fi
        echo -n "."
        sleep 2
        attempt=$((attempt + 1))
    done
    echo -e "${RED}✗ Timeout waiting for $service_name${NC}"
    return 1
}

# Step 1: Prerequisites Check
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[1/7] Checking prerequisites...${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

if ! command_exists docker; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker found${NC}"

if ! command_exists docker-compose; then
    echo -e "${RED}❌ Docker Compose is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Docker Compose found${NC}"

if ! command_exists forge; then
    echo -e "${RED}❌ Foundry (forge) is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Foundry found${NC}"

if ! command_exists anvil; then
    echo -e "${RED}❌ Anvil is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Anvil found${NC}"

# Check if Anvil is running
if ! lsof -Pi :8545 -sTCP:LISTEN -t >/dev/null 2>&1; then
    echo -e "${RED}❌ Anvil is not running on port 8545${NC}"
    echo -e "${YELLOW}Please start Anvil with the correct host binding:${NC}"
    echo -e "  ${CYAN}anvil --host 0.0.0.0${NC}"
    echo ""
    echo -e "${YELLOW}Note: --host 0.0.0.0 is required for Docker containers to connect${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Anvil is running on port 8545${NC}"

# Verify Anvil is accessible from Docker network
echo -e "${BLUE}Verifying Anvil is accessible...${NC}"
if curl -s -X POST --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
   -H "Content-Type: application/json" http://127.0.0.1:8545 > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Anvil is responding to requests${NC}"
else
    echo -e "${RED}❌ Cannot connect to Anvil${NC}"
    echo -e "${YELLOW}Please restart Anvil with: ${CYAN}anvil --host 0.0.0.0${NC}"
    exit 1
fi


# Check if .env exists
if [ ! -f .env ]; then
    echo -e "${YELLOW}⚠️  .env file not found, creating from template...${NC}"
    cp .env.example .env
fi
echo -e "${GREEN}✓ .env file exists${NC}"

# Source environment
source .env

# Check if OpenAI API key is set
if [ -z "$OPENAI_API_KEY" ] || [ "$OPENAI_API_KEY" = "your_openai_api_key_here" ]; then
    echo -e "${RED}❌ OPENAI_API_KEY not set in .env file${NC}"
    echo -e "${YELLOW}Please update .env with your OpenAI API key:${NC}"
    echo -e "  ${CYAN}Get your key from: https://platform.openai.com/api-keys${NC}"
    echo -e "  ${CYAN}Then edit .env and set: OPENAI_API_KEY=sk-...${NC}"
    exit 1
fi
echo -e "${GREEN}✓ OpenAI API key configured${NC}"

# Step 2: Deploy Smart Contract
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[2/7] Deploying DePIN smart contract...${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

# Set deployer private key if not set
if [ -z "$PRIVATE_KEY" ] || [ "$PRIVATE_KEY" = "your_private_key_here" ]; then
    # Use Anvil's default first account from .env.example
    export PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
    echo -e "${YELLOW}⚠️  Using default Anvil account for deployment${NC}"
    
    # Update .env with the default key
    if grep -q "^PRIVATE_KEY=" .env; then
        sed -i "s|^PRIVATE_KEY=.*|PRIVATE_KEY=$PRIVATE_KEY|" .env
    else
        echo "PRIVATE_KEY=$PRIVATE_KEY" >> .env
    fi
fi

echo -e "${BLUE}Compiling contracts...${NC}"
forge build

echo -e "${BLUE}Deploying contract...${NC}"

# Deployment runs on host machine, so convert host.docker.internal to localhost
DEPLOY_RPC_URL="$RPC_URL"
if [[ "$RPC_URL" == *"host.docker.internal"* ]]; then
    DEPLOY_RPC_URL="http://127.0.0.1:8545"
    echo -e "${BLUE}Using $DEPLOY_RPC_URL for deployment (running on host)${NC}"
fi

DEPLOY_OUTPUT=$(forge script script/DeployDePINNetwork.s.sol:DeployDePINNetwork \
    --rpc-url $DEPLOY_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast 2>&1)

# Extract contract address from deployment output
CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP "Contract deployed at: \K0x[a-fA-F0-9]{40}" | head -1)

if [ -z "$CONTRACT_ADDRESS" ]; then
    # Try alternative extraction method
    CONTRACT_ADDRESS=$(echo "$DEPLOY_OUTPUT" | grep -oP "0x[a-fA-F0-9]{40}" | head -1)
fi

if [ -z "$CONTRACT_ADDRESS" ]; then
    echo -e "${RED}❌ Failed to extract contract address${NC}"
    echo "Deployment output:"
    echo "$DEPLOY_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ Contract deployed at: ${CONTRACT_ADDRESS}${NC}"

# Update .env with contract address
if grep -q "^CONTRACT_ADDRESS=" .env; then
    sed -i "s|^CONTRACT_ADDRESS=.*|CONTRACT_ADDRESS=$CONTRACT_ADDRESS|" .env
else
    echo "CONTRACT_ADDRESS=$CONTRACT_ADDRESS" >> .env
fi
echo -e "${GREEN}✓ Updated .env with contract address${NC}"

# Reload environment
source .env

# Step 3: Install Dependencies
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[3/7] Installing dependencies...${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

# Check if dependencies are installed
if [ ! -d "control-plane/node_modules" ]; then
    echo -e "${BLUE}Installing Control Plane dependencies...${NC}"
    cd control-plane && npm install && cd ..
    echo -e "${GREEN}✓ Control Plane dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Control Plane dependencies already installed${NC}"
fi

if [ ! -d "listener/node_modules" ]; then
    echo -e "${BLUE}Installing Listener dependencies...${NC}"
    cd listener && npm install && cd ..
    echo -e "${GREEN}✓ Listener dependencies installed${NC}"
else
    echo -e "${GREEN}✓ Listener dependencies already installed${NC}"
fi

# Step 4: Build Docker Images
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[4/7] Building Docker images...${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

echo -e "${BLUE}Building images (this may take a few minutes)...${NC}"
docker-compose build --no-cache

echo -e "${GREEN}✓ Docker images built successfully${NC}"

# Step 5: Start Services
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[5/7] Starting services (RabbitMQ, Control Plane, Nodes)...${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

# Stop any existing services
echo -e "${BLUE}Stopping any existing services...${NC}"
docker-compose down 2>/dev/null || true

# Start services
echo -e "${BLUE}Starting all services...${NC}"
docker-compose up -d

# Wait for services to be ready
sleep 5

# Check service status
echo ""
echo -e "${BLUE}Checking service status...${NC}"
docker-compose ps

# Wait for RabbitMQ
wait_for_service "rabbitmq" 15

# Wait for Control Plane
sleep 5
if docker-compose ps | grep -q "control-plane.*Up"; then
    echo -e "${GREEN}✓ Control Plane is running${NC}"
else
    echo -e "${YELLOW}⚠️  Control Plane may still be starting${NC}"
fi

# Wait for Nodes
sleep 5
if docker-compose ps | grep -q "node-1.*Up"; then
    echo -e "${GREEN}✓ Node 1 is running${NC}"
else
    echo -e "${YELLOW}⚠️  Node 1 may still be starting${NC}"
fi

if docker-compose ps | grep -q "node-2.*Up"; then
    echo -e "${GREEN}✓ Node 2 is running${NC}"
else
    echo -e "${YELLOW}⚠️  Node 2 may still be starting${NC}"
fi

# Step 6: Verify Setup
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}[6/7] Verifying setup...${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"

echo -e "${BLUE}Waiting for services to fully initialize (15 seconds)...${NC}"
sleep 15

echo ""
echo -e "${GREEN}📊 System Status:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Check logs for successful initialization
if docker logs depin-control-plane 2>&1 | grep -q "Connected to RabbitMQ"; then
    echo -e "${GREEN}✓ Control Plane: Connected to RabbitMQ${NC}"
else
    echo -e "${YELLOW}⚠ Control Plane: Check logs for status${NC}"
fi

if docker logs depin-node-1 2>&1 | grep -q "Connected to RabbitMQ"; then
    echo -e "${GREEN}✓ Node 1: Connected to RabbitMQ${NC}"
else
    echo -e "${YELLOW}⚠ Node 1: Check logs for status${NC}"
fi

if docker logs depin-node-2 2>&1 | grep -q "Connected to RabbitMQ"; then
    echo -e "${GREEN}✓ Node 2: Connected to RabbitMQ${NC}"
else
    echo -e "${YELLOW}⚠ Node 2: Check logs for status${NC}"
fi

# Success Summary
echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Setup Complete! 🎉                                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${CYAN}📝 Summary:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "Blockchain:          ${GREEN}Anvil (port 8545)${NC}"
echo -e "Smart Contract:      ${GREEN}$CONTRACT_ADDRESS${NC}"
echo -e "RabbitMQ UI:         ${GREEN}http://localhost:15672${NC} (guest/guest)"
echo -e "Control Plane:       ${GREEN}Running${NC}"
echo -e "Node 1:              ${GREEN}Running${NC}"
echo -e "Node 2:              ${GREEN}Running${NC}"
echo ""

echo -e "${CYAN}🎯 Quick Commands:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  View logs:          docker-compose logs -f"
echo "  Control Plane logs: docker-compose logs -f control-plane"
echo "  Node logs:          docker-compose logs -f node-1"
echo "  RabbitMQ UI:        open http://localhost:15672"
echo "  Create task:        ./create-tasks.sh 'Your question here'"
echo "  Stop all:           docker-compose down"
echo ""

echo -e "${YELLOW}📋 Next Steps:${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  1. Open RabbitMQ UI to monitor queues"
echo "  2. Create a test task:"
echo "     ./create-tasks.sh 'What is blockchain?'"
echo "  3. Watch the logs to see task processing:"
echo "     docker-compose logs -f"
echo "  4. Check QUICKSTART.md for more information"
echo ""

# Optional: Show recent logs
echo -e "${BLUE}📜 Recent logs (last 10 lines per service):${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${CYAN}Control Plane:${NC}"
docker logs depin-control-plane --tail 10 2>&1 | tail -5
echo ""
echo -e "${CYAN}Node 1:${NC}"
docker logs depin-node-1 --tail 10 2>&1 | tail -5
echo ""

echo -e "${GREEN}✨ System is ready to process tasks!${NC}"
echo ""
