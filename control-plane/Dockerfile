# Control Plane Dockerfile
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

# Expose port (if needed for health checks)
EXPOSE 3000

# Start the control plane
CMD ["npm", "start"]
