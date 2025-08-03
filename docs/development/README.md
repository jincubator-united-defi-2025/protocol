# Development Guide

## Overview

This guide provides comprehensive information for developers working on the protocol.

## Development Environment Setup

### Prerequisites

- **Foundry**: Latest version (0.2.0+)
- **Node.js**: 18+ LTS
- **Git**: Latest version
- **Solidity**: 0.8.30

### Installation

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
```

## Project Structure

```
protocol/
├── src/                    # Source contracts
│   ├── Compact.sol        # Main calculator contract
│   ├── ResourceManager.sol # ERC-6909 resource management
│   ├── TychoSwapExecutor.sol # Tycho execution integration
│   ├── CompactInteraction.sol # Post-interaction handler
│   ├── RebalancerInteraction.sol # Treasury management
│   ├── OracleCalculator.sol # Price oracle integration
│   ├── Dispatcher.sol     # Request dispatching
│   └── interfaces/        # Contract interfaces
├── test/                  # Test files
│   ├── Compact.t.sol     # Main test suite
│   ├── integration/      # Integration tests
│   └── utils/           # Test utilities
├── script/               # Deployment scripts
├── docs/                # Documentation
├── lib/                 # Dependencies
└── foundry.toml        # Foundry configuration
```

## Development Workflow

### 1. Feature Development

```bash
# Create feature branch
git checkout -b feature/new-feature

# Make changes
# ... edit files ...

# Run tests
forge test

# Build contracts
forge build

# Commit changes
git add .
git commit -m "feat: add new feature"

# Push branch
git push origin feature/new-feature
```

### 2. Code Quality

```bash
# Format code
forge fmt

# Lint code
forge build --force

# Run static analysis
slither .

# Run gas optimization
forge snapshot
```

### 3. Testing

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testFunctionName

# Run with verbose output
forge test -vvvv

# Run with gas reporting
forge test --gas-report

# Run coverage
forge coverage
```

### 4. Deployment

```bash
# Deploy to local network
anvil
forge script script/Deploy.s.sol --rpc-url http://localhost:8545

# Deploy to testnet
forge script script/Deploy.s.sol \
    --rpc-url <testnet-rpc> \
    --private-key <private-key> \
    --broadcast

# Deploy to mainnet
forge script script/Deploy.s.sol \
    --rpc-url <mainnet-rpc> \
    --private-key <private-key> \
    --broadcast \
    --verify
```

## Testing Strategy

### Unit Tests

Unit tests focus on individual contract functions and their behavior.

```solidity
// Example unit test
function testLockResources() public {
    // Arrange
    address maker = address(1);
    address token = address(dai);
    uint256 amount = 1000 ether;

    // Act
    uint256 lockId = resourceManager.lockResources(maker, token, amount);

    // Assert
    assertEq(lockId, 1);
    assertEq(resourceManager.getAvailableBalance(maker, token), amount);
}
```

### Integration Tests

Integration tests verify the interaction between multiple contracts.

```solidity
// Example integration test
function testEndToEndFlow() public {
    // 1. Lock resources
    uint256 lockId = resourceManager.lockResources(makerAddr, address(dai), 1000 ether);

    // 2. Create order
    Order memory order = createOrder();

    // 3. Execute order
    swap.fillOrder(order);

    // 4. Verify results
    assertEq(dai.balanceOf(treasurer), 500 ether);
}
```

### Fuzz Tests

Fuzz tests use random inputs to find edge cases.

```solidity
// Example fuzz test
function testFuzz_ResourceLocking(uint256 amount) public {
    vm.assume(amount > 0 && amount <= 1000000 ether);

    uint256 lockId = resourceManager.lockResources(makerAddr, address(dai), amount);
    assertEq(resourceManager.getAvailableBalance(makerAddr, address(dai)), amount);
}
```

### Invariant Tests

Invariant tests verify system properties that should always hold.

```solidity
// Example invariant test
function invariant_TotalLockedEqualsSumOfLocks() public {
    uint256 totalLocked = 0;
    for (uint256 i = 1; i <= resourceManager.nextLockId() - 1; i++) {
        ResourceManager.ResourceLock memory lock = resourceManager.resourceLocks(i);
        if (lock.isActive) {
            totalLocked += lock.amount;
        }
    }
    assertEq(totalLocked, dai.balanceOf(address(resourceManager)));
}
```

## Gas Optimization

### Storage Optimization

```solidity
// Pack related variables together
struct ResourceLock {
    address maker;
    address token;
    uint256 amount;
    uint256 allocatedAmount;
    bool isActive;
    uint256 createdAt;
}
```

### Function Optimization

```solidity
// Use custom errors instead of require strings
error InsufficientBalance(uint256 requested, uint256 available);

function withdraw(uint256 amount) external {
    if (balance < amount) revert InsufficientBalance(amount, balance);
    // ... withdrawal logic
}
```

