# OrderUtils Library

A Solidity library that provides utilities for building and manipulating 1inch Limit Order Protocol orders. This library is a direct port of the JavaScript `orderUtils.js` functionality to Solidity.

## Overview

The `OrderUtils` library provides comprehensive functionality for:

- Building maker and taker traits
- Constructing orders with extensions
- Creating RFQ (Request for Quote) orders
- Building fee taker extensions
- Order signature verification
- Utility functions for common order operations

## Key Features

### 1. Order Structure

```solidity
struct Order {
    uint256 salt;
    address maker;
    address receiver;
    address makerAsset;
    address takerAsset;
    uint256 makingAmount;
    uint256 takingAmount;
    uint256 makerTraits;
}
```

### 2. Taker Traits

```solidity
struct TakerTraits {
    uint256 traits;
    bytes args;
}
```

### 3. Fee Taker Extensions

```solidity
struct FeeTakerExtensions {
    bytes makingAmountData;
    bytes takingAmountData;
    bytes postInteraction;
}
```

## Core Functions

### Building Maker Traits

#### `buildMakerTraits()`

Creates maker traits with full customization options:

```solidity
function buildMakerTraits(
    address allowedSender,
    bool shouldCheckEpoch,
    bool allowPartialFill,
    bool allowMultipleFills,
    bool usePermit2,
    bool unwrapWeth,
    uint256 expiry,
    uint256 nonce,
    uint256 series
) internal pure returns (uint256)
```

#### `buildMakerTraitsRFQ()`

Creates maker traits specifically for RFQ orders:

```solidity
function buildMakerTraitsRFQ(
    address allowedSender,
    bool shouldCheckEpoch,
    bool allowPartialFill,
    bool usePermit2,
    bool unwrapWeth,
    uint256 expiry,
    uint256 nonce,
    uint256 series
) internal pure returns (uint256)
```

### Building Taker Traits

#### `buildTakerTraits()`

Creates taker traits with various options:

```solidity
function buildTakerTraits(
    bool makingAmount,
    bool unwrapWeth,
    bool skipMakerPermitFlag,
    bool usePermit2,
    bytes memory target,
    bytes memory extension,
    bytes memory interaction,
    uint256 threshold
) internal pure returns (TakerTraits memory)
```

### Building Orders

#### `buildOrder()`

Creates a complete order with extension:

```solidity
function buildOrder(
    Order memory order,
    bytes memory makerAssetSuffix,
    bytes memory takerAssetSuffix,
    bytes memory makingAmountData,
    bytes memory takingAmountData,
    bytes memory predicate,
    bytes memory permit,
    bytes memory preInteraction,
    bytes memory postInteraction,
    bytes memory customData
) internal pure returns (Order memory, bytes memory)
```

#### `buildOrderRFQ()`

Creates an RFQ order:

```solidity
function buildOrderRFQ(
    Order memory order,
    bytes memory makerAssetSuffix,
    bytes memory takerAssetSuffix,
    bytes memory makingAmountData,
    bytes memory takingAmountData,
    bytes memory predicate,
    bytes memory permit,
    bytes memory preInteraction,
    bytes memory postInteraction
) internal pure returns (Order memory, bytes memory)
```

### Fee Taker Extensions

#### `buildFeeTakerExtensions()`

Creates fee taker extensions for complex fee structures:

```solidity
function buildFeeTakerExtensions(
    address feeTaker,
    bytes memory getterExtraPrefix,
    address integratorFeeRecipient,
    address protocolFeeRecipient,
    address makerReceiver,
    uint16 integratorFee,
    uint8 integratorShare,
    uint16 resolverFee,
    uint8 whitelistDiscount,
    bytes memory whitelist,
    bytes memory whitelistPostInteraction,
    bytes memory customMakingGetter,
    bytes memory customTakingGetter,
    bytes memory customPostInteraction
) internal pure returns (FeeTakerExtensions memory)
```

### Signature Verification

#### `buildOrderData()`

Builds order data for EIP-712 signing:

```solidity
function buildOrderData(
    uint256 chainId,
    address verifyingContract,
    Order memory order
) internal pure returns (bytes32)
```

