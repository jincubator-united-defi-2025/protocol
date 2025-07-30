// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {Test, console2} from "forge-std/Test.sol";
import {ChainlinkCalculator} from "src/ChainlinkCalculator.sol";

contract Deployers is Test {
    // Helpful Test Constants

    // Global Variables
    ChainlinkCalculator public chainLinkCalculator;

    function deployArtifacts() internal {
        chainLinkCalculator = new ChainlinkCalculator();
    }
}
