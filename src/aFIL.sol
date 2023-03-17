// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "openzeppelin-contracts/token/ERC20/ERC20.sol";
import "./LoanAgent.sol";

error InsufficientTokenAvailable(uint availableAmount, uint requestAmount);

contract aFIL is ERC20 {
    uint public totalLoanAmount;
    address public immutable oracle;

    constructor(address _oracle) ERC20("arc FIL", "aFIL") {
        oracle = _oracle;
    }

    struct Loan {
        LoanAgent loanAgent;
        uint totalAmount;
        uint expectFinishTime;
        uint remainingAmount;
    }

    mapping (address => Loan) loans;

    modifier onlyOracle() {
        require(msg.sender == oracle, "Only oracle can call this function");
        _;
    }

    function depositFIL() public payable {
        _mint(msg.sender, getAfilValue(msg.value));
    }

    function withdrawFIL(uint amount) public {
        if (amount > balanceOf(msg.sender)) {
            revert InsufficientTokenAvailable(balanceOf(msg.sender), amount);
        }
        _burn(msg.sender, amount);
        payable(msg.sender).transfer(getFilValue(amount));
    }

    // Calculate the amount of aFIL backed by an amount of FIL
    // ref: https://github.com/rocket-pool/rocketpool/blob/967e4d3c32721a84694921751920af313d1467af/contracts/contract/token/RocketTokenRETH.sol#L51
    function getAfilValue(uint filAmount) public view returns (uint256) {
        uint afilSupply = totalSupply();
        if (afilSupply == 0) {
            return filAmount;
        }
        return (filAmount * afilSupply) / getBackingFilBalance();
    }

    // Calculate the amount of FIL backing an amount of aFIL
    // ref: https://github.com/rocket-pool/rocketpool/blob/967e4d3c32721a84694921751920af313d1467af/contracts/contract/token/RocketTokenRETH.sol#LL39C68-L39C87
    function getFilValue(uint afilAmount) public view returns (uint256) {
        uint afilSupply = totalSupply();
        if (afilSupply == 0) {
            return afilAmount;
        }
        return (afilAmount * getBackingFilBalance()) / afilSupply;
    }

    function getBackingFilBalance() public view returns (uint256) {
        return address(this).balance + totalLoanAmount;
    }

    // transfer FIL to loanAgent and record the loan data
    function loan(address payable loanAgent, Loan calldata _loan) external onlyOracle {
        if (loanAgent.send(_loan.totalAmount)) {
            totalLoanAmount += _loan.totalAmount;
            loans[loanAgent] = _loan;
        }
    }
}
