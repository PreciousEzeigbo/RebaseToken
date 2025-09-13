#!/bin/bash

# Define constants 
AMOUNT=100000

# Set to "true" to skip ZKsync deployment and focus on Sepolia only
SKIP_ZKSYNC_DEPLOYMENT=${SKIP_ZKSYNC_DEPLOYMENT:-false}

DEFAULT_ZKSYNC_LOCAL_KEY="0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110"
DEFAULT_ZKSYNC_ADDRESS="0x36615Cf349d7F6344891B1e7CA7C72883F5dc049"

ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM="0x3139687Ee9938422F57933C3CDB3E21EE43c4d0F"
ZKSYNC_TOKEN_ADMIN_REGISTRY="0xc7777f12258014866c677Bdb679D0b007405b7DF"
ZKSYNC_ROUTER="0xA1fdA8aa9A8C4b945C45aD30647b01f07D7A0B16"
ZKSYNC_RNM_PROXY_ADDRESS="0x3DA20FD3D8a8f8c1f1A5fD03648147143608C467"
ZKSYNC_SEPOLIA_CHAIN_SELECTOR="6898391096552792247"
ZKSYNC_LINK_ADDRESS="0x23A1aFD896c8c8876AF46aDc38521f4432658d1e"

SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM="0x62e731218d0D47305aba2BE3751E7EE9E5520790"
SEPOLIA_TOKEN_ADMIN_REGISTRY="0x95F29FEE11c5C55d26cCcf1DB6772DE953B37B82"
SEPOLIA_ROUTER="0x0BF3dE8c5D3e8A2B34D2BEeB17ABfCeBaf363A59"
SEPOLIA_RNM_PROXY_ADDRESS="0xba3f6251de62dED61Ff98590cB2fDf6871FbB991"
SEPOLIA_CHAIN_SELECTOR="16015286601757825753"
SEPOLIA_LINK_ADDRESS="0x779877A7B0D9E8603169DdbD7836e478b4624789"

# Compile and deploy the Rebase Token contract
source .env
forge build --zksync

# 1. ZKsync Deployment (optional)
if [ "$SKIP_ZKSYNC_DEPLOYMENT" = "false" ]; then
    echo "=== Skipping ZKsync Deployment ==="
    echo "Set SKIP_ZKSYNC_DEPLOYMENT=false to enable ZKsync deployment"
    ZKSYNC_REBASE_TOKEN_ADDRESS=""
    ZKSYNC_POOL_ADDRESS=""
else
    echo "=== ZKsync Deployment Phase ==="
    echo "Compiling and deploying the Rebase Token contract on ZKsync..."
    ZKSYNC_REBASE_TOKEN_ADDRESS=$(forge create src/RebaseToken.sol:RebaseToken --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount --legacy --zksync --broadcast | awk '/Deployed to:/ {print $3}')
    echo "ZKsync rebase token address: $ZKSYNC_REBASE_TOKEN_ADDRESS"

    # Check if deployment was successful
    if [ -z "$ZKSYNC_REBASE_TOKEN_ADDRESS" ]; then
        echo "Error: Failed to deploy ZKsync rebase token"
        exit 1
    fi

    # Compile and deploy the pool contract
    echo "Compiling and deploying the pool contract on ZKsync..."
    ZKSYNC_POOL_ADDRESS=$(forge create src/RebaseTokenPool.sol:RebaseTokenPool --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount --legacy --zksync --broadcast --constructor-args ${ZKSYNC_REBASE_TOKEN_ADDRESS} "[]" ${ZKSYNC_RNM_PROXY_ADDRESS} ${ZKSYNC_ROUTER} | awk '/Deployed to:/ {print $3}')
    echo "Pool address: $ZKSYNC_POOL_ADDRESS"

    # Check if pool deployment was successful
    if [ -z "$ZKSYNC_POOL_ADDRESS" ]; then
        echo "Error: Failed to deploy ZKsync pool"
        exit 1
    fi

    # Set the permissions for the pool contract
    echo "Setting the permissions for the pool contract on ZKsync..."
    cast send ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount "grantMintAndBurnRole(address)" ${ZKSYNC_POOL_ADDRESS}
    echo "Pool permissions set"

    # Set the CCIP roles and permissions
    echo "Setting the CCIP roles and permissions on ZKsync..."
    cast send ${ZKSYNC_REGISTRY_MODULE_OWNER_CUSTOM} "registerAdminViaOwner(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
    cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "acceptAdminRole(address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
    cast send ${ZKSYNC_TOKEN_ADMIN_REGISTRY} "setPool(address,address)" ${ZKSYNC_REBASE_TOKEN_ADDRESS} ${ZKSYNC_POOL_ADDRESS} --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount
    echo "CCIP roles and permissions set"
