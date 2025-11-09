import { ethers } from "ethers";
import OpenAI from "openai";
import * as dotenv from "dotenv";
import * as path from "path";
import * as amqp from "amqplib";
import { DePINNetworkABI } from "./abi";

// Load environment variables from root directory
dotenv.config({ path: path.resolve(__dirname, "../../.env") });

interface TaskMessage {
  taskId: string;
  question: string;
  timestamp: number;
  assignedNode: string;
}

interface TaskResult {
  taskId: string;
  nodeId: string;
  answer: string;
  completedAt: number;
}

class DePINNode {
  private provider: ethers.JsonRpcProvider;
  private wallet: ethers.Wallet;
  private contract: ethers.Contract;
  private openai: OpenAI;
  private nodeName: string;
  private nodeId: string;
  private isRegistered: boolean = false;
  private rabbitmqConnection: any = null;
  private rabbitmqChannel: amqp.Channel | null = null;
  private readonly TASK_QUEUE = "depin_tasks";
  private readonly RESULT_QUEUE = "depin_results";
  private readonly REGISTRATION_QUEUE = "depin_node_registration";

  constructor() {
    // Initialize provider
    const rpcUrl = process.env.RPC_URL || "http://host.docker.internal:8545";
    this.provider = new ethers.JsonRpcProvider(rpcUrl);

    // Initialize wallet
    const privateKey = process.env.NODE_PRIVATE_KEY;
    if (!privateKey) {
      throw new Error("NODE_PRIVATE_KEY not set in .env file");
    }
    this.wallet = new ethers.Wallet(privateKey, this.provider);

    // Initialize contract
    const contractAddress = process.env.CONTRACT_ADDRESS;
    if (!contractAddress) {
      throw new Error("CONTRACT_ADDRESS not set in .env file");
    }
    this.contract = new ethers.Contract(
      contractAddress,
      DePINNetworkABI,
      this.wallet
    );

    // Initialize OpenAI
    const openaiKey = process.env.OPENAI_API_KEY;
    if (!openaiKey || openaiKey === "your_openai_api_key_here") {
      throw new Error("OPENAI_API_KEY not set properly in .env file");
    }
    this.openai = new OpenAI({ apiKey: openaiKey });

    // Node info
    this.nodeName = process.env.NODE_NAME || "AI_Node";
    this.nodeId = process.env.NODE_ID || `node_${this.wallet.address.slice(0, 8)}`;

    console.log("🚀 DEPIN Node initialized");
    console.log("📍 RPC URL:", rpcUrl);
    console.log("📍 Contract Address:", contractAddress);
    console.log("👤 Node Address:", this.wallet.address);
    console.log("🏷️  Node Name:", this.nodeName);
    console.log("🆔 Node ID:", this.nodeId);
  }

  /**
   * Connect to RabbitMQ
   */
  async connectRabbitMQ(): Promise<void> {
    const rabbitmqUrl =
      process.env.RABBITMQ_URL || "amqp://guest:guest@rabbitmq:5672";

    console.log("\n🐰 Connecting to RabbitMQ:", rabbitmqUrl);

    let retries = 5;
    while (retries > 0) {
      try {
        this.rabbitmqConnection = await amqp.connect(rabbitmqUrl);
        this.rabbitmqChannel = await this.rabbitmqConnection.createChannel();

        // Set prefetch to 1 to ensure fair distribution
        if (this.rabbitmqChannel) {
          await this.rabbitmqChannel.prefetch(1);

          // Declare queues
          await this.rabbitmqChannel.assertQueue(this.TASK_QUEUE, {
            durable: true,
          });
          await this.rabbitmqChannel.assertQueue(this.RESULT_QUEUE, {
            durable: true,
          });
          await this.rabbitmqChannel.assertQueue(this.REGISTRATION_QUEUE, {
            durable: false,
          });
        }

        console.log("✅ Connected to RabbitMQ");

        // Handle connection errors
        if (this.rabbitmqConnection) {
          this.rabbitmqConnection.on("error", (err: Error) => {
            console.error("❌ RabbitMQ connection error:", err);
          });

          this.rabbitmqConnection.on("close", () => {
            console.log("⚠️  RabbitMQ connection closed, reconnecting...");
            setTimeout(() => this.connectRabbitMQ(), 5000);
          });
        }

        return;
      } catch (error: any) {
        retries--;
        console.log(
          `⚠️  Failed to connect to RabbitMQ, retrying... (${retries} attempts left)`
        );
        if (retries === 0) {
          throw new Error(`Failed to connect to RabbitMQ: ${error.message}`);
        }
        await new Promise((resolve) => setTimeout(resolve, 5000));
      }
    }
  }

