// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract LoadAgentFactory {
    enum LoanRequestStatus{ PENDING, APPROVED, REJECTED }
    mapping(address => bool) registeredLoanAgents;

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
        LoanRequestStatus status;
    }

    LoanRequest[] loanRequestQueue;
    // called by Oracle contract can call this, transfer the loan to the LoanAgent contract
    // apply CREATE2 so the contract address can be known beforehand
    function deployLoanAgent() external {}

    function addLoanRequest(LoanRequest calldata request) external payable {}

    // Can be called either by oracle contract or request owner.
    function removeLoanRequest(address agent) external {}
    function registerNewAgents(address[] calldata agents) external onlyOracle {}
}
