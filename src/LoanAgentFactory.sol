// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract LoadAgentFactory {
    mapping(address => bool) registeredLoanAgents;

    // miner will deploy LoanAgent with partial pledge for the node
    function deployLoanAgent() external payable returns (address) {}

    function registerNewAgents(address[] calldata agents) external onlyOracle {}

    // ==== Loan request related ====
    modifier onlyOracle {
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


    LoanRequest[] loanRequestQueue;

    // consider to move the loan request to oracle?
    function addLoanRequest(LoanRequest calldata request) external payable {}

    // Can be called either by oracle contract or request owner.
    function removeLoanRequest(address agent) external {}
}
