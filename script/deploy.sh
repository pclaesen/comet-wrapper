#!/bin/bash

set -exo pipefail

if [ -n "$RPC_URL" ]; then
  rpc_args="--rpc-url $RPC_URL"
else
  rpc_args=""
fi

if [ -n "$DEPLOYER_PK" ]; then
  wallet_args="--private-key $DEPLOYER_PK"
else
  wallet_args="--unlocked"
fi

if [ -n "$ETHERSCAN_KEY" ]; then
  etherscan_args="--verify --etherscan-api-key $ETHERSCAN_KEY"
else
  etherscan_args=""
fi

# Check for required environment variables
required_vars=("COMET_ADDRESS" "REWARDS_ADDRESS" "PROXY_ADMIN_ADDRESS" "TOKEN_NAME" "TOKEN_SYMBOL" "CHAIN_ID")
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "$var is not set"
    exit 1
  fi
done

# Run the Forge script
forge script \
    $rpc_args \
    $wallet_args \
    $etherscan_args \
    --broadcast \
    $@ \
    script/DeployCometWrapper.s.sol:DeployCometWrapper

# Check if verification is enabled
if [ -n "$ETHERSCAN_KEY" ]; then
  # Extract the deployed contract address from the Forge output
  deployed_address=$(grep -oP 'Contract Address: \K[0-9a-fA-F]{40}' forge-output.txt)
  
  if [ -n "$deployed_address" ]; then
    echo "Waiting for contract verification..."
    
    # Loop until verification is successful or timeout occurs
    timeout=300  # 5 minutes timeout
    start_time=$(date +%s)
    
    while true; do
      verification_status=$(forge verify-contract $deployed_address DeployCometWrapper --chain-id $CHAIN_ID --etherscan-api-key $ETHERSCAN_KEY --watch)
      
      if [[ $verification_status == *"Contract successfully verified"* ]]; then
        echo "Contract successfully verified!"
        break
      fi
      
      current_time=$(date +%s)
      elapsed_time=$((current_time - start_time))
      
      if [ $elapsed_time -ge $timeout ]; then
        echo "Verification timed out after ${timeout} seconds."
        exit 1
      fi
      
      sleep 10  # Wait for 10 seconds before checking again
    done
  else
    echo "Failed to extract deployed contract address."
    exit 1
  fi
else
  echo "Verification skipped (ETHERSCAN_KEY not set)."
fi