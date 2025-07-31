// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@jincubator/limit-order-protocol/contracts/interfaces/IOrderMixin.sol";

/// @title ResourceManager
/// @notice Manages resource locks for the Limit Order Protocol integration with The Compact
/// @dev This contract is registered as a ResourceManager in The Compact
contract ResourceManager is Ownable {
    using SafeERC20 for IERC20;

    // Events
    event ResourceLocked(address indexed maker, address indexed token, uint256 amount, uint256 lockId);
    event ResourceUnlocked(address indexed maker, address indexed token, uint256 amount, uint256 lockId);
    event ResourceAllocated(address indexed maker, address indexed token, uint256 amount, uint256 lockId);

    // Errors
    error InsufficientLockedBalance(address maker, address token, uint256 requested, uint256 available);
    error LockNotFound(uint256 lockId);
    error UnauthorizedCaller(address caller);
    error InvalidToken(address token);
    error InvalidAmount(uint256 amount);

    // Structs
    struct ResourceLock {
        address maker;
        address token;
        uint256 amount;
        uint256 allocatedAmount;
        bool isActive;
        uint256 createdAt;
    }

    // State variables
    mapping(uint256 => ResourceLock) public resourceLocks;
    mapping(address => mapping(address => uint256)) public makerTokenLocks; // maker => token => lockId
    uint256 public nextLockId = 1;

    // The Compact integration
    address public immutable theCompact;
    address public immutable allocator;

    constructor(address _theCompact, address _allocator) Ownable(msg.sender) {
        theCompact = _theCompact;
        allocator = _allocator;
    }

    /// @notice Lock resources for a maker
    /// @param maker The address of the maker
    /// @param token The token to lock
    /// @param amount The amount to lock
    /// @return lockId The ID of the created lock
    function lockResources(address maker, address token, uint256 amount) external returns (uint256 lockId) {
        if (token == address(0)) revert InvalidToken(token);
        if (amount == 0) revert InvalidAmount(amount);
        if (maker == address(0)) revert UnauthorizedCaller(maker);

        // Transfer tokens from maker to this contract
        IERC20(token).safeTransferFrom(maker, address(this), amount);

        lockId = nextLockId++;
        resourceLocks[lockId] = ResourceLock({
            maker: maker,
            token: token,
            amount: amount,
            allocatedAmount: 0,
            isActive: true,
            createdAt: block.timestamp
        });

        makerTokenLocks[maker][token] = lockId;

        emit ResourceLocked(maker, token, amount, lockId);
    }

    /// @notice Allocate resources for an order
    /// @param lockId The ID of the lock to allocate from
    /// @param amount The amount to allocate
    function allocateResources(uint256 lockId, uint256 amount) external {
        ResourceLock storage lock = resourceLocks[lockId];
        if (!lock.isActive) revert LockNotFound(lockId);
        if (lock.allocatedAmount + amount > lock.amount) {
            revert InsufficientLockedBalance(lock.maker, lock.token, amount, lock.amount - lock.allocatedAmount);
        }

        lock.allocatedAmount += amount;
        emit ResourceAllocated(lock.maker, lock.token, amount, lockId);
    }

    /// @notice Release allocated resources
    /// @param lockId The ID of the lock to release from
    /// @param amount The amount to release
    function releaseResources(uint256 lockId, uint256 amount) external {
        ResourceLock storage lock = resourceLocks[lockId];
        if (!lock.isActive) revert LockNotFound(lockId);
        if (lock.allocatedAmount < amount) {
            revert InsufficientLockedBalance(lock.maker, lock.token, amount, lock.allocatedAmount);
        }

        lock.allocatedAmount -= amount;
        emit ResourceAllocated(lock.maker, lock.token, amount, lockId);
    }

    /// @notice Unlock resources and return to maker
    /// @param lockId The ID of the lock to unlock
    function unlockResources(uint256 lockId) external {
        ResourceLock storage lock = resourceLocks[lockId];
        if (!lock.isActive) revert LockNotFound(lockId);
        if (lock.allocatedAmount > 0) revert InsufficientLockedBalance(lock.maker, lock.token, 0, lock.allocatedAmount);

        uint256 amount = lock.amount;
        address maker = lock.maker;
        address token = lock.token;

        // Clear the lock
        delete resourceLocks[lockId];
        delete makerTokenLocks[maker][token];

        // Return tokens to maker
        IERC20(token).safeTransfer(maker, amount);

        emit ResourceUnlocked(maker, token, amount, lockId);
    }

    /// @notice Get lock details
    /// @param lockId The ID of the lock
    /// @return lock The lock details
    function getLock(uint256 lockId) external view returns (ResourceLock memory lock) {
        lock = resourceLocks[lockId];
        if (!lock.isActive) revert LockNotFound(lockId);
    }

    /// @notice Get available balance for a maker's token
    /// @param maker The maker address
    /// @param token The token address
    /// @return available The available balance
    function getAvailableBalance(address maker, address token) external view returns (uint256 available) {
        uint256 lockId = makerTokenLocks[maker][token];
        if (lockId == 0) return 0;

        ResourceLock storage lock = resourceLocks[lockId];
        if (!lock.isActive) return 0;

        return lock.amount - lock.allocatedAmount;
    }

    /// @notice Check if a lock exists and is active
    /// @param lockId The ID of the lock
    /// @return exists Whether the lock exists and is active
    function lockExists(uint256 lockId) external view returns (bool exists) {
        return resourceLocks[lockId].isActive;
    }
}
