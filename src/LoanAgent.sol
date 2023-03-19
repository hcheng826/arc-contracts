// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "filecoin-solidity/MinerAPI.sol";
import "filecoin-solidity/types/CommonTypes.sol";
import "filecoin-solidity/utils/FilAddresses.sol";
import "filecoin-solidity/utils/BigInts.sol";

contract LoanAgent {
    uint public constant WEI_DENOMINATOR = 1e18;
    struct AddressInfo {
        address miner;
        address realOwner;
        address oracle;
        CommonTypes.FilActorId filActorId;
    }

    struct LoanAgentInfo {
        uint nodeOwnerStakes;
        uint usersStakes;
        uint agentExpectedExpiry;
        uint rawBytePower;
        uint agentCreationTimestamp;
        // Amount that the miner has to return (usersStake + interestRateForPeriod)
        uint expectedReturnAmount;
        uint lastUpdateDebtTimstamp;
        uint24 interestRate;
        uint8 nodeOwnerStakePercentage;
    }

    // TODO: add status modifiers check to different functions
    enum NodeStatus {
        InQueue,
        WaitingForPledge,
        WaitingForOwnerChange,
        WaitingForOracleVerifiction,
        Active,
        Paused,
        Terminated
    }

    AddressInfo public addressInfo;
    NodeStatus public status;
    uint public currentStatusTimestamp;
    LoanAgentInfo public loanAgentInfo;

    /// checkpoint => withdrawnAmount
    mapping(uint => uint) withdrawHistory;
    /// checkpoint => available balance after withdrawal
    mapping(uint => uint) availableBalanceHistory;
    // checkpoint => miner share
    mapping(uint => uint) ownerWithrawableAmount;
    // total amount of miner share accummulated
    uint totalOwnerCredit;
    uint lastWithdrawlCheckpoint;

    address public immutable factory;
    address public immutable aFil;
    address public immutable oracleDao;

    constructor(
        AddressInfo memory _addressInfo,
        LoanAgentInfo memory _loanAgentInfo,
        address _factory,
        address _aFil,
        address _oracleDao
    ) {
        addressInfo = _addressInfo;
        loanAgentInfo = _loanAgentInfo;
        factory = _factory;
        aFil = _aFil;
        oracleDao = _oracleDao;
        status = NodeStatus.InQueue;
        currentStatusTimestamp = block.timestamp;
    }

    modifier onlyFactory() {
        require(msg.sender == factory, "can only be called by factory");
        _;
    }

    modifier onlyOracleDao() {
        require(msg.sender == oracleDao, "can only be called by oracle");
        _;
    }

    modifier onlyRealOwner() {
        require(
            msg.sender == addressInfo.realOwner,
            "can only be called by real owner"
        );
        _;
    }

    // Only called by miner address
    function changeWorker(
        address worker,
        address[] calldata controlAddresses
    ) external onlyRealOwner {
        CommonTypes.FilAddress[]
            memory controlFilAddrresses = new CommonTypes.FilAddress[](
                controlAddresses.length
            );
        for (uint i = 0; i < controlAddresses.length; ) {
            controlFilAddrresses[i] = FilAddresses.fromEthAddress(
                controlAddresses[i]
            );
            unchecked {
                i++;
            }
        }
        MinerAPI.changeWorkerAddress(
            addressInfo.filActorId,
            MinerTypes.ChangeWorkerAddressParams({
                new_worker: FilAddresses.fromEthAddress(worker),
                new_control_addresses: controlFilAddrresses
            })
        );
    }

    // miner can repay the loan and change the owner to itself
    function repayLoanAndChangeOwner() external payable onlyRealOwner {
        accumulateDebt();
        uint expectedReturnAmount = loanAgentInfo.expectedReturnAmount;
        require(
            msg.value + totalOwnerCredit >= expectedReturnAmount,
            "Insufficient repay amount"
        );
        require(
            payable(aFil).send(expectedReturnAmount),
            "Fail to return users stakes to aFIL"
        );

        address realOwner = addressInfo.realOwner;
        MinerAPI.changeOwnerAddress(
            addressInfo.filActorId,
            FilAddresses.fromEthAddress(realOwner)
        );

        require(
            payable(realOwner).send(address(this).balance),
            "Fail to return remaining balance to real owner"
        );
        totalOwnerCredit = 0;
        status = NodeStatus.Terminated;
    }

    function getBalanceInfo()
        external
        returns (
            CommonTypes.BigInt memory availableBalance,
            uint initialPledgeCollateral,
            MinerTypes.GetVestingFundsReturn memory lockedReward
        )
    {
        availableBalance = MinerAPI.getAvailableBalance(addressInfo.filActorId);
        initialPledgeCollateral = loanAgentInfo.nodeOwnerStakes;
        lockedReward = MinerAPI.getVestingFunds(addressInfo.filActorId);
    }

    function getStakeInfo()
        external
        view
        returns (uint nodeOnwerStakes, uint usersStakes)
    {
        nodeOnwerStakes = loanAgentInfo.nodeOwnerStakes;
        usersStakes = loanAgentInfo.usersStakes;
    }

    function getNodeOwner()
        external
        returns (
            MinerTypes.GetOwnerReturn memory
        )
    {
        return MinerAPI.getOwner(addressInfo.filActorId);
    }

    // Can only be callled by oracle contract or loanAgent factory
    function updateNodeStatus(NodeStatus _status) external onlyFactory {
        status = _status;
        currentStatusTimestamp = block.timestamp;
    }

    // Can only be called by oracle contract and before status == NodeStatus.Active
    // get pledged collateral, calculate residual FIL in the wallet after pledging,
    // refund the amounts according to the collateral shares and update nodeOwnerStakes and usersStakes
    function verifyAndRefundUnpledgedCollateral() external onlyOracleDao {
        require(
            status != NodeStatus.Active,
            "Can only be called before the node is active"
        );
        // TODO: implementation
    }

    // Withdraw earnings from the available balance
    // Only the oracle smart contract can call this function
    // if timeCommitment is crossed and expectedTotal return is yet not procured, 80% of minerShare will also be added in usersShare
    // only withdraw if amount <= current available balance - availableBalanceHistory[lastWithdrawlCheckpoint];
    // The minerShare won't be withdrawn and the amount will be added in totalMinerCredit which the miner can withdraw anytime
    // update availableBalanceHistory, withdrawHistory and lastWithdrawlCheckpoint
    function withdrawEarnings(
        uint checkpoint,
        uint minerShare,
        uint usersShare,
        uint oracleShare
    ) external onlyOracleDao {
        CommonTypes.BigInt memory availableBalance = MinerAPI
            .getAvailableBalance(addressInfo.filActorId);
        require(
            !availableBalance.neg,
            "availableBalance must be positive to withdraw"
        );
        MinerAPI.withdrawBalance(addressInfo.filActorId, availableBalance);
        // TODO: implementation
    }

    // The amount that realOwner can withdraw anytime.
    // The amount must be less than totalOwnerCredit and available balance.
    // The withdrawal will update totalOwnerCredit, availableBalanceHistory
    function withdrawMinerEarning(uint amount) external onlyRealOwner {
        accumulateDebt();
        require(
            amount <= totalOwnerCredit,
            "cannot withdraw more than totalOwnerCredit"
        );
        (uint availableBalance, bool _neg) = BigInts.toUint256(
            MinerAPI.getAvailableBalance(addressInfo.filActorId)
        );
        require(
            amount <= availableBalance,
            "cannot withdraw more than availableBalance"
        );

        totalOwnerCredit -= amount;

        // Q: what would be the expected `lastWithdrawlCheckpoint` here? block.timestamp?
        availableBalanceHistory[lastWithdrawlCheckpoint] =
            availableBalance -
            amount;
        require(
            payable(addressInfo.realOwner).send(amount),
            "fail to transfer to real owner"
        );
    }

    function accumulateDebt() private {
        uint expectedReturnAmount = loanAgentInfo.expectedReturnAmount;
        uint incrementalDebt = ((expectedReturnAmount *
            loanAgentInfo.interestRate) / WEI_DENOMINATOR) *
            (block.timestamp - loanAgentInfo.lastUpdateDebtTimstamp);
        expectedReturnAmount += incrementalDebt;
        loanAgentInfo.lastUpdateDebtTimstamp = block.timestamp;
    }

    function updateInterestRate(uint24 _interestRate) external onlyOracleDao {
        accumulateDebt();
        loanAgentInfo.interestRate = _interestRate;
    }
}
