# Design Unite Defi 2025 Jincubator

## Overview

The protocol implements extensions to the 1inch limit-order-protocol. To enable ERC-6909 support, resource locking and enhanced price discovery. It also facilitates back running of swaps as part of Interaction Order Extensions.

Stretch Goals include enhance price discovery and NEAR Fusion+ integration.

## Design Questions

- Passing of [Extension Information](https://github.com/1inch/limit-order-protocol/blob/master/description.md#extensions-structure) when [building an order](https://github.com/1inch/limit-order-protocol/blob/master/description.md#how-to-build-an-order)
- Custom Limit Orders should not be posted to official Limit Order API. Does this mean just use scripting or should we build out our own API
- Relayer - contract or service
- Resolver - contract or service

### Limit Order Protocol Improvements

- Stop Loss and Take profit
  - Both basic and trailing SL/TP orders
  - [ChainLink Example](https://github.com/1inch/limit-order-protocol/blob/master/test/ChainLinkExample.js)
  - [Order Creation Logic to Populate Order Extension Information](https://github.com/1inch/limit-order-protocol/blob/master/description.md#order-extensions)
  - [Order Extensions](https://github.com/1inch/limit-order-protocol/blob/master/description.md) : [Extensions Code](https://github.com/1inch/limit-order-protocol/tree/master/contracts/extensions)
    - []
    - ERC-6909 extension similar to [ERC1155PROXY.sol](https://github.com/1inch/limit-order-protocol/blob/master/contracts/extensions/ERC1155Proxy.sol)
      - Resource Locking Functionality integrating with [the-compact](https://github.com/uniswap/the-compact)
    - Price Discovery
      - [ChainCalculator.sol](https://github.com/1inch/limit-order-protocol/blob/master/contracts/extensions/ChainlinkCalculator.sol): Reference Implementation see Price Discovery codebases below.
    - [Interactions](https://github.com/1inch/limit-order-protocol/blob/master/description.md#interactions): Interactions are callbacks that enable the execution of arbitrary code, which is provided by the maker’s order or taker’s fill execution.
      - ERC-6909 Settlement (including EIP-712 Signature Verification)
      - BackRunning Of Order

### Price Discovery Improvements

- Tycho Indexing: For Streaming of State Changes of DeFi Protocols
- Tycho Simulation: For Price Discovery
- Pyth Oracle Integration: For Price Discovery

### Fusion+ to Near Implementations (Stretch Goal)

- Relayer
- Resolver

## Components

-

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

### Documentation

- [Limit order protocol v4](https://github.com/1inch/limit-order-protocol/blob/master/description.md): Technical documentation for 1nch Limit Order Protocol including Order Extensions
- [1inch OrderBook API](https://portal.1inch.dev/documentation/apis/orderbook/introduction): 1inch Orderbook API is using the 1inch Limit Order Protocol, which is a set of smart contracts that can work on any EVM-based blockchains. Key features of the protocol are extreme flexibility and high gas efficiency.
- [1inch Fusion+ (intent-based atomic cross-chain swaps)](https://portal.1inch.dev/documentation/apis/swap/fusion-plus/introduction): built on the cross-chain-sdk

### Prize Streams

#### 🍾 Expand Limit Order Protocol ⸺ $65,000

1inch Limit Order Protocol is an onchain orderbook that can be extended to do much more. Build advanced strategies and hooks for the 1inch Limit Order Protocol like options, concentrated liquidity, TWAP swaps, etc.

Qualification Requirements:

- Onchain execution of strategy should be presented during the final demo
- Custom Limit Orders should not be posted to official Limit Order API
- Consistent commit history should be in the GitHub project. No low or single-commit entries allowed!

Stretch goals (not hard requirements):

- UI

#### 🌐 Extend Fusion+ to Near ⸺ $32,000

Build a novel extension for 1inch Cross-chain Swap (Fusion+) that enables swaps between Ethereum and Near.

Qualification Requirements:

- Preserve hashlock and timelock functionality for the non-EVM implementation
- Swap functionality should be bidirectional (swaps should be possible to and from Ethereum)
- Onchain (mainnet or testnet) execution of token transfers should be presented during the final demo

Stretch goals (not hard requirements):

- UI
- Enable partial fills
- Relayer and resolver
