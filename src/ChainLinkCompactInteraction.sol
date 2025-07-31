// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IPostInteraction.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@1inch/solidity-utils/contracts/libraries/AddressLib.sol";
import "./ResourceManager.sol";

/// @title ChainLinkCompactInteraction
/// @notice Arbiter contract for The Compact that processes claims and manages resource locks
/// @dev Implements IPostInteraction interface for the Limit Order Protocol and acts as an Arbiter for The Compact
contract ChainLinkCompactInteraction is IPostInteraction {
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    error TransferFailed();
    error InvalidTreasurer();
    error InvalidArbiter();
    error ClaimProcessingFailed();
    error InsufficientOutputAmount();
    error InvalidSignature();

    /// @notice Treasurer wallet address that receives the output tokens
    address public immutable treasurer;

    /// @notice Resource manager for ERC-6909 integration
    ResourceManager public immutable resourceManager;

    /// @notice The Compact contract address
    address public immutable theCompact;

    /// @notice Emitted when tokens are transferred to treasurer
    event TokensTransferredToTreasurer(
        address indexed token, address indexed from, address indexed treasurer, uint256 amount
    );

    /// @notice Emitted when a resource lock is created for taker
    event ResourceLockCreated(address indexed taker, address indexed token, uint256 amount, uint256 lockId);

    /// @notice Emitted when a claim is processed
    event ClaimProcessed(address indexed sponsor, address indexed arbiter, bytes32 indexed claimHash, uint256 nonce);

    /// @param _treasurer The address of the treasurer wallet
    /// @param _resourceManager The address of the resource manager
    /// @param _theCompact The address of The Compact contract
    constructor(address _treasurer, address _resourceManager, address _theCompact) {
        if (_treasurer == address(0)) revert InvalidTreasurer();
        if (_resourceManager == address(0)) revert InvalidArbiter();
        if (_theCompact == address(0)) revert InvalidArbiter();

        treasurer = _treasurer;
        resourceManager = ResourceManager(_resourceManager);
        theCompact = _theCompact;
    }

    /// @notice Post-interaction callback that transfers output tokens to treasurer and creates resource lock
    /// @param order The order that was filled
    /// @param extension Order extension data
    /// @param orderHash The hash of the order
    /// @param taker The address of the taker who filled the order
    /// @param makingAmount The amount of maker asset that was transferred
    /// @param takingAmount The amount of taker asset that was transferred
    /// @param remainingMakingAmount The remaining maker amount in the order
    /// @param extraData Additional data passed to the interaction
    function postInteraction(
        IOrderMixin.Order calldata order,
        bytes calldata extension,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external override {
        // Transfer the taker's output tokens (maker asset) to the treasurer
        address outputToken = address(uint160(Address.unwrap(order.makerAsset)));
        uint256 outputAmount = makingAmount;

        // Use SafeERC20 for safe token transfers
        IERC20(outputToken).safeTransferFrom(taker, treasurer, outputAmount);
        emit TokensTransferredToTreasurer(outputToken, taker, treasurer, outputAmount);

        // Create resource lock for taker's output tokens if they meet minimum threshold
        if (outputAmount >= takingAmount) {
            _createResourceLockForTaker(taker, outputToken, outputAmount);
        } else {
            revert InsufficientOutputAmount();
        }
    }

    /// @notice Process a claim for The Compact (Arbiter functionality)
    /// @param claimHash The hash of the claim
    /// @param sponsor The sponsor address
    /// @param nonce The nonce for the claim
    /// @param expires The expiration timestamp
    /// @param lockId The resource lock ID
    /// @param amount The amount to claim
    /// @param signature The sponsor's signature
    function processClaim(
        bytes32 claimHash,
        address sponsor,
        uint256 nonce,
        uint256 expires,
        uint256 lockId,
        uint256 amount,
        bytes calldata signature
    ) external {
        // Verify the claim hasn't expired
        if (block.timestamp > expires) revert ClaimProcessingFailed();

        // Verify the sponsor's signature
        bytes32 messageHash = keccak256(abi.encodePacked(claimHash, sponsor, nonce, expires, lockId, amount));
        address recoveredSigner = ECDSA.recover(messageHash, signature);

        if (recoveredSigner != sponsor) revert InvalidSignature();

        // Process the claim by allocating resources
        try resourceManager.allocateResources(lockId, amount) {
            emit ClaimProcessed(sponsor, address(this), claimHash, nonce);
        } catch {
            revert ClaimProcessingFailed();
        }
    }

    /// @notice Create a resource lock for the taker's output tokens
    /// @param taker The taker address
    /// @param token The token address
    /// @param amount The amount to lock
    function _createResourceLockForTaker(address taker, address token, uint256 amount) internal {
        // Create resource lock for taker's output tokens
        uint256 lockId = resourceManager.lockResources(taker, token, amount);

        emit ResourceLockCreated(taker, token, amount, lockId);
    }

    /// @notice Verify that a claim is valid (Arbiter interface)
    /// @param claimHash The hash of the claim
    /// @param sponsor The sponsor address
    /// @param nonce The nonce for the claim
    /// @param expires The expiration timestamp
    /// @param lockId The resource lock ID
    /// @param amount The amount to claim
    /// @param signature The sponsor's signature
    /// @return isValid Whether the claim is valid
    function verifyClaim(
        bytes32 claimHash,
        address sponsor,
        uint256 nonce,
        uint256 expires,
        uint256 lockId,
        uint256 amount,
        bytes calldata signature
    ) external view returns (bool isValid) {
        // Check if claim has expired
        if (block.timestamp > expires) return false;

        // Verify the sponsor's signature
        bytes32 messageHash = keccak256(abi.encodePacked(claimHash, sponsor, nonce, expires, lockId, amount));
        address recoveredSigner = ECDSA.recover(messageHash, signature);

        if (recoveredSigner != sponsor) return false;

        // Check if the resource lock exists and has sufficient balance
        try resourceManager.getLock(lockId) returns (ResourceManager.ResourceLock memory lock) {
            if (lock.allocatedAmount + amount > lock.amount) return false;
            return true;
        } catch {
            return false;
        }
    }

    /// @notice Get the domain separator for EIP-712 signatures
    /// @return The domain separator
    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256("ChainLinkCompactInteraction"),
                keccak256("1"),
                block.chainid,
                address(this)
            )
        );
    }
}
