// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "./IOrderMixin.sol";

/**
 * @title ##1inch Limit Order Protocol v4
 * @notice Limit order protocol provides two different order types
 * - Regular Limit Order
 * - RFQ Order
 *
 * Both types provide similar order-fulfilling functionality. The difference is that regular order offers more customization options and features, while RFQ order is extremely gas efficient but without ability to customize.
 *
 * Regular limit order additionally supports
 * - Execution predicates. Conditions for order execution are set with predicates. For example, expiration timestamp or block number, price for stop loss or take profit strategies.
 * - Callbacks to notify maker on order execution
 *
 * See [OrderMixin](OrderMixin.md) for more details.
 *
 * RFQ orders supports
 * - Expiration time
 * - Cancelation by order id
 * - Partial Fill (only once)
 *
 * See [OrderMixin](OrderMixin.md) for more details.
 */
// interface ILimitOrderProtocol is EIP712("1inch Limit Order Protocol", "4"), Ownable, Pausable, IOrderMixin {
interface ILimitOrderProtocol is IOrderMixin {
    /// @dev Returns the domain separator for the current chain (EIP-712)
    // solhint-disable-next-line func-name-mixedcase
    function DOMAIN_SEPARATOR() external view returns (bytes32);

    /**
     * @notice Pauses all the trading functionality in the contract.
     */
    function pause() external;

    /**
     * @notice Unpauses all the trading functionality in the contract.
     */
    function unpause() external;

    /**
     * @notice Low-level call function
     * @param value Value to send with the call
     * @param target Target address to call
     * @param data Data to send with the call
     * @return success Whether the call was successful
     */
    function lt(uint256 value, address target, bytes calldata data) external view returns (bool success);
}
