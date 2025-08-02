# Deployment Guide

## Overview

This guide covers the deployment process for the protocol contracts across different networks.

## Prerequisites

### Environment Setup

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone repository
git clone <repository-url>
cd protocol

# Install dependencies
forge install

# Build contracts
forge build
```

### Environment Configuration

```bash
# Copy environment template
cp .env.example .env

# Configure environment variables
export PRIVATE_KEY=your_private_key
export RPC_URL=your_rpc_url
export ETHERSCAN_API_KEY=your_etherscan_key
export COINMARKETCAP_API_KEY=your_coinmarketcap_key
```

## Network Configuration

### Supported Networks

| Network          | Chain ID | RPC URL                                | Explorer                       |
| ---------------- | -------- | -------------------------------------- | ------------------------------ |
| Ethereum Mainnet | 1        | https://eth.llamarpc.com               | https://etherscan.io           |
| Ethereum Sepolia | 11155111 | https://rpc.sepolia.org                | https://sepolia.etherscan.io   |
| Polygon          | 137      | https://polygon-rpc.com                | https://polygonscan.com        |
| Polygon Mumbai   | 80001    | https://rpc-mumbai.maticvigil.com      | https://mumbai.polygonscan.com |
| Arbitrum One     | 42161    | https://arb1.arbitrum.io/rpc           | https://arbiscan.io            |
| Arbitrum Sepolia | 421614   | https://sepolia-rollup.arbitrum.io/rpc | https://sepolia.arbiscan.io    |

### Network-Specific Configuration

```toml
# foundry.toml
[profile.default]
src = "src"
out = "out"
libs = ["lib"]

[rpc_endpoints]
mainnet = "${ETH_RPC_URL}"
sepolia = "${SEPOLIA_RPC_URL}"
polygon = "${POLYGON_RPC_URL}"
arbitrum = "${ARBITRUM_RPC_URL}"

[etherscan]
mainnet = { key = "${ETHERSCAN_API_KEY}" }
sepolia = { key = "${ETHERSCAN_API_KEY}" }
polygon = { key = "${POLYGONSCAN_API_KEY}" }
arbitrum = { key = "${ARBISCAN_API_KEY}" }
```

## Deployment Scripts

### Main Deployment Script

```solidity
// script/Deploy.s.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import "../src/Compact.sol";
import "../src/ResourceManager.sol";
import "../src/TychoSwapExecutor.sol";
import "../src/CompactInteraction.sol";
import "../src/RebalancerInteraction.sol";
import "../src/OracleCalculator.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy core contracts
        console2.log("Deploying ResourceManager...");
        ResourceManager resourceManager = new ResourceManager(
            address(0), // theCompact - will be set later
            address(this) // allocator
        );
        console2.log("ResourceManager deployed at:", address(resourceManager));

        console2.log("Deploying Compact...");
        Compact compact = new Compact(address(resourceManager));
        console2.log("Compact deployed at:", address(compact));

        console2.log("Deploying OracleCalculator...");
        OracleCalculator oracleCalculator = new OracleCalculator();
        console2.log("OracleCalculator deployed at:", address(oracleCalculator));

        // Deploy interaction contracts
        console2.log("Deploying CompactInteraction...");
        CompactInteraction compactInteraction = new CompactInteraction(
            address(0), // treasurer - will be set later
            address(resourceManager),
            address(0) // theCompact - will be set later
        );
        console2.log("CompactInteraction deployed at:", address(compactInteraction));

        console2.log("Deploying RebalancerInteraction...");
        RebalancerInteraction rebalancerInteraction = new RebalancerInteraction(
            address(0) // treasurer - will be set later
        );
        console2.log("RebalancerInteraction deployed at:", address(rebalancerInteraction));

        // Deploy TychoSwapExecutor (requires Tycho router)
        console2.log("Deploying TychoSwapExecutor...");
        TychoSwapExecutor tychoSwapExecutor = new TychoSwapExecutor(
            address(0), // executor - will be set later
            payable(address(0)) // tychoRouter - will be set later
        );
        console2.log("TychoSwapExecutor deployed at:", address(tychoSwapExecutor));

        vm.stopBroadcast();

        // Log deployment summary
        console2.log("\n=== Deployment Summary ===");
        console2.log("ResourceManager:", address(resourceManager));
        console2.log("Compact:", address(compact));
        console2.log("OracleCalculator:", address(oracleCalculator));
        console2.log("CompactInteraction:", address(compactInteraction));
        console2.log("RebalancerInteraction:", address(rebalancerInteraction));
        console2.log("TychoSwapExecutor:", address(tychoSwapExecutor));
    }
}
```

### Configuration Script

```solidity
// script/Configure.s.sol
contract ConfigureScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Get deployed contract addresses
        address resourceManager = vm.envAddress("RESOURCE_MANAGER");
        address compact = vm.envAddress("COMPACT");
        address compactInteraction = vm.envAddress("COMPACT_INTERACTION");
        address rebalancerInteraction = vm.envAddress("REBALANCER_INTERACTION");
        address tychoSwapExecutor = vm.envAddress("TYCHO_SWAP_EXECUTOR");

        // Configure contracts
        console2.log("Configuring contracts...");

        // Set ERC-6909 enabled
        Compact(compact).setERC6909Enabled(true);
        console2.log("ERC-6909 enabled on Compact");

        // Set treasurer addresses
        CompactInteraction(compactInteraction).setTreasurer(address(0x123)); // Replace with actual treasurer
        RebalancerInteraction(rebalancerInteraction).setTreasurer(address(0x123)); // Replace with actual treasurer
        console2.log("Treasurer addresses set");

        vm.stopBroadcast();
    }
}
```

## Deployment Process

### 1. Local Development

```bash
# Start local node
anvil

