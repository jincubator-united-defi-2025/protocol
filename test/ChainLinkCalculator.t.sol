// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {ChainlinkCalculator} from "src/ChainlinkCalculator.sol";
import {Deployers} from "test/utils/Deployers.sol";

contract ChainLinkCalculatorTest is Test, Deployers {
    function setUp() public {
        deployArtifacts();
        // counter.setNumber(0);
    }

    // function test_Increment() public {
    //     counter.increment();
    //     assertEq(counter.number(), 1);
    // }

    // function testFuzz_SetNumber(uint256 x) public {
    //     counter.setNumber(x);
    //     assertEq(counter.number(), x);
    // }
}
