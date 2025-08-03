// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IAmountGetter.sol";
import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import "./ResourceManager.sol";

// solhint-disable not-rely-on-time

/// @title Compact - ERC-6909 enabled Chainlink Calculator
/// @notice A helper contract for interactions with Chainlink with ERC-6909 resource locking
contract Compact is IAmountGetter {
    using SafeCast for int256;

    error DifferentOracleDecimals();
    error StaleOraclePrice();
    error InsufficientResourceLock(address maker, address token, uint256 requested, uint256 available);
    error ResourceLockNotFound(address maker, address token);
    error ERC6909NotEnabled();
    error InvalidResourceManager();

    uint256 private constant _SPREAD_DENOMINATOR = 1e9;
    uint256 private constant _ORACLE_TTL = 4 hours;
    bytes1 private constant _INVERSE_FLAG = 0x80;
    bytes1 private constant _DOUBLE_PRICE_FLAG = 0x40;

    // ERC-6909 integration
    ResourceManager public immutable resourceManager;
    bool public erc6909Enabled;

    constructor(address _resourceManager) {
        resourceManager = ResourceManager(_resourceManager);
        erc6909Enabled = true;
    }

    /// @notice Enable or disable ERC-6909 functionality
    /// @param enabled Whether to enable ERC-6909
    function setERC6909Enabled(bool enabled) external {
        erc6909Enabled = enabled;
    }

    /// @notice Calculates price of token A relative to token B. Note that order is important
    /// @return result Token A relative price times amount
    function doublePrice(
        AggregatorV3Interface oracle1,
        AggregatorV3Interface oracle2,
        int256 decimalsScale,
        uint256 amount
    ) external view returns (uint256 result) {
        return _doublePrice(oracle1, oracle2, decimalsScale, amount);
    }

    function getMakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external view returns (uint256) {
        // Check ERC-6909 resource locks if enabled
        if (erc6909Enabled) {
            _validateResourceLock(
                address(uint160(Address.unwrap(order.maker))),
                address(uint160(Address.unwrap(order.makerAsset))),
                takingAmount
            );
        }

        return _getSpreadedAmount(takingAmount, extraData);
    }

    function getTakingAmount(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external view returns (uint256) {
        // Check ERC-6909 resource locks if enabled
        if (erc6909Enabled) {
            _validateResourceLock(
                address(uint160(Address.unwrap(order.maker))),
                address(uint160(Address.unwrap(order.makerAsset))),
                makingAmount
            );
        }

        return _getSpreadedAmount(makingAmount, extraData);
    }

    /// @notice Validate that the maker has sufficient resource lock for the requested amount
    /// @param maker The maker address
    /// @param token The token address
    /// @param amount The requested amount
    function _validateResourceLock(address maker, address token, uint256 amount) internal view {
        uint256 available = resourceManager.getAvailableBalance(maker, token);
        if (available < amount) {
            revert InsufficientResourceLock(maker, token, amount, available);
        }
    }

    /// @notice Allocate resources for an order execution
    /// @param maker The maker address
    /// @param token The token address
    /// @param amount The amount to allocate
    /// @param lockId The lock ID to allocate from
    function allocateResources(address maker, address token, uint256 amount, uint256 lockId) external {
        if (!erc6909Enabled) revert ERC6909NotEnabled();

        resourceManager.allocateResources(lockId, amount);
    }

    /// @notice Release allocated resources after order execution
    /// @param lockId The lock ID to release from
    /// @param amount The amount to release
    function releaseResources(uint256 lockId, uint256 amount) external {
        if (!erc6909Enabled) revert ERC6909NotEnabled();

        resourceManager.releaseResources(lockId, amount);
    }

    /// @notice Get the lock ID for a maker's token
    /// @param maker The maker address
    /// @param token The token address
    /// @return lockId The lock ID
    function getLockId(address maker, address token) external view returns (uint256 lockId) {
        // This would need to be implemented in ResourceManager or tracked here
        // For now, we'll use a simple mapping approach
        return resourceManager.makerTokenLocks(maker, token);
    }

    /// @notice Calculates price of token relative to oracle unit (ETH or USD)
    /// The first byte of the blob contain inverse and useDoublePrice flags,
    /// The inverse flag is set when oracle price should be inverted,
    /// e.g. for DAI-ETH oracle, inverse=false means that we request DAI price in ETH
    /// and inverse=true means that we request ETH price in DAI
    /// The useDoublePrice flag is set when needs price for two custom tokens (other than ETH or USD)
    /// @return Amount * spread * oracle price
    function _getSpreadedAmount(uint256 amount, bytes calldata blob) internal view returns (uint256) {
        bytes1 flags = bytes1(blob[:1]);
        if (flags & _DOUBLE_PRICE_FLAG == _DOUBLE_PRICE_FLAG) {
            AggregatorV3Interface oracle1 = AggregatorV3Interface(address(bytes20(blob[1:21])));
            AggregatorV3Interface oracle2 = AggregatorV3Interface(address(bytes20(blob[21:41])));
            int256 decimalsScale = int256(uint256(bytes32(blob[41:73])));
            uint256 spread = uint256(bytes32(blob[73:105]));
            return _doublePrice(oracle1, oracle2, decimalsScale, spread * amount) / _SPREAD_DENOMINATOR;
        } else {
            AggregatorV3Interface oracle = AggregatorV3Interface(address(bytes20(blob[1:21])));
            uint256 spread = uint256(bytes32(blob[21:53]));
            (, int256 latestAnswer,, uint256 updatedAt,) = oracle.latestRoundData();
            // solhint-disable-next-line not-rely-on-time
            if (updatedAt + _ORACLE_TTL < block.timestamp) revert StaleOraclePrice();
            if (flags & _INVERSE_FLAG == _INVERSE_FLAG) {
                return spread * amount * (10 ** oracle.decimals()) / latestAnswer.toUint256() / _SPREAD_DENOMINATOR;
            } else {
                return spread * amount * latestAnswer.toUint256() / (10 ** oracle.decimals()) / _SPREAD_DENOMINATOR;
            }
        }
    }

    function _doublePrice(
        AggregatorV3Interface oracle1,
        AggregatorV3Interface oracle2,
        int256 decimalsScale,
        uint256 amount
    ) internal view returns (uint256 result) {
        if (oracle1.decimals() != oracle2.decimals()) revert DifferentOracleDecimals();

        {
            (, int256 latestAnswer,, uint256 updatedAt,) = oracle1.latestRoundData();
            // solhint-disable-next-line not-rely-on-time
            if (updatedAt + _ORACLE_TTL < block.timestamp) revert StaleOraclePrice();
            result = amount * latestAnswer.toUint256();
        }

        if (decimalsScale > 0) {
            result *= 10 ** decimalsScale.toUint256();
        } else if (decimalsScale < 0) {
            result /= 10 ** (-decimalsScale).toUint256();
        }

        {
            (, int256 latestAnswer,, uint256 updatedAt,) = oracle2.latestRoundData();
            // solhint-disable-next-line not-rely-on-time
            if (updatedAt + _ORACLE_TTL < block.timestamp) revert StaleOraclePrice();
            result /= latestAnswer.toUint256();
        }
    }
}

// solhint-enable not-rely-on-time
