#!/bin/bash

set -e

# Wait for the contract addresses file to be available
while [ ! -f /app/data/contract_addresses.env ]; do
  echo "Waiting for contract_addresses.env..."
  sleep 5
done

# Source the contract addresses
source /app/data/contract_addresses.env

echo "TAIKO_L1_ADDRESS= $TAIKO_L1_ADDRESS"
echo "TAIKO_L2_ADDRESS= $TAIKO_L2_ADDRESS"
echo "TAIKO_TOKEN_ADDRESS= $TAIKO_TOKEN_ADDRESS"

# Proceed based on the first argument
if [ "$1" == "driver" ]; then
  shift
  exec ./bin/taiko-client driver \
    --l1.ws ws://host.docker.internal:32003 \
    --l1.beacon http://host.docker.internal:33001 \
    --l2.ws ws://unifi-geth:8546 \
    --taikoL1 $TAIKO_L1_ADDRESS \
    --taikoL2 $TAIKO_L2_ADDRESS \
    --jwtSecret /app/jwt.txt \
    --l2.auth http://unifi-geth:8551/ \
    --verbosity 5 "$@"
elif [ "$1" == "proposer" ]; then
  shift
  exec ./bin/taiko-client proposer \
    --l1.ws ws://host.docker.internal:32003 \
    --l2.http http://unifi-geth:8545 \
    --l2.auth http://unifi-geth:8551 \
    --taikoL1 $TAIKO_L1_ADDRESS \
    --taikoL2 $TAIKO_L2_ADDRESS \
    --taikoToken $TAIKO_TOKEN_ADDRESS \
    --jwtSecret /app/jwt.txt \
    --l1.proposerPrivKey 0xc5114526e042343c6d1899cad05e1c00ba588314de9b96929914ee0df18d46b2 \
    --l2.suggestedFeeRecipient 0xD8F3183DEF51A987222D845be228e0Bbb932C222 \
    --verbosity 5 "$@"
else
  echo "Unknown command: $1"
  exit 1
fi
