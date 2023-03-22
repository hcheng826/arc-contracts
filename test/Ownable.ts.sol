// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Ownable.sol";


contract Own is Ownable {
    constructor() Ownable() {}
}

contract TestOwnable is Test {

    event OwnerAdded(address indexed sender, address indexed recp);
    event OwnerRemoved(address indexed sender, address indexed recp);

    Own own;
    address owner;

    function setUp() public {
        owner = vm.addr(1234);
        vm.prank(owner);
        own = new Own();
    }

    function test_isOwner() public {
        assertEq(own.isOwner(vm.addr(1)), false);
        assertEq(own.isOwner(owner), true);
    }

    function test_addOwnerFail() public  {
        vm.expectRevert();
        own.addOwner(vm.addr(2));
    }

    function test_addOwnerPass() public {
        vm.prank(owner);
        address addr = vm.addr(2);
        vm.expectEmit(true, true, false, false);
        emit OwnerAdded(owner, addr);
        own.addOwner(addr);
        assertEq(own.isOwner(addr), true);
    }

    function test_removeOwner() public {
        vm.prank(owner);
        emit OwnerRemoved(owner, vm.addr(2));
        own.removeOwner(vm.addr(2));
        assertEq(own.isOwner(vm.addr(2)), false);
    }
}