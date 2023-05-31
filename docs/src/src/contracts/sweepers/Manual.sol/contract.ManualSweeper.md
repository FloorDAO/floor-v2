# ManualSweeper
[Git Source](https://github.com/FloorDAO/floor-v2/blob/fce0c6edadd90eef36eb24d13cfb5b386eeb9d00/src/contracts/sweepers/Manual.sol)

**Inherits:**
[ISweeper](/src/interfaces/actions/Sweeper.sol/contract.ISweeper.md)

Allows a sweep to be referenced as manually swept outside of onchain logic. This references
another transaction to provide information that the sweep was completed.
This can be used to allow for multiple fractional sweeps from multiple epoch votes to be
completed in a single transaction.


## Functions
### execute

Our execute function call will just return the provided bytes data that should unpack
into a string message to be subsequently stored onchain against the sweep.


```solidity
function execute(address[] calldata, uint[] calldata, bytes calldata data) external payable override returns (string memory);
```

