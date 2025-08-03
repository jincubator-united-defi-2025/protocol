# Protocol

## Overview

This protocol implements four key enhancements to the [1inch Limit Order Protocol](https://github.com/1inch/limit-order-protocol):

1. **Enhanced Swap Execution**: [TychoSwapExecutor.sol](./src/TychoSwapExecutor.sol) integrates [Tycho Execution](https://github.com/propeller-heads/tycho-execution) to enable complex swaps across multiple DEXs without upfront liquidity
2. **Stop Loss and Profit Taking Orders**: [OracleIntegration.sol](./src/OracleCalculator.sol) Oracle-based (starting with chainlink) pricing calculator for advanced order strategies
3. **Treasury Management**: [RebalancerInteraction.sol](./src/RebalancerInteraction.sol) enables makers and takers to immediately balance their funds to a treasury (and moving forward more advanced asset management strategies).
4. **ERC-6909 Resource Locking**: [CompactInteraction.sol](./src/CompactInteraction.sol) integrates the [1inch Limit Order Protocol](https://github.com/1inch/limit-order-protocol) with [The Compact](https://github.com/uniswap/the-compact) for [ERC-6909](https://eips.ethereum.org/EIPS/eip-6909) support and moving forward integration with additional cross chain intent standards such as [ERC-7683](https://www.erc7683.org/) leveraging [Mandates and Solver Payloads](https://www.jincubator.com/research/solving/protocol) and [Advanced Resource Locking](https://www.jincubator.com/research/solving/resources).

## Architecture

### Core Components

- **Compact**: ERC-6909 enabled Chainlink calculator for price discovery
- **ResourceManager**: Manages resource locks for ERC-6909 integration
- **TychoSwapExecutor**: Executes complex swaps using Tycho Execution
- **CompactInteraction**: Post-interaction handler for resource allocation
- **RebalancerInteraction**: Treasury management and portfolio rebalancing
- **OracleCalculator**: Price oracle integration for advanced order strategies

### Key Features

- **Resource Locking**: ERC-6909 compliant resource management
- **Multi-DEX Execution**: Cross-platform swap execution via Tycho
- **Advanced Order Types**: Stop-loss and take-profit orders
- **Treasury Management**: Automated portfolio rebalancing
- **Oracle Integration**: Chainlink price feeds for accurate pricing

### Key Technology Enhancements

- Solidity based tests including a migration from `OrderUtils.js` to solidity based [OrderUtils](./test/utils/orderUtils/README_OrderUtils.md)
- Solidity `^0.8.30` compatibility provided by creating an interface [ILimitOrderProtocol.sol](./src/interfaces/1inch/ILimitOrderProtocol.sol) and introducing [LimitOrderProtocolManager](./test/helpers/LimitOrderProtocolManager.sol) for testing.

## Quick Start

### Prerequisites

- Foundry (latest version)
- Node.js 18+
- Git

### Installation

```bash
git clone <repository-url>
cd protocol
forge install
forge build
```

### Testing

```bash
forge test
```

### Development

```bash
anvil
forge script script/Deploy.s.sol --rpc-url http://localhost:8545
```

## Documentation

Comprehensive documentation is available in the [docs](./docs/) folder:

- [API Reference](./docs/api/README.md) - Contract interfaces and function documentation
- [Integration Guide](./docs/integration/README.md) - How to integrate with the protocol
- [Security](./docs/security/README.md) - Security considerations and best practices
- [Development](./docs/development/README.md) - Development setup and workflow

## Development

### Build

```bash
forge build
```

### Test

```bash
forge test
```

### Format

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

### Anvil

```bash
anvil
```

### Deploy

```bash
forge script script/Deploy.s.sol --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```bash
cast <subcommand>
```

### Help

```bash
forge --help
anvil --help
cast --help
```

## Technical References

### Core Protocols

- **[1inch Limit Order Protocol](https://github.com/1inch/limit-order-protocol)**: Base limit order protocol with extreme flexibility and high gas efficiency
- **[The Compact](https://github.com/uniswap/the-compact)**: ERC-6909 resource locking mechanism for voluntary formation of reusable resource locks
- **[Tycho Execution](https://github.com/propeller-heads/tycho-execution)**: Multi-DEX execution framework for complex swap routing

### Standards and Specifications

- **[ERC-6909](https://eips.ethereum.org/EIPS/eip-6909)**: Multi-token standard for resource management
- **[EIP-712](https://eips.ethereum.org/EIPS/eip-712)**: Typed structured data hashing and signing
- **[Chainlink Price Feeds](https://docs.chain.link/data-feeds)**: Decentralized price oracle network

### Development Tools

- **[Foundry](https://getfoundry.sh/)**: Fast, portable and modular toolkit for Ethereum application development
- **[Slither](https://github.com/crytic/slither)**: Static analysis framework for Solidity
- **[Mythril](https://github.com/ConsenSys/mythril)**: Security analysis tool for Ethereum smart contracts
- **[Echidna](https://github.com/crytic/echidna)**: Fuzzing framework for Ethereum smart contracts

### Security and Auditing

- **[Consensys Diligence](https://consensys.net/diligence/)**: Smart contract security services
- **[Trail of Bits](https://www.trailofbits.com/)**: Security research and consulting
- **[OpenZeppelin](https://openzeppelin.com/)**: Smart contract security library and tools
- **[Quantstamp](https://quantstamp.com/)**: Blockchain security company

### Oracle and Price Discovery

- **[Chainlink](https://chain.link/)**: Decentralized oracle network
- **[Pyth Network](https://pyth.network/)**: Cross-chain price oracle
- **[Redstone](https://redstone.finance/)**: Modular oracle for DeFi protocols

### Cross-Chain and Interoperability

- **[1inch Fusion](https://1inch.io/fusion/)**: Cross-chain atomic swap protocol
- **[NEAR Protocol](https://near.org/)**: Scalable blockchain platform
- **[Fusion+](https://github.com/1inch/fusion-plus)**: Enhanced cross-chain protocol

### DeFi Protocols and Standards

- **[Uniswap](https://uniswap.org/)**: Decentralized exchange protocol
- **[OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)**: Secure smart contract library
- **[SafeERC20](https://docs.openzeppelin.com/contracts/api/token/erc20#SafeERC20)**: Safe ERC20 operations

### Testing and Quality Assurance

- **[Forge Standard Library](https://github.com/foundry-rs/forge-std)**: Standard library for Foundry
- **[Hardhat](https://hardhat.org/)**: Ethereum development environment
- **[Tenderly](https://tenderly.co/)**: Blockchain development platform

### Documentation and Learning

- **[Solidity Docs](https://docs.soliditylang.org/)**: Official Solidity documentation
- **[Ethereum Docs](https://ethereum.org/en/developers/docs/)**: Ethereum developer documentation
- **[OpenZeppelin Docs](https://docs.openzeppelin.com/)**: OpenZeppelin documentation

### Community and Support

- **[Ethereum Stack Exchange](https://ethereum.stackexchange.com/)**: Q&A for Ethereum developers
- **[Solidity Forum](https://forum.soliditylang.org/)**: Solidity language discussions
- **[OpenZeppelin Forum](https://forum.openzeppelin.com/)**: OpenZeppelin community

### Monitoring and Analytics

- **[Etherscan](https://etherscan.io/)**: Ethereum blockchain explorer
- **[Tenderly](https://tenderly.co/)**: Blockchain monitoring and debugging
- **[The Graph](https://thegraph.com/)**: Decentralized indexing protocol

### Deployment and Infrastructure

- **[Infura](https://infura.io/)**: Ethereum infrastructure provider
- **[Alchemy](https://www.alchemy.com/)**: Blockchain development platform
- **[QuickNode](https://www.quicknode.com/)**: Blockchain infrastructure provider