### Loop Optimization

```solidity
// Cache array length
uint256 length = array.length;
for (uint256 i = 0; i < length; i++) {
    // ... loop logic
}
```

## Debugging

### Foundry Debugging

```bash
# Trace transaction
forge trace <tx-hash> --rpc-url <rpc-url>

# Debug specific test
forge test --match-test testName -vvvv

# Use console.log for debugging
import "forge-std/console.sol";

function debugFunction() external {
    console.log("Debug value:", someValue);
}
```

### Hardhat Debugging

```bash
# Debug with Hardhat
npx hardhat test --verbose

# Use console.log
console.log("Debug:", value);
```

## Code Standards

### Solidity Style Guide

1. **Naming Conventions**

   - Contracts: PascalCase
   - Functions: camelCase
   - Variables: camelCase
   - Constants: UPPER_SNAKE_CASE

2. **Function Order**

   - Constructor
   - Receive/Fallback
   - External functions
   - Public functions
   - Internal functions
   - Private functions

3. **Documentation**
   - Use NatSpec comments
   - Document all public functions
   - Include parameter descriptions
   - Document return values

### Code Review Checklist

- [ ] Code follows style guide
- [ ] Functions are properly documented
- [ ] Tests cover all functionality
- [ ] Gas optimization applied
- [ ] Security considerations addressed
- [ ] Error handling implemented
- [ ] Access control verified

## Performance Optimization

### Gas Optimization Techniques

1. **Storage Packing**: Pack related variables together
2. **Custom Errors**: Use custom errors instead of require strings
3. **Loop Optimization**: Cache array lengths and use unchecked
4. **Function Visibility**: Use appropriate visibility modifiers
5. **External Calls**: Minimize external calls

### Memory Optimization

1. **Struct Packing**: Pack struct members efficiently
2. **Array Optimization**: Use appropriate array types
3. **Mapping Usage**: Use mappings for efficient lookups
4. **Storage vs Memory**: Use appropriate data locations

## Security Best Practices

### Access Control

```solidity
// Use OpenZeppelin's Ownable
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyContract is Ownable {
    function adminFunction() external onlyOwner {
        // ... admin logic
    }
}
```

### Reentrancy Protection

```solidity
// Use ReentrancyGuard
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract MyContract is ReentrancyGuard {
    function withdraw() external nonReentrant {
        // ... withdrawal logic
    }
}
```

### Input Validation

```solidity
// Validate all inputs
function transfer(address to, uint256 amount) external {
    require(to != address(0), "Invalid recipient");
    require(amount > 0, "Invalid amount");
    // ... transfer logic
}
```

## Deployment

### Deployment Scripts

```solidity
// script/Deploy.s.sol
contract DeployScript is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy contracts
        ResourceManager resourceManager = new ResourceManager(
            address(theCompact),
            address(allocator)
        );

        Compact compact = new Compact(address(resourceManager));

        // ... deploy other contracts

        vm.stopBroadcast();
    }
}
```

### Environment Management

```bash
# Development
forge script script/Deploy.s.sol --rpc-url http://localhost:8545

# Staging
forge script script/Deploy.s.sol \
    --rpc-url $STAGING_RPC \
    --private-key $STAGING_KEY \
    --broadcast

# Production
forge script script/Deploy.s.sol \
    --rpc-url $PROD_RPC \
    --private-key $PROD_KEY \
    --broadcast \
    --verify
```

## Monitoring and Maintenance

### Contract Monitoring

1. **Event Monitoring**: Monitor contract events
2. **State Monitoring**: Monitor contract state changes
3. **Gas Monitoring**: Monitor gas usage
4. **Error Monitoring**: Monitor for errors and reverts

### Maintenance Procedures

1. **Regular Audits**: Schedule regular security audits
2. **Upgrade Procedures**: Plan for contract upgrades
3. **Emergency Procedures**: Have emergency response procedures
4. **Backup Procedures**: Regular backup and recovery

## Resources

### Documentation

- [Foundry Book](https://book.getfoundry.sh/)
- [Solidity Docs](https://docs.soliditylang.org/)
- [OpenZeppelin Docs](https://docs.openzeppelin.com/)

### Tools

- [Foundry](https://getfoundry.sh/): Development framework
- [Slither](https://github.com/crytic/slither): Static analysis
- [Mythril](https://github.com/ConsenSys/mythril): Symbolic execution
- [Echidna](https://github.com/crytic/echidna): Fuzzing

### Community

- [Ethereum Stack Exchange](https://ethereum.stackexchange.com/)
- [Solidity Forum](https://forum.soliditylang.org/)
- [OpenZeppelin Forum](https://forum.openzeppelin.com/)