  /**
   * Register this node with the Control Plane
   */
  async registerWithControlPlane(): Promise<void> {
    if (!this.rabbitmqChannel) {
      throw new Error("RabbitMQ not connected");
    }

    try {
      console.log("\n📝 Registering with Control Plane...");

      const message = {
        nodeId: this.nodeId,
        nodeName: this.nodeName,
        nodeAddress: this.wallet.address,
      };

      this.rabbitmqChannel.sendToQueue(
        this.REGISTRATION_QUEUE,
        Buffer.from(JSON.stringify(message))
      );

      console.log("✅ Registered with Control Plane");
    } catch (error: any) {
      console.error("❌ Failed to register with Control Plane:", error.message);
      throw error;
    }
  }

  /**
   * Register this node with the blockchain
   */
  async registerNode(): Promise<void> {
    try {
      console.log("\n📝 Registering node on blockchain...");

      // Check if already registered
      const isActive = await this.contract.isNodeActive(this.wallet.address);
      if (isActive) {
        console.log("✅ Node already registered and active on blockchain");
        this.isRegistered = true;
        return;
      }

      // Register the node
      const tx = await this.contract.registerNode(this.nodeName);
      console.log("⏳ Transaction sent:", tx.hash);

      await tx.wait();
      console.log("✅ Node registered on blockchain successfully!");
      this.isRegistered = true;

      // Display node info
      const [nodeName, , registeredAt, tasksCompleted] =
        await this.contract.getNodeInfo(this.wallet.address);
      console.log("📊 Node Info:");
      console.log("   Name:", nodeName);
      console.log(
        "   Registered at:",
        new Date(Number(registeredAt) * 1000).toLocaleString()
      );
      console.log("   Tasks completed:", tasksCompleted.toString());
    } catch (error: any) {
      console.error("❌ Failed to register node:", error.message);
      throw error;
    }
  }

  /**
   * Use OpenAI to answer a question
   */
  async answerQuestion(question: string): Promise<string> {
    try {
      console.log("🤖 Asking OpenAI:", question);

      const completion = await this.openai.chat.completions.create({
        model: "gpt-4o",
        messages: [
          {
            role: "system",
            content:
              "You are a helpful assistant. Provide concise and accurate answers to questions.",
          },
          {
            role: "user",
            content: question,
          },
        ],
        max_tokens: 150,
        temperature: 0.7,
      });

      const answer =
        completion.choices[0]?.message?.content || "No answer generated";
      console.log("💡 AI Answer:", answer);

      return answer;
    } catch (error: any) {
      console.error("❌ OpenAI error:", error.message);
      return `Error: Unable to generate answer - ${error.message}`;
    }
  }

