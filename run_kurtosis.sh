#!/bin/bash

# Ensure Kurtosis is installed
if ! command -v kurtosis &> /dev/null
then
    echo "Kurtosis not found. Installing Kurtosis..."
    curl -fsSL https://docs.kurtosis.com/install.sh | bash
fi

# Clean any existing enclaves to prevent conflicts
kurtosis clean -a

# Run the Kurtosis command
kurtosis run --enclave my-testnet github.com/ethpandaops/ethereum-package --args-file ./network_params.yaml
