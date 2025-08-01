// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {ChainlinkCalculator} from "src/ChainlinkCalculator.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {ERC20} from "the-compact/lib/solady/src/tokens/ERC20.sol";
import {WETH} from "the-compact/lib/solady/src/tokens/WETH.sol";
import {IWETH} from "@1inch/solidity-utils/contracts/interfaces/IWETH.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
// import {LimitOrderProtocol} from "@jincubator/limit-order-protocol/contracts/LimitOrderProtocol.sol";
import {ILimitOrderProtocol} from "src/interfaces/1inch/ILimitOrderProtocol.sol";
import {Permit2Deployer} from "test/helpers/Permit2.sol";
import {LimitOrderProtocolDeployer} from "test/helpers/LimitOrderProtocolManager.sol";
import {ChainlinkCalculator} from "src/ChainlinkCalculator.sol";
import {AggregatorMock} from "src/mocks/1inch/AggregatorMock.sol";

contract Deployers is Test {
    // Helpful Test Constants
    address constant ZERO_ADDRESS = address(0);

    // Global Variables
    IPermit2 permit2;
    ChainlinkCalculator public chainLinkCalculator;
    MockERC20 public dai;
    WETH public weth;
    MockERC20 public inch;
    MockERC20 public usdc;
    ILimitOrderProtocol public swap;
    ChainlinkCalculator public chainlinkCalculator;
    AggregatorMock public daiOracle;
    AggregatorMock public inchOracle;
    uint256 public chainId = 1;

    // Test users - global variables
    address public makerAddr;
    uint256 public makerPK;
    address public takerAddr;
    uint256 public takerPK;

    function setupUsers() internal {
        (makerAddr, makerPK) = makeAddrAndKey("makerAddr");
        (takerAddr, takerPK) = makeAddrAndKey("takerAddr");
        // Mint tokens to test addresses
        dai.mint(takerAddr, 1_000_000 ether);
        dai.mint(makerAddr, 1_000_000 ether);
        inch.mint(takerAddr, 1_000_000 ether);
        inch.mint(makerAddr, 1_000_000 ether);

        // Setup WETH deposits
        vm.deal(makerAddr, 100 ether);
        vm.deal(takerAddr, 100 ether);
        vm.prank(makerAddr);
        weth.deposit{value: 100 ether}();
        vm.prank(takerAddr);
        weth.deposit{value: 100 ether}();

        // Approve tokens for swap contract
        vm.prank(makerAddr);
        dai.approve(address(swap), 1_000_000 ether);
        vm.prank(makerAddr);
        weth.approve(address(swap), 1_000_000 ether);
        vm.prank(makerAddr);
        inch.approve(address(swap), 1_000_000 ether);

        vm.prank(takerAddr);
        dai.approve(address(swap), 1_000_000 ether);
        vm.prank(takerAddr);
        weth.approve(address(swap), 1_000_000 ether);
        vm.prank(takerAddr);
        inch.approve(address(swap), 1_000_000 ether);
    }

    function deploySwapTokens() internal {
        dai = new MockERC20("Test Token", "TEST", 18);
        dai.mint(address(this), 10_000_000 ether);
        weth = new WETH();
        inch = new MockERC20("1INCH", "1INCH", 18);
        inch.mint(address(this), 10_000_000 ether);
        usdc = new MockERC20("USDC", "USDC", 6);
        usdc.mint(address(this), 10_000_000 ether);
    }

    function deployPermit2() internal {
        address permit2Address = address(0x000000000022D473030F116dDEE9F6B43aC78BA3); // Same on all chains.

        if (permit2Address.code.length > 0) {
            // Permit2 is already deployed, no need to etch it.
        } else {
            address tempDeployAddress = address(Permit2Deployer.deploy());

            vm.etch(permit2Address, tempDeployAddress.code);
        }

        permit2 = IPermit2(permit2Address);
        vm.label(permit2Address, "Permit2");
    }

    function deployLimitOrderProtocol(address weth) internal {
        swap = ILimitOrderProtocol(address(LimitOrderProtocolDeployer.deploy(weth, address(permit2))));

        vm.label(address(swap), "LimitOrderProtocol");
    }

    function deployArtifacts() internal {
        deployPermit2();
        chainLinkCalculator = new ChainlinkCalculator();
        deploySwapTokens();
        // swap = new LimitOrderProtocol(IWETH(address(weth)));
        chainlinkCalculator = new ChainlinkCalculator();
        daiOracle = new AggregatorMock(1000000000000000000);
        inchOracle = new AggregatorMock(1000000000000000000);

        deployLimitOrderProtocol(address(weth));
        setupUsers();
    }
}
