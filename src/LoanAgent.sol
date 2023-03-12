// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract LoadAgent {
    address public minerAddress;
    address public lendingVaultAddress;
    address public oracleAddress;

    enum LoadAgentStatus {
        // Stake Pool is in the collateral queue
        InQueue,
        // Stake pool is waiting for the node to transfer the onwerhsip address to StakePool
        // with updated quota and epoch
        OwnershipConfirmationPending,
        // Stake Pool is waiting for the node to host an oracle and confirm its liveliness by responding to a challenge
        OracleConfirmationPending,
        // Stake Pool is active
        Active,
        // Stake Pool is paused
        Paused,
        // Stake Pool is terminated
        Terminated,
        // Stake pool is active but the miner is in the queue to add more power
        AsyncInQueue,
    }

    // should be called using LoanAgentFactory
    constructor(
        address _lendingVaultAddress,
        address _minerAddress,
        address _oracleAddress,
        address workerAddress
    ) {
        // Call ChangeWorkerAddress in MinerAPI: https://docs.zondax.ch/fevm/filecoin-solidity/api/actors/Miner#changeworkeraddress
    }

    // withdraw the funds from the Miner actor to this contract
    function withdrawBalacne() external {}

    // transfer the reward from this contract to LendingVault, Miner, Oracle, respectively
    function distributeReward() external {}

    // Only called by minder address
    function changeWorker(address newWorkerAddress) external {}

    // Only called by LendingVault when the loan is fully repaid
    function changeOwner(address ownerAddress) external {}
}
