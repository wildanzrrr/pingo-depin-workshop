#!/bin/bash
set -e

# Install system dependencies
echo "Installing system dependencies..."
sudo apt-get update
sudo apt-get install -y lcov

# Install Foundry
echo "Installing Foundry..."
curl -L https://foundry.paradigm.xyz | bash

# Add foundry to PATH for this session
export PATH="$PATH:$HOME/.foundry/bin"

# Run foundryup to install forge, cast, anvil, and chisel
echo "Running foundryup..."
$HOME/.foundry/bin/foundryup

# Verify installation
echo "Verifying Foundry installation..."
if command -v forge &> /dev/null; then
    echo "✓ Foundry installed successfully!"
    forge --version
else
    echo "✗ Foundry installation failed"
    exit 1
fi
