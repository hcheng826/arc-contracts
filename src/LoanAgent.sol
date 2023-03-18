// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract LoanAgent {
    struct AddressInfo {
        address miner;
        address realOwner;
        address oracle;
    }

    AddressInfo public addressInfo;

    // The owner address registered with the miner
    // In the begining the realOwner will be the miner's claimed owner
    // but it has to change from realOwner to LoanAgent address.
    // This variable will be updated After WaitingForOwnerChange, and the reason
    // to implement this variable is the MinerAPI returns bytes form f410 address which is dirty to handle.
    address public nodeClaimedOwner;

    struct LoanAgentInfo {
        uint256 nodeOwnerStakes;
        uint256 usersStakes;
        uint256 poolExpectedExpiry;
        uint256 rawBytePower;
        uint256 poolCreationTimestamp;
        uint24 interestRate;
        // Amount that the miner has to return (usersStake + interestRateForPeriod)
        uint256 expectedReturnAmount;
        uint24 nodeOwnerCollateralStakes;
    }

    // Amount that the miner has returned to protocol till now
    /// updated by withdrawBalance function
    // if totalReturnedAmount == expectedReturnAmount (changeOwner of the miner and terminate the stakepool)
    uint256 public totalReturnedAmount;

    LoanAgentInfo public loanAgentInfo;

    /// checkpoint => withdrawnAmount
    mapping(uint256 => uint256) withdrawHistory;
    /// checkpoint => available balance after withdrawl
    mapping(uint256 => uint256) availableBalanceHistory;
    // checkpoint => miner share
    mapping(uint256 => uint256) ownerWithrawableAmount;
    // total amount of miner share accummulated
    uint256 public totalOwnerCredit;
    uint256 public lastWithdrawlCheckpoint;

    enum NodeStatus {
        InQueue,
        WaitingForOwnerChange,
        WaitingForOracleVerification,
        WaitingForSectorPledging,
        Active,
        Paused,
        Terminated
    }

    // timestamp at which current status was applied
    uint256 public currentStatusTimestamp;

    NodeStatus public status;

    // Stakepool factory
    address public immutable factory;

    // should be called using LoanAgentFactory
    constructor(
        AddressInfo memory _addressInfo,
        LoanAgentInfo memory _loanAgentInfo,
        address _factory
    ) {
        // Call ChangeWorkerAddress in MinerAPI: https://docs.zondax.ch/fevm/filecoin-solidity/api/actors/Miner#changeworkeraddress
        factory = _factory;
    }

    modifier onlyFactory {
        require(msg.sender == factory, "Not LoanAgentFactory");
        _;
    }

    modifier onlyOracle {
        _;
    }

    modifier onlyRealOwner {
        _;
    }


    // withdraw the funds from the Miner actor to this contract
    function withdrawBalacne() external {}

    // transfer the reward from this contract to LendingVault, Miner, Oracle, respectively
    function distributeReward() external {}

    // // Only called by miner address
    // function changeWorker(address newWorkerAddress) external {}

    // miner can repay the loan and change the owner to itself, LoanAgent will selfdestruct and transfer the funds to LendingVault
    function repayLoanAndChangeOwner(address ownerAddress) external {}

    function changeOwnerBackToReal() external {}

    function getBalanceInfo()
        external
        view
        returns (
            uint256 availableBalance,
            uint256 lockedReward,
            uint256 initialPledgeCollateral
        ) {}

    function getStakeInfo()
        external
        view
        returns (uint256 nodeOwnerStakes, uint256 usersStakes) {}



    function setNodeClaimedOwner(address _owner) external onlyOracle {
        nodeClaimedOwner = _owner;
    }

    // Can only be callled by loan agent factory
    function updateNodeStatus(NodeStatus _status) external onlyFactory {
        status = _status;
        currentStatusTimestamp = block.timestamp;
    }

    function destructStakePool() external onlyFactory {}

    // Can only be called by oracle contract and before status == NodeStatus.Active
    // get pledged collateral, calculate residual FIL in the wallet after pledging,
    // refund the amounts according to the collateral shares and update nodeOwnerStakes and usersStakes
    function verifyAndRefundUnpledgedCollateral() external {}

    // Withdraw earnings from the available balance
    // Only the oracle smart contract can call this function
    // if timeCommitment is crossed and expectedTotal return is yet not procured, 80% of minerShare will also be added in usersShare
    // only withdraw if amount <= current available balance - availableBalanceHistory[lastWithdrawlCheckpoint];
    // The minerShare won't be withdrawn and the amount will be added in totalMinerCredit which the miner can withdraw anytime
    // update availableBalanceHistory, withdrawHistory and lastWithdrawlCheckpoint
    function withdrawEarnings(
        uint256 checkpoint,
        uint256 minerShare,
        uint256 usersShare,
        uint256 oracleShare
    ) external onlyOracle {}

    // The amount that realOwner can withdraw anytime.
    // The amount must be less than totalOwnerCredit and available balance.
    // The withdrawal will update totalOwnerCredit, availableBalanceHistory
    function withdrawMinerEarning(uint256 amount) external onlyRealOwner {}
}
