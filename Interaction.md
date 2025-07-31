# Interaction

## Requirements

### Rebalancer

1. Create an Interaction Contract called RebalancerInteraction.sol (in the src directory)
2. Create a test contract called RebalancerInteraction.t.sol (in the test directory)
3. In RebalancerInteraction.t.sol
   1. Create test scenarios the same as in ChainLinkCalculator.t.sol
   2. Add to that an Interaction using RebalancerInteraction.sol which
      1. Takes the output tokens the taker receives
      2. Transfers them to a third wallet (addr3) which is a treasurer
      3. If the transfer fails reject the order.