  /**
   * Process a task from the queue
   */
  async processTask(taskMessage: TaskMessage): Promise<void> {
    try {
      console.log(`\n🎯 Processing Task #${taskMessage.taskId}`);
      console.log("❓ Question:", taskMessage.question);
      console.log("🆔 Assigned to:", taskMessage.assignedNode);

      // Verify this task is assigned to this node
      if (taskMessage.assignedNode !== this.nodeId) {
        console.log("⚠️  Task not assigned to this node, skipping...");
        return;
      }

      const taskId = BigInt(taskMessage.taskId);

      // Check if task is already completed
      const [, , assignedNode, isCompleted] = await this.contract.getTaskResult(
        taskId
      );

      if (isCompleted) {
        console.log("⚠️  Task already completed, skipping...");
        return;
      }

      // Assign task if not already assigned on blockchain
      if (assignedNode === ethers.ZeroAddress) {
        console.log("📌 Assigning task to this node on blockchain...");
        const assignTx = await this.contract.assignTask(taskId);
        await assignTx.wait();
        console.log("✅ Task assigned on blockchain");
      }

      // Get answer from AI
      const answer = await this.answerQuestion(taskMessage.question);

      // Submit answer to blockchain
      console.log("📤 Submitting answer to blockchain...");
      const completeTx = await this.contract.completeTask(taskId, answer);
      console.log("⏳ Transaction sent:", completeTx.hash);

      await completeTx.wait();
      console.log("✅ Task completed on blockchain!");

      // Send result back to control plane
      await this.sendResult({
        taskId: taskMessage.taskId,
        nodeId: this.nodeId,
        answer,
        completedAt: Date.now(),
      });

      // Get updated node stats
      const [, , , tasksCompleted] = await this.contract.getNodeInfo(
        this.wallet.address
      );
      console.log("📊 Total tasks completed:", tasksCompleted.toString());
    } catch (error: any) {
      console.error(
        `❌ Failed to process task #${taskMessage.taskId}:`,
        error.message
      );
    }
  }

  /**
   * Send task result back to control plane
   */
  async sendResult(result: TaskResult): Promise<void> {
    if (!this.rabbitmqChannel) {
      console.error("❌ RabbitMQ channel not initialized");
      return;
    }

    try {
      this.rabbitmqChannel.sendToQueue(
        this.RESULT_QUEUE,
        Buffer.from(JSON.stringify(result)),
        {
          persistent: true,
        }
      );

      console.log(`📤 Result sent to Control Plane for Task #${result.taskId}`);
    } catch (error: any) {
      console.error("❌ Failed to send result:", error.message);
    }
  }

  /**
   * Start consuming tasks from RabbitMQ
   */
  async startListening(): Promise<void> {
    if (!this.isRegistered || !this.rabbitmqChannel) {
      console.error("❌ Node not properly initialized");
      return;
    }

    console.log("\n👂 Listening for tasks from Control Plane...");
    console.log("Press Ctrl+C to stop\n");

    await this.rabbitmqChannel.consume(
      this.TASK_QUEUE,
      async (msg) => {
        if (msg) {
          try {
            const taskMessage: TaskMessage = JSON.parse(
              msg.content.toString()
            );

            console.log("\n🔔 New task received from queue!");
            console.log("Task ID:", taskMessage.taskId);
            console.log(
              "Time:",
              new Date(taskMessage.timestamp * 1000).toLocaleString()
            );

            await this.processTask(taskMessage);

            // Acknowledge the message after processing
            this.rabbitmqChannel?.ack(msg);
          } catch (error: any) {
            console.error("❌ Error processing task:", error.message);
            // Reject and requeue the message
            this.rabbitmqChannel?.nack(msg, false, true);
          }
        }
      },
      { noAck: false }
    );

    // Keep the process running
    process.on("SIGINT", async () => {
      console.log("\n\n👋 Shutting down node...");
      if (this.rabbitmqConnection) {
        try {
          if (this.rabbitmqChannel) {
            await this.rabbitmqChannel.close();
          }
          await this.rabbitmqConnection.close();
        } catch (error) {
          console.error("Error closing RabbitMQ connection:", error);
        }
      }
      process.exit(0);
    });
  }

  /**
   * Initialize and start the node
   */
  async start(): Promise<void> {
    try {
      await this.connectRabbitMQ();
      await this.registerNode();
      await this.registerWithControlPlane();
      await this.startListening();
    } catch (error: any) {
      console.error("❌ Failed to start node:", error.message);
      process.exit(1);
    }
  }
}

// Main execution
async function main() {
  console.log("🌟 Starting DEPIN Node...\n");

  const node = new DePINNode();
  await node.start();
}

// Run the application
main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
