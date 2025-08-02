// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "test/utils/orderUtils/OrderUtils.sol";
import "test/utils/orderUtils/OrderUtilsExample.sol";

contract OrderUtilsTest is Test {
    using OrderUtils for *;

    OrderUtilsExample example;

    function setUp() public {
        example = new OrderUtilsExample();
    }

    function testBuildMakerTraits() public {
        uint256 traits = OrderUtils.buildMakerTraits(
            address(0x123), // allowedSender
            false, // shouldCheckEpoch
            true, // allowPartialFill
            true, // allowMultipleFills
            false, // usePermit2
            false, // unwrapWeth
            1000, // expiry
            5, // nonce
            1 // series
        );

        // Verify that the traits are built correctly
        assertTrue(traits > 0);

        // Check that allowPartialFill and allowMultipleFills are set
        assertTrue(OrderUtils.getBit(traits, 254)); // _ALLOW_MULTIPLE_FILLS_FLAG
        assertFalse(OrderUtils.getBit(traits, 255)); // _NO_PARTIAL_FILLS_FLAG
    }

    function testBuildMakerTraitsRFQ() public {
        uint256 traits = OrderUtils.buildMakerTraitsRFQ(
            address(0x123), // allowedSender
            false, // shouldCheckEpoch
            true, // allowPartialFill
            false, // usePermit2
            false, // unwrapWeth
            1000, // expiry
            5, // nonce
            1 // series
        );

        // Verify that the traits are built correctly
        assertTrue(traits > 0);

        // Check that RFQ-specific flags are not set
        assertFalse(OrderUtils.getBit(traits, 254)); // _ALLOW_MULTIPLE_FILLS_FLAG
        assertFalse(OrderUtils.getBit(traits, 255)); // _NO_PARTIAL_FILLS_FLAG
        assertFalse(OrderUtils.getBit(traits, 250)); // _NEED_EPOCH_CHECK_FLAG
    }

    function testBuildTakerTraits() public {
        OrderUtils.TakerTraits memory traits = OrderUtils.buildTakerTraits(
            true, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            "", // extension
            "", // interaction
            1000 // threshold
        );

        // Verify that the traits are built correctly
        assertEq(traits.traits, 1000 | (1 << 255)); // _MAKER_AMOUNT_FLAG
        assertEq(traits.args.length, 0);
    }

    function testBuildSimpleOrder() public {
        (OrderUtils.Order memory order, bytes memory extension) = example.buildSimpleOrder(
            address(0x123), // maker
            address(0x456), // makerAsset
            address(0x789), // takerAsset
            1000, // makingAmount
            2000 // takingAmount
        );

        // Verify order structure
        assertEq(order.maker, address(0x123));
        assertEq(order.makerAsset, address(0x456));
        assertEq(order.takerAsset, address(0x789));
        assertEq(order.makingAmount, 1000);
        assertEq(order.takingAmount, 2000);
        assertTrue(order.salt > 0); // Should be calculated based on extension
    }

    function testBuildRFQOrder() public {
        (OrderUtils.Order memory order, bytes memory extension) = example.buildRFQOrder(
            address(0x123), // maker
            address(0x456), // makerAsset
            address(0x789), // takerAsset
            1000, // makingAmount
            2000 // takingAmount
        );

        // Verify order structure
        assertEq(order.maker, address(0x123));
        assertEq(order.makerAsset, address(0x456));
        assertEq(order.takerAsset, address(0x789));
        assertEq(order.makingAmount, 1000);
        assertEq(order.takingAmount, 2000);
        assertTrue(order.salt > 0);
    }

    function testBuildFeeTakerExtensions() public {
        OrderUtils.FeeTakerExtensions memory extensions = example.buildFeeTakerExtensionsExample(
            address(0x123), // feeTaker
            address(0x456), // integratorFeeRecipient
            address(0x789), // protocolFeeRecipient
            100, // integratorFee
            50 // integratorShare
        );

        // Verify extensions are built
        assertTrue(extensions.makingAmountData.length > 0);
        assertTrue(extensions.takingAmountData.length > 0);
        assertTrue(extensions.postInteraction.length > 0);
    }

    function testFillWithMakingAmount() public {
        uint256 amount = 1000;
        uint256 result = OrderUtils.fillWithMakingAmount(amount);

        // Should have the making amount flag set
        assertTrue((result & (1 << 255)) != 0); // _MAKER_AMOUNT_FLAG
        assertEq(result & (type(uint256).max ^ (1 << 255)), amount);
    }

    function testUnwrapWethTaker() public {
        uint256 amount = 1000;
        uint256 result = OrderUtils.unwrapWethTaker(amount);

        // Should have the unwrap WETH flag set
        assertTrue((result & (1 << 254)) != 0); // _UNWRAP_WETH_FLAG_TAKER
        assertEq(result & (type(uint256).max ^ (1 << 254)), amount);
    }

    function testSkipMakerPermit() public {
        uint256 amount = 1000;
        uint256 result = OrderUtils.skipMakerPermit(amount);

        // Should have the skip maker permit flag set
        assertTrue((result & (1 << 253)) != 0); // _SKIP_ORDER_PERMIT_FLAG
        assertEq(result & (type(uint256).max ^ (1 << 253)), amount);
    }

    function testSetBit() public {
        uint256 value = 0;

        // Set bit 5
        value = OrderUtils.setBit(value, 5, true);
        assertTrue(OrderUtils.getBit(value, 5));

        // Clear bit 5
        value = OrderUtils.setBit(value, 5, false);
        assertFalse(OrderUtils.getBit(value, 5));
    }

    function testGetProtocolConstants() public {
        (string memory name, string memory version) = example.getProtocolConstants();
        assertEq(name, "1inch Limit Order Protocol");
        assertEq(version, "4");
    }

    function testBuildOrderWithExtension() public {
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: address(0x123),
            receiver: address(0),
            makerAsset: address(0x456),
            takerAsset: address(0x789),
            makingAmount: 1000,
            takingAmount: 2000,
            makerTraits: OrderUtils.buildMakerTraits(address(0), false, true, true, false, false, 0, 0, 0)
        });

        bytes memory customData = "0x1234567890abcdef";

        (OrderUtils.Order memory order, bytes memory extension) = OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            "", // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            customData
        );

        // Verify that extension contains custom data
        assertTrue(extension.length > 0);
        assertTrue(order.salt > 0);
    }

    function testBuildOrderData() public {
        OrderUtils.Order memory order = OrderUtils.Order({
            salt: 123,
            maker: address(0x123),
            receiver: address(0),
            makerAsset: address(0x456),
            takerAsset: address(0x789),
            makingAmount: 1000,
            takingAmount: 2000,
            makerTraits: 0
        });

        bytes32 orderData = OrderUtils.buildOrderData(1, address(0xabc), order);
        assertTrue(orderData != bytes32(0));
    }
}
