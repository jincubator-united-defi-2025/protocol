// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {ERC20} from "the-compact/lib/solady/src/tokens/ERC20.sol";
import {WETH} from "the-compact/lib/solady/src/tokens/WETH.sol";
import {IWETH} from "@1inch/solidity-utils/contracts/interfaces/IWETH.sol";
import {IPermit2} from "permit2/src/interfaces/IPermit2.sol";
// import {LimitOrderProtocol} from "@jincubator/limit-order-protocol/contracts/LimitOrderProtocol.sol";
import {ILimitOrderProtocol} from "src/interfaces/1inch/ILimitOrderProtocol.sol";
import {Permit2Deployer} from "test/helpers/Permit2.sol";
import {LimitOrderProtocolDeployer} from "test/helpers/LimitOrderProtocolManager.sol";
import {AggregatorMock} from "src/mocks/1inch/AggregatorMock.sol";
import {Dispatcher} from "src/Dispatcher.sol";
import {ChainLinkCalculator} from "src/ChainLinkCalculator.sol";
import {RebalancerInteraction} from "src/RebalancerInteraction.sol";
import {SwapExecutor} from "src/SwapExecutor.sol";
import {TychoSwapExecutor} from "src/TychoSwapExecutor.sol";
import {TychoRouterTestSetup} from "test/tycho/TychoRouterTestSetup.sol";

contract Deployers is Test, TychoRouterTestSetup {
    // Helpful Test Constants
    address constant ZERO_ADDRESS = address(0);

    // Global Variables
    uint256 public chainId = 1;
    IPermit2 permit2;
    MockERC20 public dai;
    MockERC20 public inch;
    MockERC20 public usdc;
    WETH public weth;
    AggregatorMock public daiOracle;
    AggregatorMock public inchOracle;
    ILimitOrderProtocol public swap;
    Dispatcher public dispatcher;
    ChainLinkCalculator public chainLinkCalculator;
    RebalancerInteraction public rebalancerInteraction;
    SwapExecutor public swapExecutor;
    TychoSwapExecutor public tychoSwapExecutor;

    // Test users - global variables
    address public makerAddr;
    uint256 public makerPK;
    address public takerAddr;
    uint256 public takerPK;
    address public treasurerAddr; //TODO: Create a Treasurer contract
    uint256 public treasurerPK;

    function setupUsers() internal {
        (makerAddr, makerPK) = makeAddrAndKey("makerAddr");
        (takerAddr, takerPK) = makeAddrAndKey("takerAddr");
        (treasurerAddr, treasurerPK) = makeAddrAndKey("treasurerAddr");
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

    function setUp() public {
        tychoSetUp();
        deployPermit2();
        deploySwapTokens();
        daiOracle = new AggregatorMock(1000000000000000000);
        inchOracle = new AggregatorMock(1000000000000000000);
        deployLimitOrderProtocol(address(weth));
        dispatcher = new Dispatcher();
        chainLinkCalculator = new ChainLinkCalculator();
        swapExecutor = new SwapExecutor(address(dispatcher));
        tychoSwapExecutor = new TychoSwapExecutor(address(dispatcher), payable(tychoRouter));
        setupUsers();
        rebalancerInteraction = new RebalancerInteraction(address(treasurerAddr));
    }
}
