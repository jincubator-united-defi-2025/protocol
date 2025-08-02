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

## Implementation Approach

    1. TychoFillPredicate.sol (Predicate): copied from OracleCalculator.sol
    2. TychoFillInteraction.sol : copied from RebalancerInteraction.sol
    3. TychoResolver.sol: Copied from ResolverCrossChain.sol and Dispatcher.sol
    4. Tests copied from RebalancerInteraction.t.sol and enhanced with
       1. Creation of Swap (MakerTokens to TakerTokens) similar to
       2. Call of Fill Contract passing
          1. target: TychoResolver address
          2. interaction: SolverPayload
       3. Checking of Treasurer Balances after swap is executed

## Flow

### Interactions

Interactions are callbacks that enable the execution of arbitrary code, which is provided by the maker’s order or taker’s fill execution.

The order execution logic includes several steps that also involve interaction calls:

1. Validate the order
2. **Call the maker's pre-interaction**
3. Transfer the maker's asset to the taker
4. **Call the taker's interaction**
5. Transfer the taker's asset to the maker
6. **Call the maker's post-interaction**
7. Emit the OrderFilled event

Calls are executed in the context of the limit order protocol. The target contract should implement the `IPreInteraction` or `IPostInteraction` interfaces for the maker's pre- and post-interactions and the `ITakerInteraction` interface for the taker's interaction. These interfaces declare the single callback function for maker and taker interactions, respectively.

Here is how the maker’s pre- & post- interactions and the taker’s interaction are defined in the interfaces:

```solidity
//Maker's pre-interaction
function preInteraction(
        IOrderMixin.Order calldata order,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external;

//Maker's post-interaction
function postInteraction(
        IOrderMixin.Order calldata order,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external;

//Taker's interaction
function takerInteraction(
        IOrderMixin.Order calldata order,
        bytes32 orderHash,
        address taker,
        uint256 makingAmount,
        uint256 takingAmount,
        uint256 remainingMakingAmount,
        bytes calldata extraData
    ) external returns(uint256 offeredTakingAmount);
```

- Resolver Contract executes calls to Tycho Dispatcher or Router
- Three functions
  - preInteraction: used in OracleCalculator (to ensure price before swap)
  - takerInteraction used in SwapExecutor to Execute Swap by Taker
  - postInteraction used in Rebalancer to Send Funds to Treasury

### Design Questions

1. **Interface Compatibility**:

   - How will the TychoResolver interface be defined to ensure compatibility with the LimitOrderProtocol bytecode deployment approach?
   - Should we create a custom interface for TychoResolver or use the concrete type like the working project?

2. **Predicate Logic**:

   - What predicate logic will TychoFill.sol use? Will it be similar to OracleCalculator.sol with price comparisons?
   - How will the predicate determine when a solve is profitable vs. when it should execute?

3. **Solver Payload Structure**:

   - What data structure will the SolverPayload contain? Will it include target addresses, amounts, and execution parameters?
   - How will the payload be encoded/decoded between the Solver Service and TychoResolver?

4. **Treasury Integration**:

   - How will excess tokens be calculated and transferred to Treasury?
   - What mechanism will prevent MEV attacks on the treasury transfers?

5. **Error Handling**:

   - How will failed solves be handled? Will orders be cancelled or retried?
   - What happens if the TychoResolver execution fails during the order fill?

6. **Gas Optimization**:

   - How will the solver service optimize gas costs across multiple orders?
   - Will batch processing be implemented for multiple orders?

7. **Oracle Integration**:

   - Will TychoFill use the same Chainlink oracle approach as OracleCalculator ?
   - How will price feeds be validated and updated?

8. **Cross-Chain Considerations**:
   - How will the ResolverCrossChain functionality be integrated with Tycho Dispatcher?
   - What bridge mechanisms will be used for cross-chain swaps?

### Implementation Plan

1. **Phase 1: Core Contract Development**

   - Create `TychoFill.sol` based on `OracleCalculator.sol`

     - Implement predicate logic for profitable solve detection
     - Add Tycho-specific price calculation methods
     - Ensure interface compatibility with LimitOrderProtocol

   - Create `TychoFillInteraction.sol` based on `RebalancerInteraction.sol`
     - Implement post-interaction logic for treasury transfers
     - Add balance validation and excess token calculation
     - Integrate with TychoResolver for swap execution

2. **Phase 2: Resolver Contract Development**

   - Create `TychoResolver.sol` combining ResolverCrossChain and Dispatcher functionality
     - Implement swap execution using maker tokens
     - Add taker token provision for relayer
     - Integrate treasury transfer logic
     - Ensure proper error handling and revert conditions

3. **Phase 3: Testing Framework**

   - Create comprehensive test suite based on `RebalancerInteraction.t.sol`
     - Test order creation with Tycho-specific predicates
     - Test solver payload encoding/decoding
     - Test treasury balance validation
     - Test cross-chain swap scenarios
     - Test error conditions and edge cases

4. **Phase 4: Integration Testing**

   - Test end-to-end flow from order creation to execution
   - Validate predicate execution with bytecode deployment
   - Test solver service integration with Tycho-indexer
   - Verify treasury transfers and balance calculations

5. **Phase 5: Optimization and Security**

   - Implement gas optimization strategies
   - Add comprehensive error handling
   - Implement MEV protection mechanisms
   - Add monitoring and logging capabilities

6. **Phase 6: Deployment and Monitoring**
   - Deploy contracts with proper bytecode generation
   - Set up monitoring for solver service
   - Implement alerting for failed solves
   - Add analytics for treasury performance
