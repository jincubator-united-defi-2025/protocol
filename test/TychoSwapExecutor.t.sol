// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import "@jincubator/tycho-execution/foundry/src/executors/UniswapV4Executor.sol";
import {TychoRouter} from "@jincubator/tycho-execution/foundry/src/TychoRouter.sol";
import "@jincubator/tycho-execution/foundry/test/TychoRouterTestSetup.sol";
import {ChainLinkCalculator} from "src/ChainLinkCalculator.sol";
import {Deployers} from "test/utils/Deployers.sol";
import {OrderUtils} from "test/utils/orderUtils/OrderUtils.sol";
// import {LimitOrderProtocol} from "@jincubator/limit-order-protocol/contracts/LimitOrderProtocol.sol";
import {AggregatorMock} from "src/mocks/1inch/AggregatorMock.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {WETH} from "the-compact/lib/solady/src/tokens/WETH.sol";
// import {IWETH} from "@1inch/solidity-utils/contracts/interfaces/IWETH.sol";
import {IOrderMixin} from "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {Address as AddressLib} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import {MakerTraits} from "@jincubator/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import {TakerTraits} from "@jincubator/limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract TychoSwapExecutorTest is Test, Deployers {
    using OrderUtils for *;

    function buildPostInteractionCalldata(address interactionAddress) internal pure returns (bytes memory) {
        return abi.encodePacked(interactionAddress);
    }

    function buildTakerInteractionCalldata(address interactionAddress) internal pure returns (bytes memory) {
        return abi.encodePacked(interactionAddress);
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

    // Helper function to get oracle answer
    function getOracleAnswer(AggregatorMock oracle) internal view returns (uint256) {
        (, int256 answer,,,) = oracle.latestRoundData();
        return uint256(answer);
    }

    // function createTychoSingleSwapUniswapV2(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut)
    function createTychoSingleSwapUniswapV2(
        address tokenIn,
        address target,
        address receiver,
        bool zero2one,
        RestrictTransferFrom.TransferType transferType
    ) internal returns (bytes memory tychoSwap) {
        bytes memory protocolData =
            encodeUniswapV2Swap(WETH_ADDR, WETH_DAI_POOL, ALICE, false, RestrictTransferFrom.TransferType.TransferFrom);

        tychoSwap = encodeSingleSwap(address(usv2Executor), protocolData);
        return tychoSwap;
    }

    function testSingleSwapNoPermit2() public {
        // Trade 1 WETH for DAI with 1 swap on Uniswap V2
        // Checks amount out at the end
        uint256 amountIn = 1 ether;

        deal(WETH_ADDR, ALICE, amountIn);
        vm.startPrank(ALICE);
        // Approve the tokenIn to be transferred to the router
        IERC20(WETH_ADDR).approve(address(tychoRouterAddr), amountIn);

        bytes memory protocolData =
            encodeUniswapV2Swap(WETH_ADDR, WETH_DAI_POOL, ALICE, false, RestrictTransferFrom.TransferType.TransferFrom);

        bytes memory swap = encodeSingleSwap(address(usv2Executor), protocolData);

        uint256 minAmountOut = 2000 * 1e18;
        uint256 amountOut =
            tychoRouter.singleSwap(amountIn, WETH_ADDR, DAI_ADDR, minAmountOut, false, false, ALICE, true, swap);

        uint256 expectedAmount = 2018817438608734439722;
        assertEq(amountOut, expectedAmount);
        uint256 daiBalance = IERC20(DAI_ADDR).balanceOf(ALICE);
        assertEq(daiBalance, expectedAmount);
        assertEq(IERC20(WETH_ADDR).balanceOf(ALICE), 0);

        vm.stopPrank();
    }

    function test_eth_to_dai_chainlink_order_with_tychoSwapExecutor() public {
        // Advance block timestamp to ensure oracle data is considered fresh
        vm.warp(block.timestamp + 3600 seconds); // Increase from 99 to 3600 seconds

        // Setup oracles with specific prices
        // DAI oracle: 1 ETH = 4000 DAI (0.00025 ETH per DAI)
        daiOracle = new AggregatorMock(0.00025 ether);

        address chainlinkCalcAddress = address(chainLinkCalculator);
        address oracleAddress = address(daiOracle);

        // Build order with chainlink price data
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: makerAddr,
            receiver: address(0),
            makerAsset: address(weth),
            takerAsset: address(dai),
            makingAmount: 1 ether,
            takingAmount: 4000 ether,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        bytes memory postInteractionData = buildPostInteractionCalldata(address(rebalancerInteraction));
        bytes memory takerInteractionData = buildTakerInteractionCalldata(address(swapExecutor));

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            // makingAmountData,
            // takingAmountData,
            "", // predicate
            "", // permit
            // takerInteractionData, // preInteraction SwapExecutor address
            "", // preInteraction SwapExecutor address
            // postInteractionData, // postInteraction Rebalancer address
            "", // postInteraction
            ""
        );

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Add approvals for maker to allow swapExecutor contract to use input tokens for SWAP //TODO place this in the preintraction based on a flag
        addApproval(makerAddr, address(swapExecutor), address(baseOrder.makerAsset), baseOrder.makingAmount);
        // Add approvals for taker to allow swapExecutor contract to use output tokens for SWAP //TODO remove this once the swapExecutor has got the swap working
        addApproval(takerAddr, address(swapExecutor), address(baseOrder.takerAsset), baseOrder.takingAmount);

        // ===== Begin of Taker Tasks =====
        // Create Tycho Swap
        // bytes memory tychoSwap = createTychoSingleSwapUniswapV2(
        //     address(baseOrder.makerAsset), address(baseOrder.takerAsset), baseOrder.makingAmount, baseOrder.takingAmount
        // );
        // WETH_ADDR, WETH_DAI_POOL, ALICE, false, RestrictTransferFrom.TransferType.TransferFrom
        // TODO: Dynamically poulate the target fields
        bytes memory tychoSwap = createTychoSingleSwapUniswapV2(
            address(baseOrder.makerAsset), // address tokenIn,
            WETH_DAI_POOL, // address target this is the pool address
            makerAddr, // address receiver,
            false, // bool zero2one,
            RestrictTransferFrom.TransferType.TransferFrom // RestrictTransferFrom.TransferType transferType
        );

        // bytes memory tychoSwap = createTychoSingleSwapUniswapV2(
        //     WETH_ADDR, WETH_DAI_POOL, ALICE, false, RestrictTransferFrom.TransferType.TransferFrom
        // );
        console2.log("tychoSwap Below");
        console2.logBytes(tychoSwap);

        // Build taker traits
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            false, // If set, the protocol implies that the passed amount is the making amount
            false, // If set, the WETH will be unwrapped into ETH before sending to the taker's target address.
            false, // skipMakerPermit Unused
            false, // If set, the order uses the Uniswap Permit 2.
            "", // If set, then first 20 bytes of args are treated as target address for maker’s funds transfer
            "", // extension (Comes from OrderUtils.buildOrder)
            // Taker’s interaction calldata coded in args argument length: TODO fill this out with swap payload
            abi.encodePacked(
                // address(swapExecutor), hex"0102030405060708090a0b0c0d0e0f101112131415161718191a1b1c1d1e1f20"
                address(tychoSwapExecutor),
                tychoSwap
            ),
            0.99 ether // threshold
        );
        console2.log("takerTraits Below");
        console2.logBytes(takerTraits.args);
        console2.log("LimitOrderProtocol(address)", address(swap));

        // Record initial balances
        uint256 addrDaiBalanceBefore = dai.balanceOf(takerAddr);
        uint256 makerAddrDaiBalanceBefore = dai.balanceOf(makerAddr);
        uint256 addrWethBalanceBefore = weth.balanceOf(takerAddr);
        uint256 makerAddrWethBalanceBefore = weth.balanceOf(makerAddr);
        uint256 treasurerAddrWethBalanceBefore = weth.balanceOf(treasurerAddr);

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, 4000 ether, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Verify balance changes
        assertEq(dai.balanceOf(takerAddr), addrDaiBalanceBefore - 4000 ether);
        assertEq(dai.balanceOf(makerAddr), makerAddrDaiBalanceBefore + 4000 ether);
        // Taker doesn't receive WETH because it's transferred to treasurer
        assertEq(weth.balanceOf(takerAddr), addrWethBalanceBefore + 1 ether);
        assertEq(weth.balanceOf(makerAddr), makerAddrWethBalanceBefore - 1 ether);
    }
}
