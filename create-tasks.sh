#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if contract address is provided
if [ ! -f "deployment.txt" ]; then
    echo -e "${RED}❌ deployment.txt not found!${NC}"
    echo -e "${YELLOW}Please run ./deploy.sh first${NC}"
    exit 1
fi

CONTRACT_ADDRESS=$(cat deployment.txt | grep "DEPIN_CONTRACT_ADDRESS=" | cut -d'=' -f2)
OWNER_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

echo -e "${BLUE}╔═══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      DEPIN Network - Create Tasks         ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}📍 Contract:${NC} ${CONTRACT_ADDRESS}"
echo ""

# Sample questions
questions=(
    "What is the capital of France?"
    "Explain quantum computing in one sentence"
    "What is 15 multiplied by 23?"
    "Who wrote the novel '1984'?"
    "What is the chemical formula for water?"
    "Name three programming languages"
    "What year did World War II end?"
    "Explain the concept of artificial intelligence briefly"
    "What is the speed of light in meters per second?"
    "Name the largest planet in our solar system"
)

# Check if argument is provided
if [ $# -eq 0 ]; then
    # No arguments - pick random question
    echo -e "${YELLOW}Creating random task...${NC}"
    echo ""
    
    # Get random question
    random_index=$((RANDOM % ${#questions[@]}))
    question="${questions[$random_index]}"
    echo -e "${BLUE}Task:${NC} ${question}"
    
    cast send "${CONTRACT_ADDRESS}" \
        "addTask(string)" \
        "${question}" \
        --rpc-url http://127.0.0.1:8545 \
        --private-key ${OWNER_KEY}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Task created${NC}"
    else
        echo -e "${RED}❌ Failed to create task${NC}"
    fi
    echo ""
else
    # Arguments provided - use as custom question
    custom_question="$*"
    echo -e "${YELLOW}Creating custom task...${NC}"
    echo ""
    echo -e "${BLUE}Task:${NC} ${custom_question}"
    
    cast send "${CONTRACT_ADDRESS}" \
        "addTask(string)" \
        "${custom_question}" \
        --rpc-url http://127.0.0.1:8545 \
        --private-key ${OWNER_KEY}
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Task created${NC}"
    else
        echo -e "${RED}❌ Failed to create task${NC}"
    fi
    echo ""
fi

echo -e "${GREEN}✨ Task creation complete!${NC}"
echo ""
echo -e "${YELLOW}Check your listener terminal to see tasks being processed${NC}"
echo ""
echo -e "${BLUE}Usage:${NC}"
echo -e "  ${GREEN}./create-tasks.sh${NC}                          - Create random task"
echo -e "  ${GREEN}./create-tasks.sh \"Your custom question\"${NC}  - Create custom task"
echo ""
