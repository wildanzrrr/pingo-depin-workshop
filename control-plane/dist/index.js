"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
const ethers_1 = require("ethers");
const amqp = __importStar(require("amqplib"));
const dotenv = __importStar(require("dotenv"));
const path = __importStar(require("path"));
const abi_1 = require("./abi");
// Load environment variables from root directory
dotenv.config({ path: path.resolve(__dirname, "../../.env") });
class ControlPlane {
    constructor() {
        this.rabbitmqConnection = null;
        this.rabbitmqChannel = null;
        this.TASK_QUEUE = "depin_tasks";
        this.RESULT_QUEUE = "depin_results";
        this.nodeList = [];
        this.currentNodeIndex = 0;
        // Initialize provider
        const rpcUrl = process.env.RPC_URL || "http://host.docker.internal:8545";
        this.provider = new ethers_1.ethers.JsonRpcProvider(rpcUrl);
        // Initialize contract
        const contractAddress = process.env.CONTRACT_ADDRESS;
        if (!contractAddress) {
            throw new Error("CONTRACT_ADDRESS not set in .env file");
        }
        this.contract = new ethers_1.ethers.Contract(contractAddress, abi_1.DePINNetworkABI, this.provider);
        console.log("🎛️  Control Plane initialized");
        console.log("📍 RPC URL:", rpcUrl);
        console.log("📍 Contract Address:", contractAddress);
    }
    /**
     * Connect to RabbitMQ
     */
    async connectRabbitMQ() {
        const rabbitmqUrl = process.env.RABBITMQ_URL || "amqp://guest:guest@rabbitmq:5672";
        console.log("\n🐰 Connecting to RabbitMQ:", rabbitmqUrl);
        let retries = 5;
        while (retries > 0) {
            try {
                this.rabbitmqConnection = await amqp.connect(rabbitmqUrl);
                this.rabbitmqChannel = await this.rabbitmqConnection.createChannel();
                // Declare queues
                if (this.rabbitmqChannel) {
                    await this.rabbitmqChannel.assertQueue(this.TASK_QUEUE, {
                        durable: true,
                    });
                    await this.rabbitmqChannel.assertQueue(this.RESULT_QUEUE, {
                        durable: true,
                    });
                }
                console.log("✅ Connected to RabbitMQ");
                console.log("📬 Task Queue:", this.TASK_QUEUE);
                console.log("📬 Result Queue:", this.RESULT_QUEUE);
                // Handle connection errors
                if (this.rabbitmqConnection) {
                    this.rabbitmqConnection.on("error", (err) => {
                        console.error("❌ RabbitMQ connection error:", err);
                    });
                    this.rabbitmqConnection.on("close", () => {
                        console.log("⚠️  RabbitMQ connection closed, reconnecting...");
                        setTimeout(() => this.connectRabbitMQ(), 5000);
                    });
                }
                return;
            }
            catch (error) {
                retries--;
                console.log(`⚠️  Failed to connect to RabbitMQ, retrying... (${retries} attempts left)`);
                if (retries === 0) {
                    throw new Error(`Failed to connect to RabbitMQ: ${error.message}`);
                }
                await new Promise((resolve) => setTimeout(resolve, 5000));
            }
        }
    }
    /**
     * Get next node using round-robin algorithm
     */
    getNextNode() {
        if (this.nodeList.length === 0) {
            return null;
        }
        const node = this.nodeList[this.currentNodeIndex];
        this.currentNodeIndex = (this.currentNodeIndex + 1) % this.nodeList.length;
        return node;
    }
    /**
     * Publish task to RabbitMQ queue with node assignment
     */
    async publishTask(task) {
        if (!this.rabbitmqChannel) {
            console.error("❌ RabbitMQ channel not initialized");
            return;
        }
        const assignedNode = this.getNextNode();
        if (!assignedNode) {
            console.log("⚠️  No nodes available to assign task");
            return;
        }
        const message = {
            ...task,
            assignedNode,
        };
        try {
            this.rabbitmqChannel.sendToQueue(this.TASK_QUEUE, Buffer.from(JSON.stringify(message)), {
                persistent: true,
            });
            console.log(`📤 Task #${task.taskId} published to queue`);
            console.log(`🎯 Assigned to node: ${assignedNode}`);
        }
        catch (error) {
            console.error("❌ Failed to publish task:", error.message);
        }
    }
    /**
     * Listen for task results from nodes
     */
    async listenForResults() {
        if (!this.rabbitmqChannel) {
            console.error("❌ RabbitMQ channel not initialized");
            return;
        }
        console.log("\n📥 Listening for task results...");
        await this.rabbitmqChannel.consume(this.RESULT_QUEUE, (msg) => {
            if (msg) {
                try {
                    const result = JSON.parse(msg.content.toString());
                    console.log(`\n✅ Task #${result.taskId} completed`);
                    console.log(`👤 Node: ${result.nodeId}`);
                    console.log(`💡 Answer: ${result.answer}`);
                    this.rabbitmqChannel?.ack(msg);
                }
                catch (error) {
                    console.error("❌ Error processing result:", error.message);
                    this.rabbitmqChannel?.nack(msg, false, false);
                }
            }
        }, { noAck: false });
    }
    /**
     * Register a node in the control plane
     */
    async registerNode(nodeId) {
        if (!this.nodeList.includes(nodeId)) {
            this.nodeList.push(nodeId);
            console.log(`✅ Node registered: ${nodeId}`);
            console.log(`📊 Total nodes: ${this.nodeList.length}`);
        }
    }
    /**
     * Listen to blockchain for new tasks
     */
    async startListening() {
        console.log("\n👂 Listening for TaskCreated events on blockchain...");
        console.log("Press Ctrl+C to stop\n");
        // Listen for TaskCreated events
        this.contract.on("TaskCreated", async (taskId, question, timestamp) => {
            console.log("\n🔔 New task detected on blockchain!");
            console.log("Task ID:", taskId.toString());
            console.log("Question:", question);
            console.log("Time:", new Date(Number(timestamp) * 1000).toLocaleString());
            const task = {
                taskId: taskId.toString(),
                question,
                timestamp: Number(timestamp),
            };
            await this.publishTask(task);
        });
        // Keep the process running
        process.on("SIGINT", async () => {
            console.log("\n\n👋 Shutting down Control Plane...");
            if (this.rabbitmqConnection) {
                try {
                    // Close the connection properly
                    if (this.rabbitmqChannel) {
                        await this.rabbitmqChannel.close();
                    }
                    await this.rabbitmqConnection.close();
                }
                catch (error) {
                    console.error("Error closing RabbitMQ connection:", error);
                }
            }
            process.exit(0);
        });
    }
    /**
     * Initialize and start the control plane
     */
    async start() {
        try {
            await this.connectRabbitMQ();
            // Start a simple HTTP server for node registration (optional)
            this.startRegistrationEndpoint();
            await this.listenForResults();
            await this.startListening();
        }
        catch (error) {
            console.error("❌ Failed to start Control Plane:", error.message);
            process.exit(1);
        }
    }
    /**
     * Start a simple registration endpoint (via RabbitMQ)
     */
    async startRegistrationEndpoint() {
        if (!this.rabbitmqChannel)
            return;
        const REGISTRATION_QUEUE = "depin_node_registration";
        await this.rabbitmqChannel.assertQueue(REGISTRATION_QUEUE, {
            durable: false,
        });
        console.log("\n📝 Node registration endpoint active");
        await this.rabbitmqChannel.consume(REGISTRATION_QUEUE, (msg) => {
            if (msg) {
                try {
                    const { nodeId } = JSON.parse(msg.content.toString());
                    this.registerNode(nodeId);
                    this.rabbitmqChannel?.ack(msg);
                }
                catch (error) {
                    console.error("❌ Error registering node:", error.message);
                    this.rabbitmqChannel?.nack(msg, false, false);
                }
            }
        }, { noAck: false });
    }
}
// Main execution
async function main() {
    console.log("🌟 Starting DEPIN Control Plane...\n");
    const controlPlane = new ControlPlane();
    await controlPlane.start();
}
// Run the application
main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
});
