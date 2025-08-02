# protocol

## Overview

This Protocol implements four enhancements to [1inch Limit Order Protocol](https://github.com/1inch/limit-order-protocol)

1. Enhanced Swap Execution: [TychoSwapExecutor.sol](./src/TychoSwapExecutor.sol) Integrates [Tycho Execution](https://github.com/jincubator/tycho-execution) to enable takers to execute complex swaps and routes on multiple platforms without providing up front liquidity.
2. Stop Loss and Profit Taking Orders: Integrates Price oracles with an oracle based Pricing Calculator to facilitate advanced order Stategies
3. Treasury Management: A Rebalanc

### Enhanced Swap Execution

### Stop Loss and

Technical documentation can be found on [![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/jincubator-united-defi-2025/protocol)

## Development

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Counter.s.sol:CounterScript --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
