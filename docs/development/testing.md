# Testing Guide

## Overview

This guide covers the testing strategy, test types, and best practices for the protocol.

## Testing Strategy

### Test Pyramid

```
    ┌─────────────────┐
    │   E2E Tests     │  ← Few, high-level tests
    └─────────────────┘
    ┌─────────────────┐
    │ Integration     │  ← Medium number, component tests
    │ Tests           │
    └─────────────────┘
    ┌─────────────────┐
    │   Unit Tests    │  ← Many, fast, focused tests
    └─────────────────┘
```

### Test Types

1. **Unit Tests**: Test individual functions and components
2. **Integration Tests**: Test interactions between contracts
3. **End-to-End Tests**: Test complete user workflows
4. **Fuzz Tests**: Test with random inputs to find edge cases
5. **Invariant Tests**: Test system properties that should always hold

## Running Tests

### Basic Commands

```bash
# Run all tests
forge test

# Run specific test file
forge test --match-path "test/Compact.t.sol"

# Run specific test function
forge test --match-test "testLockResources"

# Run with verbose output
forge test -vvvv

# Run with gas reporting
forge test --gas-report

# Run coverage
forge coverage
```

### Test Categories

```bash
# Run unit tests only
forge test --match-contract "UnitTest"

# Run integration tests only
forge test --match-contract "IntegrationTest"

# Run fuzz tests only
forge test --match-test "testFuzz"
```

## Test Structure

### Test File Organization

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import "../src/Compact.sol";
import "../src/ResourceManager.sol";

contract CompactTest is Test {
    // Setup
    Compact public compact;
    ResourceManager public resourceManager;

    // Test addresses
    address public maker = address(1);
    address public taker = address(2);

    function setUp() public {
        // Deploy contracts
        resourceManager = new ResourceManager(address(0), address(this));
        compact = new Compact(address(resourceManager));

        // Setup test environment
        setupUsers();
    }

    // Unit Tests
    function testLockResources() public {
        // Test implementation
    }

    // Integration Tests
    function testEndToEndFlow() public {
        // Test implementation
    }

    // Fuzz Tests
    function testFuzz_ResourceLocking(uint256 amount) public {
        // Test implementation
    }

    // Helper functions
    function setupUsers() internal {
        // Setup implementation
    }
}
```

### Test Naming Conventions

```solidity
// Unit tests
function testFunctionName() public { }
function testFunctionName_WithSpecificScenario() public { }

// Integration tests
function testIntegration_ComponentInteraction() public { }
function testEndToEnd_CompleteWorkflow() public { }

// Fuzz tests
function testFuzz_InputValidation(uint256 input) public { }
function testFuzz_BoundaryConditions(uint256 amount) public { }

// Invariant tests
function invariant_PropertyName() public { }
function invariant_StateConsistency() public { }
```

## Test Examples

### Unit Tests

```solidity
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
    assertTrue(resourceManager.resourceLocks(lockId).isActive);
}

function testLockResources_RevertsOnZeroAmount() public {
    // Arrange
    address maker = address(1);
    address token = address(dai);
    uint256 amount = 0;

    // Act & Assert
    vm.expectRevert(ResourceManager.InvalidAmount.selector);
    resourceManager.lockResources(maker, token, amount);
}
```

### Integration Tests

```solidity
function testEndToEnd_ResourceLockingFlow() public {
    // 1. Lock resources
    uint256 lockId = resourceManager.lockResources(makerAddr, address(dai), 1000 ether);

    // 2. Create order with resource validation
    Order memory order = createOrderWithResourceLock();

    // 3. Execute order
    swap.fillOrder(order);

    // 4. Verify results
    assertEq(dai.balanceOf(treasurer), 500 ether);
    assertEq(resourceManager.getAvailableBalance(makerAddr, address(dai)), 500 ether);
}
```

### Fuzz Tests

```solidity
function testFuzz_ResourceLocking(uint256 amount) public {
    // Bound the input
    vm.assume(amount > 0 && amount <= 1000000 ether);

    // Test the function
    uint256 lockId = resourceManager.lockResources(makerAddr, address(dai), amount);

    // Verify the result
    assertEq(resourceManager.getAvailableBalance(makerAddr, address(dai)), amount);
    assertTrue(resourceManager.resourceLocks(lockId).isActive);
}

