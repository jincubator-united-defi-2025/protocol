// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IPostInteraction.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title RebalancerInteraction
/// @notice Post-interaction contract that transfers output tokens to a treasurer wallet
/// @dev Implements IPostInteraction interface for the Limit Order Protocol
contract RebalancerInteraction is IPostInteraction {
    using SafeERC20 for IERC20;

    error TransferFailed();
    error InvalidTreasurer();

    /// @notice Treasurer wallet address that receives the output tokens
    address public immutable treasurer;

    /// @notice Emitted when tokens are transferred to treasurer
    event TokensTransferredToTreasurer(
        address indexed token, address indexed from, address indexed treasurer, uint256 amount
    );

    /// @param _treasurer The address of the treasurer wallet
    constructor(address _treasurer) {
        if (_treasurer == address(0)) revert InvalidTreasurer();
        treasurer = _treasurer;
    }

    /// @notice Post-interaction callback that transfers output tokens to treasurer
    /// @param order The order that was filled
    /// @param extension Order extension data
    /// @param orderHash The hash of the order
    /// @param taker The address of the taker who filled the order
    /// @param makingAmount The amount of maker asset that was transferred
    /// @param takingAmount The amount of taker asset that was transferred
    /// @param remainingMakingAmount The remaining maker amount in the order
    /// @param extraData Additional data passed to the interaction (unused in this implementation)
    function postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external override {
        // Transfer the taker's output tokens (maker asset) to the treasurer
        address outputToken = address(uint160(Address.unwrap(order.makerAsset)));
        uint256 outputAmount = makingAmount;

        // Use SafeERC20 for safe token transfers
        IERC20(outputToken).safeTransferFrom(taker, treasurer, outputAmount);

        emit TokensTransferredToTreasurer(outputToken, taker, treasurer, outputAmount);
    }
}
