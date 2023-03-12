# arc-contracts

## Contracts

### LendingVault.sol

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

## Scenarios

### Start a mining node with loan

1. Miner deploy LoanAgent contract with correct addresses for LendingVault and Oracle
2. Miner deposit the collateral to (LoanAgent or LendingVault, to be discussed)
3. Miner submit a request for loan (off-chain)
4. Oracle DAO members will verify that the LoanAgent is set up, the collateral is sent and vote on Oracle contract
5. Once approved, miner can call the function in LendingVault to get the loan and activate the node

### Oracle operations

### When the node does not meet the goal for each period (Does not run the node properly)

1. The miner will be stopped from getting the reward portion. If there's still reward it will be accumulated in the LoanAgent contract
2. Miner will need to repay the gap to resume the right to claiming the reward portion
3. If the gap is not filled after certain amount of periods, the node will be terminated and the collateral will firstly be used to repay the original amount from LendingAgent and also some fee. The remaining will be returned to the miner

## Reference

- Blueprint design from filecoin doc: https://docs.filecoin.io/developers/smart-contracts/about/blueprints/#lending-pool
- Addresses in Filecoin (owner address, worker address, control address, etc): https://lotus.filecoin.io/storage-providers/operate/addresses/
- MinerAPI (solidity contract for Actors-related APIs): https://docs.zondax.ch/fevm/filecoin-solidity/api/actors/Miner
