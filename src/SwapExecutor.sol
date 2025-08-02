// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/ITakerInteraction.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Swap Executor
/// @notice Taker interaction contract that executes the swap
/// @dev Implements ITakerInteraction interface for the Limit Order Protocol
contract SwapExecutor is ITakerInteraction {
    using SafeERC20 for IERC20;

    error SwapFailed();
    error InvalidExecutor();

    /// @notice Treasurer wallet address that receives the output tokens
    address public immutable executor;

    /// @notice Emitted when tokens are transferred to treasurer
    event TokensSwapExecuted(
        address indexed maker,
        address tokenFrom,
        uint256 amountFrom,
        address indexed taker,
        address tokenTo,
        uint256 amountTo,
        address indexed executor
    );

    /// @param _executor The address of the treasurer wallet
    constructor(address _executor) {
        if (_executor == address(0)) revert InvalidExecutor();
        executor = _executor;
    }

    /// @notice Taker's interaction callback that executes the swap
    /// @param order The order that was filled
    /// @param extension Order extension data
    /// @param orderHash The hash of the order
    /// @param taker The address of the taker who filled the order
    /// @param makingAmount The amount of maker asset that was transferred
    /// @param takingAmount The amount of taker asset that was transferred
    /// @param remainingMakingAmount The remaining maker amount in the order
    /// @param extraData Additional data passed to the interaction (unused in this implementation)
    function takerInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external override {
        console2.log("SwapExecutor: takerInteraction");
        console2.log("extraData Below");
        console2.logBytes(extraData);
        // console2.logbytes32("SwapExecutor: orderHash", orderHash);
        // console2.logbytes32(orderHash);
        console2.log("SwapExecutor: taker", taker);
        console2.log("SwapExecutor: makingAmount", makingAmount);
        console2.log("SwapExecutor: takingAmount", takingAmount);
        console2.log("SwapExecutor: remainingMakingAmount", remainingMakingAmount);
        // Transfer the taker's output tokens (maker asset) to the treasurer
        address maker = address(uint160(Address.unwrap(order.maker)));
        address inputToken = address(uint160(Address.unwrap(order.makerAsset)));
        address outputToken = address(uint160(Address.unwrap(order.takerAsset)));
        uint256 inputAmount = makingAmount;
        uint256 outputAmount = takingAmount;

        // TODO: Implement the swap logic here using tycho router
        // Use SafeERC20 for safe token transfers
        // IERC20(inputToken).safeTransferFrom(maker, taker, makingAmount);
        // IERC20(outputToken).safeTransferFrom(taker, maker, outputAmount); //TODO replace this with the swap logic

        emit TokensSwapExecuted(maker, inputToken, inputAmount, taker, outputToken, outputAmount, executor);
        // return takingAmount; //TODO Update this after executing the swap
    }
}
