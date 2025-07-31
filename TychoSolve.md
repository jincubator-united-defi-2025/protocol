# Tycho Fill (Solve)

## Actors

1. Maker
   1. Creates orders specifying the spread price they are looking for (currently using chainlink Oracle)
2. Solver Service
   1. Monitors 1inch Intents created
   2. Monitors Liquidity Positions on Chain using Tycho-indexer
   3. Simulates Solves for Orders (to see if profitable)
   4. Calls Resolver Contract to execute the Swap
      1. Solver Payload - encoded to call TychoResolver a modified version of Tycho Execution
   5. Calls Order Fill passing
      1. target: TychoResolver address
      2. interaction: SolverPayload
3. Resolver Contract (modified version combining ResolverCrossChain and Tycho Dispatcher)
   1. Called by LimitOrderProtocol as part of Order.fill
   2. Executes swap using Makers Tokens
   3. Provides TakerToken to Relayer to pass back to Taker
   4. Transfers excess maker (or taker) tokens to Treasury

## Implementation

    1. TychoFill.sol (Predicate): copied from ChainLinkCalculator.sol
    2. TychoFillInteraction.sol : copied from RebalancerInteraction.sol
    3. TychoResolver.sol: Copied from ResolverCrossChain.sol and Dispatcher.sol
    4. Tests copied from RebalancerInteraction.t.sol and enhanced with
       1. Creation of Swap (MakerTokens to TakerTokens) similar to
       2. Call of Fill Contract passing
          1. target: TychoResolver address
          2. interaction: SolverPayload
       3. Checking of Treasurer Balances after swap is executed

## Flow

- Resolver Contract executes calls to Tycho Dispatcher
- Need to pass SolverPayload and Resolver Address when calling fill
  - uses `buildTakerTraits`
    ```solidity
        function buildTakerTraits(
        bool makingAmount,
        bool unwrapWeth,
        bool skipMakerPermitFlag,
        bool usePermit2,
        bytes memory target, //This is the address of the Resolver
        bytes memory extension,
        bytes memory interaction, //This is where the solverPayload goes to execute the swap
        uint256 threshold
    ```
