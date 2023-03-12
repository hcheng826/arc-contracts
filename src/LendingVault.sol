// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract LendingVault {
    // deposit FIL and get aFIL
    function deposit() external payable {}

    // pay aFIL to redeem FIL
    function withdraw(uint256 withdrawAmount) external {}

    // transfer the FIL to LoanAgent as loan to start the node
    function loan() external {}
}
