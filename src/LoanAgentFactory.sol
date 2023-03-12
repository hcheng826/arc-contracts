// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract LoadAgentFactory {
    // called by Oracle contract can call this, transfer the loan to the LoanAgent contract
    // apply CREATE2 so the contract address can be known beforehand
    function deployLoanAgent() external {}
}
