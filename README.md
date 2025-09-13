# Cross-Chain Rebase Token with Chainlink CCIP

An implementation of a cross-chain rebase token system using Chainlink CCIP (Cross-Chain Interoperability Protocol), deployed on Sepolia and ZKsync Sepolia testnets. This project demonstrates how to create tokens that maintain interest-bearing properties across different blockchain networks.

## 🌟 Features

- **Cross-Chain Rebase Token**: ERC20 token with rebase functionality that works across chains
- **Chainlink CCIP Integration**: Secure cross-chain token bridging with proper interest rate preservation
- **Interest-Bearing Vault**: Deposit ETH to mint rebase tokens that accrue interest over time
- **Rate Limit Protection**: Robust deployment scripts with retry logic for network congestion
- **Dynamic Configuration**: No hardcoded addresses for CCIP components (configurable for different networks)

## 🏗️ Architecture

### Core Contracts

1. **RebaseToken.sol**: Main ERC20 token with rebase functionality and user-specific interest rates
2. **RebaseTokenPool.sol**: CCIP pool contract handling cross-chain token transfers while preserving interest rates
3. **Vault.sol**: Interest-bearing vault that mints rebase tokens when ETH is deposited

### Key Components

- **Cross-Chain Interest Preservation**: When tokens are bridged, user interest rates are encoded and transferred
- **CCIP Integration**: Uses Chainlink's Token Admin Registry and Router for secure cross-chain operations
- **Access Control**: Role-based permissions for minting, burning, and pool operations

## 🚀 Quick Start

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Access to Sepolia and ZKsync Sepolia RPC endpoints
- Test ETH on both networks
- A funded account for deployments

### Installation

```bash
git clone <your-repo-url>
cd ccip-rebase-token
forge install
```

### Environment Setup

Create a `.env` file:

```bash
SEPOLIA_RPC_URL=your_sepolia_rpc_url
ZKSYNC_SEPOLIA_RPC_URL=your_zksync_sepolia_rpc_url
# Add your private key or keystore configuration
```

### Deployment

#### Option 1: Full Cross-Chain Deployment

```bash
# Deploy on both Sepolia and ZKsync Sepolia
SKIP_ZKSYNC_DEPLOYMENT=false ./bridgeToZKsync.sh
```

#### Option 2: Sepolia Only (Recommended for testing)

```bash
# Deploy only on Sepolia to avoid rate limits
SKIP_ZKSYNC_DEPLOYMENT=true ./bridgeToZKsync.sh
```

## 📋 Deployment Script Features

The `bridgeToZKsync.sh` script provides:

- **Automated Deployment**: Deploys all contracts in the correct order
- **Rate Limit Handling**: Automatic retry logic with exponential backoff
- **Permission Setup**: Configures all CCIP roles and token permissions
- **Cross-Chain Configuration**: Sets up pools for inter-chain communication
- **Vault Integration**: Deploys and configures the interest-bearing vault

### Script Flow

1. **ZKsync Deployment** (optional): Deploys RebaseToken and RebaseTokenPool
2. **Sepolia Deployment**: Individual contract deployment to avoid rate limits
3. **Permission Setup**: Grants necessary roles for CCIP functionality
4. **Vault Deployment**: Deploys interest-bearing vault with retry logic
5. **Cross-Chain Configuration**: Configures pools for bridging
6. **Testing**: Optional vault deposit and token bridging

## 🔧 Manual Operations

### Deploy Individual Contracts

```bash
# Deploy RebaseToken
forge create src/RebaseToken.sol:RebaseToken --rpc-url $SEPOLIA_RPC_URL --account myaccount --broadcast

# Deploy RebaseTokenPool
forge create src/RebaseTokenPool.sol:RebaseTokenPool --rpc-url $SEPOLIA_RPC_URL --account myaccount --broadcast --constructor-args <token_address> "[]" <rnm_proxy> <router>

# Deploy Vault
forge create src/Vault.sol:Vault --rpc-url $SEPOLIA_RPC_URL --account myaccount --broadcast --constructor-args <token_address>
```

### Test Vault Functionality

```bash
# Deposit ETH to mint rebase tokens
cast send <vault_address> --value 100000 --rpc-url $SEPOLIA_RPC_URL --account myaccount "deposit()"

# Check token balance
cast balance <your_address> --erc20 <token_address> --rpc-url $SEPOLIA_RPC_URL
```

## 🧪 Testing

Run the test suite:

```bash
# Run all tests
forge test

# Run specific test files
forge test --match-contract CrossChainTest
forge test --match-contract RebaseTokenTest

# Run with detailed output
forge test -vvv
```

## ⚠️ Known Issues & Limitations

### Vault Deployment Issues

The vault deployment component has some reliability issues that may require manual intervention:

- **Rate Limiting**: May fail during high network congestion
- **Address Extraction**: Sometimes fails to parse deployment addresses correctly
- **Permission Setup**: Requires manual role granting in some cases

**Workarounds**:

- Deploy vault manually using `forge create`
- Manually grant minter role: `cast send <token> "grantMintAndBurnRole(address)" <vault>`
- Use individual deployment commands instead of the script for problematic components

### Network Considerations

- **Sepolia Rate Limits**: Aggressive rate limiting requires careful timing between transactions
- **ZKsync Compatibility**: Some operations may require different gas settings
- **CCIP Delays**: Cross-chain messages can take several minutes to process

## 🙏 Acknowledgments

- [Chainlink CCIP](https://docs.chain.link/ccip) for cross-chain infrastructure
- [OpenZeppelin](https://openzeppelin.com/) for secure contract patterns
- [Foundry](https://book.getfoundry.sh/) for development framework
- [CyfrinUpdraft](https://updraft.cyfrin.io/courses) for learning

**Note**: This is a testnet implementation. Additional security audits and testing are recommended before any mainnet deployment.
