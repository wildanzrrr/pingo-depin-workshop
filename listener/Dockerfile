# Node Dockerfile
FROM node:20-slim

WORKDIR /app

# Copy package files
COPY package*.json ./
COPY tsconfig.json ./

# Install dependencies
RUN npm install

# Copy source code
COPY src ./src

# Build TypeScript
RUN npm run build

# Start the node (using the RabbitMQ version)
CMD ["node", "dist/index-rabbitmq.js"]
