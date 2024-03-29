// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "./LoanAgent.sol";
import "./aFIL.sol";
import "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

contract LoadAgentFactory {
    uint16 public constant ONE_HUNDRED_DENOMINATOR = 100;

    using EnumerableSet for EnumerableSet.AddressSet;

    address public immutable oracle;
    address public immutable aFil;
    uint16 public immutable oracleFeePercentage;

    EnumerableSet.AddressSet private agentsInQueue;
    EnumerableSet.AddressSet private acceptedInActiveAgents;
    EnumerableSet.AddressSet private activeAgents;

    mapping(address => LoanRequest) loanAgents;

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
        address requestOwner;
        uint256 rawBytesPower;
        // miner will transfer 10% extra amount for rate changes
        // which will be refunded after sector pledging if not used
        uint256 pledgeAmount;
        uint256 timeCommitement;
        uint256 requestCreationTimestamp;
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
            oracle: oracle
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
        loanAgents[address(loanAgent)] = request;
    }

    // Can be called either by oracle contract or request owner.
    function removeLoanRequest(address agent) external {
        require(agentsInQueue.contains(agent), "Agent not in the queue");
        require(
            msg.sender == loanAgents[agent].requestOwner,
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
}