#### `verifyOrderSignature()`

Verifies order signatures:

```solidity
function verifyOrderSignature(
    Order memory order,
    uint256 chainId,
    address verifyingContract,
    bytes memory signature
) internal pure returns (address)
```

### Utility Functions

#### `fillWithMakingAmount()`

Creates taker traits for filling with making amount:

```solidity
function fillWithMakingAmount(uint256 amount) internal pure returns (uint256)
```

#### `unwrapWethTaker()`

Creates taker traits for unwrapping WETH:

```solidity
function unwrapWethTaker(uint256 amount) internal pure returns (uint256)
```

#### `skipMakerPermit()`

Creates taker traits for skipping maker permit:

```solidity
function skipMakerPermit(uint256 amount) internal pure returns (uint256)
```

#### `setBit()` and `getBit()`

Utility functions for bit manipulation:

```solidity
function setBit(uint256 value, uint256 bit, bool set) internal pure returns (uint256)
function getBit(uint256 value, uint256 bit) internal pure returns (bool)
```

## Usage Examples

### Basic Order Creation

```solidity
import "./OrderUtils.sol";

contract MyContract {
    using OrderUtils for *;

    function createSimpleOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount
    ) external pure returns (OrderUtils.Order memory, bytes memory) {
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: maker,
            receiver: address(0),
            makerAsset: makerAsset,
            takerAsset: takerAsset,
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: OrderUtils.buildMakerTraits(
                address(0), false, true, true, false, false, 0, 0, 0
            )
        });

        return OrderUtils.buildOrder(
            baseOrder,
            "", "", "", "", "", "", "", "", ""
        );
    }
}
```

### RFQ Order Creation

```solidity
function createRFQOrder(
    address maker,
    address makerAsset,
    address takerAsset,
    uint256 makingAmount,
    uint256 takingAmount
) external pure returns (OrderUtils.Order memory, bytes memory) {
    OrderUtils.Order memory baseOrder = OrderUtils.Order({
        salt: 0,
        maker: maker,
        receiver: address(0),
        makerAsset: makerAsset,
        takerAsset: takerAsset,
        makingAmount: makingAmount,
        takingAmount: takingAmount,
        makerTraits: OrderUtils.buildMakerTraitsRFQ(
            address(0), false, true, false, false, 0, 0, 0
        )
    });

    return OrderUtils.buildOrderRFQ(
        baseOrder, "", "", "", "", "", "", "", ""
    );
}
```

### Taker Traits Creation

```solidity
function createTakerTraits(
    bool makingAmount,
    bool unwrapWeth,
    uint256 threshold
) external pure returns (OrderUtils.TakerTraits memory) {
    return OrderUtils.buildTakerTraits(
        makingAmount,
        unwrapWeth,
        false, // skipMakerPermit
        false, // usePermit2
        "",    // target
        "",    // extension
        "",    // interaction
        threshold
    );
}
```

## Constants

The library includes several important constants:

- `NAME`: "1inch Limit Order Protocol"
- `VERSION`: "4"

## Testing

The library includes comprehensive tests in `test/OrderUtils.t.sol` that cover:

- Maker traits building
- Taker traits building
- Order creation
- RFQ order creation
- Fee taker extensions
- Signature verification
- Utility functions

Run the tests with:

```bash
forge test --match-contract OrderUtilsTest -vv
```

## Dependencies

- OpenZeppelin Contracts (for ECDSA functionality)
- Solidity ^0.8.0

## Security Considerations

- All functions are `pure` or `view` to ensure no state changes
- Input validation is included for critical parameters
- Bit manipulation is handled safely
- Signature verification uses standard EIP-712 format

## Migration from JavaScript

This library provides equivalent functionality to the JavaScript `orderUtils.js` file. Key differences:

1. **Type Safety**: Solidity provides compile-time type checking
2. **Gas Optimization**: Functions are optimized for on-chain execution
3. **Memory Management**: Uses Solidity's memory model for efficient data handling
4. **Error Handling**: Uses Solidity's revert mechanism for error conditions

## License

MIT License - same as the original JavaScript implementation.