fi

# 2. On Sepolia!

echo ""
echo "=== Sepolia Deployment Phase ==="
echo "Deploying contracts individually to avoid rate limits..."

# Deploy RebaseToken
echo "Deploying RebaseToken on Sepolia..."
SEPOLIA_REBASE_TOKEN_ADDRESS=$(forge create src/RebaseToken.sol:RebaseToken --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast | awk '/Deployed to:/ {print $3}')
echo "Sepolia rebase token address: $SEPOLIA_REBASE_TOKEN_ADDRESS"

if [ -z "$SEPOLIA_REBASE_TOKEN_ADDRESS" ]; then
    echo "Error: Failed to deploy Sepolia rebase token"
    exit 1
fi

# Wait before next deployment
echo "Waiting 30 seconds before next deployment..."
sleep 30

# Deploy RebaseTokenPool
echo "Deploying RebaseTokenPool on Sepolia..."
SEPOLIA_POOL_ADDRESS=$(forge create src/RebaseTokenPool.sol:RebaseTokenPool --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --constructor-args ${SEPOLIA_REBASE_TOKEN_ADDRESS} "[]" ${SEPOLIA_RNM_PROXY_ADDRESS} ${SEPOLIA_ROUTER} | awk '/Deployed to:/ {print $3}')
echo "Sepolia pool address: $SEPOLIA_POOL_ADDRESS"

if [ -z "$SEPOLIA_POOL_ADDRESS" ]; then
    echo "Error: Failed to deploy Sepolia pool"
    exit 1
fi

# Wait before next transaction
echo "Waiting 15 seconds before setting permissions..."
sleep 15

# Grant mint and burn role to pool
echo "Granting mint and burn role to pool..."
cast send ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL} --account myaccount "grantMintAndBurnRole(address)" ${SEPOLIA_POOL_ADDRESS}

# Wait before next transaction
echo "Waiting 15 seconds before CCIP setup..."
sleep 15

# Set up CCIP permissions
echo "Setting up CCIP permissions..."
cast send ${SEPOLIA_REGISTRY_MODULE_OWNER_CUSTOM} "registerAdminViaOwner(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL} --account myaccount

sleep 10
cast send ${SEPOLIA_TOKEN_ADMIN_REGISTRY} "acceptAdminRole(address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL} --account myaccount

sleep 10
cast send ${SEPOLIA_TOKEN_ADMIN_REGISTRY} "setPool(address,address)" ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${SEPOLIA_POOL_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL} --account myaccount

echo "Sepolia contracts deployed and configured successfully!"

# Deploy the vault 
echo "Deploying the vault on Sepolia..."
echo "Waiting for previous transactions to settle..."
sleep 15

deploy_vault() {
    local max_attempts=3
    local wait_time=30
    vault_output=""
    
    for attempt in $(seq 1 $max_attempts); do
        echo "Vault deployment attempt $attempt/$max_attempts..."
        
        if [ $attempt -gt 1 ]; then
            echo "Waiting ${wait_time} seconds for rate limits to reset..."
            sleep $wait_time
            wait_time=$((wait_time * 2))
        fi
        
        vault_output=$(forge create src/Vault.sol:Vault --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --constructor-args ${SEPOLIA_REBASE_TOKEN_ADDRESS} 2>&1)
        result=$?
        
        if [ $result -eq 0 ] && ! echo "$vault_output" | grep -q "in-flight transaction limit"; then
            echo "Vault deployment successful!"
            return 0
        elif echo "$vault_output" | grep -q "in-flight transaction limit"; then
            echo "Rate limited on vault attempt $attempt. Will retry..."
            continue
        else
            echo "Vault deployment failed on attempt $attempt"
            return 1
        fi
    done
    
    return 1
}

if deploy_vault; then
    echo "DEBUG: vault_output contents:"
    echo "$vault_output"
    echo "--- END DEBUG ---"

    VAULT_ADDRESS=$(echo "$vault_output" | grep "DEPLOYED_VAULT_ADDRESS:" | awk '{print $2}')
    
    if [ -z "$VAULT_ADDRESS" ]; then
        VAULT_ADDRESS=$(echo "$vault_output" | grep -o "0x[a-fA-F0-9]\{40\}")
    fi
    
    echo "Vault address: $VAULT_ADDRESS"
    
    if [ -z "$VAULT_ADDRESS" ]; then
        echo "Warning: Failed to extract vault address, continuing without vault"
    fi
