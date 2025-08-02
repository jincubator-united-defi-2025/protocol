// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/ITakerInteraction.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TychoRouter} from "@jincubator/tycho-execution/foundry/src/TychoRouter.sol";

/// @title Swap Executor
/// @notice Taker interaction contract that executes the swap
/// @dev Implements ITakerInteraction interface for the Limit Order Protocol
contract TychoSwapExecutor is ITakerInteraction {
    using SafeERC20 for IERC20;

    error SwapFailed();
    error InvalidExecutor();

    /// @notice Treasurer wallet address that receives the output tokens
    address public immutable executor;
    address payable public immutable tychoRouterAddress;
    TychoRouter public immutable tychoRouter;

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
    constructor(address _executor, address payable _tychoRouterAddress) {
        if (_executor == address(0)) revert InvalidExecutor();
        executor = _executor;
        tychoRouterAddress = _tychoRouterAddress;
        tychoRouter = TychoRouter(payable(_tychoRouterAddress));
    }

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
        // Get the remaining bytes as the swap data
        bytes memory tychoSwap = extraData;
        // Transfer the taker's output tokens (maker asset) to the treasurer
        address maker = address(uint160(Address.unwrap(order.maker)));
        address inputToken = address(uint160(Address.unwrap(order.makerAsset)));
        address outputToken = address(uint160(Address.unwrap(order.takerAsset)));
        uint256 inputAmount = makingAmount;
        uint256 outputAmount = takingAmount;

        // Transfer WETH from taker to TychoRouter first
        IERC20(inputToken).safeTransferFrom(taker, address(tychoRouter), inputAmount);

        uint256 amountOut =
            tychoRouter.singleSwap(inputAmount, inputToken, outputToken, 1, false, false, maker, false, tychoSwap);

        emit TokensSwapExecuted(maker, inputToken, inputAmount, taker, outputToken, outputAmount, executor);
    }
}
