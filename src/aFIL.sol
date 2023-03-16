// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "./LoanAgent.sol";

// is ERC20
contract aFIL {
    modifier onlyOracle() {
        _;
    }

    struct Loan {
        LoanAgent loanAgent;
        uint loanAmount;
        uint finishTime;
        uint remainingAmount;
    }

    function depositFIL() public payable {}

    function withdrawFIL() public {}

    // transfer FIL to loanAgent and record the loan data
    function loan(address loanAgent, uint amount) external onlyOracle {}
}
