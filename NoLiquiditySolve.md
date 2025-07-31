# NoLiquidity Solving

## Actors

1. Maker
2. Smart Maker
3. Taker
4. Smart Taker

## Price Feeds

1. Oracle: ChainLink Oracle giving price
2. PythOracle: Gives a slightly Different Price
3. Resolver: Off-chain service
   1. monitoring 1inch Orders
   2. finding best practices for swaps using Tycho Simulation
   3. Creates SolverPayloads for orders it wants to resolve
   4. Executes the swap
4. TychoSimulation: Finds best swap available
5. CEX API: Integrated Price Feed from Binance

## Order Flow

1. SmartMaker: Creates an order

   1. Approves Tokens to the ResourceManager
   2. Specifies an Arbiter (which is the ChainLinkCompact)
   3. Calls Swap Functionality
   4. ResourceManager
   5. takes tokens and creates a resource Lock
   6. creates a claim
   7. ChainLinkCompact(arbiter) -
      1. receives the Payload from the resolver
      2. takes the maker tokens from the claim
      3. executes the solver payload
      4. checks the taker amount is correct
         1. if not revert
   8. Relayer
      1. Transfers (taker)tokens to Order Maker
      2. Transfers excess (maker)tokens to Resolver

2. Resolver:
   1. Listens for all Orders (demo for a token pair)
   2. Calls Simulate on Each Block to find the best price for a token Pair
   3. If it finds a profitable execution
   4. Creates a Solver Payload (swapping the maker token and amount for the taker tokens amount)
   5.
