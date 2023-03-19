// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./LoanAgent.sol";
import "./aFIL.sol";
import "./Oracle.sol";
import "openzeppelin-contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/utils/Create2.sol";
import "./Utils.sol";

contract LoadAgentFactory {


    using EnumerableSet for EnumerableSet.AddressSet;


    event LoanAgentAddedInQueue(address indexed miner, address indexed agent, uint256 indexed block);
    event LoanAgentCreated(address indexed agent, address indexed miner);
    event LoanAgentNodeStatusChange(LoanAgent.NodeStatus indexed status, address indexed agent, uint256 indexed timestamp);

    struct LoanRequest {
        address miner;
        address oracle;
        // Final raw byte power of the miner previous + newly added
        uint256 rawBytePower;
        uint256 timeCommitment;
        uint8 interestRate;
        uint8 nodeOwnerStakePercentage;
    }


    struct LoanAgentInProcessData {
        address miner;
        address owner;
        address oracle;
        uint256 rawBytePowerNet;
        uint256 rawBytePowerDelta;
        uint256 pledgeAmount;
        uint8 nodeOwnerStakePercentage;
        uint8 interestRate;
        uint256 timeCommitment;
        uint256 creationTimestamp;
        uint256 creationBlock;
        uint256 currentInitialCollateral;
    }

    struct LoanAgentInQueue {
        LoanAgentInProcessData data;
        uint256 timestamp;
    }


    uint16 public constant ONE_HUNDRED_DENOMINATOR = 100;
    uint256 public constant MIN_TIME_COMMIT = 180 days;
    uint256 public constant MAX_TIME_COMMIT = 540 days;
    uint private constant IN_Q_DEADLINE = 3 days;

    address public immutable oracle;
    address public immutable aFil;

    // miner address => loan agent
    mapping(address => address) minerLoanAgentMap;

    EnumerableSet.AddressSet private agentInQueue;
    EnumerableSet.AddressSet private acceptedInActiveAgents;
    EnumerableSet.AddressSet private activeAgents;

    mapping(address => LoanAgentInQueue) public minerDataInQueue;

    mapping(address => LoanRequest) loanAgentRequests;

    uint32 public constant minerValidationDeadlineAtEachStatus = 3 days;

    constructor(address _oracle, address _aFil) {
        oracle = _oracle;
        aFil = _aFil;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle can call this function");
        _;
    }

    


    function isStatusExpired(uint256 timestamp) internal view {
        require(block.timestamp - timestamp <= minerValidationDeadlineAtEachStatus,
            "Timeout"
        );
    }   


    function getAgentsInQueue() external view returns(address[] memory) {
        return agentsInQueue.values();
    }

    function getAcceptedInActiveAgents() external view returns(address[] memory) {
        return acceptedInActiveAgents.values();
    }

    function getActiveAgents() external view returns(address[] memory) {
        return activeAgents.values();
    }

    function _checkLoanRequest(LoanRequest memory request) internal {
        // Miner is not already in queue or process
        require(!minerInQueue.contains(request.miner) && 
            !minerInProcess[request.miner], "Request already In queue");
        require(Utils.isOwnerOfTheMiner(request.miner, msg.sender), "Only owner can request for loan");
        require(request.nodeOwnerStakePercentage >= 50 && request.nodeOwnerStakePercentage <= 75, "Owner stake out of bound");
        require(request.timeCommitment >= MIN_TIME_COMMIT && 
            request.timeCommitment <= MAX_TIME_COMMIT, "Time commitment out of bound");
        require(request.oracle != address(0), "Invalid oracle address");
        require(Utils.isEligibleRawBytePower(request.rawBytesPower), "Min. 3PiB storage");
        uint256 expectedCollateral = Oracle(oracle).getIntialCollateralPrice(request.rawBytesPower) * request.nodeOwnerStakePercentage / ONE_HUNDRED_DENOMINATOR;
        // 10% extra collateral
        uint256 requiredPledge = expectedCollateral + (expectedCollateral * 10 / ONE_HUNDRED_DENOMINATOR);
        require(msg.sender >= requiredPledge, "Value sent is less");
        
    }

    function createLoanRequest(LoanRequest memory request) external payable {
        _checkLoanRequest(request);
        uint256 prevRawBytePower = Utils.getRawBytePower(request.miner);
        LoanAgentInProcessData processData = LoanAgentInProcessData({
            miner: request.miner,
            owner: msg.sender,
            oracle: request.oracle,
            rawBytePowerNet: prevRawBytePower + request.rawBytePower,
            rawBytePowerDelta: request.rawBytePower,
            pledgeAmount: msg.value,
            nodeOwnerStakePercentage: request.nodeOwnerStakePercentage,
            timeCommitment: request.timeCommitment,
            creationTimestamp: block.timestamp,
            creationBlock: block.number,
            currentInitialCollateral: 0,
            interestRate: request.interestRate
        });


        address agent = minerLoanAgentMap[request.miner] != address(0) ?minerLoanAgentMap[request.miner] :
              _createLoanAgent(processData);
        LoanAgentInQueue qData = LoanAgentInQueue(processData, block.timestamp);
        agentInQueue.add(agent);
        minerDataInQueue[agent] = qData;
        emit LoanAgentAddedInQueue(request.miner, agent, block.number);
        
    }


    function _createLoanAgent(LoanAgentInProcessData calldata processData) internal returns (address agent) {
        LoanAgent.AddressInfo memory addressInfo = LoanAgent.AddressInfo(processData.miner, processData.owner, processData.oracle);
        LoanAgent.LoanAgentInfo memory agentInfo = LoanAgent.LoanAgentIndo({
            nodeOwnerStakes: processData.pledgeAmount,
            userStakes: processData.pledgeAmount * ((100 - processData.nodeOwnerStakePercentage)/100),
            poolExpectedExpiry: 0,
            rawBytePower: processData.rawBytePowerNet - processData.rawBytePowerDelta,
            poolCreationTimestamp: block.timestamp,
            interestRate: 0,
            expectedReturnAmount: 0,
            nodeOwnerStakePercentage: processData.nodeOwnerStakePercentage
        });
        agent = address(new LoanAgent(addressInfom, agentInfo));
        emit LoanAgentCreated(agent, processData.miner);
    }

    


    function _initOwnerAndBenfValidationOrChange(address agent) internal {
        LoanAgentInQueue memory qData = minerDataInQueue[agent];
        if (Utils.isOwnerOfTheMiner(qData.processData.miner, agent) 
            && Utils.isBeneficiaryOfTheMiner(qData.processData.miner, agent)) {
                // LoanAgent is miner's owner and benf
                _initOracleVerification(agent);
        }
        minerDataInQueue[agent].timestamp = block.timestamp;
        LoanAgent(agent).updateNodeStatus(LoanAgent.NodeStatus.WaitingForOwnerChange);
        // Submitting proposal for owner and benf address change to LoanAgent
        Utils.changeOwner(qData.processData.miner, agent);
        Utils.changeBenficiary(qData.processData.miner, agent);
    }

    function _initOracleVerification(address agent) internal {
        LoanAgentInQueue memory qData = minerDataInQueue[agent];
        if (Oracle(oracle).isRegisterdOracle(qData.processData.oracle)) {
            // Oracle is verified moved on to sector pledging
        }
        minerDataInQueue[agent].timestamp = block.timestamp;
        LoanAgent(agent).updateNodeStatus(LoanAgent.NodeStatus.WaitingForOracleVerification);
        Oracle(oracle).verifyOracleForRegistration(qData.processData.oracle);
    }

    function _initSectorPledging(address agent) internal {
        // Transfer pledge amount and user stakes
    }

    function acceptMinerForLoan(address agent, uint256 currentInitialCollateral) external onlyOracle {
        require(agentInQueue.contains(agent), "Miner not in queue");
        LoanAgentInQueue memory qData = agentInProcess[agent];  
        agentInQueue.remove(agent);
        if (block.timestamp - qData.timestamp > IN_Q_DEADLINE) {
            require(false, "Timeout");
        }
        agentInProcess[agent].processData.currentInitialCollateral = currentInitialCollateral;
        acceptedInActiveAgents.add(agent);
       
    }

    function submitOwnerAndBenfChange(address agent) external onlyOracle {
        require(acceptedInActiveAgents.contains(agent), "Miner is not accepted for loan");
        LoanAgentInQueue memory qData = agentInProcess[agent];
        if (block.timestamp - qData.timestamp > IN_Q_DEADLINE) {
            acceptedInActiveAgents.remove(agent);
            require(false, "Timeout");
        }
        _initOwnerAndBenfValidationOrChange(agent);
    }

    function submitOracleVerification(address agent) external onlyOracle {
        require(acceptedInActiveAgents.contains(agent), "Miner is not accepted for loan");
        LoanAgentInQueue memory qData = agentInProcess[agent];
        if (block.timestamp - qData.timestamp > IN_Q_DEADLINE) {
            acceptedInActiveAgents.remove(agent);
            require(false, "Timeout");
        }
        _initOracleVerification(agent);
    }

    function submitSectorPledging(address agent, uint256 initialCollateral) external onlyOracle {
        
    }




    




 
}
