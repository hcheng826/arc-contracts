// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "../src/Oracle.sol";
import "forge-std/console2.sol";

contract TestOracle is Test {

    event OracleAdded(address indexed oracle, uint256 indexed oracleCount);
    event SentinelDataSubmitted(address indexed oracle, uint256 indexed height, uint256 indexed currentHeight);
    event SentinelDataUpdated(uint256 indexed height, uint256 indexed currentHeight);


    Oracle public oracle;
    address owner;

    function setUp() public {
        owner = vm.addr(1234);
        vm.startPrank(owner);
        oracle = new Oracle();
        oracle.registerOracleThroughOwner(vm.addr(1));
        vm.stopPrank();

    }

    function test_registerOracleFailDueToNoOwner() public {
        bytes memory err ="Not an owner";
        vm.expectRevert(err);
        oracle.registerOracleThroughOwner(vm.addr(2));
    }

    function test_registerOraclePass() public {
        vm.startPrank(owner);
        assertEq(oracle.totalRegisterdOracles(), 1);
        address addr = vm.addr(2);
        vm.expectEmit(true, true, false, false);
        emit OracleAdded(addr, 2);
        oracle.registerOracleThroughOwner(addr);
        assertEq(oracle.totalRegisterdOracles(), 2);
        vm.stopPrank();
    }

    function test_registerOracleFailDueToExhaust() public {
        vm.startPrank(owner);
        assertEq(oracle.totalRegisterdOracles(), 1);
        bytes memory err = "Privilege exhausted";

        oracle.registerOracleThroughOwner(vm.addr(2));
        oracle.registerOracleThroughOwner(vm.addr(3));
        vm.expectRevert(err);
        oracle.registerOracleThroughOwner(vm.addr(4));
        vm.stopPrank();
    }

    function test_submitSentinelDataSingleOracle() public {
        vm.startPrank(vm.addr(1));
        vm.expectEmit(true, true, false, false);
        emit SentinelDataUpdated(27, block.number);
        oracle.submit_SentinelData(
            27,
            1e12,
            1e8,
            1e20,
            1e20
        );

    }
   
}

contract TestOracleInDAO is Test {
    event SentinelDataSubmitted(address indexed oracle, uint256 indexed height, uint256 indexed currentHeight);
    event SentinelDataUpdated(uint256 indexed height, uint256 indexed currentHeight);


    Oracle public oracle;
    address owner;

    function setUp() public {
        owner = vm.addr(1234);
        vm.startPrank(owner);
        oracle = new Oracle();
        oracle.registerOracleThroughOwner(address(this));
        oracle.registerOracleThroughOwner(vm.addr(2));
        oracle.registerOracleThroughOwner(vm.addr(3));
        vm.stopPrank();
    }

    function test_submitSentinelDataSubmission() public  {
        vm.expectEmit(true, true, true, false);
        emit SentinelDataSubmitted(address(this), 27, block.number);
        oracle.submit_SentinelData(
            27,
            1e12,
            1e8,
            1e20,
            1e20
        );

    }

    function test_sybmitSentinelDataUpdated() public {
        vm.expectEmit(true, true, true, false);
        emit SentinelDataSubmitted(vm.addr(2), 27, block.number);
        vm.prank(vm.addr(2));
        oracle.submit_SentinelData(
            27,
            1e12,
            1e8,
            1e20,
            1e20
        );
        vm.expectEmit(true, true, false, false);
        emit SentinelDataUpdated(27, block.number);
        oracle.submit_SentinelData(
            27,
            1e12,
            1e8,
            1e20,
            1e20
        );


    }
}