else
    echo "Warning: Vault deployment failed, continuing without vault"
    VAULT_ADDRESS=""
fi

# Configure the pool on Sepolia
echo "Configuring the pool on Sepolia..."
echo "Waiting for transactions to settle..."
sleep 10

if [ ! -z "$ZKSYNC_POOL_ADDRESS" ] && [ ! -z "$ZKSYNC_REBASE_TOKEN_ADDRESS" ]; then
    forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${SEPOLIA_POOL_ADDRESS} ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${ZKSYNC_POOL_ADDRESS} ${ZKSYNC_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0
else
    echo "Skipping Sepolia pool configuration (missing ZKsync addresses)"
fi

# Deposit funds to the vault
if [ ! -z "$VAULT_ADDRESS" ]; then
    echo "Depositing funds to the vault on Sepolia..."
    cast send ${VAULT_ADDRESS} --value ${AMOUNT} --rpc-url ${SEPOLIA_RPC_URL} --account myaccount "deposit()"
else
    echo "Skipping vault deposit (no vault address)"
fi

# Wait a beat for some interest to accrue

# Configure the pool on ZKsync
if [ ! -z "$ZKSYNC_POOL_ADDRESS" ] && [ ! -z "$SEPOLIA_POOL_ADDRESS" ] && [ ! -z "$SEPOLIA_REBASE_TOKEN_ADDRESS" ]; then
    echo "Configuring the pool on ZKsync..."
    echo "Waiting for transactions to settle..."
    sleep 10
    
    forge script ./script/ConfigurePool.s.sol:ConfigurePoolScript --rpc-url ${ZKSYNC_SEPOLIA_RPC_URL} --account myaccount --broadcast --sig "run(address,uint64,address,address,bool,uint128,uint128,bool,uint128,uint128)" ${ZKSYNC_POOL_ADDRESS} ${SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_POOL_ADDRESS} ${SEPOLIA_REBASE_TOKEN_ADDRESS} false 0 0 false 0 0
else
    echo "Skipping ZKsync pool configuration (missing required addresses)"
fi

# Bridge the funds using the script to zksync 
if [ ! -z "$SEPOLIA_REBASE_TOKEN_ADDRESS" ] && [ ! -z "$ZKSYNC_POOL_ADDRESS" ]; then
    echo "Bridging the funds using the script to ZKsync..."
    USER_ADDRESS=$(cast wallet address --account myaccount)
    SEPOLIA_BALANCE_BEFORE=$(cast balance $USER_ADDRESS --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
    echo "Sepolia balance before bridging: $SEPOLIA_BALANCE_BEFORE"
    
    if [ "$SEPOLIA_BALANCE_BEFORE" -gt 0 ]; then
        forge script ./script/BridgeTokens.s.sol:BridgeTokensScript --rpc-url ${SEPOLIA_RPC_URL} --account myaccount --broadcast --sig "sendMessage(address,uint64,address,uint256,address,address)" $USER_ADDRESS ${ZKSYNC_SEPOLIA_CHAIN_SELECTOR} ${SEPOLIA_REBASE_TOKEN_ADDRESS} ${AMOUNT} ${SEPOLIA_LINK_ADDRESS} ${SEPOLIA_ROUTER}
        echo "Funds bridged to ZKsync"
        
        SEPOLIA_BALANCE_AFTER=$(cast balance $USER_ADDRESS --erc20 ${SEPOLIA_REBASE_TOKEN_ADDRESS} --rpc-url ${SEPOLIA_RPC_URL})
        echo "Sepolia balance after bridging: $SEPOLIA_BALANCE_AFTER"
    else
        echo "No tokens to bridge (balance is 0)"
    fi
else
    echo "Skipping bridging (missing required addresses)"
fi

echo ""
echo "=== Deployment Summary ==="
echo "ZKsync Token: $ZKSYNC_REBASE_TOKEN_ADDRESS"
echo "ZKsync Pool: $ZKSYNC_POOL_ADDRESS"
echo "Sepolia Token: $SEPOLIA_REBASE_TOKEN_ADDRESS"
echo "Sepolia Pool: $SEPOLIA_POOL_ADDRESS"
echo "Vault: $VAULT_ADDRESS"
echo ""
echo "Script completed!"