function testFuzz_PriceCalculation(uint256 price, uint256 amount) public {
    // Bound inputs
    vm.assume(price > 0 && price <= 1e20);
    vm.assume(amount > 0 && amount <= 1e18);

    // Test price calculation
    uint256 result = compact.calculatePrice(price, amount);

    // Verify result is reasonable
    assertGt(result, 0);
    assertLt(result, type(uint256).max);
}
```

### Invariant Tests

```solidity
function invariant_TotalLockedEqualsSumOfLocks() public {
    uint256 totalLocked = 0;

    // Sum all active locks
    for (uint256 i = 1; i <= resourceManager.nextLockId() - 1; i++) {
        ResourceManager.ResourceLock memory lock = resourceManager.resourceLocks(i);
        if (lock.isActive) {
            totalLocked += lock.amount;
        }
    }

    // Verify invariant
    assertEq(totalLocked, dai.balanceOf(address(resourceManager)));
}

function invariant_NoNegativeBalances() public {
    // Check all user balances are non-negative
    assertGe(dai.balanceOf(makerAddr), 0);
    assertGe(dai.balanceOf(takerAddr), 0);
    assertGe(dai.balanceOf(treasurer), 0);
}
```

## Test Utilities

### Mock Contracts

```solidity
contract MockOracle is AggregatorV3Interface {
    int256 public price;
    uint8 public decimals;

    constructor(int256 _price, uint8 _decimals) {
        price = _price;
        decimals = _decimals;
    }

    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (1, price, block.timestamp, block.timestamp, 1);
    }

    // Implement other interface functions...
}
```

### Test Helpers

```solidity
contract TestHelpers {
    function createOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount
    ) internal pure returns (Order memory) {
        return Order({
            salt: 0,
            maker: Address.wrap(uint256(uint160(maker))),
            receiver: Address.wrap(0),
            makerAsset: Address.wrap(uint256(uint160(makerAsset))),
            takerAsset: Address.wrap(uint256(uint160(takerAsset))),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: MakerTraits.wrap(0)
        });
    }

    function signOrder(bytes32 orderHash, uint256 privateKey) internal pure returns (bytes32 r, bytes32 vs) {
        (uint8 v, bytes32 r_, bytes32 s) = vm.sign(privateKey, orderHash);
        r = r_;
        uint8 yParity = v - 27;
        vs = bytes32(uint256(s) | (uint256(yParity) << 255));
    }
}
```

## Gas Testing

### Gas Snapshots

```bash
# Generate gas snapshot
forge snapshot

# Compare with previous snapshot
forge snapshot --check

# Update snapshot
forge snapshot --snap .gas-snapshot
```

### Gas Optimization Testing

```solidity
function testGas_LockResources() public {
    uint256 gasBefore = gasleft();

    resourceManager.lockResources(makerAddr, address(dai), 1000 ether);

    uint256 gasUsed = gasBefore - gasleft();
    console.log("Gas used for lockResources:", gasUsed);
}
```

## Coverage Testing

### Coverage Commands

```bash
# Generate coverage report
forge coverage

# Generate coverage with lcov
forge coverage --report lcov

# Generate coverage for specific files
forge coverage --match-path "src/Compact.sol"
```

### Coverage Targets

- **Line Coverage**: > 90%
- **Branch Coverage**: > 85%
- **Function Coverage**: > 95%

## Property-Based Testing

### Invariant Properties

```solidity
function invariant_ResourceConservation() public {
    // Total resources should be conserved
    uint256 totalLocked = resourceManager.getTotalLocked();
    uint256 totalAllocated = resourceManager.getTotalAllocated();
    uint256 totalUnlocked = resourceManager.getTotalUnlocked();

    assertEq(totalLocked, totalAllocated + totalUnlocked);
}

