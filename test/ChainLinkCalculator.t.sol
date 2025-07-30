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

    function test_eth_to_dai_chainlink_order() public {
        // chainlink rate is 1 eth = 4000 dai

        // function test_Increment() public {
        //     counter.increment();
        //     assertEq(counter.number(), 1);
        // }

        // function testFuzz_SetNumber(uint256 x) public {
        //     counter.setNumber(x);
        //     assertEq(counter.number(), x);
        // }
    }
}
