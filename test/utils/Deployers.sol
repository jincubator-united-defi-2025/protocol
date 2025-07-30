// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ChainlinkCalculator} from "src/ChainlinkCalculator.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {ERC20} from "the-compact/lib/solady/src/tokens/ERC20.sol";
import {WETH} from "the-compact/lib/solady/src/tokens/WETH.sol";
import {IWETH} from "@1inch/solidity-utils/contracts/interfaces/IWETH.sol";
import {LimitOrderProtocol} from "@1inch/limit-order-protocol/contracts/LimitOrderProtocol.sol";
import {ChainlinkCalculator} from "src/ChainlinkCalculator.sol";
import {AggregatorMock} from "@1inch/limit-order-protocol/contracts/mocks/AggregatorMock.sol";

contract Deployers is Test {
    // Helpful Test Constants
    address constant ZERO_ADDRESS = address(0);

    // Global Variables
    ChainlinkCalculator public chainLinkCalculator;
    MockERC20 public dai;
    WETH public weth;
    MockERC20 public inch;
    MockERC20 public usdc;
    LimitOrderProtocol public swap;
    ChainlinkCalculator public chainlinkCalculator;
    AggregatorMock public daiOracle;
    AggregatorMock public inchOracle;

    function deploySwapTokens() internal {
        dai = new MockERC20("Test Token", "TEST", 18);
        dai.mint(address(this), 10_000_000 ether);
        weth = new WETH();
        inch = new MockERC20("1INCH", "1INCH", 18);
        inch.mint(address(this), 10_000_000 ether);
        usdc = new MockERC20("USDC", "USDC", 6);
        usdc.mint(address(this), 10_000_000 ether);
    }

    function deployArtifacts() internal {
        chainLinkCalculator = new ChainlinkCalculator();
        deploySwapTokens();
        swap = new LimitOrderProtocol(IWETH(address(weth)));
        chainlinkCalculator = new ChainlinkCalculator();
        daiOracle = new AggregatorMock(1000000000000000000);
        inchOracle = new AggregatorMock(1000000000000000000);
    }
}