function invariant_NoDoubleSpending() public {
    // No resource should be allocated more than locked
    for (uint256 i = 1; i <= resourceManager.nextLockId() - 1; i++) {
        ResourceManager.ResourceLock memory lock = resourceManager.resourceLocks(i);
        if (lock.isActive) {
            assertLe(lock.allocatedAmount, lock.amount);
        }
    }
}
```

## Stress Testing

### Load Testing

```solidity
function testStress_MultipleLocks() public {
    uint256 numLocks = 100;

    for (uint256 i = 0; i < numLocks; i++) {
        address maker = address(uint160(i + 1));
        uint256 amount = 1000 ether;

        resourceManager.lockResources(maker, address(dai), amount);
    }

    assertEq(resourceManager.nextLockId(), numLocks + 1);
}
```

### Boundary Testing

```solidity
function testBoundary_MaximumAmount() public {
    uint256 maxAmount = type(uint256).max;

    vm.expectRevert(); // Should revert due to overflow
    resourceManager.lockResources(makerAddr, address(dai), maxAmount);
}

function testBoundary_ZeroAddress() public {
    vm.expectRevert(ResourceManager.InvalidToken.selector);
    resourceManager.lockResources(makerAddr, address(0), 1000 ether);
}
```

## Debugging Tests

### Verbose Output

```bash
# Run with maximum verbosity
forge test -vvvv

# Run specific test with verbosity
forge test --match-test "testFunction" -vvvv
```

### Console Logging

```solidity
import "forge-std/console.sol";

function testWithLogging() public {
    console.log("Testing with amount:", 1000 ether);

    uint256 result = someFunction(1000 ether);
    console.log("Result:", result);
}
```

### Debugging Failed Tests

```bash
# Run failed test with debug info
forge test --match-test "testFunction" -vvvv --fuzz-runs 1000

# Trace specific transaction
forge trace <tx-hash> --rpc-url <rpc-url>
```

## Best Practices

### Test Organization

1. **Setup**: Use `setUp()` for common initialization
2. **Teardown**: Clean up state after tests
3. **Isolation**: Each test should be independent
4. **Naming**: Use descriptive test names
5. **Documentation**: Comment complex test logic

### Test Data

1. **Fixtures**: Use test fixtures for common data
2. **Factories**: Create helper functions for test objects
3. **Randomization**: Use fuzz testing for edge cases
4. **Boundaries**: Test boundary conditions explicitly

### Performance

1. **Fast Tests**: Keep unit tests fast (< 1 second)
2. **Parallel Execution**: Use `--jobs` flag for parallel tests
3. **Gas Optimization**: Monitor gas usage in tests
4. **Memory Management**: Clean up large test data

## Continuous Integration

### GitHub Actions Example

```yaml
name: Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: actions/setup-node@v3
        with:
          node-version: "18"
      - name: Install Foundry
        run: curl -L https://foundry.paradigm.xyz | bash
      - name: Run tests
        run: |
          source ~/.bashrc
          forge test
      - name: Generate coverage
        run: forge coverage
```

## Resources

### Testing Tools

- [Foundry Testing](https://book.getfoundry.sh/forge/tests)
- [Forge Standard Library](https://github.com/foundry-rs/forge-std)
- [Hardhat Testing](https://hardhat.org/tutorial/testing-contracts)

### Testing Patterns

- [AAA Pattern](https://en.wikipedia.org/wiki/Arrange-Act-Assert)
- [Given-When-Then](https://en.wikipedia.org/wiki/Given-When-Then)
- [Test-Driven Development](https://en.wikipedia.org/wiki/Test-driven_development)

### Advanced Testing

- [Property-Based Testing](https://en.wikipedia.org/wiki/Property-based_testing)
- [Fuzz Testing](https://en.wikipedia.org/wiki/Fuzzing)
- [Invariant Testing](<https://en.wikipedia.org/wiki/Invariant_(mathematics)>)
