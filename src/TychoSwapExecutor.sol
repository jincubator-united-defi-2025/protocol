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

    //TODO: remove debug enum
    enum TransferType {
        TransferFrom,
        Transfer,
        None
    }

    /// @param _executor The address of the treasurer wallet
    constructor(address _executor, address payable _tychoRouterAddress) {
        if (_executor == address(0)) revert InvalidExecutor();
        executor = _executor;
        tychoRouterAddress = _tychoRouterAddress;
        tychoRouter = TychoRouter(payable(_tychoRouterAddress));
    }

    //TODO: remove debug function
    function encodeUniswapV2Swap(
        address tokenIn,
        address target,
        address receiver,
        bool zero2one,
        TransferType transferType
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(tokenIn, target, receiver, zero2one, transferType);
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
        console2.log("TychoSwapExecutor: takerInteraction");
        console2.log("extraData Below");
        console2.logBytes(extraData);
        // bytes memory tychoSwap = abi.decode(extraData, (bytes));
        // Extract the address (first 20 bytes)
        address tychoExecutor = address(uint160(bytes20(extraData[:20])));
        console2.log("TychoSwapExecutor: tychoExecutor");
        console2.log(tychoExecutor);
        // Get the remaining bytes as the swap data
        bytes memory tychoSwap = extraData;
        console2.log("TychoSwapExecutor: tychoSwap");
        console2.logBytes(tychoSwap);
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

        // debug purposes only
        address ALICE = address(0xcd09f75E2BF2A4d11F3AB23f1389FcC1621c0cc2);
        address WETH_DAI_POOL = 0xA478c2975Ab1Ea89e8196811F51A7B7Ade33eB11;
        address WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
        address DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
        bytes memory debugSwap = encodeUniswapV2Swap(WETH, WETH_DAI_POOL, ALICE, false, TransferType.TransferFrom);
        console2.log("SwapExecutor: debugSwap");
        console2.logBytes(debugSwap);
        // uint256 amountOut = tychoRouter.singleSwap(
        //     inputAmount, inputToken, outputToken, outputAmount, false, false, maker, true, debugSwap
        // );

        console2.log("SwapExecutor: amountOut");
        // TODO: Implement the swap logic here using tycho router
        console2.log("SwapExecutor: tychoSwap");
        // uint256 amountOut = tychoRouter.singleSwap(
        //     inputAmount, inputToken, outputToken, outputAmount, false, false, maker, true, tychoSwap
        // );
        //TODO: Replace hardcoded values with above
        uint256 amountOut =
            tychoRouter.singleSwap(inputAmount, WETH, DAI, outputAmount, false, false, maker, true, tychoSwap);

        console2.log("SwapExecutor: amountOut");
        console2.log(amountOut);
        // Use SafeERC20 for safe token transfers
        // IERC20(inputToken).safeTransferFrom(maker, taker, makingAmount);
        // IERC20(outputToken).safeTransferFrom(taker, maker, outputAmount); //TODO replace this with the swap logic

        emit TokensSwapExecuted(maker, inputToken, inputAmount, taker, outputToken, outputAmount, executor);
        // return takingAmount; //TODO Update this after executing the swap
    }
}
