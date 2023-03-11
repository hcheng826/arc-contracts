# arc-contracts

## Contracts

### Vault.sol
- One instance for entire protocol
- ERC20 contract
- Lenders put FIL to this contract (and get something like aFIL. like rETH for rocket protocol)
- Provide the collateral needed for miner to start the node

### LoanAgent.sol
- New instance for each new miner node
- Deployed when a new miner actor is approved to join the protocol
- Serve as owner address and beneficiary for the miner actor
- Based on the data from Oracle contract and the available balance and vesting funds from MinerAPI, calculate the expected goal for each cycle
  - Positive case (goal achieved): Withdraw funds from miner, distribute it to node runner, Vault, and Oracle members. Continue next cycle
  - Negative case (goal missed): Pause the distribution to node runner until the gap is paid. If not paid for long enough the node will be terminated and collateral will be returned

### Oracle.sol
- Singleton for entire protocol
- Register all Oracle DAO member wallets
- Oracle DAO will read the node data, construct Merkle root and submit the value to the contrat and the contract will record counts for each value, > 50% to make it valid data
- Record the gas consumptions for legit oracle iteractions

## Reference
- Addresses in Filecoin (owner address, worker address, control address, etc): https://lotus.filecoin.io/storage-providers/operate/addresses/
- MinerAPI (solidity contract for Actors-related APIs): https://docs.zondax.ch/fevm/filecoin-solidity/api/actors/Miner
