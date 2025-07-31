# Design Unite Defi 2025 Jincubator

## Overview

The protocol implements extensions to the 1inch limit-order-protocol. To enable ERC-6909 support, resource locking and enhanced price discovery. It also facilitates back running of swaps as part of Interaction Order Extensions.

Stretch Goals include enhance price discovery and NEAR Fusion+ integration.

Technical documentation can be found on [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/jincubator-united-defi-2025/protocol)

## Design

For Unite Defi we are working on 3 separate but compatible streams.

### Limit Order Protocol

Here are the Key Features Under Consideration

- Price Discovery: Integrating Pyth Oracles such as Redstone to improve Price Discovery
- Stop Loss Orders: Implementing a Holistic Advanced Limit Order (HALO) using a Predicate which passes price criteria for execution
- ERC-6909 Support: We implement the ability to Lock Resources in an ERC-6909 compatible Extension
- No Liquidity Solving (Same Chain Only): Provide the ability for Resolvers to use the Locked Resources as part of the Solve
- Portfolio Management: We implement the ability to rebalance the maker or takers assets during the fill with an Interaction

### Near Fusion+

We Integrate Near and 1inch Fusion (see [near-fusion-plus](https://github.com/jincubator-united-defi-2025/near-fusion-plus))

- Near Contracts for hash lock and time lock functionality
- Swap Functionality between Ethereum and Near via Fusion Plus
- Demonstration of bidirectional token transfers between Ethereum and NEAR

### Near Solver Built with NEAR's Shade Agent Framework

A decentralized solver which works with 1inch Fusion+

1. **Smart Contracts**

   - `solver-registry`: Support liquidity pools creation. Manage registration and verification of TEE solvers for each liquidity pool.
   - `intents-vault`: The vault contract that manage the pool's asset within NEAR Intents.

2. **Solver Management Server**
   - A Rust based server that manages the lifecycle of TEE solvers
   - Handles solver deployment and monitoring for each liquidity pool

### Design Questions

- Custom Limit Orders should not be posted to official Limit Order API. [Answered](https://discord.com/channels/554623348622098432/1385673870941618348/1399699600515796992)
  - Scripting is fine for the Hackathon
  - We don't need to build out our own API

## Implementation Details

### Limit Order Protocol Improvements

- Stop Loss and Take profit
  - Both basic and trailing SL/TP orders
  - [ChainLink Example](https://github.com/1inch/limit-order-protocol/blob/master/test/ChainLinkExample.js)
  - [Order Creation Logic to Populate Order Extension Information](https://github.com/1inch/limit-order-protocol/blob/master/description.md#order-extensions)
  - [Order Extensions](https://github.com/1inch/limit-order-protocol/blob/master/description.md) : [Extensions Code](https://github.com/1inch/limit-order-protocol/tree/master/contracts/extensions)
    - ERC-6909 extension similar to [ERC1155PROXY.sol](https://github.com/1inch/limit-order-protocol/blob/master/contracts/extensions/ERC1155Proxy.sol)
      - Resource Locking Functionality integrating with [the-compact](https://github.com/uniswap/the-compact)
    - Price Discovery
      - [ChainCalculator.sol](https://github.com/1inch/limit-order-protocol/blob/master/contracts/extensions/ChainlinkCalculator.sol): Reference Implementation see Price Discovery codebases below.
    - [Interactions](https://github.com/1inch/limit-order-protocol/blob/master/description.md#interactions): Interactions are callbacks that enable the execution of arbitrary code, which is provided by the maker’s order or taker’s fill execution.
      - ERC-6909 Settlement (including EIP-712 Signature Verification)
      - BackRunning Of Order

Note: For demonstration purposes we can use order and fulfillment via local scripts. It is recommended to use [Tenderly Virtual Testnets](https://tenderly.co/virtual-testnets) so that judges have visibility. (This is preferred over anvil).

### Price Discovery Improvements

- Tycho Indexing: For Streaming of State Changes of DeFi Protocols
- Tycho Simulation: For Price Discovery
- Pyth Oracle Integration: For Price Discovery

### Fusion+ to Near Implementations (Stretch Goal)

- Relayer
- [Resolver](https://github.com/1inch/cross-chain-resolver-example/blob/master/contracts/src/Resolver.sol)
  - [Fusion Resolver Example](https://github.com/1inch/fusion-resolver-example/blob/main/contracts/ResolverExample.sol) - don't need this one

### Near Solver Built with NEAR's Shade Agent Framework

### Components

- [Jincubator Near Fusion+](https://github.com/jincubator-united-defi-2025/near-fusion-plus): NEAR Fusion+ Smart contracts

### Foundational (git modules)

- [limit-order-protocol](https://github.com/1inch/limit-order-protocol): 1inch Limit Order Protocol Smart Contract. Key features of the protocol are extreme flexibility and high gas efficiency
- [https://github.com/1inch/cross-chain-swap](https://github.com/1inch/cross-chain-swap): 1inch Network Fusion Atomic Swaps
- [the-compact](https://github.com/uniswap/the-compact) : The Compact 🤝 ERC-6909 Resource Locking Mechanism an ownerless ERC6909 contract that facilitates the voluntary formation (and, if necessary, eventual dissolution) of reusable resource locks.
- [Tycho Execution](https://github.com/propeller-heads/tycho-execution): Tycho Execution makes it easy to trade on different DEXs by handling the complex encoding for you. Instead of creating custom code for each DEX, you get a simple, ready-to-use tool that generates the necessary data to execute trades. It's designed to be safe, straightforward, and quick to set up, so anyone can start trading without extra effort.

## References

### Code

- [Limit Order SDK](https://github.com/1inch/limit-order-sdk):1inch Limit Order Protocol v4 SDK
- [Cross Chain Resolver Example](https://github.com/1inch/cross-chain-resolver-example): An example Cross Chain Resolver
- [Cross Chain SDK](https://github.com/1inch/cross-chain-sdk): SDK for creating atomic swaps through 1inch
- [p2p network (Relayer)](https://github.com/1inch/p2p-network): consists of several key components that work in concert to provide a decentralized service layer for Web3 applications.
  - [Relayer Node](https://github.com/1inch/p2p-network/blob/dev/cmd/relayer/README.md): The Relayer Node enables clients to interact with the decentralized network. It utilizes HTTP for SDP signaling and WebRTC data channels on the front-facing API while communicating with Resolver nodes through gRPC requests.
  - [Resolver](https://github.com/1inch/p2p-network/blob/dev/cmd/resolver/README.md): Resolver application serves as a lowest-level endpoint in the p2p-network architecture. It processes requests received from the relayer and forwards them to the API(s) that it wraps.
  - [LP Hub BackRunner](https://github.com/itskillian/hookathon-hooks/blob/02cedce8376943267be9582094ec544eede78e4e/src/ArbPinHook.sol#L205)

Price Discovery

- [ChainLinkCalculator](https://github.com/1inch/limit-order-protocol/blob/master/contracts/extensions/ChainlinkCalculator.sol)
- [Tycho Simulation TokenProxy](https://github.com/propeller-heads/tycho-simulation/blob/main/token-proxy/src/TokenProxy.sol)
- [SkySwap Oracle Manager](https://github.com/SkyYap/SkySwap/blob/main/src/OracleManager.sol)
- [Yolo Protocol Oracle](https://github.com/YOLO-Protocol/yolo-core-v0/tree/main/src/oracles)
- [Euler Price Oracle](https://github.com/euler-xyz/euler-price-oracle): See adapters below

| Adapter                                                             | Type     | Method | Supported Pairs         | Parameters                                   |
| ------------------------------------------------------------------- | -------- | ------ | ----------------------- | -------------------------------------------- |
| [ChainlinkOracle](src/adapter/chainlink/ChainlinkOracle.sol)        | External | Push   | Provider feeds          | feed, max staleness                          |
| [ChronicleOracle](src/adapter/chainlink/ChronicleOracle.sol)        | External | Push   | Provider feeds          | feed, max staleness                          |
| [PythOracle](src/adapter/pyth/PythOracle.sol)                       | External | Pull   | Provider feeds          | feed, max staleness, max confidence interval |
| [RedstoneCoreOracle](src/adapter/redstone/RedstoneCoreOracle.sol)   | External | Pull   | Provider feeds          | feed, max staleness, cache ttl               |
| [LidoOracle](src/adapter/lido/LidoOracle.sol)                       | Onchain  | Rate   | wstETH/stETH            | -                                            |
| [LidoFundamentalOracle](src/adapter/lido/LidoFundamentalOracle.sol) | Onchain  | Rate   | wstETH/ETH              | -                                            |
| [UniswapV3Oracle](src/adapter/uniswap/UniswapV3Oracle.sol)          | Onchain  | TWAP   | UniV3 pools             | fee, twap window                             |
| [PendleOracle](src/adapter/pendle/PendleOracle.sol)                 | Onchain  | TWAP   | Pendle markets          | pendle market, twap window                   |
| [RateProviderOracle](src/adapter/rate/RateProviderOracle.sol)       | Onchain  | Rate   | Balancer rate providers | rate provider                                |
| [FixedRateOracle](src/adapter/fixed/FixedRateOracle.sol)            | Onchain  | Rate   | Any                     | rate                                         |

NEAR Integration

- [Jincubator Near Fusion+](https://github.com/jincubator-united-defi-2025/near-fusion-plus)
- [Cargo Near](https://github.com/near/cargo-near)
- [Donation Examples](https://github.com/near-examples/donation-examples)
- Frontend: `npx create-near-app@latest`
- Solver manager and deployer https://github.com/jincubator-united-defi-2025/tee-solver
- Solver https://github.com/jincubator-united-defi-2025/near-intents-tee-amm-solver
- [Near Intents](https://docs.near.org/chain-abstraction/intents/overview)
  - https://near-intents.org/

### Documentation

- [Limit order protocol v4](https://github.com/1inch/limit-order-protocol/blob/master/description.md): Technical documentation for 1nch Limit Order Protocol including Order Extensions
- [1inch OrderBook API](https://portal.1inch.dev/documentation/apis/orderbook/introduction): 1inch Orderbook API is using the 1inch Limit Order Protocol, which is a set of smart contracts that can work on any EVM-based blockchains. Key features of the protocol are extreme flexibility and high gas efficiency.
- [1inch Fusion+ (intent-based atomic cross-chain swaps)](https://portal.1inch.dev/documentation/apis/swap/fusion-plus/introduction): built on the cross-chain-sdk
- [1inch Cross-chain swaps - Fusion+ Tanner Moore](https://www.youtube.com/watch?v=EnHov0tCalU&t=860s)
- Passing of [Extension Information](https://github.com/1inch/limit-order-protocol/blob/master/description.md#extensions-structure) when [building an order](https://github.com/1inch/limit-order-protocol/blob/master/description.md#how-to-build-an-order)

NEAR Integration

- [Near Smart Contracts](https://dev.near.org/documentation/smart-contracts/what-is)
- [NEAR Rust SDK Documentation](https://docs.near.org/sdk/rust/introduction)
- [NEAR Market Maker](https://docs.near-intents.org/near-intents/market-makers): We are adding Fusion as a Market Maker on NEAR

### Prize Streams

#### 🍾 Expand Limit Order Protocol ⸺ $65,000 ($10,000 x 3, $7,000 x 3, $3500 x 4 )

1inch Limit Order Protocol is an onchain orderbook that can be extended to do much more. Build advanced strategies and hooks for the 1inch Limit Order Protocol like options, concentrated liquidity, TWAP swaps, etc.

Qualification Requirements:

- Onchain execution of strategy should be presented during the final demo
- Custom Limit Orders should not be posted to official Limit Order API
- Consistent commit history should be in the GitHub project. No low or single-commit entries allowed!

Stretch goals (not hard requirements):

- UI

#### 🌐 Extend Fusion+ to Near ⸺ $32,000 ($12,000, $7,500, $5,000, 4,000, $3500)

Build a novel extension for 1inch Cross-chain Swap (Fusion+) that enables swaps between Ethereum and Near.

Qualification Requirements:

- Preserve hashlock and timelock functionality for the non-EVM implementation
- Swap functionality should be bidirectional (swaps should be possible to and from Ethereum)
- Onchain (mainnet or testnet) execution of token transfers should be presented during the final demo

Stretch goals (not hard requirements):

- UI
- Enable partial fills
- Relayer and resolver

#### 🔗 Best 1inch Fusion+ Solver Built with NEAR's Shade Agent Framework ⸺ $10,000 (2x $5000)

Build a decentralized solver that integrates with 1inch Fusion+ for cross-chain swaps using NEAR's Shade Agent Framework and Trusted Execution Environment.

There is an existing decentralized NEAR Intents solver here:

- Solver manager and deployer https://github.com/Near-One/tee-solver/
- Solver https://github.com/think-in-universe/near-intents-tee-amm-solver/tree/feat/tee-solver

It listens for intents, generates quotes, and submits them for execution on NEAR Intents. Your task is to build a similar system that works with 1inch Fusion+ and its meta-order format. Make sure the solver is created using NEAR’s Shade Agent Framework and is deployed in a Trusted Execution Environment.

The Shade Agent Framework allows you to build decentralized solvers, enabling users to delegate and provide liquidity to solvers without requiring trust that the solver will behave correctly or having to set up their own solver.

Qualification Requirements:

Your solver must listen for quote requests (mocked or real), produce valid 1inch Fusion meta-orders using NEAR's Chain Signatures, include comprehensive documentation with setup instructions, and demonstrate end-to-end functionality. Bonus points for modular architecture that extends to other protocols.
