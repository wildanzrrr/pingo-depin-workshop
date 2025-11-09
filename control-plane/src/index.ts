import { ethers } from "ethers";
import * as amqp from "amqplib";
import * as dotenv from "dotenv";
import * as path from "path";
import { DePINNetworkABI } from "./abi";

// Load environment variables from root directory
dotenv.config({ path: path.resolve(__dirname, "../../.env") });

interface Task {
  taskId: string;
  question: string;
  timestamp: number;
}

class ControlPlane {
  private provider: ethers.JsonRpcProvider;
  private contract: ethers.Contract;
  private rabbitmqConnection: any = null;
  private rabbitmqChannel: amqp.Channel | null = null;
  private readonly TASK_QUEUE = "depin_tasks";
  private readonly RESULT_QUEUE = "depin_results";
  private nodeList: string[] = [];
  private currentNodeIndex = 0;

  constructor() {
    // Initialize provider
    const rpcUrl = process.env.RPC_URL || "http://host.docker.internal:8545";
    this.provider = new ethers.JsonRpcProvider(rpcUrl);

    // Initialize contract
    const contractAddress = process.env.CONTRACT_ADDRESS;
    if (!contractAddress) {
      throw new Error("CONTRACT_ADDRESS not set in .env file");
    }
    this.contract = new ethers.Contract(
      contractAddress,
      DePINNetworkABI,
      this.provider
    );

    console.log("🎛️  Control Plane initialized");
    console.log("📍 RPC URL:", rpcUrl);
    console.log("📍 Contract Address:", contractAddress);
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
   * Get next node using round-robin algorithm
   */
  private getNextNode(): string | null {
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
  async publishTask(task: Task): Promise<void> {
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
      this.rabbitmqChannel.sendToQueue(
        this.TASK_QUEUE,
        Buffer.from(JSON.stringify(message)),
        {
          persistent: true,
        }
      );

      console.log(`📤 Task #${task.taskId} published to queue`);
      console.log(`🎯 Assigned to node: ${assignedNode}`);
    } catch (error: any) {
      console.error("❌ Failed to publish task:", error.message);
    }
  }

  /**
   * Listen for task results from nodes
   */
  async listenForResults(): Promise<void> {
    if (!this.rabbitmqChannel) {
      console.error("❌ RabbitMQ channel not initialized");
      return;
    }

    console.log("\n📥 Listening for task results...");

    await this.rabbitmqChannel.consume(
      this.RESULT_QUEUE,
      (msg) => {
        if (msg) {
          try {
            const result = JSON.parse(msg.content.toString());
            console.log(`\n✅ Task #${result.taskId} completed`);
            console.log(`👤 Node: ${result.nodeId}`);
            console.log(`💡 Answer: ${result.answer}`);

            this.rabbitmqChannel?.ack(msg);
          } catch (error: any) {
            console.error("❌ Error processing result:", error.message);
            this.rabbitmqChannel?.nack(msg, false, false);
          }
        }
      },
      { noAck: false }
    );
  }

  /**
   * Register a node in the control plane
   */
  async registerNode(nodeId: string): Promise<void> {
    if (!this.nodeList.includes(nodeId)) {
      this.nodeList.push(nodeId);
      console.log(`✅ Node registered: ${nodeId}`);
      console.log(`📊 Total nodes: ${this.nodeList.length}`);
    }
  }

  /**
   * Listen to blockchain for new tasks
   */
  async startListening(): Promise<void> {
    console.log("\n👂 Listening for TaskCreated events on blockchain...");
    console.log("Press Ctrl+C to stop\n");

    // Listen for TaskCreated events
    this.contract.on(
      "TaskCreated",
      async (taskId: bigint, question: string, timestamp: bigint) => {
        console.log("\n🔔 New task detected on blockchain!");
        console.log("Task ID:", taskId.toString());
        console.log("Question:", question);
        console.log(
          "Time:",
          new Date(Number(timestamp) * 1000).toLocaleString()
        );

        const task: Task = {
          taskId: taskId.toString(),
          question,
          timestamp: Number(timestamp),
        };

        await this.publishTask(task);
      }
    );

    // Keep the process running
    process.on("SIGINT", async () => {
      console.log("\n\n👋 Shutting down Control Plane...");
      if (this.rabbitmqConnection) {
        try {
          // Close the connection properly
          if (this.rabbitmqChannel) {
            await this.rabbitmqChannel.close();
          }
          await (this.rabbitmqConnection as any).close();
        } catch (error) {
          console.error("Error closing RabbitMQ connection:", error);
        }
      }
      process.exit(0);
    });
  }

  /**
   * Initialize and start the control plane
   */
  async start(): Promise<void> {
    try {
      await this.connectRabbitMQ();

      // Start a simple HTTP server for node registration (optional)
      this.startRegistrationEndpoint();

      await this.listenForResults();
      await this.startListening();
    } catch (error: any) {
      console.error("❌ Failed to start Control Plane:", error.message);
      process.exit(1);
    }
  }

  /**
   * Start a simple registration endpoint (via RabbitMQ)
   */
  private async startRegistrationEndpoint(): Promise<void> {
    if (!this.rabbitmqChannel) return;

    const REGISTRATION_QUEUE = "depin_node_registration";
    await this.rabbitmqChannel.assertQueue(REGISTRATION_QUEUE, {
      durable: false,
    });

    console.log("\n📝 Node registration endpoint active");

    await this.rabbitmqChannel.consume(
      REGISTRATION_QUEUE,
      (msg) => {
        if (msg) {
          try {
            const { nodeId } = JSON.parse(msg.content.toString());
            this.registerNode(nodeId);
            this.rabbitmqChannel?.ack(msg);
          } catch (error: any) {
            console.error("❌ Error registering node:", error.message);
            this.rabbitmqChannel?.nack(msg, false, false);
          }
        }
      },
      { noAck: false }
    );
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
