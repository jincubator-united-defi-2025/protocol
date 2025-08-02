// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ChainLinkCalculator} from "src/ChainLinkCalculator.sol";
import {Deployers} from "test/utils/Deployers.sol";
import {OrderUtils} from "test/utils/orderUtils/OrderUtils.sol";
// import {LimitOrderProtocol} from "@jincubator/limit-order-protocol/contracts/LimitOrderProtocol.sol";
import {AggregatorMock} from "src/mocks/1inch/AggregatorMock.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {WETH} from "the-compact/lib/solady/src/tokens/WETH.sol";
import {IWETH} from "@1inch/solidity-utils/contracts/interfaces/IWETH.sol";
import {IOrderMixin} from "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {Address} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import {MakerTraits} from "@jincubator/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";
import {TakerTraits} from "@jincubator/limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";

contract ChainLinkCalculatorTest is Test, Deployers {
    using OrderUtils for *;

    function setUp() public {
        // Deploy contracts
        deployArtifacts();
    }

    function buildSinglePriceCalldata(address chainlinkCalcAddress, address oracleAddress, uint256 spread, bool inverse)
        internal
        pure
        returns (bytes memory)
    {
        return abi.encodePacked(chainlinkCalcAddress, inverse ? bytes1(0x80) : bytes1(0x00), oracleAddress, spread);
    }

    function buildDoublePriceCalldata(
        address chainlinkCalcAddress,
        address oracleAddress1,
        address oracleAddress2,
        int256 decimalsScale,
        uint256 spread
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(chainlinkCalcAddress, bytes1(0x40), oracleAddress1, oracleAddress2, decimalsScale, spread);
    }

    function test_eth_to_dai_chainlink_order() public {
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

        bytes memory makingAmountData = buildSinglePriceCalldata(
            chainlinkCalcAddress,
            oracleAddress,
            990000000, // maker offset is 0.99
            false
        );

        bytes memory takingAmountData = buildSinglePriceCalldata(
            chainlinkCalcAddress,
            oracleAddress,
            1010000000, // taker offset is 1.01
            true
        );

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            makingAmountData,
            takingAmountData,
            "", // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );
        console2.logBytes(extension);

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        console2.log("Order hash:", uint256(orderData));
        console2.log("Expected maker:", makerAddr);
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Build taker traits
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            false, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            0.99 ether // threshold
        );

        // Record initial balances
        uint256 addrDaiBalanceBefore = dai.balanceOf(takerAddr);
        uint256 makerAddrDaiBalanceBefore = dai.balanceOf(makerAddr);
        uint256 addrWethBalanceBefore = weth.balanceOf(takerAddr);
        uint256 makerAddrWethBalanceBefore = weth.balanceOf(makerAddr);

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, 4000 ether, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Verify balance changes
        assertEq(dai.balanceOf(takerAddr), addrDaiBalanceBefore - 4000 ether);
        assertEq(dai.balanceOf(makerAddr), makerAddrDaiBalanceBefore + 4000 ether);
        assertEq(weth.balanceOf(takerAddr), addrWethBalanceBefore + 0.99 ether);
        assertEq(weth.balanceOf(makerAddr), makerAddrWethBalanceBefore - 0.99 ether);
    }

    function test_dai_to_eth_chainlink_order() public {
        // Advance block timestamp to ensure oracle data is considered fresh
        vm.warp(block.timestamp + 3600 seconds); // Increase from 99 to 3600 seconds

        // Setup oracles with specific prices
        daiOracle = new AggregatorMock(0.00025 ether);

        address chainlinkCalcAddress = address(chainLinkCalculator);
        address oracleAddress = address(daiOracle);

        // Build order with chainlink price data
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: makerAddr,
            receiver: address(0),
            makerAsset: address(dai),
            takerAsset: address(weth),
            makingAmount: 4000 ether,
            takingAmount: 1 ether,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        bytes memory makingAmountData = buildSinglePriceCalldata(
            chainlinkCalcAddress,
            oracleAddress,
            990000000, // maker offset is 0.99
            true
        );

        bytes memory takingAmountData = buildSinglePriceCalldata(
            chainlinkCalcAddress,
            oracleAddress,
            1010000000, // taker offset is 1.01
            false
        );

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            makingAmountData,
            takingAmountData,
            "", // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Build taker traits with makingAmount flag
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            1.01 ether // threshold
        );

        // Record initial balances
        uint256 addrDaiBalanceBefore = dai.balanceOf(takerAddr);
        uint256 makerAddrDaiBalanceBefore = dai.balanceOf(makerAddr);
        uint256 addrWethBalanceBefore = weth.balanceOf(takerAddr);
        uint256 makerAddrWethBalanceBefore = weth.balanceOf(makerAddr);

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, 4000 ether, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Verify balance changes
        assertEq(dai.balanceOf(takerAddr), addrDaiBalanceBefore + 4000 ether);
        assertEq(dai.balanceOf(makerAddr), makerAddrDaiBalanceBefore - 4000 ether);
        assertEq(weth.balanceOf(takerAddr), addrWethBalanceBefore - 1.01 ether);
        assertEq(weth.balanceOf(makerAddr), makerAddrWethBalanceBefore + 1.01 ether);
    }

    function test_dai_to_1inch_chainlink_order_takingAmountData() public {
        // Advance block timestamp to ensure oracle data is considered fresh
        vm.warp(block.timestamp + 3600 seconds); // Increase from 99 to 3600 seconds

        // Setup oracles with specific prices
        daiOracle = new AggregatorMock(0.00025 ether); // 1 ETH = 4000 DAI
        inchOracle = new AggregatorMock(1577615249227853); // 1 INCH = 0.0001577615249227853 ETH

        address chainlinkCalcAddress = address(chainLinkCalculator);
        address oracleAddress1 = address(inchOracle);
        address oracleAddress2 = address(daiOracle);

        uint256 makingAmount = 100 ether;
        uint256 takingAmount = 632 ether;
        int256 decimalsScale = 0;
        uint256 takingSpread = 1010000000; // taker offset is 1.01

        // Build order with double price data
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: makerAddr,
            receiver: address(0),
            makerAsset: address(inch),
            takerAsset: address(dai),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        bytes memory makingAmountData = buildDoublePriceCalldata(
            chainlinkCalcAddress,
            oracleAddress2, // DAI oracle
            oracleAddress1, // INCH oracle
            decimalsScale,
            990000000 // maker offset is 0.99
        );

        bytes memory takingAmountData = buildDoublePriceCalldata(
            chainlinkCalcAddress,
            oracleAddress1, // INCH oracle
            oracleAddress2, // DAI oracle
            decimalsScale,
            takingSpread
        );

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            makingAmountData,
            takingAmountData,
            "", // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Build taker traits with makingAmount flag
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            takingAmount * takingSpread / 1e9 + 0.01 ether // threshold
        );

        // Record initial balances
        uint256 addrDaiBalanceBefore = dai.balanceOf(takerAddr);
        uint256 makerAddrDaiBalanceBefore = dai.balanceOf(makerAddr);
        uint256 addrInchBalanceBefore = inch.balanceOf(takerAddr);
        uint256 makerAddrInchBalanceBefore = inch.balanceOf(makerAddr);

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, makingAmount, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Calculate expected taking amount based on oracle prices
        uint256 realTakingAmount =
            makingAmount * takingSpread / 1e9 * getOracleAnswer(inchOracle) / getOracleAnswer(daiOracle);

        // Verify balance changes
        assertEq(dai.balanceOf(takerAddr), addrDaiBalanceBefore - realTakingAmount);
        assertEq(dai.balanceOf(makerAddr), makerAddrDaiBalanceBefore + realTakingAmount);
        assertEq(inch.balanceOf(takerAddr), addrInchBalanceBefore + makingAmount);
        assertEq(inch.balanceOf(makerAddr), makerAddrInchBalanceBefore - makingAmount);
    }

    function test_dai_to_1inch_chainlink_order_makingAmountData() public {
        // Advance block timestamp to ensure oracle data is considered fresh
        // The chainLinkCalculator  checks if updatedAt + 4 hours < block.timestamp
        // Minimum advancement needed: 99 seconds
        vm.warp(block.timestamp + 3600 seconds); // Increase from 99 to 3600 seconds

        // Setup oracles with specific prices
        daiOracle = new AggregatorMock(0.00025 ether); // 1 ETH = 4000 DAI
        inchOracle = new AggregatorMock(1577615249227853); // 1 INCH = 0.0001577615249227853 ETH

        address chainlinkCalcAddress = address(chainLinkCalculator);
        address oracleAddress1 = address(inchOracle);
        address oracleAddress2 = address(daiOracle);

        uint256 makingAmount = 100 ether;
        uint256 takingAmount = 632 ether;
        int256 decimalsScale = 0;
        uint256 makingSpread = 990000000; // maker offset is 0.99

        // Build order with double price data
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: makerAddr,
            receiver: address(0),
            makerAsset: address(inch),
            takerAsset: address(dai),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        bytes memory makingAmountData = buildDoublePriceCalldata(
            chainlinkCalcAddress,
            oracleAddress2, // DAI oracle
            oracleAddress1, // INCH oracle
            decimalsScale,
            makingSpread
        );

        bytes memory takingAmountData = buildDoublePriceCalldata(
            chainlinkCalcAddress,
            oracleAddress1, // INCH oracle
            oracleAddress2, // DAI oracle
            decimalsScale,
            1010000000 // taker offset is 1.01
        );

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            makingAmountData,
            takingAmountData,
            "", // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Build taker traits
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            false, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            makingAmount * makingSpread / 1e9 + 0.01 ether // threshold
        );

        // Record initial balances
        uint256 addrDaiBalanceBefore = dai.balanceOf(takerAddr);
        uint256 makerAddrDaiBalanceBefore = dai.balanceOf(makerAddr);
        uint256 addrInchBalanceBefore = inch.balanceOf(takerAddr);
        uint256 makerAddrInchBalanceBefore = inch.balanceOf(makerAddr);

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, takingAmount, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Calculate expected making amount based on oracle prices
        uint256 realMakingAmount =
            takingAmount * makingSpread / 1e9 * getOracleAnswer(daiOracle) / getOracleAnswer(inchOracle);

        // Verify balance changes
        assertEq(dai.balanceOf(takerAddr), addrDaiBalanceBefore - takingAmount);
        assertEq(dai.balanceOf(makerAddr), makerAddrDaiBalanceBefore + takingAmount);
        assertEq(inch.balanceOf(takerAddr), addrInchBalanceBefore + realMakingAmount);
        assertEq(inch.balanceOf(makerAddr), makerAddrInchBalanceBefore - realMakingAmount);
    }

    function test_dai_to_1inch_stop_loss_order() public {
        // Advance block timestamp to ensure oracle data is considered fresh
        vm.warp(block.timestamp + 3600 seconds); // Increase from 99 to 3600 seconds

        // Setup oracles with specific prices
        daiOracle = new AggregatorMock(0.00025 ether);
        inchOracle = new AggregatorMock(1577615249227853);

        uint256 makingAmount = 100 ether;
        uint256 takingAmount = 631 ether;

        // Build price call for predicate
        bytes memory priceCall =
            abi.encodeWithSelector(chainLinkCalculator.doublePrice.selector, inchOracle, daiOracle, int256(0), 1 ether);

        // Build predicate call
        bytes memory predicate = abi.encodeWithSelector(
            swap.lt.selector,
            6.32 ether,
            abi.encodeWithSelector(swap.arbitraryStaticCall.selector, address(chainLinkCalculator), priceCall)
        );

        // Build order with predicate
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: makerAddr,
            receiver: address(0),
            makerAsset: address(inch),
            takerAsset: address(dai),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            predicate, // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Build taker traits with makingAmount flag
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            takingAmount + 0.01 ether // threshold
        );

        // Record initial balances
        uint256 addrDaiBalanceBefore = dai.balanceOf(takerAddr);
        uint256 makerAddrDaiBalanceBefore = dai.balanceOf(makerAddr);
        uint256 addrInchBalanceBefore = inch.balanceOf(takerAddr);
        uint256 makerAddrInchBalanceBefore = inch.balanceOf(makerAddr);

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, makingAmount, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Verify balance changes
        assertEq(dai.balanceOf(takerAddr), addrDaiBalanceBefore - takingAmount);
        assertEq(dai.balanceOf(makerAddr), makerAddrDaiBalanceBefore + takingAmount);
        assertEq(inch.balanceOf(takerAddr), addrInchBalanceBefore + makingAmount);
        assertEq(inch.balanceOf(makerAddr), makerAddrInchBalanceBefore - makingAmount);
    }

    function test_dai_to_1inch_stop_loss_order_predicate_invalid() public {
        // Advance block timestamp to ensure oracle data is considered fresh
        vm.warp(block.timestamp + 3600 seconds); // Increase from 99 to 3600 seconds

        // Setup oracles with specific prices
        daiOracle = new AggregatorMock(0.00025 ether);
        inchOracle = new AggregatorMock(1577615249227853);

        uint256 makingAmount = 100 ether;
        uint256 takingAmount = 631 ether;

        // Build price call for predicate (invalid threshold)
        bytes memory priceCall =
            abi.encodeWithSelector(chainLinkCalculator.doublePrice.selector, inchOracle, daiOracle, int256(0), 1 ether);

        // Build predicate call with invalid threshold
        bytes memory predicate = abi.encodeWithSelector(
            swap.lt.selector,
            6.31 ether, // Invalid threshold
            priceCall
        );

        // Build order with predicate
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: makerAddr,
            receiver: address(0),
            makerAsset: address(inch),
            takerAsset: address(dai),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            predicate, // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Build taker traits with makingAmount flag
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            takingAmount + 0.01 ether // threshold
        );

        // Expect the transaction to revert due to invalid predicate
        vm.prank(takerAddr);
        vm.expectRevert();
        swap.fillOrderArgs(
            convertOrder(order), r, vs, makingAmount, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );
    }

    function test_eth_to_dai_stop_loss_order() public {
        // Advance block timestamp to ensure oracle data is considered fresh
        vm.warp(block.timestamp + 3600 seconds); // Increase from 99 to 3600 seconds

        // Setup oracles with specific prices
        daiOracle = new AggregatorMock(0.00025 ether);

        uint256 makingAmount = 1 ether;
        uint256 takingAmount = 4000 ether;

        // Build latest answer call for predicate
        bytes memory latestAnswerCall = abi.encodeWithSelector(
            swap.arbitraryStaticCall.selector,
            address(daiOracle),
            abi.encodeWithSelector(daiOracle.latestAnswer.selector)
        );

        // Build predicate call
        bytes memory predicate = abi.encodeWithSelector(
            swap.lt.selector,
            0.0002501 ether, // Threshold - higher than oracle value to make predicate true
            latestAnswerCall
        );

        // Build order with predicate
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: makerAddr,
            receiver: address(0),
            makerAsset: address(weth),
            takerAsset: address(dai),
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            predicate, // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Build taker traits with makingAmount flag
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            takingAmount // threshold
        );

        // Record initial balances
        uint256 addrDaiBalanceBefore = dai.balanceOf(takerAddr);
        uint256 makerAddrDaiBalanceBefore = dai.balanceOf(makerAddr);
        uint256 addrWethBalanceBefore = weth.balanceOf(takerAddr);
        uint256 makerAddrWethBalanceBefore = weth.balanceOf(makerAddr);

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, makingAmount, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Verify balance changes
        assertEq(dai.balanceOf(takerAddr), addrDaiBalanceBefore - takingAmount);
        assertEq(dai.balanceOf(makerAddr), makerAddrDaiBalanceBefore + takingAmount);
        assertEq(weth.balanceOf(takerAddr), addrWethBalanceBefore + makingAmount);
        assertEq(weth.balanceOf(makerAddr), makerAddrWethBalanceBefore - makingAmount);
    }

    function test_simple_order_without_extension() public {
        // Build a simple order without any extension data
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 1,
            maker: makerAddr,
            receiver: address(0),
            makerAsset: address(weth),
            takerAsset: address(dai),
            makingAmount: 1 ether,
            takingAmount: 4000 ether,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        // Build order without extension data
        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData - empty
            "", // takingAmountData - empty
            "", // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Build taker traits without extension
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            false, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            "", // extension - empty
            "", // interaction
            0.99 ether // threshold
        );

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, 4000 ether, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Check balances
        assertEq(dai.balanceOf(takerAddr), 996000000000000000000000, "takerAddr DAI balance");
        assertEq(dai.balanceOf(makerAddr), 1004000000000000000000000, "makerAddr DAI balance");
        assertEq(weth.balanceOf(takerAddr), 101000000000000000000, "takerAddr WETH balance");
        assertEq(weth.balanceOf(makerAddr), 99000000000000000000, "makerAddr WETH balance");
    }

    function test_simple_order_with_different_amounts() public {
        // Build a simple order without any extension data
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 2,
            maker: makerAddr,
            receiver: address(0),
            makerAsset: address(weth),
            takerAsset: address(dai),
            makingAmount: 0.5 ether,
            takingAmount: 2000 ether,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        // Build order without extension data
        (OrderUtils.Order memory order,) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData - empty
            "", // takingAmountData - empty
            "", // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(makerPK, orderData);

        // Build taker traits without extension
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            false, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            "", // extension - empty
            "", // interaction
            0.49 ether // threshold
        );

        // Fill the order
        vm.prank(takerAddr);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, 2000 ether, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // Check balances
        assertEq(dai.balanceOf(takerAddr), 998000000000000000000000, "takerAddr DAI balance");
        assertEq(dai.balanceOf(makerAddr), 1002000000000000000000000, "makerAddr DAI balance");
        assertEq(weth.balanceOf(takerAddr), 100500000000000000000, "takerAddr WETH balance");
        assertEq(weth.balanceOf(makerAddr), 99500000000000000000, "makerAddr WETH balance");
    }

    // Helper function to convert OrderUtils.Order to IOrderMixin.Order
    function convertOrder(OrderUtils.Order memory order) internal pure returns (IOrderMixin.Order memory) {
        return IOrderMixin.Order({
            salt: order.salt,
            maker: Address.wrap(uint256(uint160(order.maker))),
            receiver: Address.wrap(uint256(uint160(order.receiver))),
            makerAsset: Address.wrap(uint256(uint160(order.makerAsset))),
            takerAsset: Address.wrap(uint256(uint160(order.takerAsset))),
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
}
