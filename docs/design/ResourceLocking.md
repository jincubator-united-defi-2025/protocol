# ERC-6909 Support

## Requirements

1. Read lib\the-compact\README.md (open in editor) to understand how the compact works
2. We are looking to create an end to end flow where
   1. We register a new contract ResourceManager.sol as a ResourceManager
   2. We Register ChainLinkCompactInteraction.sol as the Arbiter
   3. The Maker (the Swapper in compact terms signs permission for their tokens (or ETH) to be stored in the-compact as ERC-6909)
   4. ChainLinkCompact.sol checks that the we have a ResourceLock for the amount required.
   5. ChainLinkCompact then executes the trade using the same logic that was in ChainLinkCalculator and creates a resource lock for their (tokens/ETH)
   6. ChainLinkCompactInteraction is copied from RebalancerInteraction it takes the output tokens provided by the Taker and
   7. If they are >= TakerAmount then it calls the ResourceManager to lock the funds
   8. It then does the token transfer to the treasurer the same as it was done in the original RebalancerInteraction

## Design Questions

1. **Resource Manager Registration**: How should we register the LimitOrderProtocol as a ResourceManager in The Compact? Should it be a separate contract or integrated directly?

   1. Answer: We are registering it as a separate contract let's call it ResourceManager.sol and this contract will be called by ChainLinkCompact to lock the resources before calling the swap on LimitOrderProtocl

2. **Arbiter Implementation**: Should ChainLinkCompactInteraction.sol be a standalone arbiter or integrated with existing ChainLinkCalculator logic?

   1. Answer: It should be Standalone ChainLinkCalculator and RebalancerInteraction remain unchanged

3. **Token Locking Strategy**: Should makers lock their entire balance upfront or lock tokens dynamically when orders are matched?

   1. Answer: Initially Lock their whole balance

4. **Resource Lock Scope**: Should resource locks be chain-specific or multichain for cross-chain order execution?

   1. Answer: Chain-specific

5. **Allocator Selection**: Which allocator should we use for the resource locks? Should we create a custom allocator or use existing ones like Smallocator/Autocator?

   1. Answer: Create a custom Allocator based on Autocator(which is used for End User signing which is the Maker in our case)
   2. The logic for calling this should be in ChainLinkCompact.t.sol
   3. Moving forward we will also create a custom Smallocator used when smart contract call this

6. **EIP-712 Signature Structure**: How should we structure the EIP-712 signatures for the compact agreements? Should we include mandate data for additional conditions?

   1. Answer: For Phase 1 we do not need to add mandate data or Solver Payloads we will incorporate those in a later phase

7. **Fallback Mechanisms**: What should happen if the arbiter fails to process a claim? Should we implement emissary fallbacks?

   1. If an arbiter fails to process the claim the swap should revert

8. **Gas Optimization**: How can we optimize gas usage for the ERC-6909 integration, especially for batch operations?

   1. We will optimize gas in phase 2

9. **Error Handling**: How should we handle cases where resource locks are insufficient or expired?

   1. We revert the transaction with custom errors stating the reason for the failure

10. **Integration Points**: Should the ERC-6909 functionality be optional (opt-in) or mandatory for all orders?
    1. Optional set by a boolean ERC-6909 flag for now
    2. Later this may move to an enum with additional swap types

## Implementation

### Phase 1: Core Contract Development

1. **Create ResourceManager.sol** - New contract

   - Register as ResourceManager in The Compact
   - Handle resource lock creation and management for makers
   - Implement allocator integration for order validation
   - Called by ChainLinkCompact to lock resources before swap execution

2. **Create ChainLinkCompact.sol** - Copy from ChainLinkCalculator.sol

   - Add ERC-6909 flag for optional functionality
   - Integrate with The Compact for resource lock verification
   - Add ERC-6909 token validation before order execution
   - Call ResourceManager.sol to lock resources before LimitOrderProtocol execution
   - Implement custom error handling for insufficient/expired locks

3. **Create ChainLinkCompactInteraction.sol** - Copy from RebalancerInteraction.sol

   - Implement IArbiter interface for The Compact
   - Add resource lock creation for taker's output tokens
   - Maintain treasurer transfer functionality
   - Add EIP-712 signature verification for compact agreements
   - Revert entire transaction if arbiter fails to process claim

4. **Create Custom Allocator** - Based on Autocator
   - Implement IAllocator interface
   - Handle end-user (Maker) signing authorization
   - Add nonce management for compact claims
   - Implement claim authorization logic
   - Logic for calling this should be in ChainLinkCompact.t.sol

### Phase 2: Integration & Testing

5. **Compact Registration System**

   - Implement EIP-712 signature generation for makers (no mandate data for Phase 1)
   - Create compact registration functions
   - Add chain-specific resource lock scope
   - Implement upfront token locking strategy

6. **Testing Suite**
   - Unit tests for each contract
   - Integration tests for end-to-end flow
   - Test ERC-6909 flag functionality
   - Test custom error handling scenarios

### Phase 3: Advanced Features

7. **Gas Optimization**

   - Optimize gas usage for ERC-6909 integration
   - Implement batch operations optimization
   - Profile and optimize critical paths

8. **Enhanced Features**
   - Add mandate data structure for order conditions
   - Implement multichain support
   - Create custom Smallocator for smart contract calls
   - Add emissary fallback mechanisms
   - Implement enum for additional swap types beyond boolean flag

### Technical Architecture

**Core Flow:**

1. Maker deposits tokens into The Compact (creates ERC-6909 resource lock)
2. Maker signs EIP-712 compact agreement with arbiter (ChainLinkCompactInteraction)
3. Order is posted to LimitOrderProtocol with ERC-6909 extension
4. Taker fills order through ChainLinkCompact.sol
5. ChainLinkCompactInteraction processes claim:
   - Verifies resource lock availability
   - Executes trade using ChainLinkCalculator logic
   - Creates new resource lock for taker's output tokens
   - Transfers tokens to treasurer
   - Calls ResourceManager to lock funds

**Key Interfaces:**

- `ITheCompact` - For resource lock management
- `IAllocator` - For claim authorization
- `IArbiter` - For claim processing
- `IEmissary` - For fallback verification

**Data Structures:**

- `Compact` - EIP-712 payload for single resource lock
- `BatchCompact` - EIP-712 payload for multiple resource locks
- `Mandate` - Witness data for order conditions
- `Claim` - Claim payload for processing

### Future Test Enhancements

For ERC-6909 integration, additional test categories will be needed:

1. **ERC-6909 Resource Lock Tests**

   - Resource lock creation and validation
   - Insufficient lock handling
   - Lock expiration scenarios

2. **Compact Integration Tests**

   - EIP-712 signature verification
   - Compact agreement validation
   - Arbiter claim processing

3. **Resource Manager Tests**

   - Lock management functionality
   - Allocator integration
   - Error handling for resource conflicts

4. **End-to-End Flow Tests**
   - Complete maker-to-taker flow
   - Treasurer integration
   - Cross-contract interaction validation
