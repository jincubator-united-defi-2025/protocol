// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import "../src/ResourceManager.sol";
import "../src/ChainLinkCompact.sol";
import "../src/ChainLinkCompactInteraction.sol";
import "../test/utils/Deployers.sol";
import "../test/utils/OrderUtils.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import {TakerTraits} from "@jincubator/limit-order-protocol/contracts/libraries/TakerTraitsLib.sol";
import {Address} from "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import {MakerTraits} from "@jincubator/limit-order-protocol/contracts/libraries/MakerTraitsLib.sol";

contract ChainLinkCompactTest is Test, Deployers {
    using OrderUtils for IOrderMixin.Order;

    ResourceManager public resourceManager;
    ChainLinkCompact public chainLinkCompact;
    ChainLinkCompactInteraction public chainLinkCompactInteraction;

    address public treasurer;
    address public mockTheCompact;

    function setUp() public {
        // Deploy base contracts first
        deployArtifacts();

        // Deploy ERC-6909 contracts
        treasurer = makeAddr("treasurer");
        mockTheCompact = makeAddr("theCompact");

        resourceManager = new ResourceManager(mockTheCompact, address(this));
        chainLinkCompact = new ChainLinkCompact(address(resourceManager));
        chainLinkCompactInteraction =
            new ChainLinkCompactInteraction(treasurer, address(resourceManager), mockTheCompact);

        // Setup tokens and balances
        _setupTokens();
    }

    function _setupTokens() internal {
        // Mint tokens to test addresses
        dai.mint(addr1, 10000 ether);
        vm.deal(addr1, 10 ether);
        vm.prank(addr1);
        weth.deposit{value: 10 ether}();
        inch.mint(addr1, 10000 ether);

        dai.mint(addr2, 10000 ether);
        vm.deal(addr2, 10 ether);
        vm.prank(addr2);
        weth.deposit{value: 10 ether}();
        inch.mint(addr2, 10000 ether);

        // Approve tokens for resource manager
        vm.prank(addr1);
        dai.approve(address(resourceManager), type(uint256).max);
        vm.prank(addr1);
        weth.approve(address(resourceManager), type(uint256).max);
        vm.prank(addr1);
        inch.approve(address(resourceManager), type(uint256).max);

        vm.prank(addr2);
        dai.approve(address(resourceManager), type(uint256).max);
        vm.prank(addr2);
        weth.approve(address(resourceManager), type(uint256).max);
        vm.prank(addr2);
        inch.approve(address(resourceManager), type(uint256).max);
    }

    function test_ResourceManager_LockResources() public {
        uint256 lockAmount = 1000 ether;

        vm.prank(addr1);
        uint256 lockId = resourceManager.lockResources(addr1, address(dai), lockAmount);

        assertEq(lockId, 1);
        assertEq(resourceManager.getAvailableBalance(addr1, address(dai)), lockAmount);
    }

    function test_ResourceManager_AllocateResources() public {
        uint256 lockAmount = 1000 ether;
        uint256 allocateAmount = 500 ether;

        vm.prank(addr1);
        uint256 lockId = resourceManager.lockResources(addr1, address(dai), lockAmount);

        resourceManager.allocateResources(lockId, allocateAmount);

        assertEq(resourceManager.getAvailableBalance(addr1, address(dai)), lockAmount - allocateAmount);
    }

    function test_ResourceManager_ReleaseResources() public {
        uint256 lockAmount = 1000 ether;
        uint256 allocateAmount = 500 ether;

        vm.prank(addr1);
        uint256 lockId = resourceManager.lockResources(addr1, address(dai), lockAmount);

        resourceManager.allocateResources(lockId, allocateAmount);
        resourceManager.releaseResources(lockId, allocateAmount);

        assertEq(resourceManager.getAvailableBalance(addr1, address(dai)), lockAmount);
    }

    function test_ResourceManager_UnlockResources() public {
        uint256 lockAmount = 1000 ether;

        vm.prank(addr1);
        uint256 lockId = resourceManager.lockResources(addr1, address(dai), lockAmount);

        uint256 balanceBefore = dai.balanceOf(addr1);
        resourceManager.unlockResources(lockId);
        uint256 balanceAfter = dai.balanceOf(addr1);

        assertEq(balanceAfter - balanceBefore, lockAmount);
        assertEq(resourceManager.getAvailableBalance(addr1, address(dai)), 0);
    }

    function test_ChainLinkCompact_ERC6909Enabled() public {
        assertTrue(chainLinkCompact.erc6909Enabled());

        chainLinkCompact.setERC6909Enabled(false);
        assertFalse(chainLinkCompact.erc6909Enabled());
    }

    function test_ChainLinkCompact_ValidateResourceLock() public {
        uint256 lockAmount = 1000 ether;

        vm.prank(addr1);
        resourceManager.lockResources(addr1, address(dai), lockAmount);

        // Should not revert when sufficient balance exists
        resourceManager.getAvailableBalance(addr1, address(dai));
    }

    function test_ChainLinkCompact_InsufficientResourceLock() public {
        uint256 lockAmount = 1000 ether;
        uint256 requestAmount = 1500 ether;

        vm.prank(addr1);
        resourceManager.lockResources(addr1, address(dai), lockAmount);

        // Should revert when insufficient balance
        vm.expectRevert(
            abi.encodeWithSelector(
                ChainLinkCompact.InsufficientResourceLock.selector, addr1, address(dai), requestAmount, lockAmount
            )
        );

        // Call getMakingAmount which internally calls _validateResourceLock
        chainLinkCompact.getMakingAmount(
            IOrderMixin.Order({
                salt: 0,
                maker: Address.wrap(uint256(uint160(addr1))),
                receiver: Address.wrap(0),
                makerAsset: Address.wrap(uint256(uint160(address(dai)))),
                takerAsset: Address.wrap(0),
                makingAmount: 0,
                takingAmount: 0,
                makerTraits: MakerTraits.wrap(0)
            }),
            "", // extension
            bytes32(0), // orderHash
            address(0), // taker
            requestAmount, // takingAmount
            0, // remainingMakingAmount
            "" // extraData
        );
    }

    function test_ChainLinkCompactInteraction_PostInteraction() public {
        // Setup: Create a resource lock for addr1
        uint256 lockAmount = 1000 ether;
        vm.prank(addr1);
        resourceManager.lockResources(addr1, address(dai), lockAmount);

        // Create an order
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: addr1,
            receiver: address(0),
            makerAsset: address(dai),
            takerAsset: address(weth),
            makingAmount: 1000 ether,
            takingAmount: 1 ether,
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
            "", // preInteraction
            abi.encodePacked(address(chainLinkCompactInteraction)), // postInteraction
            "" // customData
        );

        // Setup taker with tokens and approvals
        vm.prank(addr2);
        weth.approve(address(swap), 1 ether);
        vm.prank(addr2);
        dai.approve(address(chainLinkCompactInteraction), 1000 ether);

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(orderData);

        // Build taker traits
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            false, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            1 ether // threshold
        );

        // Fill the order
        vm.prank(addr2);
        swap.fillOrderArgs(convertOrder(order), r, vs, 1 ether, TakerTraits.wrap(takerTraits.traits), takerTraits.args);

        // Verify tokens were transferred to treasurer (maker asset = DAI)
        assertEq(dai.balanceOf(treasurer), 1000 ether);
    }

    function test_ChainLinkCompactInteraction_TransferFailure() public {
        // Create an order
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: addr1,
            receiver: address(0),
            makerAsset: address(dai),
            takerAsset: address(weth),
            makingAmount: 1000 ether,
            takingAmount: 1 ether,
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
            "", // preInteraction
            abi.encodePacked(address(chainLinkCompactInteraction)), // postInteraction
            "" // customData
        );

        // Don't approve tokens for taker - this should cause transfer to fail
        vm.prank(addr2);
        weth.approve(address(swap), 1 ether);
        // Note: No approval for chainLinkCompactInteraction - this should cause transfer to fail

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(orderData);

        // Build taker traits
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            false, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            1 ether // threshold
        );

        // Fill the order - should revert due to transfer failure
        vm.prank(addr2);
        vm.expectRevert();
        swap.fillOrderArgs(convertOrder(order), r, vs, 1 ether, TakerTraits.wrap(takerTraits.traits), takerTraits.args);
    }

    function test_ChainLinkCompactInteraction_ProcessClaim() public {
        // Setup: Create a resource lock
        uint256 lockAmount = 1000 ether;
        vm.prank(addr1);
        uint256 lockId = resourceManager.lockResources(addr1, address(dai), lockAmount);

        // Create claim data
        bytes32 claimHash = keccak256("test claim");
        uint256 nonce = 1;
        uint256 expires = block.timestamp + 1 hours;
        uint256 amount = 500 ether;

        // Sign the claim
        bytes32 messageHash = keccak256(abi.encodePacked(claimHash, addr1, nonce, expires, lockId, amount));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkAddr1, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Process the claim
        chainLinkCompactInteraction.processClaim(claimHash, addr1, nonce, expires, lockId, amount, signature);

        // Verify resources were allocated
        assertEq(resourceManager.getAvailableBalance(addr1, address(dai)), lockAmount - amount);
    }

    function test_ChainLinkCompactInteraction_VerifyClaim() public {
        // Setup: Create a resource lock
        uint256 lockAmount = 1000 ether;
        vm.prank(addr1);
        uint256 lockId = resourceManager.lockResources(addr1, address(dai), lockAmount);

        // Create claim data
        bytes32 claimHash = keccak256("test claim");
        uint256 nonce = 1;
        uint256 expires = block.timestamp + 1 hours;
        uint256 amount = 500 ether;

        // Sign the claim
        bytes32 messageHash = keccak256(abi.encodePacked(claimHash, addr1, nonce, expires, lockId, amount));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkAddr1, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Verify the claim
        bool isValid =
            chainLinkCompactInteraction.verifyClaim(claimHash, addr1, nonce, expires, lockId, amount, signature);

        assertTrue(isValid);
    }

    function test_ChainLinkCompactInteraction_InvalidSignature() public {
        // Setup: Create a resource lock
        uint256 lockAmount = 1000 ether;
        vm.prank(addr1);
        uint256 lockId = resourceManager.lockResources(addr1, address(dai), lockAmount);

        // Create claim data
        bytes32 claimHash = keccak256("test claim");
        uint256 nonce = 1;
        uint256 expires = block.timestamp + 1 hours;
        uint256 amount = 500 ether;

        // Sign with wrong private key
        bytes32 messageHash = keccak256(abi.encodePacked(claimHash, addr1, nonce, expires, lockId, amount));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkAddr2, messageHash); // Wrong key
        bytes memory signature = abi.encodePacked(r, s, v);

        // Process the claim - should revert
        vm.expectRevert(ChainLinkCompactInteraction.InvalidSignature.selector);
        chainLinkCompactInteraction.processClaim(claimHash, addr1, nonce, expires, lockId, amount, signature);
    }

    function test_ChainLinkCompactInteraction_ExpiredClaim() public {
        // Setup: Create a resource lock
        uint256 lockAmount = 1000 ether;
        vm.prank(addr1);
        uint256 lockId = resourceManager.lockResources(addr1, address(dai), lockAmount);

        // Create claim data with expired timestamp
        bytes32 claimHash = keccak256("test claim");
        uint256 nonce = 1;
        uint256 expires = block.timestamp - 1; // Expired timestamp
        uint256 amount = 500 ether;

        // Sign the claim
        bytes32 messageHash = keccak256(abi.encodePacked(claimHash, addr1, nonce, expires, lockId, amount));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pkAddr1, messageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        // Process the claim - should revert
        vm.expectRevert(ChainLinkCompactInteraction.ClaimProcessingFailed.selector);
        chainLinkCompactInteraction.processClaim(claimHash, addr1, nonce, expires, lockId, amount, signature);
    }

    function test_EndToEnd_ERC6909Flow() public {
        // 1. Maker locks resources
        uint256 lockAmount = 1000 ether;
        vm.prank(addr1);
        uint256 lockId = resourceManager.lockResources(addr1, address(dai), lockAmount);

        // 2. Create order with ERC-6909 enabled
        OrderUtils.Order memory baseOrder = OrderUtils.Order({
            salt: 0,
            maker: addr1,
            receiver: address(0),
            makerAsset: address(dai),
            takerAsset: address(weth),
            makingAmount: 500 ether,
            takingAmount: 0.5 ether,
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
            "", // preInteraction
            abi.encodePacked(address(chainLinkCompactInteraction)), // postInteraction
            "" // customData
        );

        // 3. Setup taker
        vm.prank(addr2);
        weth.approve(address(swap), 0.5 ether);
        vm.prank(addr2);
        dai.approve(address(chainLinkCompactInteraction), 500 ether);

        // Sign the order
        bytes32 orderData = swap.hashOrder(convertOrder(order));
        (bytes32 r, bytes32 vs) = signOrder(orderData);

        // Build taker traits
        OrderUtils.TakerTraits memory takerTraits = OrderUtils.buildTakerTraits(
            false, // makingAmount
            false, // unwrapWeth
            false, // skipMakerPermit
            false, // usePermit2
            "", // target
            extension, // extension
            "", // interaction
            0.5 ether // threshold
        );

        // 4. Fill order
        vm.prank(addr2);
        swap.fillOrderArgs(
            convertOrder(order), r, vs, 0.5 ether, TakerTraits.wrap(takerTraits.traits), takerTraits.args
        );

        // 5. Verify results
        assertEq(dai.balanceOf(treasurer), 500 ether); // Maker asset (DAI) should be transferred to treasurer
        assertEq(resourceManager.getAvailableBalance(addr1, address(dai)), lockAmount - 500 ether);

        // 6. Verify taker's output tokens are locked
        uint256 takerLockId = resourceManager.makerTokenLocks(addr2, address(dai));
        assertGt(takerLockId, 0);
    }

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
    function signOrder(bytes32 orderData) internal view returns (bytes32 r, bytes32 vs) {
        (uint8 v, bytes32 r_, bytes32 s) = vm.sign(pkAddr1, orderData);
        r = r_;
        // yParityAndS format: s | (v << 255)
        // v should be 27 or 28, we need to convert to 0 or 1 for yParity
        uint8 yParity = v - 27;
        vs = bytes32(uint256(s) | (uint256(yParity) << 255));
    }
}
