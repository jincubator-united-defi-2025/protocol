# Integration Guide

## Overview

This guide provides step-by-step instructions for integrating with the protocol's enhanced features.

## Prerequisites

- Foundry development environment
- Understanding of the 1inch Limit Order Protocol
- Basic knowledge of ERC-6909 resource locking
- Familiarity with Chainlink price feeds

## Quick Integration

### 1. Install Dependencies

```bash
# Clone the repository
git clone <repository-url>
cd protocol

# Install Foundry dependencies
forge install

# Build contracts
forge build
```

### 2. Deploy Core Contracts

```solidity
// Deploy ResourceManager
ResourceManager resourceManager = new ResourceManager(
    address(theCompact),
    address(allocator)
);

// Deploy Compact calculator
Compact compact = new Compact(address(resourceManager));

// Deploy TychoSwapExecutor
TychoSwapExecutor executor = new TychoSwapExecutor(
    address(dispatcher),
    payable(tychoRouter)
);

// Deploy interaction contracts
CompactInteraction compactInteraction = new CompactInteraction(
    address(treasurer),
    address(resourceManager),
    address(theCompact)
);

RebalancerInteraction rebalancerInteraction = new RebalancerInteraction(
    address(treasurer)
);
```

### 3. Configure Resource Locking

```solidity
// Enable ERC-6909 functionality
compact.setERC6909Enabled(true);

// Lock resources for a maker
uint256 lockId = resourceManager.lockResources(
    makerAddress,
    tokenAddress,
    amount
);
```

## Advanced Integration

### ERC-6909 Resource Management

The protocol integrates with [The Compact](https://github.com/uniswap/the-compact) for ERC-6909 resource locking.

#### Resource Locking Flow

1. **Lock Resources**: Maker locks tokens in ResourceManager
2. **Create Order**: Order includes resource lock validation
3. **Execute Order**: Compact validates resource availability
4. **Allocate Resources**: Resources are allocated during execution
5. **Release Resources**: Resources are released after completion

```solidity
// Example: Complete resource locking flow
function createOrderWithResourceLock() external {
    // 1. Lock resources
    uint256 lockId = resourceManager.lockResources(
        msg.sender,
        address(dai),
        1000 ether
    );

    // 2. Create order with resource validation
    Order memory order = Order({
        // ... order parameters
    });

    // 3. Order execution will validate resources
    // 4. Resources are automatically allocated/released
}
```

### Tycho Execution Integration

The protocol uses Tycho Execution for complex multi-DEX swaps.

#### Swap Execution Flow

1. **Prepare Swap Data**: Generate Tycho swap data
2. **Create Order**: Include TychoSwapExecutor as interaction
3. **Execute Order**: TychoSwapExecutor handles the swap
4. **Complete Swap**: Tokens are transferred to destination

```solidity
// Example: Tycho swap execution
function executeTychoSwap() external {
    // 1. Prepare Tycho swap data
    bytes memory tychoSwapData = generateTychoSingleSwapData(
        inputToken,
        outputToken,
        inputAmount,
        slippage
    );

    // 2. Create order with TychoSwapExecutor
    Order memory order = Order({
        // ... order parameters
    });

    // 3. Include TychoSwapExecutor in postInteraction
    bytes memory postInteraction = abi.encodePacked(
        address(tychoSwapExecutor),
        tychoSwapData
    );

    // 4. Execute order
    swap.fillOrder(order, postInteraction);
}
```

### Oracle Integration

The protocol supports Chainlink price feeds for advanced order strategies.

#### Price Validation

```solidity
// Example: Oracle-based order validation
function createStopLossOrder() external {
    // 1. Get current price from oracle
    uint256 currentPrice = oracleCalculator.getPrice(priceOracle);

    // 2. Validate price is within acceptable range
    require(
        oracleCalculator.validatePrice(priceOracle, expectedPrice),
        "Price validation failed"
    );

    // 3. Create order with price conditions
    Order memory order = Order({
        // ... order parameters with price validation
    });
}
```

### Treasury Management

The protocol includes automated treasury management through RebalancerInteraction.

#### Treasury Flow

1. **Order Execution**: Tokens are transferred to treasurer
2. **Portfolio Rebalancing**: Automatic rebalancing based on strategy
3. **Token Distribution**: Tokens are distributed according to strategy

```solidity
// Example: Treasury management integration
function setupTreasuryManagement() external {
    // 1. Deploy RebalancerInteraction
    RebalancerInteraction rebalancer = new RebalancerInteraction(
        address(treasurer)
    );

    // 2. Create order with treasury management
    Order memory order = Order({
        // ... order parameters
    });

    // 3. Include RebalancerInteraction in postInteraction
    bytes memory postInteraction = abi.encodePacked(
        address(rebalancer)
    );

    // 4. Execute order with treasury management
    swap.fillOrder(order, postInteraction);
}
```

## Testing Integration

### Unit Tests

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-contract CompactTest

# Run with verbose output
forge test -vvvv
```

### Integration Tests

```bash
# Run integration tests
forge test --match-path "test/integration/*"

# Run with gas reporting
forge test --gas-report
```

### Test Coverage

```bash
# Generate coverage report
forge coverage

# Generate coverage report with lcov
forge coverage --report lcov
```

## Deployment

### Local Development

```bash
# Start local node
anvil

# Deploy contracts
forge script script/Deploy.s.sol --rpc-url http://localhost:8545
```

### Testnet Deployment

```bash
# Deploy to testnet
forge script script/Deploy.s.sol \
    --rpc-url <testnet-rpc-url> \
    --private-key <private-key> \
    --broadcast
```

### Mainnet Deployment

```bash
# Deploy to mainnet
forge script script/Deploy.s.sol \
    --rpc-url <mainnet-rpc-url> \
    --private-key <private-key> \
    --broadcast \
    --verify
```

## Best Practices

### Security

1. **Access Control**: Implement proper access controls
2. **Input Validation**: Validate all external inputs
3. **Reentrancy Protection**: Use reentrancy guards
4. **Oracle Security**: Validate oracle responses
5. **Resource Management**: Properly manage resource locks

### Gas Optimization

1. **Batch Operations**: Batch operations when possible
2. **Storage Optimization**: Use efficient storage patterns
3. **External Calls**: Minimize external calls
4. **Loop Optimization**: Optimize loops and conditionals

### Error Handling

1. **Custom Errors**: Use custom errors for gas efficiency
2. **Error Messages**: Provide clear error messages
3. **Graceful Degradation**: Handle failures gracefully
4. **Monitoring**: Monitor for errors and failures

## Troubleshooting

### Common Issues

1. **Resource Lock Errors**: Ensure sufficient locked resources
2. **Oracle Errors**: Check oracle connectivity and staleness
3. **Swap Failures**: Validate swap parameters and slippage
4. **Gas Issues**: Optimize gas usage and check limits

### Debug Tools

```bash
# Trace transaction
forge trace <tx-hash> --rpc-url <rpc-url>

# Debug specific test
forge test --match-test <test-name> -vvvv

# Gas profiling
forge test --gas-report
```

## Support

For additional support:

- [GitHub Issues](https://github.com/jincubator-united-defi-2025/protocol/issues)
- [Documentation](https://deepwiki.com/jincubator-united-defi-2025/protocol)
- [Discord Community](https://discord.gg/jincubator)
