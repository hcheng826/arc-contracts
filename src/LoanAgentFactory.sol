// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "./LoanAgent.sol";
import "./aFIL.sol";
import "./Oracle.sol";
import "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

contract LoadAgentFactory {
    uint16 public constant ONE_HUNDRED_DENOMINATOR = 100;

    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable oracle;
    address public immutable aFil;
    uint16 public immutable oracleFeePercentage;

    event LoanAgentStatusChange(address indexed agent, LoanAgent.NodeStatus indexed status, uint256 indexed block);

    EnumerableSet.AddressSet private agentsInQueue;
    EnumerableSet.AddressSet private acceptedInActiveAgents;
    EnumerableSet.AddressSet private activeAgents;

    mapping(address => LoanRequest) loanAgentRequests;

    uint32 public constant minerValidationDeadlineAtEachStatus = 3 days;

    constructor(address _oracle, address _aFil, uint16 _oracleFeePercentage) {
        oracle = _oracle;
        aFil = _aFil;

        require(
            _oracleFeePercentage >= 0 && _oracleFeePercentage <= 100,
            "oracleFeePercentage needs to be in range 0-100"
        );
        oracleFeePercentage = _oracleFeePercentage;
    }

    modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle can call this function");
        _;
    }

    struct LoanRequest {
        address miner;
        address owner;
        address oracle;
        address requestOwner;
        uint256 rawBytesPower;
        // miner will transfer 10% extra amount for rate changes
        // which will be refunded after sector pledging if not used
        uint256 pledgeAmount;
        uint256 timeCommitement;
        uint256 requestCreationTimestamp;
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

    // called by anyone
    function addLoanRequest(LoanRequest calldata request) external payable {
        require(
            msg.sender == request.owner,
            "can only add request with itself as request owner"
        );
        LoanAgent.AddressInfo memory addressInfo = LoanAgent.AddressInfo({
            miner: request.miner,
            realOwner: request.owner,
            oracle: request.oracle
        });


        LoanAgent.LoanAgentInfo memory loanAgentInfo = LoanAgent.LoanAgentInfo({
            nodeOwnerStakes: request.pledgeAmount,
            usersStakes: 0,
            poolExpectedExpiry: block.timestamp + request.timeCommitement,
            rawBytePower: request.rawBytesPower,
            poolCreationTimestamp: block.timestamp,
            interestRate: 0, // Set the interest rate
            expectedReturnAmount: 0, // Set the expected return amount
            nodeOwnerCollateralStakes: 0 // Set the node owner collateral stakes
        });

        LoanAgent loanAgent = new LoanAgent(
            addressInfo,
            loanAgentInfo,
            address(this)
        );

        require(
            payable(oracle).send(
                (msg.value * oracleFeePercentage) / ONE_HUNDRED_DENOMINATOR
            ),
            "should send FIL to oracle successfully"
        );

        require(
            payable(address(loanAgent)).send(
                (msg.value * (ONE_HUNDRED_DENOMINATOR - oracleFeePercentage)) /
                    ONE_HUNDRED_DENOMINATOR
            ),
            "should send FIL to loanAgent successfully"
        );
        agentsInQueue.add(address(loanAgent));
        loanAgentRequests[address(loanAgent)] = request;
        _updateNodeStatus(address(loanAgent), LoanAgent.NodeStatus.InQueue);

    }

    // Can be called either by oracle contract or request owner.
    function removeLoanRequest(address agent) external {
        require(agentsInQueue.contains(agent), "Agent not in the queue");
        require(
            msg.sender == loanAgentRequests[agent].requestOwner,
            "only request owner can remove request"
        );
        agentsInQueue.remove(agent);
        // TODO: call selfdestruct in LoanAgent and return the FIL to request owner (deduct fee)
    }


    // after oracle review the request and approved, call this
    function registerNewAgents(
        address[] calldata agents,
        uint[] calldata loanAmount
    ) external onlyOracle {
        for (uint i; i < agents.length; ) {
            require(
                agentsInQueue.contains(agents[i]),
                "Agent not in the queue"
            );
            aFIL(aFil).loan(agents[i], loanAmount[i]);
            agentsInQueue.remove(agents[i]);
            acceptedInActiveAgents.add(agents[i]);
            unchecked {
                i++;
            }
        }
    }

    function _updateNodeStatus(address agent, LoanAgent.NodeStatus status) internal {
        LoanAgent(agent).updateNodeStatus(status);
        emit LoanAgentStatusChange(agent, status, block.number);
    }


    function _initiateOwnerVerifiticationOrImpl(LoanAgent agent) internal {
        isStatusExpired(agent.currentStatusTimestamp());
        if (agent.nodeClaimedOwner() != address(agent)) {
            // Begin WaitingForOwnerChange
            _updateNodeStatus(address(agent), LoanAgent.NodeStatus.WaitingForOwnerChange);
            return;
        }
        _initiateOracleVerificationOrImpl(agent);
    }

    function _initiateOracleVerificationOrImpl(LoanAgent agent) internal {
        isStatusExpired(agent.currentStatusTimestamp());
        (,,address nodeOracle) = agent.addressInfo();
        if (!Oracle(oracle).isRegisterdOracle(nodeOracle)) {
            // Begin Oracle Verification
            _updateNodeStatus(address(agent), LoanAgent.NodeStatus.WaitingForOracleVerification);
            // Publish challenge for oracle to respond
            return;
        }
        // Begin sector pledging
    }

    // function _initiateSectorPledgingOrImpl(LoanAgent agent) internal {
    //     isStatusExpired(agent.currentStatusTimestamp());

    // }


    function submitOwnerChangeConfirmation(address agent) external onlyOracle {
        require(acceptedInActiveAgents.contains(agent), "LoanAgent is not in waiting");
        LoanAgent agentInstance = LoanAgent(agent);
        require(agentInstance.status() == LoanAgent.NodeStatus.WaitingForOwnerChange, 
            "Not waiting for owner change");
        require(agentInstance.nodeClaimedOwner() == address(agent), "Miner owner not updated");
        _initiateOracleVerificationOrImpl(agentInstance);
    }


    function submitOracleVerification(address agent) external onlyOracle {
        require(acceptedInActiveAgents.contains(agent), "LoanAgent is not in waiting");
        LoanAgent agentInstance = LoanAgent(agent);
        require(agentInstance.status() == LoanAgent.NodeStatus.WaitingForOracleVerification, 
            "Not waiting for oracle verification");
        (,,address nodeOracle) = agentInstance.addressInfo();
        require(Oracle(oracle).isRegisterdOracle(nodeOracle), "Oracle is not verified");
    }






    function acceptAgentInQueue(address agent) external onlyOracle {
        require(agentsInQueue.contains(agent), "LoanAgent not in queue");
        agentsInQueue.remove(agent);
        acceptedInActiveAgents.add(agent);
        LoanAgent agentInstance = LoanAgent(agent);
        _initiateOwnerVerifiticationOrImpl(agentInstance);
    }
}
