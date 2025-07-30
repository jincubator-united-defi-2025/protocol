// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../test/utils/OrderUtils.sol";

/**
 * @title OrderUtilsExample
 * @dev Example contract demonstrating how to use the OrderUtils library
 */
contract OrderUtilsExample {
    using OrderUtils for *;

    /**
     * @dev Example of building a simple order
     */
    function buildSimpleOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount
    ) external pure returns (OrderUtils.Order memory order, bytes memory extension) {
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: maker,
            receiver: address(0),
            makerAsset: makerAsset,
            takerAsset: takerAsset,
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: OrderUtils.buildMakerTraits(
                address(0), // allowedSender
                false, // shouldCheckEpoch
                true, // allowPartialFill
                true, // allowMultipleFills
                false, // usePermit2
                false, // unwrapWeth
                0, // expiry
                0, // nonce
                0 // series
            )
        });

        return OrderUtils.buildOrder(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            "", // predicate
            "", // permit
            "", // preInteraction
            "", // postInteraction
            "" // customData
        );
    }

    /**
     * @dev Example of building an RFQ order
     */
    function buildRFQOrder(
        address maker,
        address makerAsset,
        address takerAsset,
        uint256 makingAmount,
        uint256 takingAmount
    ) external pure returns (OrderUtils.Order memory order, bytes memory extension) {
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: maker,
            receiver: address(0),
            makerAsset: makerAsset,
            takerAsset: takerAsset,
            makingAmount: makingAmount,
            takingAmount: takingAmount,
            makerTraits: OrderUtils.buildMakerTraitsRFQ(
                address(0), // allowedSender
                false, // shouldCheckEpoch
                true, // allowPartialFill
                false, // usePermit2
                false, // unwrapWeth
                0, // expiry
                0, // nonce
                0 // series
            )
        });

        return OrderUtils.buildOrderRFQ(
            baseOrder,
            "", // makerAssetSuffix
            "", // takerAssetSuffix
            "", // makingAmountData
            "", // takingAmountData
            "", // predicate
            "", // permit
            "", // preInteraction
            "" // postInteraction
        );
    }

    /**
     * @dev Example of building taker traits
     */
    function buildTakerTraitsExample(bool makingAmount, bool unwrapWeth, uint256 threshold)
        external
        pure
        returns (OrderUtils.TakerTraits memory)
    {
        return OrderUtils.buildTakerTraits(
            makingAmount,
            unwrapWeth,
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            "", // extension
            "", // interaction
            threshold
        );
    }

    /**
     * @dev Example of building fee taker extensions
     */
    function buildFeeTakerExtensionsExample(
        address feeTaker,
        address integratorFeeRecipient,
        address protocolFeeRecipient,
        uint16 integratorFee,
        uint8 integratorShare
    ) external pure returns (OrderUtils.FeeTakerExtensions memory) {
        return OrderUtils.buildFeeTakerExtensions(
            feeTaker,
            "", // getterExtraPrefix
            integratorFeeRecipient,
            protocolFeeRecipient,
            address(0), // makerReceiver
            integratorFee,
            integratorShare,
            0, // resolverFee
            0, // whitelistDiscount
            "", // whitelist
            "", // whitelistPostInteraction
            "", // customMakingGetter
            "", // customTakingGetter
            "" // customPostInteraction
        );
    }

    /**
     * @dev Example of verifying an order signature
     */
    function verifyOrderSignatureExample(
        OrderUtils.Order memory order,
        uint256 chainId,
        address verifyingContract,
        bytes memory signature
    ) external pure returns (address signer) {
        return OrderUtils.verifyOrderSignature(order, chainId, verifyingContract, signature);
    }

    /**
     * @dev Example of creating taker traits for different scenarios
     */
    function createTakerTraitsExamples(uint256 amount)
        external
        pure
        returns (uint256 fillWithMakingAmount, uint256 unwrapWeth, uint256 skipMakerPermit)
    {
        fillWithMakingAmount = OrderUtils.fillWithMakingAmount(amount);
        unwrapWeth = OrderUtils.unwrapWethTaker(amount);
        skipMakerPermit = OrderUtils.skipMakerPermit(amount);
    }

    /**
     * @dev Get protocol constants
     */
    function getProtocolConstants() external pure returns (string memory name, string memory version) {
        return (OrderUtils.NAME, OrderUtils.VERSION);
    }
}
