# API Reference

## Contract Overview

This document provides detailed API documentation for all contracts in the protocol.

## Core Contracts

### Compact.sol

The main calculator contract that integrates ERC-6909 resource locking with Chainlink price feeds.

#### Constructor

```solidity
constructor(address _resourceManager)
```

- `_resourceManager`: Address of the ResourceManager contract

#### State Variables

- `resourceManager`: Immutable ResourceManager instance
- `erc6909Enabled`: Boolean flag for ERC-6909 functionality

#### Functions

##### `setERC6909Enabled(bool enabled)`

Enables or disables ERC-6909 functionality.

- `enabled`: Boolean to enable/disable ERC-6909

##### `getMakingAmount(...)`

Calculates the making amount for an order with resource validation.

- Returns: `uint256` - The calculated making amount
- Validates ERC-6909 resource locks if enabled

##### `getTakingAmount(...)`

Calculates the taking amount for an order with resource validation.

- Returns: `uint256` - The calculated taking amount
- Validates ERC-6909 resource locks if enabled

##### `allocateResources(address maker, address token, uint256 amount, uint256 lockId)`

Allocates resources for order execution.

- `maker`: The maker address
- `token`: The token address
- `amount`: Amount to allocate
- `lockId`: Lock ID to allocate from

#### Errors

- `DifferentOracleDecimals()`: Oracle decimals mismatch
- `StaleOraclePrice()`: Oracle price is stale
- `InsufficientResourceLock()`: Insufficient locked resources
- `ResourceLockNotFound()`: Resource lock not found
- `ERC6909NotEnabled()`: ERC-6909 not enabled
- `InvalidResourceManager()`: Invalid resource manager

### ResourceManager.sol

Manages ERC-6909 resource locks for the protocol.

#### Constructor

```solidity
constructor(address _theCompact, address _allocator)
```

- `_theCompact`: Address of The Compact contract
- `_allocator`: Address of the allocator

#### Functions

##### `lockResources(address maker, address token, uint256 amount)`

Locks resources for a maker.

- Returns: `uint256` - Lock ID
- Transfers tokens from maker to contract

##### `allocateResources(uint256 lockId, uint256 amount)`

Allocates resources from a lock.

- `lockId`: Lock ID to allocate from
- `amount`: Amount to allocate

##### `releaseResources(uint256 lockId, uint256 amount)`

Releases allocated resources.

- `lockId`: Lock ID to release from
- `amount`: Amount to release

##### `unlockResources(uint256 lockId)`

Unlocks resources and returns tokens to maker.

- `lockId`: Lock ID to unlock

##### `getAvailableBalance(address maker, address token)`

Gets available balance for a maker-token pair.

- Returns: `uint256` - Available balance

#### Events

- `ResourceLocked`: Emitted when resources are locked
- `ResourceUnlocked`: Emitted when resources are unlocked
- `ResourceAllocated`: Emitted when resources are allocated

### TychoSwapExecutor.sol

Executes complex swaps using Tycho Execution.

#### Constructor

```solidity
constructor(address _executor, address payable _tychoRouterAddress)
```

- `_executor`: Executor address
- `_tychoRouterAddress`: Tycho router address

#### Functions

##### `takerInteraction(...)`

Executes the swap interaction.

- Handles token transfers to TychoRouter
- Executes swap via Tycho router
- Emits `TokensSwapExecuted` event

#### Events

- `TokensSwapExecuted`: Emitted when swap is executed

### CompactInteraction.sol

Post-interaction handler for resource allocation.

#### Constructor

```solidity
constructor(address _treasurer, address _resourceManager, address _theCompact)
```

- `_treasurer`: Treasurer address
- `_resourceManager`: ResourceManager address
- `_theCompact`: The Compact address

#### Functions

##### `postInteraction(...)`

Handles post-interaction logic.

- Transfers output tokens to treasurer
- Creates resource lock for taker
- Allocates resources for order execution

### RebalancerInteraction.sol

Treasury management and portfolio rebalancing.

#### Constructor

```solidity
constructor(address _treasurer)
```

- `_treasurer`: Treasurer address

#### Functions

##### `postInteraction(...)`

Handles post-interaction rebalancing.

- Transfers output tokens to treasurer
- Emits `TokensTransferredToTreasurer` event

#### Events

- `TokensTransferredToTreasurer`: Emitted when tokens are transferred

### OracleCalculator.sol

Price oracle integration for advanced order strategies.

#### Functions

##### `getPrice(AggregatorV3Interface oracle)`

Gets current price from oracle.

- Returns: `uint256` - Current price

##### `validatePrice(AggregatorV3Interface oracle, uint256 expectedPrice)`

Validates oracle price against expected value.

- Returns: `bool` - True if price is valid

## Integration Interfaces

### IOrderMixin.sol

Interface for order management from the 1inch Limit Order Protocol.

### IPostInteraction.sol

Interface for post-interaction callbacks.

### ITakerInteraction.sol

Interface for taker interaction callbacks.

### IAmountGetter.sol

Interface for amount calculation callbacks.

## Error Codes

| Error                      | Code | Description                   |
| -------------------------- | ---- | ----------------------------- |
| `DifferentOracleDecimals`  | -    | Oracle decimals mismatch      |
| `StaleOraclePrice`         | -    | Oracle price is stale         |
| `InsufficientResourceLock` | -    | Insufficient locked resources |
| `ResourceLockNotFound`     | -    | Resource lock not found       |
| `ERC6909NotEnabled`        | -    | ERC-6909 not enabled          |
| `InvalidResourceManager`   | -    | Invalid resource manager      |
| `SwapFailed`               | -    | Swap execution failed         |
| `InvalidExecutor`          | -    | Invalid executor address      |
| `TransferFailed`           | -    | Token transfer failed         |
| `InvalidTreasurer`         | -    | Invalid treasurer address     |

## Gas Optimization

The contracts are optimized for gas efficiency:

- Use of immutable variables where possible
- Efficient storage patterns
- Minimal external calls
- Optimized loops and conditionals

## Security Considerations

- All external calls are validated
- Access control implemented where needed
- Reentrancy protection in place
- Input validation on all public functions
- Safe math operations throughout
