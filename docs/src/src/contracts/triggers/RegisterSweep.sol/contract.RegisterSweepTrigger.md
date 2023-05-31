# RegisterSweepTrigger
[Git Source](https://github.com/FloorDAO/floor-v2/blob/c8169a0594ad07a37d169672a50f4155c41be809/src/contracts/triggers/RegisterSweep.sol)

**Inherits:**
[EpochManaged](/src/contracts/utils/EpochManaged.sol/contract.EpochManaged.md), [IEpochEndTriggered](/src/interfaces/utils/EpochEndTriggered.sol/contract.IEpochEndTriggered.md)

If the current epoch is a Collection Addition, then the floor war is ended and the
winning collection is chosen. The losing collections are released to be claimed, but
the winning collection remains locked for an additional epoch to allow the DAO to
exercise the option(s).
If the current epoch is just a gauge vote, then we look at the top voted collections
and calculates the distribution of yield to each of them based on the vote amounts. This
yield is then allocated to a Sweep structure that can be executed by the {Treasury}
at a later date.

*Requires `TREASURY_MANAGER` role.*

*Requires `COLLECTION_MANAGER` role.*


## State Variables
### pricingExecutor
Holds our internal contract references


```solidity
IBasePricingExecutor public pricingExecutor;
```


### newCollectionWars

```solidity
INewCollectionWars public newCollectionWars;
```


### voteContract

```solidity
ISweepWars public voteContract;
```


### treasury

```solidity
ITreasury public treasury;
```


### strategyFactory

```solidity
IStrategyFactory public strategyFactory;
```


### tokenEthPrice
Store our token prices, set by our `pricingExecutor`


```solidity
mapping(address => uint) internal tokenEthPrice;
```


## Functions
### constructor

..


```solidity
constructor(address _newCollectionWars, address _pricingExecutor, address _strategyFactory, address _treasury, address _voteContract);
```

### endEpoch


```solidity
function endEpoch(uint epoch) external onlyEpochManager;
```

