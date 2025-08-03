# Protocol Documentation

## Overview

This protocol implements four key enhancements to the [1inch Limit Order Protocol](https://github.com/1inch/limit-order-protocol):

1. **Enhanced Swap Execution**: Integrates [Tycho Execution](https://github.com/propeller-heads/tycho-execution) to enable complex swaps across multiple DEXs
2. **Stop Loss and Profit Taking Orders**: Oracle-based pricing calculator for advanced order strategies
3. **Treasury Management**: Rebalancer interaction for portfolio management
4. **ERC-6909 Resource Locking**: Integration with [The Compact](https://github.com/uniswap/the-compact) for resource management

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

## Documentation Structure

### Design Documents

- [Initial Design](./design/InitialDESIGN.md) - Original design specifications
- [Resource Locking](./design/ResourceLocking.md) - ERC-6909 integration details
- [Oracle Integration](./design/OracleIntegration.md) - Price discovery mechanisms
- [Treasury Management](./design/Treasury.md) - Portfolio management features
- [TychoSwapExecutor](./design/TychoSwapExecutor.md) - Enhanced swap execution

### Technical Documentation

- [API Reference](./api/README.md) - Contract interfaces and function documentation
- [Integration Guide](./integration/README.md) - How to integrate with the protocol
- [Security](./security/README.md) - Security considerations and best practices

### Development

- [Getting Started](./development/README.md) - Development setup and workflow
- [Testing](./development/testing.md) - Test suite and testing strategies
- [Deployment](./development/deployment.md) - Deployment procedures

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

## Contributing

Please read our [Contributing Guidelines](./CONTRIBUTING.md) before submitting pull requests.

## License

MIT License - see [LICENSE](../LICENSE) for details.
