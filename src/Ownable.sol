// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;


abstract contract Ownable {
    event OwnerAdded(address indexed sender, address indexed recp);
    event OwnerRemoved(address indexed sender, address indexed recp);
    mapping(address => bool) public  isOwner;

    modifier onlyOwner {
        require(isOwner[msg.sender], "Not an owner");
        _;
    }

    constructor() {
        _addOwner(msg.sender);
    }

    function _addOwner(address recp) internal {
        isOwner[recp] = true;
        emit OwnerAdded(msg.sender, recp);
    }

    function addOwner(address recp) external onlyOwner {
        _addOwner(recp);
    }

    function removeOwner(address recp) external onlyOwner {
        isOwner[recp] = false;
        emit OwnerRemoved(msg.sender, recp);
    }
}