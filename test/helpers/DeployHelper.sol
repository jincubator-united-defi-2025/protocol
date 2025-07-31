//SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

library DeployHelper {
    function create(bytes memory initcode) internal returns (address deployed) {
        bytes memory _initcode = initcode;

        assembly ("memory-safe") {
            let ptr := add(_initcode, 32)
            let length := mload(_initcode)

            deployed := create(0, ptr, length)

            if iszero(deployed) {
                let errPtr := mload(0x40)
                let errLen := returndatasize()
                returndatacopy(errPtr, 0, errLen)
                revert(errPtr, errLen)
            }
        }
    }

    function create2(bytes memory initcode, bytes32 salt) internal returns (address deployed) {
        bytes memory _initcode = initcode; // lift stack variables
        bytes32 _salt = salt;

        assembly ("memory-safe") {
            let ptr := add(_initcode, 32)
            let length := mload(_initcode)

            deployed := create2(0, ptr, length, _salt)

            if iszero(deployed) {
                let errPtr := mload(0x40)
                let errLen := returndatasize()
                returndatacopy(errPtr, 0, errLen)
                revert(errPtr, errLen)
            }
        }
    }

    function create2(bytes memory initcode) internal returns (address) {
        return create2(initcode, 0x00);
    }
}
