#!/bin/bash

set -e

GENESIS_ALLOC_FILE="/app/unifi-geth/core/taiko_genesis/unifi_l2.json"

if [ ! -f "$GENESIS_ALLOC_FILE" ]; then
  echo "Error: File $GENESIS_ALLOC_FILE not found!"
  exit 1
fi

# Install dependencies and compile contracts
cd /app/unifi-mono/packages/protocol
echo "Installing dependencies and compiling contracts..."
pnpm install
pnpm compile

# Set environment variables needed for deployment
export PRIVATE_KEY=0xc5114526e042343c6d1899cad05e1c00ba588314de9b96929914ee0df18d46b2
export L1_RPC_URL=http://host.docker.internal:32002
export L2_RPC_URL=http://unifi-geth:8545
# Wait for L1 RPC to be available
echo "Waiting for L1 RPC to be available..."
until curl -s $L1_RPC_URL > /dev/null; do
  sleep 5
  echo "Retrying..."
done
echo "L1 RPC is available."

# Obtain L2 genesis hash
echo "Obtaining L2 genesis hash..."
L2_GENESIS_HASH=$(curl -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_getBlockByNumber","params":["0x0", false],"id":1}' $L2_RPC_URL | jq -r '.result.hash')
echo "L2_GENESIS_HASH: $L2_GENESIS_HASH"
L1_CHAIN_ID=$(curl -s -X POST -H "Content-Type: application/json" --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' $L1_RPC_URL | jq -r '.result' | xargs printf "%d");
echo "L1_CHAIN_ID: $L1_CHAIN_ID"

# Extract TAIKO_L2_ADDRESS and L2_SIGNAL_SERVICE from genesis_alloc.json
GENESIS_ALLOC_FILE="/app/unifi-geth/core/taiko_genesis/unifi_l2.json"
echo "Extracting TAIKO_L2_ADDRESS and L2_SIGNAL_SERVICE from $GENESIS_ALLOC_FILE"
TAIKO_L2_ADDRESS=$(jq -r '. | to_entries[] | select(.value.contractName != null and .value.contractName == "TaikoL2") | .key' "$GENESIS_ALLOC_FILE")
L2_SIGNAL_SERVICE=$(jq -r '. | to_entries[] | select(.value.contractName != null and .value.contractName == "SignalService") | .key' "$GENESIS_ALLOC_FILE")
echo "TAIKO_L2_ADDRESS: $TAIKO_L2_ADDRESS"
echo "L2_SIGNAL_SERVICE: $L2_SIGNAL_SERVICE"

# Set other environment variables
export GUARDIAN_PROVERS="0xD8F3183DEF51A987222D845be228e0Bbb932C222,0xE25583099BA105D9ec0A67f5Ae86D90e50036425"
export CONTRACT_OWNER=0xD8F3183DEF51A987222D845be228e0Bbb932C222
export PROVER_SET_ADMIN=0xD8F3183DEF51A987222D845be228e0Bbb932C222
export TAIKO_TOKEN_PREMINT_RECIPIENT=0xD8F3183DEF51A987222D845be228e0Bbb932C222
export PROPOSER=0x0000000000000000000000000000000000000000
export PROPOSER_ONE=0x0000000000000000000000000000000000000000
export TAIKO_TOKEN_NAME="Taiko Token Test"
export TAIKO_TOKEN_SYMBOL=TTKOk
export SHARED_ADDRESS_MANAGER=0x0000000000000000000000000000000000000000
export TAIKO_TOKEN=0x0000000000000000000000000000000000000000
export PAUSE_TAIKO_L1=false
export PAUSE_BRIDGE=false
export BLOCK_GAS_LIMIT=200000000
export NUM_MIN_MAJORITY_GUARDIANS=2
export NUM_MIN_MINORITY_GUARDIANS=2
export TIER_PROVIDER="devnet"
export FOUNDRY_PROFILE="layer1"
export TAIKO_L2_ADDRESS=$TAIKO_L2_ADDRESS
export L2_SIGNAL_SERVICE=$L2_SIGNAL_SERVICE
export L2_GENESIS_HASH=$L2_GENESIS_HASH

# Run the deployment script
echo "Deploying L1 contracts..."

forge script ./script/layer1/DeployProtocolOnL1.s.sol:DeployProtocolOnL1 \
    --fork-url $L1_RPC_URL \
    --broadcast \
    --ffi \
    -vvvv \
    --private-key $PRIVATE_KEY \
    --block-gas-limit $BLOCK_GAS_LIMIT

# Extract contract addresses
echo "Extracting contract addresses..."
DEPLOYMENT_OUTPUT_FILE="/app/unifi-mono/packages/protocol/broadcast/DeployProtocolOnL1.s.sol/$L1_CHAIN_ID/run-latest.json"

TAIKO_IMPLEMENTATION_ADDRESS=$(jq -r '
  .. | objects
  | select(.contractName? == "DevnetTaikoL1" and .contractAddress != null)
  | .contractAddress
' "$DEPLOYMENT_OUTPUT_FILE")

echo "Taiko L1 Implementation Address: $TAIKO_IMPLEMENTATION_ADDRESS"

TAIKO_PROXY_ADDRESS=$(jq -r --arg impl "$TAIKO_IMPLEMENTATION_ADDRESS" '
  .. | objects
  | select(
      .contractName? == "ERC1967Proxy"
      and .arguments? != null
      and (.arguments[0]? | ascii_downcase) == ($impl | ascii_downcase)
      and .contractAddress != null
    )
  | .contractAddress
' "$DEPLOYMENT_OUTPUT_FILE")

echo "Taiko L1 Proxy Address: $TAIKO_PROXY_ADDRESS"

TAIKO_TOKEN_IMPLEMENTATION_ADDRESS=$(jq -r '
  .. | objects
  | select(.contractName? == "TaikoToken" and .contractAddress != null)
  | .contractAddress
' "$DEPLOYMENT_OUTPUT_FILE")

echo "Taiko Token Implementation Address: $TAIKO_TOKEN_IMPLEMENTATION_ADDRESS"

# Step 2: Get the proxy address using the implementation address
TAIKO_TOKEN_PROXY_ADDRESS=$(jq -r --arg impl "$TAIKO_TOKEN_IMPLEMENTATION_ADDRESS" '
  .. | objects
  | select(
      .contractName? == "ERC1967Proxy"
      and .arguments? != null
      and (.arguments[0]? | ascii_downcase) == ($impl | ascii_downcase)
      and .contractAddress != null
    )
  | .contractAddress
' "$DEPLOYMENT_OUTPUT_FILE")

echo "Taiko Token  Proxy Address: $TAIKO_TOKEN_PROXY_ADDRESS"

# Approve Taiko Token
echo "Approving Taiko Token..."

# Set environment variables
export TAIKO_L1_ADDRESS=$TAIKO_PROXY_ADDRESS
export TAIKO_TOKEN_ADDRESS=$TAIKO_TOKEN_PROXY_ADDRESS
export PRIVATE_KEY=0xc5114526e042343c6d1899cad05e1c00ba588314de9b96929914ee0df18d46b2
export SENDER_ADDRESS=0xD8F3183DEF51A987222D845be228e0Bbb932C222
export L1_RPC_URL=http://host.docker.internal:32002

# Install Python dependencies
pip3 install web3 eth_account

# Run the Python script
python3 /app/approve_taiko_token.py

# Save the addresses to environment files for later use
echo "Saving contract addresses..."
echo "TAIKO_L1_ADDRESS=$TAIKO_PROXY_ADDRESS" > /app/data/contract_addresses.env
echo "TAIKO_L2_ADDRESS=$TAIKO_L2_ADDRESS" >> /app/data/contract_addresses.env
echo "TAIKO_TOKEN_ADDRESS=$TAIKO_TOKEN_PROXY_ADDRESS" >> /app/data/contract_addresses.env

chmod 644 /app/data/contract_addresses.env
echo "Contract addresses saved to /app/data/contract_addresses.env"