# Deploy to local network
forge script script/Deploy.s.sol --rpc-url http://localhost:8545 --broadcast

# Verify deployment
forge script script/Verify.s.sol --rpc-url http://localhost:8545
```

### 2. Testnet Deployment

```bash
# Deploy to Sepolia
forge script script/Deploy.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify

# Configure contracts
forge script script/Configure.s.sol \
    --rpc-url $SEPOLIA_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

### 3. Mainnet Deployment

```bash
# Deploy to mainnet
forge script script/Deploy.s.sol \
    --rpc-url $MAINNET_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast \
    --verify

# Configure contracts
forge script script/Configure.s.sol \
    --rpc-url $MAINNET_RPC_URL \
    --private-key $PRIVATE_KEY \
    --broadcast
```

## Verification

### Contract Verification

```bash
# Verify on Etherscan
forge verify-contract \
    <contract_address> \
    src/Compact.sol:Compact \
    --chain-id 1 \
    --etherscan-api-key $ETHERSCAN_API_KEY \
    --constructor-args $(cast abi-encode "constructor(address)" <resource_manager_address>)
```

### Verification Script

```solidity
// script/Verify.s.sol
contract VerifyScript is Script {
    function run() external {
        // Verify all deployed contracts
        console2.log("Verifying contracts...");

        // Verify Compact
        string memory compactArgs = vm.toString(abi.encode(
            vm.envAddress("RESOURCE_MANAGER")
        ));

        string memory verifyCommand = string.concat(
            "forge verify-contract ",
            vm.envString("COMPACT_ADDRESS"),
            " src/Compact.sol:Compact",
            " --chain-id ",
            vm.toString(block.chainid),
            " --etherscan-api-key ",
            vm.envString("ETHERSCAN_API_KEY"),
            " --constructor-args ",
            compactArgs
        );

        console2.log("Running:", verifyCommand);
        // Note: This would need to be executed externally
    }
}
```

## Post-Deployment

### Contract Initialization

```solidity
// script/Initialize.s.sol
contract InitializeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Initialize contracts with proper parameters
        console2.log("Initializing contracts...");

        // Set up initial configurations
        // Configure oracle addresses
        // Set up initial permissions
        // Initialize default parameters

        vm.stopBroadcast();
    }
}
```

### Testing Deployment

```bash
# Run deployment tests
forge test --match-contract DeploymentTest

# Test contract interactions
forge test --match-contract IntegrationTest

# Test with real network
forge test --fork-url $MAINNET_RPC_URL
```

## Security Considerations

### Multi-Sig Deployment

```solidity
// script/MultiSigDeploy.s.sol
contract MultiSigDeployScript is Script {
    function run() external {
        // Deploy with multi-sig wallet
        address multiSigWallet = vm.envAddress("MULTISIG_WALLET");

        // Deploy contracts
        // Transfer ownership to multi-sig
        // Set up timelock if needed
    }
}
```

### Timelock Integration

```solidity
// script/TimelockDeploy.s.sol
contract TimelockDeployScript is Script {
    function run() external {
        // Deploy with timelock
        address timelock = vm.envAddress("TIMELOCK");

        // Deploy contracts
        // Set timelock as owner
        // Configure delay periods
    }
}
```

