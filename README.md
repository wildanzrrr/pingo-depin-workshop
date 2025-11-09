<!--
 Copyright (c) 2025 wildanzrrr
 
 This software is released under the MIT License.
 https://opensource.org/licenses/MIT
-->

# DeAI - AI Task Processing 

A decentralized physical infrastructure network (DePIN) that coordinates AI nodes to process tasks using OpenAI's GPT models.

![DePIN Network Showcase](docs/Screenshot%20at%20Nov%2009%2022-56-26.png)

## 🌟 Features

- **Control Plane Architecture**: Centralized coordinator manages task distribution
- **RabbitMQ Message Broker**: Reliable task queuing with round-robin distribution
- **AI Task Processing**: Nodes use OpenAI GPT to answer questions
- **Blockchain Integration**: Smart contracts on Ethereum/Anvil for task management
- **Docker Orchestration**: Easy deployment with Docker Compose
- **Scalable**: Add/remove nodes dynamically without downtime

## 🏗️ Architecture

```
Blockchain → Control Plane → RabbitMQ → AI Nodes (Round Robin)
                ↓                ↓
         Task Coordination   Fair Distribution
```

## 📋 Prerequisites

1. **VS Code** with [Dev Container extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
   
   ![Dev Container Extension](docs/Screenshot%20at%20Nov%2009%2022-44-08.png)

2. **Docker Desktop** - [Download here](https://www.docker.com/products/docker-desktop/)

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/wildanzrrr/pingo-depin-workshop
cd workshop-depin
```

### 2. Open in Dev Container

In VS Code:
- Press `F1` or `Ctrl+Shift+P` (Cmd+Shift+P on Mac)
- Select **"Dev Containers: Reopen in Container"**

![Reopen in Container](docs/Screenshot%20at%20Nov%2009%2022-43-09.png)

Wait for the container to build (first time takes a few minutes).

### 3. Configure Environment

```bash
# Copy the example environment file
cp .env.example .env

# Edit .env and add your OpenAI API key
nano .env
```

Update this line in `.env`:
```bash
OPENAI_API_KEY=sk-your-actual-api-key-here
```

Get your API key from: https://platform.openai.com/api-keys

### 4. Start Anvil Blockchain

Open a new terminal in VS Code and run:

```bash
anvil --host 0.0.0.0
```

> ⚠️ **Important**: Keep this terminal running! The `--host 0.0.0.0` flag is required for Docker containers to connect.

### 5. Run Setup Script

Open another terminal and run:

```bash
./setup.sh
```

This will:
- ✅ Deploy the smart contract
- ✅ Build Docker images
- ✅ Start RabbitMQ, Control Plane, and 2 AI Nodes
- ✅ Verify all services are running

### 6. Monitor Logs

Watch the Control Plane processing tasks:

```bash
docker-compose logs -f control-plane
```

Or watch all services:

```bash
docker-compose logs -f
```

### 7. Create a Task

Open a new terminal and create your first task:

```bash
./create-tasks.sh "What is blockchain technology?"
```

Watch the logs to see:
1. Control Plane detects the task
2. Task is published to RabbitMQ
3. A node picks up the task
4. AI processes the question
5. Result is submitted to blockchain


## 🎯 Common Commands

```bash
# View all logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f node-1
docker-compose logs -f control-plane

# Add more nodes
./add-node.sh 3 0x<private-key>

# List all running nodes
./list-nodes.sh

# Remove a node
./remove-node.sh 3

# Stop all services
docker-compose down

# Restart services
docker-compose restart
```

## 🎓 How It Works

1. **Task Creation**: Owner calls `addTask()` on smart contract
2. **Event Detection**: Control Plane listens for `TaskCreated` events
3. **Queue Distribution**: Task is published to RabbitMQ queue
4. **Node Assignment**: RabbitMQ distributes to next available node (round-robin)
5. **AI Processing**: Node uses OpenAI to generate answer
6. **Blockchain Submit**: Node submits result to smart contract
7. **Result Report**: Node reports completion to Control Plane


## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.
