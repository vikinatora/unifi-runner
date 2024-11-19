#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# Navigate to the protocol directory
cd /app/unifi-mono/packages/protocol

# Install dependencies and compile contracts
echo "Installing dependencies and compiling contracts..."
pnpm install
pnpm compile

# Set environment variables needed for deployment
export PRIVATE_KEY=0xc5114526e042343c6d1899cad05e1c00ba588314de9b96929914ee0df18d46b2
export L1_RPC_URL=http://host.docker.internal:32002

# Run the deployment script
echo "Deploying L1 contracts..."
pnpm test:deploy:l1

# Define the path to the deployment output file
DEPLOYMENT_OUTPUT_DIR="/app/unifi-mono/packages/protocol/broadcast"
LATEST_RUN_DIR=$(ls -td $DEPLOYMENT_OUTPUT_DIR/*/ | head -1)
DEPLOYMENT_OUTPUT_FILE="$LATEST_RUN_DIR/run-latest.json"

echo "Parsing deployment output from $DEPLOYMENT_OUTPUT_FILE..."

# Check if the deployment output file exists
if [ ! -f "$DEPLOYMENT_OUTPUT_FILE" ]; then
    echo "Deployment output file not found: $DEPLOYMENT_OUTPUT_FILE"
    exit 1
fi

# Extract contract addresses using jq
TAIKO_L1_ADDRESS=$(jq -r '.transactions[] | select(.contractName=="ERC1967Proxy" and .metadata.contractName=="DevnetTaikoL1") | .contractAddress' "$DEPLOYMENT_OUTPUT_FILE")
TAIKO_TOKEN_ADDRESS=$(jq -r '.transactions[] | select(.contractName=="ERC1967Proxy" and .metadata.contractName=="TaikoToken") | .contractAddress' "$DEPLOYMENT_OUTPUT_FILE")

if [ -z "$TAIKO_L1_ADDRESS" ] || [ -z "$TAIKO_TOKEN_ADDRESS" ]; then
    echo "Failed to extract contract addresses."
    exit 1
fi

echo "TaikoL1 Proxy Address: $TAIKO_L1_ADDRESS"
echo "TaikoToken Proxy Address: $TAIKO_TOKEN_ADDRESS"

# Extract TaikoL2 address from genesis_alloc.json
GENESIS_ALLOC_FILE="/app/unifi-geth/core/taiko_genesis/unifi_l2.json"
TAIKO_L2_ADDRESS=$(jq -r '.alloc | to_entries[] | select(.value.contractName=="TaikoL2") | .key' "$GENESIS_ALLOC_FILE")

if [ -z "$TAIKO_L2_ADDRESS" ]; then
    echo "Failed to extract TaikoL2 address."
    exit 1
fi

echo "TaikoL2 Address: $TAIKO_L2_ADDRESS"

# Save the addresses to environment files for later use
echo "TAIKO_L1_ADDRESS=$TAIKO_L1_ADDRESS" > /app/data/contract_addresses.env
echo "TAIKO_TOKEN_ADDRESS=$TAIKO_TOKEN_ADDRESS" >> /app/data/contract_addresses.env
echo "TAIKO_L2_ADDRESS=$TAIKO_L2_ADDRESS" >> /app/data/contract_addresses.env

# Ensure the file has appropriate permissions
chmod 644 /app/data/contract_addresses.env

echo "Contract addresses saved to /app/data/contract_addresses.env"
