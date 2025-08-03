# OracleCalculator Extension for Limit Order Protocol

## Overview

The OracleCalculator extension is a powerful addition to the 1inch Limit Order Protocol that enables dynamic pricing based on Chainlink oracle data. This extension allows orders to be filled at prices that are calculated on-chain using real-time oracle feeds, making it possible to create orders that automatically adjust to market conditions.

## 1. What the OracleCalculator Extension Does

The OracleCalculator extension serves as an `IAmountGetter` implementation that:

- **Calculates dynamic exchange rates** using Chainlink oracle data
- **Supports both single and double oracle pricing** for different token pairs
- **Applies configurable spreads** to provide maker/taker incentives
- **Handles inverse pricing** for tokens quoted in different base currencies
- **Validates oracle freshness** to ensure price data is current (within 4 hours)
- **Integrates with predicates** for conditional order execution

### Key Features:

1. **Single Oracle Pricing**: Uses one oracle to price a token relative to ETH or USD
2. **Double Oracle Pricing**: Uses two oracles to price custom token pairs (e.g., INCH/DAI)
3. **Spread Application**: Applies maker and taker spreads to create profitable order books
4. **Inverse Flag Support**: Handles cases where oracle prices need to be inverted
5. **Oracle Freshness Check**: Ensures oracle data is not stale (within 4 hours TTL)

## 2. Types of Orders That Can Be Created

### A. Single Oracle Orders

Orders that use one Chainlink oracle to price a token relative to ETH or USD:

- **ETH → DAI**: Using DAI/ETH oracle
- **DAI → ETH**: Using DAI/ETH oracle with inverse flag
- **WETH → USDC**: Using USDC/ETH oracle
- **USDC → WETH**: Using USDC/ETH oracle with inverse flag

### B. Double Oracle Orders

Orders that use two oracles to price custom token pairs:

- **INCH → DAI**: Using INCH/ETH and DAI/ETH oracles
- **DAI → INCH**: Using DAI/ETH and INCH/ETH oracles
- **Custom Token Pairs**: Any combination of tokens with available oracles

### C. Conditional Orders (Predicates)

Orders that only execute under specific oracle conditions:

- **Stop-Loss Orders**: Execute only when price falls below threshold
- **Take-Profit Orders**: Execute only when price rises above threshold
- **Range Orders**: Execute only within specific price ranges

## 3. Fields Passed to the Extension and How They Are Populated

### Extension Data Structure

The extension data is passed as `bytes calldata extraData` to the `getMakingAmount` and `getTakingAmount` functions:

```solidity
function getMakingAmount(
    IOrderMixin.Order calldata order,
    bytes calldata extension,
    bytes32 orderHash,
    address taker,
    uint256 takingAmount,
    uint256 remainingMakingAmount,
    bytes calldata extraData  // ← Extension data here
) external view returns (uint256)
```

### Single Oracle Data Format

For single oracle pricing, the `extraData` contains:

```
[1 byte flags][20 bytes oracle address][32 bytes spread]
```

**Flags Byte:**

- Bit 7 (0x80): Inverse flag - if set, invert the oracle price
- Bit 6 (0x40): Double price flag - if set, use double oracle mode
- Bits 0-5: Reserved

**Example:**

```solidity
// DAI/ETH oracle at 0x1234... with 0.99 spread, no inverse
bytes memory data = abi.encodePacked(
    bytes1(0x00),           // flags: no inverse, no double price
    address(daiOracle),      // oracle address
    uint256(990000000)       // spread: 0.99 (990000000 / 1e9)
);
```

### Double Oracle Data Format

For double oracle pricing, the `extraData` contains:

```
[1 byte flags][20 bytes oracle1][20 bytes oracle2][32 bytes decimalsScale][32 bytes spread]
```

**Example:**

```solidity
// INCH/DAI pricing using INCH/ETH and DAI/ETH oracles
bytes memory data = abi.encodePacked(
    bytes1(0x40),           // flags: double price mode
    address(inchOracle),     // oracle1: INCH/ETH
    address(daiOracle),      // oracle2: DAI/ETH
    int256(0),              // decimalsScale: no adjustment
    uint256(1010000000)     // spread: 1.01 (1010000000 / 1e9)
);
```

### How Fields Are Populated