## Monitoring

### Deployment Monitoring

```bash
# Monitor deployment transactions
forge script script/Monitor.s.sol --rpc-url $MAINNET_RPC_URL

# Check contract states
forge script script/CheckState.s.sol --rpc-url $MAINNET_RPC_URL
```

### Health Checks

```solidity
// script/HealthCheck.s.sol
contract HealthCheckScript is Script {
    function run() external view {
        console2.log("Performing health checks...");

        // Check contract deployments
        // Verify configurations
        // Test basic functionality
        // Check oracle connectivity
        // Verify resource manager state
    }
}
```

## Rollback Procedures

### Emergency Pause

```solidity
// script/EmergencyPause.s.sol
contract EmergencyPauseScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Pause all contracts
        console2.log("Pausing contracts...");

        // Pause ResourceManager
        // Pause Compact
        // Pause interactions

        vm.stopBroadcast();
    }
}
```

### Contract Upgrades

```solidity
// script/Upgrade.s.sol
contract UpgradeScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        // Deploy new contracts
        // Migrate state
        // Update references

        vm.stopBroadcast();
    }
}
```

## Documentation

### Deployment Records

```bash
# Generate deployment report
forge script script/GenerateReport.s.sol --rpc-url $MAINNET_RPC_URL

# Save deployment addresses
echo "RESOURCE_MANAGER=0x..." >> .env
echo "COMPACT=0x..." >> .env
echo "ORACLE_CALCULATOR=0x..." >> .env
```

### Network-Specific Configurations

```bash
# Mainnet configuration
export MAINNET_RPC_URL=https://eth.llamarpc.com
export MAINNET_PRIVATE_KEY=your_private_key
export MAINNET_ETHERSCAN_API_KEY=your_etherscan_key

# Testnet configuration
export SEPOLIA_RPC_URL=https://rpc.sepolia.org
export SEPOLIA_PRIVATE_KEY=your_private_key
export SEPOLIA_ETHERSCAN_API_KEY=your_etherscan_key
```

## Best Practices

### Pre-Deployment Checklist

- [ ] All tests passing
- [ ] Gas optimization completed
- [ ] Security audit completed
- [ ] Documentation updated
- [ ] Environment variables configured
- [ ] Network connectivity verified
- [ ] Private keys secured
- [ ] Backup procedures in place

### Deployment Checklist

- [ ] Deploy contracts
- [ ] Verify contracts on explorer
- [ ] Configure contracts
- [ ] Test basic functionality
- [ ] Monitor for issues
- [ ] Update documentation
- [ ] Notify stakeholders

### Post-Deployment Checklist

- [ ] Monitor contract events
- [ ] Check oracle connectivity
- [ ] Verify resource management
- [ ] Test user interactions
- [ ] Monitor gas usage
- [ ] Check for errors
- [ ] Update deployment records

## Troubleshooting

### Common Issues

1. **Gas Estimation Failures**

   ```bash
   # Increase gas limit
   forge script script/Deploy.s.sol --gas-limit 5000000
   ```

2. **Verification Failures**

   ```bash
   # Verify manually
   forge verify-contract --help
   ```

3. **Network Connectivity**
   ```bash
   # Test RPC connection
   cast block-number --rpc-url $RPC_URL
   ```

### Debug Commands

```bash
# Trace deployment transaction
forge trace <tx-hash> --rpc-url $RPC_URL

# Check contract bytecode
cast code <contract_address> --rpc-url $RPC_URL

# Verify contract state
cast call <contract_address> "function()" --rpc-url $RPC_URL
```

## Resources

### Deployment Tools

- [Foundry Deploy](https://book.getfoundry.sh/forge/deploying)
- [Hardhat Deploy](https://hardhat.org/tutorial/deploying)
- [OpenZeppelin Defender](https://defender.openzeppelin.com/)

### Network Resources

- [Etherscan](https://etherscan.io/)
- [Polygonscan](https://polygonscan.com/)
- [Arbiscan](https://arbiscan.io/)

### Security Resources

- [OpenZeppelin Defender](https://defender.openzeppelin.com/)
- [Timelock Documentation](https://docs.openzeppelin.com/contracts/4.x/governance)
- [Multi-sig Best Practices](https://consensys.net/blog/blockchain-development/multisig-wallet-best-practices/)
