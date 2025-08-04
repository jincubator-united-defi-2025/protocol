// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import "@jincubator/tycho-execution/foundry/src/executors/UniswapV4Executor.sol";
import {TychoRouter} from "@jincubator/tycho-execution/foundry/src/TychoRouter.sol";
import "@jincubator/tycho-execution/foundry/test/TychoRouterTestSetup.sol";
import {OracleCalculator} from "src/OracleCalculator.sol";
import {DeployersDemoDL} from "test/utils/DeployersDemoDL.sol";
import {OrderUtils} from "test/utils/orderUtils/OrderUtils.sol";
import {AggregatorMock} from "src/mocks/1inch/AggregatorMock.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {WETH} from "the-compact/lib/solady/src/tokens/WETH.sol";
import {IOrderMixin} from "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {Address as AddressLib} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import {MakerTraits} from "@jincubator/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import {TakerTraits} from "@jincubator/limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TychoSwapExecutorDemoTestDL is Test, DeployersDemoDL {
    using OrderUtils for *;

    // Flag constants for MakerTraits

    function buildInteractionCalldata(address interactionAddress, bytes memory interactionData)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(interactionAddress, interactionData);
    }

    function addApproval(address granter, address spender, address token, uint256 amount) internal {
        vm.prank(granter);
        IERC20(token).approve(address(spender), amount);
    }
    // Helper function to convert OrderUtils.Order to IOrderMixin.Order

    function convertOrder(OrderUtils.Order memory order) internal pure returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: order.salt,
            maker: AddressLib.wrap(uint256(uint160(order.maker))),
            receiver: AddressLib.wrap(uint256(uint160(order.receiver))),
            makerAsset: AddressLib.wrap(uint256(uint160(order.makerAsset))),
            takerAsset: AddressLib.wrap(uint256(uint160(order.takerAsset))),
            makingAmount: order.makingAmount,
            takingAmount: order.takingAmount,
            makerTraits: MakerTraits.wrap(order.makerTraits)
        });
    }

    // Helper function to sign order and create vs
    function signOrder(uint256 privateKey, bytes32 orderData) internal view returns (bytes32 r, bytes32 vs) {
        (uint8 v, bytes32 r_, bytes32 s) = vm.sign(privateKey, orderData);
        r = r_;
        // yParityAndS format: s | (v << 255)
        // v should be 27 or 28, we need to convert to 0 or 1 for yParity
        uint8 yParity = v - 27;
        vs = bytes32(uint256(s) | (uint256(yParity) << 255));
    }

    // function createTychoSingleSwapUniswapV2(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)
    function createTychoSingleSwapUniswapV2(
        address tokenIn,
        address target,
        address receiver,
        bool zero2one,
        RestrictTransferFrom.TransferType transferType
    ) internal returns (bytes memory tychoSwap) {
        bytes memory protocolData = encodeUniswapV2Swap(
            tokenIn,
            WETH_DAI_POOL, //TODO need to add dynamic pool lookups
            receiver,
            false,
            RestrictTransferFrom.TransferType.Transfer
        );

        tychoSwap = encodeSingleSwap(address(usv2Executor), protocolData);
        return tychoSwap;
    }

    function test_demo_DL_tychoSwapExecutor() public {
        // Log addresses
        console2.log("+++++++++++++++++ Addresses +++++++++++++++++");
        console2.log("LimitOrderProtocol Address    :", address(swap));
        console2.log("TychoSwapExecutor Address     :", address(tychoSwapExecutor));
        console2.log("TychoRouter Address           :", address(tychoRouter));
        console2.log("Mary Maker Address            :", makerAddr);
        console2.log("Tabatha Taker Address         :", takerAddr);
        console2.log("Tabatha's Treasurer Address   :", treasurerAddr);
        console2.log("WETH Address                  :", address(weth));
        console2.log("DAI Address                   :", address(dai));
        console2.log("+++++++++++++++++ End of Addresses +++++++++++++++++");
        // Log Starting Balances
        console2.log("++++++++++++++++ Starting Balances +++++++++++++++++");
        console2.log("Mary Maker Address WETH Balance          :", weth.balanceOf(makerAddr) / 1e18);
        console2.log("Tabatha Taker Address WETH Balance       :", weth.balanceOf(takerAddr) / 1e18);
        console2.log("Tabatha's Treasurer Address WETH Balance :", weth.balanceOf(treasurerAddr) / 1e18);
        console2.log("Mary's Maker Address DAI Balance         :", dai.balanceOf(makerAddr) / 1e18);
        console2.log("Tabatha's Taker Address DAI Balance      :", dai.balanceOf(takerAddr) / 1e18);
        console2.log("Tabatha's Treasurer Address DAI Balance  :", dai.balanceOf(treasurerAddr) / 1e18);
        console2.log("+++++++++++++ End of Starting Balances +++++++++++++");

        // Build order with original maker (like ApprovalPreInteraction example)
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: makerAddr, // Keep original maker
            receiver: address(0),
            makerAsset: address(weth),
            takerAsset: address(dai),
            makingAmount: 1 ether,
            takingAmount: 2000 ether, // Updated to realistic market price
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            "", // predicate
            "", // permit
            // "", // preInteraction - no extension data needed
            abi.encodePacked(address(tychoSwapExecutor)), // call TychoSwapExecutor to do preInteraction
            "", // postInteraction
            ""
        );
        // set _NEED_PREINTERACTION_FLAG in makerTraits
        order.makerTraits = order.makerTraits |= 1 << 252;
        // traits |= 1 << _NEED_EPOCH_CHECK_FLAG;

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Add approval for tychoSwapExecutor to spend inputToken from makerAddr (needed for the swap)
        addApproval(makerAddr, address(tychoSwapExecutor), address(baseOrder.makerAsset), baseOrder.makingAmount);
        addApproval(makerAddr, address(swap), address(baseOrder.makerAsset), baseOrder.makingAmount);
        // Add approval for maker to receive outputToken from takerAddr (executed by LIMIT_ORDER_PROTOCOL to give back to maker)
        addApproval(takerAddr, address(tychoSwapExecutor), address(baseOrder.makerAsset), baseOrder.makingAmount);
        addApproval(takerAddr, address(makerAddr), address(baseOrder.takerAsset), baseOrder.takingAmount);
        addApproval(takerAddr, address(swap), address(baseOrder.takerAsset), baseOrder.takingAmount);

        // ===== Begin of Taker Tasks =====
        // Create Tycho Swap
        // TODO: Dynamically poulate the Pool address
        bytes memory tychoSwap = createTychoSingleSwapUniswapV2(
            address(baseOrder.makerAsset), // address tokenIn,
            WETH_DAI_POOL, // address target this is the pool address
            takerAddr, // address receiver is the taker address who will send the output token outputAmount back to the maker
            false, // bool zero2one,
            RestrictTransferFrom.TransferType.TransferFrom // RestrictTransferFrom.TransferType transferType
        );

        // Build taker traits
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            false, // If set, the protocol implies that the passed amount is the making amount
            false, // If set, the WETH will be unwrapped into ETH before sending to the taker's target address.
            false, // skipMakerPermit Unused
            false, // If set, the order uses the Uniswap Permit 2.
            "", // If set, then first 20 bytes of args are treated as target address for maker’s funds transfer
            // "", // extension (Comes from OrderUtils.buildOrder)
            extension, // extension (Comes from OrderUtils.buildOrder)
            // Taker’s interaction calldata coded in args argument length: TODO fill this out with swap payload
            abi.encodePacked(address(tychoSwapExecutor), tychoSwap),
            0.99 ether // threshold
        );

        // Record initial balances
        uint256 addrDaiBalanceBefore = dai.balanceOf(takerAddr);
        uint256 makerAddrDaiBalanceBefore = dai.balanceOf(makerAddr);
        uint256 addrWethBalanceBefore = weth.balanceOf(takerAddr);
        uint256 makerAddrWethBalanceBefore = weth.balanceOf(makerAddr);
        uint256 treasurerAddrWethBalanceBefore = weth.balanceOf(treasurerAddr);

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, 2000 ether, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Verify balance changes
        // The taker pays 2000 DAI directly to the maker (as specified in the order)
        // assertEq(dai.balanceOf(takerAddr), addrDaiBalanceBefore - 2000 ether);
        // The maker receives DAI from the swap (WETH -> DAI conversion) + direct payment
        // assertEq(dai.balanceOf(makerAddr), makerAddrDaiBalanceBefore + 2018817438608734439722 + 2000 ether);
        // Taker receives 1 WETH from maker but uses it for the swap, so balance stays the same
        // assertEq(weth.balanceOf(takerAddr), addrWethBalanceBefore);
        // assertEq(weth.balanceOf(makerAddr), makerAddrWethBalanceBefore - 1 ether);

        // Log Ending Balances
        console2.log();
        console2.log("++++++++++++++++ Ending Balances ++++++++++++++++");
        console2.log("Mary Maker Address WETH Balance          :", weth.balanceOf(makerAddr) / 1e18);
        console2.log("Tabatha Taker Address WETH Balance       :", weth.balanceOf(takerAddr) / 1e18);
        console2.log("Tabatha's Treasurer Address WETH Balance :", weth.balanceOf(treasurerAddr) / 1e18);
        console2.log("Mary's Maker Address DAI Balance         :", dai.balanceOf(makerAddr) / 1e18);
        console2.log("Tabatha's Taker Address DAI Balance      :", dai.balanceOf(takerAddr) / 1e18);
        console2.log("Tabatha's Treasurer Address DAI Balance  :", dai.balanceOf(treasurerAddr) / 1e18);
        console2.log("+++++++++++++ End of Ending  Balances +++++++++++++");
    }
}