1. **Oracle Addresses**: Retrieved from Chainlink's oracle registry or deployment
2. **Spreads**: Calculated based on desired maker/taker incentives (typically 0.99 for maker, 1.01 for taker)
3. **Flags**: Set based on pricing requirements (inverse needed, double oracle needed)
4. **Decimals Scale**: Used to adjust for different oracle decimal precisions

## 4. Test Case Walkthrough

### Test Case 1: ETH → DAI Chainlink Order

**Scenario**: Maker wants to sell 1 ETH for DAI at oracle price with spreads

**Order Details:**

- Maker: makerAddr
- Taker: takerAddr
- Maker Asset: WETH (1 ether)
- Taker Asset: DAI (4000 ether)
- Oracle: DAI/ETH at 0.00025 ETH per DAI (1 ETH = 4000 DAI)

**Extension Data:**

```solidity
// Making amount data (maker spread: 0.99)
bytes memory makingAmountData = abi.encodePacked(
    chainlinkCalcAddress,    // Calculator address
    bytes1(0x00),           // No inverse flag
    oracleAddress,           // DAI oracle
    uint256(990000000)       // 0.99 spread
);

// Taking amount data (taker spread: 1.01)
bytes memory takingAmountData = abi.encodePacked(
    chainlinkCalcAddress,    // Calculator address
    bytes1(0x80),           // Inverse flag set
    oracleAddress,           // DAI oracle
    uint256(1010000000)     // 1.01 spread
);
```

**Execution Flow:**

1. Taker calls `fillOrderArgs` with 4000 DAI
2. Protocol calls `getTakingAmount` with 4000 DAI
3. Calculator applies 1.01 spread: 4000 \* 1.01 = 4040 DAI
4. Protocol calls `getMakingAmount` with 4040 DAI
5. Calculator applies 0.99 spread: 4040 \* 0.99 / 4000 = 0.99 ETH
6. Order executes: taker receives 0.99 ETH, maker receives 4000 DAI

**Result**: Taker pays 4000 DAI, receives 0.99 ETH (effective rate: 1 ETH = 4040.4 DAI)

### Test Case 2: DAI → ETH Chainlink Order

**Scenario**: Maker wants to sell 4000 DAI for ETH at oracle price

**Order Details:**

- Maker: makerAddr
- Taker: takerAddr
- Maker Asset: DAI (4000 ether)
- Taker Asset: WETH (1 ether)
- Oracle: DAI/ETH at 0.00025 ETH per DAI

**Extension Data:**

```solidity
// Making amount data (inverse + maker spread)
bytes memory makingAmountData = abi.encodePacked(
    chainlinkCalcAddress,
    bytes1(0x80),           // Inverse flag
    oracleAddress,
    uint256(990000000)       // 0.99 spread
);

// Taking amount data (no inverse + taker spread)
bytes memory takingAmountData = abi.encodePacked(
    chainlinkCalcAddress,
    bytes1(0x00),           // No inverse flag
    oracleAddress,
    uint256(1010000000)     // 1.01 spread
);
```

**Execution Flow:**

1. Taker calls with `makingAmount` flag set to true
2. Protocol calls `getMakingAmount` with 4000 DAI
3. Calculator applies inverse + 0.99 spread: 4000 \* 0.99 / 4000 = 0.99 ETH
4. Protocol calls `getTakingAmount` with 0.99 ETH
5. Calculator applies 1.01 spread: 0.99 \* 1.01 = 1.01 ETH
6. Order executes: taker receives 4000 DAI, maker receives 1.01 ETH

**Result**: Taker pays 1.01 ETH, receives 4000 DAI (effective rate: 1 ETH = 3960.4 DAI)

### Test Case 3: INCH → DAI Double Oracle Order

**Scenario**: Maker wants to sell 100 INCH for DAI using double oracle pricing

**Order Details:**

- Maker: makerAddr
- Taker: takerAddr
- Maker Asset: INCH (100 ether)
- Taker Asset: DAI (632 ether)
- Oracles: INCH/ETH (0.0001577615249227853 ETH) and DAI/ETH (0.00025 ETH)

**Extension Data:**

