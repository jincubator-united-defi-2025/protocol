// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title OrderUtils
 * @dev Solidity library providing utilities for building and manipulating 1inch Limit Order Protocol orders
 */
library OrderUtils {
    using ECDSA for bytes32;

    // Order structure
    struct Order {
        uint256 salt;
        address maker;
        address receiver;
        address makerAsset;
        address takerAsset;
        uint256 makingAmount;
        uint256 takingAmount;
        uint256 makerTraits;
    }

    // Taker traits structure
    struct TakerTraits {
        uint256 traits;
        bytes args;
    }

    // Fee taker extensions structure
    struct FeeTakerExtensions {
        bytes makingAmountData;
        bytes takingAmountData;
        bytes postInteraction;
    }

    // Constants for maker traits flags
    uint256 private constant _NO_PARTIAL_FILLS_FLAG = 255;
    uint256 private constant _ALLOW_MULTIPLE_FILLS_FLAG = 254;
    uint256 private constant _NEED_PREINTERACTION_FLAG = 252;
    uint256 private constant _NEED_POSTINTERACTION_FLAG = 251;
    uint256 private constant _NEED_EPOCH_CHECK_FLAG = 250;
    uint256 private constant _HAS_EXTENSION_FLAG = 249;
    uint256 private constant _USE_PERMIT2_FLAG = 248;
    uint256 private constant _UNWRAP_WETH_FLAG = 247;

    // Constants for taker traits
    uint256 private constant _MAKER_AMOUNT_FLAG = 1 << 255;
    uint256 private constant _UNWRAP_WETH_FLAG_TAKER = 1 << 254;
    uint256 private constant _SKIP_ORDER_PERMIT_FLAG = 1 << 253;
    uint256 private constant _USE_PERMIT2_FLAG_TAKER = 1 << 252;
    uint256 private constant _ARGS_HAS_TARGET = 1 << 251;

    uint256 private constant _ARGS_EXTENSION_LENGTH_OFFSET = 224;
    uint256 private constant _ARGS_EXTENSION_LENGTH_MASK = 0xffffff;
    uint256 private constant _ARGS_INTERACTION_LENGTH_OFFSET = 200;
    uint256 private constant _ARGS_INTERACTION_LENGTH_MASK = 0xffffff;

    // Protocol constants
    string public constant NAME = "1inch Limit Order Protocol";
    string public constant VERSION = "4";

    /**
     * @dev Builds taker traits with the specified options
     */
    function buildTakerTraits(
        bool makingAmount,
        bool unwrapWeth,
        bool skipMakerPermitFlag,
        bool usePermit2,
        bytes memory target,
        bytes memory extension,
        bytes memory interaction,
        uint256 threshold
    ) internal pure returns (TakerTraits memory) {
        uint256 traits = threshold;

        if (makingAmount) traits |= _MAKER_AMOUNT_FLAG;
        if (unwrapWeth) traits |= _UNWRAP_WETH_FLAG_TAKER;
        if (skipMakerPermitFlag) traits |= _SKIP_ORDER_PERMIT_FLAG;
        if (usePermit2) traits |= _USE_PERMIT2_FLAG_TAKER;
        if (target.length > 0) traits |= _ARGS_HAS_TARGET;

        traits |= extension.length << _ARGS_EXTENSION_LENGTH_OFFSET;
        traits |= interaction.length << _ARGS_INTERACTION_LENGTH_OFFSET;

        bytes memory args = abi.encodePacked(target, extension, interaction);

        return TakerTraits({traits: traits, args: args});
    }

    /**
     * @dev Builds maker traits for RFQ orders
     */
    function buildMakerTraitsRFQ(
        address allowedSender,
        bool shouldCheckEpoch,
        bool allowPartialFill,
        bool usePermit2,
        bool unwrapWeth,
        uint256 expiry,
        uint256 nonce,
        uint256 series
    ) internal pure returns (uint256) {
        return buildMakerTraits(
            allowedSender,
            shouldCheckEpoch,
            allowPartialFill,
            false, // allowMultipleFills
            usePermit2,
            unwrapWeth,
            expiry,
            nonce,
            series
        );
    }

    /**
     * @dev Builds maker traits with the specified options
     */
    function buildMakerTraits(
        address allowedSender,
        bool shouldCheckEpoch,
        bool allowPartialFill,
        bool allowMultipleFills,
        bool usePermit2,
        bool unwrapWeth,
        uint256 expiry,
        uint256 nonce,
        uint256 series
    ) internal pure returns (uint256) {
        require(expiry < 1 << 40, "Expiry should be less than 40 bits");
        require(nonce < 1 << 40, "Nonce should be less than 40 bits");
        require(series < 1 << 40, "Series should be less than 40 bits");

        uint256 traits = 0;

        traits |= series << 160;
        traits |= nonce << 120;
        traits |= expiry << 80;
        traits |= uint256(uint160(allowedSender)) & ((1 << 80) - 1);

        if (unwrapWeth) traits |= 1 << _UNWRAP_WETH_FLAG;
        if (allowMultipleFills) traits |= 1 << _ALLOW_MULTIPLE_FILLS_FLAG;
        if (!allowPartialFill) traits |= 1 << _NO_PARTIAL_FILLS_FLAG;
        if (shouldCheckEpoch) traits |= 1 << _NEED_EPOCH_CHECK_FLAG;
        if (usePermit2) traits |= 1 << _USE_PERMIT2_FLAG;

        return traits;
    }

    /**
     * @dev Builds fee taker extensions
     */
    function buildFeeTakerExtensions(
        address feeTaker,
        bytes memory getterExtraPrefix,
        address integratorFeeRecipient,
        address protocolFeeRecipient,
        address makerReceiver,
        uint16 integratorFee,
        uint8 integratorShare,
        uint16 resolverFee,
        uint8 whitelistDiscount,
        bytes memory whitelist,
        bytes memory whitelistPostInteraction,
        bytes memory customMakingGetter,
        bytes memory customTakingGetter,
        bytes memory customPostInteraction
    ) internal pure returns (FeeTakerExtensions memory) {
        bytes memory makingAmountData = abi.encodePacked(
            feeTaker,
            getterExtraPrefix,
            integratorFee,
            integratorShare,
            resolverFee,
            whitelistDiscount,
            whitelist,
            customMakingGetter
        );

        bytes memory takingAmountData = abi.encodePacked(
            feeTaker,
            getterExtraPrefix,
            integratorFee,
            integratorShare,
            resolverFee,
            whitelistDiscount,
            whitelist,
            customTakingGetter
        );

        bytes memory postInteraction;
        if (makerReceiver != address(0)) {
            postInteraction = abi.encodePacked(
                feeTaker,
                bytes1(0x01),
                integratorFeeRecipient,
                protocolFeeRecipient,
                makerReceiver,
                integratorFee,
                integratorShare,
                resolverFee,
                whitelistDiscount,
                whitelistPostInteraction,
                customPostInteraction
            );
        } else {
            postInteraction = abi.encodePacked(
                feeTaker,
                bytes1(0x00),
                integratorFeeRecipient,
                protocolFeeRecipient,
                integratorFee,
                integratorShare,
                resolverFee,
                whitelistDiscount,
                whitelistPostInteraction,
                customPostInteraction
            );
        }

        return FeeTakerExtensions({
            makingAmountData: makingAmountData,
            takingAmountData: takingAmountData,
            postInteraction: postInteraction
        });
    }

    /**
     * @dev Builds an RFQ order
     */
    function buildOrderRFQ(
        Order memory order,
        bytes memory makerAssetSuffix,
        bytes memory takerAssetSuffix,
        bytes memory makingAmountData,
        bytes memory takingAmountData,
        bytes memory predicate,
        bytes memory permit,
        bytes memory preInteraction,
        bytes memory postInteraction
    ) internal pure returns (Order memory, bytes memory) {
        // Set RFQ-specific flags
        order.makerTraits = setBit(order.makerTraits, _ALLOW_MULTIPLE_FILLS_FLAG, false);
        order.makerTraits = setBit(order.makerTraits, _NO_PARTIAL_FILLS_FLAG, false);
        order.makerTraits = setBit(order.makerTraits, _NEED_EPOCH_CHECK_FLAG, false);

        return buildOrder(
            order,
            makerAssetSuffix,
            takerAssetSuffix,
            makingAmountData,
            takingAmountData,
            predicate,
            permit,
            preInteraction,
            postInteraction,
            ""
        );
    }

    /**
     * @dev Builds a complete order with extension
     */
    function buildOrder(
        Order memory order,
        bytes memory makerAssetSuffix,
        bytes memory takerAssetSuffix,
        bytes memory makingAmountData,
        bytes memory takingAmountData,
        bytes memory predicate,
        bytes memory permit,
        bytes memory preInteraction,
        bytes memory postInteraction,
        bytes memory customData
    ) internal pure returns (Order memory, bytes memory) {
        bytes[] memory allInteractions = new bytes[](8);
        allInteractions[0] = makerAssetSuffix;
        allInteractions[1] = takerAssetSuffix;
        allInteractions[2] = makingAmountData;
        allInteractions[3] = takingAmountData;
        allInteractions[4] = predicate;
        allInteractions[5] = permit;
        allInteractions[6] = preInteraction;
        allInteractions[7] = postInteraction;

        bytes memory allInteractionsConcat = abi.encodePacked(
            makerAssetSuffix,
            takerAssetSuffix,
            makingAmountData,
            takingAmountData,
            predicate,
            permit,
            preInteraction,
            postInteraction,
            customData
        );

        bytes memory extension = "";
        if (allInteractionsConcat.length > 0) {
            uint256[] memory offsets = new uint256[](8);
            uint256 cumulativeOffset = 0;

            // Calculate offsets as the END position of each parameter's calldata
            for (uint256 i = 0; i < 8; i++) {
                cumulativeOffset += allInteractions[i].length;
                offsets[i] = cumulativeOffset;
            }

            uint256 offsetsPacked = 0;
            for (uint256 i = 0; i < 8; i++) {
                offsetsPacked |= offsets[i] << (32 * i);
            }

            extension = abi.encodePacked(offsetsPacked, allInteractionsConcat);
        }

        // Calculate salt based on extension
        if (extension.length > 0) {
            order.salt = uint256(keccak256(extension)) & ((1 << 160) - 1);
            order.makerTraits |= 1 << _HAS_EXTENSION_FLAG;
        } else {
            order.salt = 1;
        }

        // Set interaction flags
        if (preInteraction.length > 0) {
            order.makerTraits |= 1 << _NEED_PREINTERACTION_FLAG;
        }

        if (postInteraction.length > 0) {
            order.makerTraits |= 1 << _NEED_POSTINTERACTION_FLAG;
        }

        return (order, extension);
    }

    /**
     * @dev Builds order data for EIP-712 signing
     */
    function buildOrderData(uint256 chainId, address verifyingContract, Order memory order)
        internal
        pure
        returns (bytes32)
    {
        bytes32 orderHash = keccak256(
            abi.encodePacked(
                order.salt,
                order.maker,
                order.receiver,
                order.makerAsset,
                order.takerAsset,
                order.makingAmount,
                order.takingAmount,
                order.makerTraits
            )
        );

        bytes32 domainSeparator = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes(NAME)),
                keccak256(bytes(VERSION)),
                chainId,
                verifyingContract
            )
        );

        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, orderHash));
    }

    /**
     * @dev Verifies order signature
     */
    function verifyOrderSignature(
        Order memory order,
        uint256 chainId,
        address verifyingContract,
        bytes memory signature
    ) internal pure returns (address) {
        bytes32 orderData = buildOrderData(chainId, verifyingContract, order);
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", orderData));
        return hash.recover(signature);
    }

    /**
     * @dev Creates taker traits for filling with making amount
     */
    function fillWithMakingAmount(uint256 amount) internal pure returns (uint256) {
        TakerTraits memory traits = buildTakerTraits(true, false, false, false, "", "", "", 0);
        return amount | traits.traits;
    }

    /**
     * @dev Creates taker traits for unwrapping WETH
     */
    function unwrapWethTaker(uint256 amount) internal pure returns (uint256) {
        TakerTraits memory traits = buildTakerTraits(false, true, false, false, "", "", "", 0);
        return amount | traits.traits;
    }

    /**
     * @dev Creates taker traits for skipping maker permit
     */
    function skipMakerPermit(uint256 amount) internal pure returns (uint256) {
        TakerTraits memory traits = buildTakerTraits(false, false, true, false, "", "", "", 0);
        return amount | traits.traits;
    }

    /**
     * @dev Sets or clears a bit in a uint256
     */
    function setBit(uint256 value, uint256 bit, bool set) internal pure returns (uint256) {
        if (set) {
            return value | (1 << bit);
        } else {
            return value & ~(1 << bit);
        }
    }

    /**
     * @dev Gets a bit from a uint256
     */
    function getBit(uint256 value, uint256 bit) internal pure returns (bool) {
        return (value & (1 << bit)) != 0;
    }
}
