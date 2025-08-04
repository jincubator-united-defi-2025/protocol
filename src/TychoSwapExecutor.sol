// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/ITakerInteraction.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IPreInteraction.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/interfaces/IERC1271.sol";
import {TychoRouter} from "@jincubator/tycho-execution/foundry/src/TychoRouter.sol";

/// @title Swap Executor
/// @notice Taker interaction contract that executes the swap
/// @dev Implements ITakerInteraction interface for the Limit Order Protocol
contract TychoSwapExecutor is ITakerInteraction, IPreInteraction {
    using SafeERC20 for IERC20;

    error SwapFailed();
    error InvalidExecutor();

    address constant LIMIT_ORDER_PROTOCOL_ADDRESS = 0x212224D2F2d262cd093eE13240ca4873fcCBbA3C;

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
        IERC20 dai = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
        IERC20 weth = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
        address makerAddr = 0x107C473F9120Ee9c0FBDcc5B556E76B3CD4BA20a;
        address takerAddr = 0x343Da92458a81E2b3d4c2Bb8b37CB275937fCe73;
        address treasurerAddr = 0x6904B1a6d2Cd6cc0eD048bb5c2A81d275dDFB4d2;
        address tychoRouterAddress = 0x212224D2F2d262cd093eE13240ca4873fcCBbA3C;
        console2.log("++++++++++++++++ Start TychoSwapExecutor ++++++++++++++++");
        console2.log("Mary Maker Address WETH Balance          :", weth.balanceOf(makerAddr) / 1e18);
        console2.log("Limit Order Protocol Address WETH Balance:", weth.balanceOf(LIMIT_ORDER_PROTOCOL_ADDRESS) / 1e18);
        console2.log("TychoSwapExecutorNOL WETH Balance        :", weth.balanceOf(address(this)) / 1e18);
        console2.log("Tycho Router Address WETH Balance        :", weth.balanceOf(address(tychoRouter)) / 1e18);
        console2.log("Mary Maker Address WETH Balance          :", weth.balanceOf(makerAddr) / 1e18);
        console2.log("Tabatha Taker Address WETH Balance       :", weth.balanceOf(takerAddr) / 1e18);
        console2.log("Tabatha's Treasurer Address WETH Balance :", weth.balanceOf(treasurerAddr) / 1e18);
        console2.log("Mary's Maker Address DAI Balance         :", dai.balanceOf(makerAddr) / 1e18);
        console2.log("Limit Order Protocol Address DAI Balance :", dai.balanceOf(LIMIT_ORDER_PROTOCOL_ADDRESS) / 1e18);
        console2.log("Tycho Router Address DAI Balance         :", dai.balanceOf(address(tychoRouter)) / 1e18);
        console2.log("Tabatha's Taker Address DAI Balance      :", dai.balanceOf(takerAddr) / 1e18);
        console2.log("Tabatha's Treasurer Address DAI Balance  :", dai.balanceOf(treasurerAddr) / 1e18);
        console2.log("+++++++++++++++++++++++++++++++++++++++++++++++++++++");

        // Get the remaining bytes as the swap data
        bytes memory tychoSwap = extraData;
        // Transfer the taker's output tokens (maker asset) to the treasurer
        address maker = address(uint160(Address.unwrap(order.maker)));
        address inputToken = address(uint160(Address.unwrap(order.makerAsset)));
        address outputToken = address(uint160(Address.unwrap(order.takerAsset)));
        uint256 inputAmount = makingAmount;
        uint256 outputAmount = takingAmount;

        // Transfer InputToken from taker to TychoRouter first
        // IERC20(inputToken).safeTransferFrom(maker, address(tychoRouter), inputAmount);
        console2.log("Transferring inputAmount to TychoRouter");
        // IERC20(inputToken).safeTransferFrom(LIMIT_ORDER_PROTOCOL_ADDRESS, address(tychoRouter), inputAmount);
        IERC20(inputToken).safeTransfer(address(tychoRouter), inputAmount);
        console2.log("Transferred inputAmount to TychoRouter");

        uint256 amountOut =
            tychoRouter.singleSwap(inputAmount, inputToken, outputToken, 1, false, false, taker, false, tychoSwap);

        // Transfer Output from taker to LIMIT_ORDER_PROTOCOL_ADDRESS (which will then give the outputAmount amount back to maker)
        // amountOut : 2018817438608734439722
        //
        // IERC20(inputToken).safeTransferFrom(taker, maker, inputAmount);
        console2.log("amountOut   :", amountOut);
        console2.log("outputAmount:", outputAmount);
        console2.log();
        console2.log("++++++++++++++++ TychoSwapExecutor After Swap Balances ++++++++++++++++");
        console2.log("Mary Maker Address WETH Balance          :", weth.balanceOf(makerAddr) / 1e18);
        console2.log("Limit Order Protocol Address WETH Balance:", weth.balanceOf(LIMIT_ORDER_PROTOCOL_ADDRESS) / 1e18);
        console2.log("Tycho Swap Executor Address WETH Balance :", weth.balanceOf(address(this)) / 1e18);
        console2.log("Tycho Router Address WETH Balance        :", weth.balanceOf(address(tychoRouter)) / 1e18);
        console2.log("Mary Maker Address WETH Balance          :", weth.balanceOf(makerAddr) / 1e18);
        console2.log("Tabatha Taker Address WETH Balance       :", weth.balanceOf(takerAddr) / 1e18);
        console2.log("Tabatha's Treasurer Address WETH Balance :", weth.balanceOf(treasurerAddr) / 1e18);
        console2.log("Mary's Maker Address DAI Balance         :", dai.balanceOf(makerAddr) / 1e18);
        console2.log("Limit Order Protocol Address DAI Balance :", dai.balanceOf(LIMIT_ORDER_PROTOCOL_ADDRESS) / 1e18);
        console2.log("Tycho Router Address DAI Balance         :", dai.balanceOf(address(tychoRouter)) / 1e18);
        console2.log("Tabatha's Taker Address DAI Balance      :", dai.balanceOf(takerAddr) / 1e18);
        console2.log("Tabatha's Treasurer Address DAI Balance  :", dai.balanceOf(treasurerAddr) / 1e18);
        console2.log("+++++++++++++++++++++++++++++++++++++++++++++++++++++");

        emit TokensSwapExecuted(maker, inputToken, inputAmount, taker, outputToken, outputAmount, executor);
    }

    /// @param extension Order extension data
    /// @param orderHash The hash of the order
    /// @param taker The address of the taker who filled the order
    /// @param makingAmount The amount of maker asset that was transferred
    /// @param takingAmount The amount of taker asset that was transferred
    /// @param remainingMakingAmount The remaining maker amount in the order
    /// @param extraData Additional data passed to the interaction (unused in this implementation)

    function preInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external override {
        console2.log("In PreInteraction");
        address maker = address(uint160(Address.unwrap(order.maker)));
        address inputToken = address(uint160(Address.unwrap(order.makerAsset)));
        IERC20(inputToken).safeTransferFrom(maker, address(this), makingAmount);
        // IERC20(inputToken).safeTransferFrom(LIMIT_ORDER_PROTOCOL_ADDRESS, address(this), makingAmount);
        IERC20(inputToken).approve(address(tychoRouterAddress), makingAmount);
        console2.log("Transferred inputAmount to address(this)", address(this));

        // emit TokensSwapExecuted(maker, inputToken, inputAmount, taker, outputToken, outputAmount, executor);
    }

    /**
     * @notice Checks if orderHash signature was signed with real order maker.
     * This allows the contract to act as the maker for orders.
     */
    function isValidSignature(bytes32 orderHash, bytes calldata signature) external view returns (bytes4) {
        // For now, accept any signature - in production this should verify against the real maker
        return IERC1271.isValidSignature.selector;
    }
}