```solidity
// Making amount data (double oracle + maker spread)
bytes memory makingAmountData = abi.encodePacked(
    chainlinkCalcAddress,
    bytes1(0x40),           // Double price flag
    address(daiOracle),      // Oracle1: DAI/ETH
    address(inchOracle),     // Oracle2: INCH/ETH
    int256(0),              // No decimals adjustment
    uint256(990000000)       // 0.99 spread
);

// Taking amount data (double oracle + taker spread)
bytes memory takingAmountData = abi.encodePacked(
    chainlinkCalcAddress,
    bytes1(0x40),           // Double price flag
    address(inchOracle),     // Oracle1: INCH/ETH
    address(daiOracle),      // Oracle2: DAI/ETH
    int256(0),              // No decimals adjustment
    uint256(1010000000)     // 1.01 spread
);
```

**Execution Flow:**

1. Taker calls with `makingAmount` flag set to true
2. Protocol calls `getMakingAmount` with 100 INCH
3. Calculator applies double oracle calculation:
   - INCH price in ETH: 0.0001577615249227853
   - DAI price in ETH: 0.00025
   - INCH/DAI rate: 0.0001577615249227853 / 0.00025 = 0.631046
   - With 0.99 spread: 100 _ 0.631046 _ 0.99 = 62.47 DAI
4. Protocol calls `getTakingAmount` with 62.47 DAI
5. Calculator applies inverse calculation with 1.01 spread
6. Order executes with calculated amounts

**Result**: Complex pricing based on two oracle feeds with spread adjustments

### Test Case 4: Stop-Loss Order with Predicate

**Scenario**: Maker wants to sell INCH for DAI only if INCH/DAI price falls below 6.32

**Order Details:**

- Maker: makerAddr
- Taker: takerAddr
- Maker Asset: INCH (100 ether)
- Taker Asset: DAI (631 ether)
- Predicate: INCH/DAI price < 6.32

**Predicate Construction:**

```solidity
// Build price call for predicate
bytes memory priceCall = abi.encodeWithSelector(
    OracleCalculator .doublePrice.selector,
    inchOracle,    // INCH/ETH oracle
    daiOracle,     // DAI/ETH oracle
    int256(0),     // No decimals adjustment
    1 ether        // Base amount
);

// Build predicate call
bytes memory predicate = abi.encodeWithSelector(
    swap.lt.selector,        // Less than comparison
    6.32 ether,             // Threshold: 6.32
    abi.encodeWithSelector(
        swap.arbitraryStaticCall.selector,
        address(oracleCalculator ),
        priceCall
    )
);
```

**Execution Flow:**

1. Order fill is attempted
2. Protocol evaluates predicate before execution
3. Predicate calls `OracleCalculator .doublePrice()` with oracle data
4. Calculated INCH/DAI price is compared to 6.32 threshold
5. If price < 6.32: order executes normally
6. If price ≥ 6.32: order reverts with predicate failure

**Result**: Order only executes when INCH/DAI price is below the specified threshold

### Test Case 5: Simple Order Without Extension

**Scenario**: Basic order without any Chainlink integration

**Order Details:**

- Maker: makerAddr
- Taker: takerAddr
- Maker Asset: WETH (1 ether)
- Taker Asset: DAI (4000 ether)
- No extensions or predicates

**Execution Flow:**

1. Taker calls `fillOrderArgs` with 4000 DAI
2. No extension data provided
3. Protocol uses default proportional calculation
4. Order executes at fixed 1:4000 ratio

**Result**: Simple fixed-rate order execution without dynamic pricing

## Key Implementation Details

### Oracle Freshness Check

```solidity
if (updatedAt + _ORACLE_TTL < block.timestamp) revert StaleOraclePrice();
```

- Ensures oracle data is not older than 4 hours
- Prevents execution with stale price data

### Spread Application

```solidity
return spread * amount * latestAnswer.toUint256() / (10 ** oracle.decimals()) / _SPREAD_DENOMINATOR;
```

- Spreads are applied as multipliers (e.g., 990000000 = 0.99)
- `_SPREAD_DENOMINATOR = 1e9` for 9-decimal precision

### Double Oracle Calculation

```solidity
result = amount * latestAnswer1.toUint256();
if (decimalsScale > 0) {
    result *= 10 ** decimalsScale.toUint256();
} else if (decimalsScale < 0) {
    result /= 10 ** (-decimalsScale).toUint256();
}
result /= latestAnswer2.toUint256();
```

- Calculates cross-oracle pricing for custom token pairs
- Handles decimal precision adjustments between oracles

This extension enables sophisticated DeFi applications that can automatically adjust to market conditions while providing liquidity providers with profitable spreads.
