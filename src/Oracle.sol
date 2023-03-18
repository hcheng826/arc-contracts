// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
import "./Ownable.sol";
import "openzeppelin-contracts/utils/structs/EnumerableSet.sol";

contract Oracle is Ownable {

    using EnumerableSet for EnumerableSet.AddressSet;

    event SentinelDataSubmitted(address indexed oracle, uint256 indexed height, uint256 indexed currentHeight);
    event SentinelDataUpdated(uint256 indexed height, uint256 indexed currentHeight);

    event OracleAdded(address indexed oracle, uint256 indexed oracleCount);

    EnumerableSet.AddressSet private oracles;

    // mapping(address => bool) public isRegisterdOracle;
    // uint256 public totalRegisterdOracles;
    uint8 private constant quorum = 51;


    mapping(bytes32 => uint256) public dataFeedVotes;
    mapping(bytes32 => bool) public nodeSubmissions;
    mapping(bytes32 => bool) public executedSubmissions;

    constructor() Ownable() {}

    struct SentinelData {
       uint256 height;
       uint256 initialPledgeRateFor32GiB;
       uint256 rawBytesPowerOfProtocol;
       uint256 availableBalanceOfProtocol;
       uint256 pledgedCollateralOfProtocol;
    }

    SentinelData public sentinelData;
    // block number at which consensus was achieved to update the sentinel data
    // This is used to schedule the next sentinel data feed and has no use for real data
    uint256 currentSentinelFeedBlock;

    function isRegisterdOracle(address oracle) public view returns(bool) {
        return oracles.contains(oracle);
    }

    function totalRegisterdOracles() public view returns(uint256) {
        return oracles.length();
    }


    modifier onlyOracle {
        require(isRegisterdOracle(msg.sender), "Unknown source");
        _;
    }


    function getThresholdVoteCount() public view returns(uint256) {
        return totalRegisterdOracles() * quorum;
    }

    function isPassingThresholdVoteCount(uint256 vote) internal view returns(bool) {
        return vote * 100 >= getThresholdVoteCount();
    }

    function _registerOracle(address oracle) internal {
        require(!isRegisterdOracle(oracle), "Oracle already registered");
        oracles.add(oracle);
        emit OracleAdded(oracle, totalRegisterdOracles());
    }

    function getOracles() external view returns(address[] memory) {
        return oracles.values();
    }

    /// Register oracle on contract owner's command
    /// Maximum 3 oracles can be added by owners to seed the protocol
    function registerOracleThroughOwner(address oracle) external onlyOwner {
        require(totalRegisterdOracles() < 3, "Privilege exhausted");
        _registerOracle(oracle);
    }

    function submitSentinelData(SentinelData calldata data) external onlyOracle {
        bytes32 nodeSubmissionKey = keccak256(abi.encodePacked("sentinel_data", msg.sender, data.height));
        require(!nodeSubmissions[nodeSubmissionKey], "Already submitted");
        bytes32 executedSubmissionKey = keccak256(abi.encode("sentinel_data", data));
        require(!executedSubmissions[executedSubmissionKey], "Sentinel already updated");
        bytes32 detaFeedVoteKey = keccak256(abi.encode("sentinel_data", data));
        nodeSubmissions[nodeSubmissionKey] = true;
       
        uint256 voteCount = dataFeedVotes[detaFeedVoteKey] + 1;
        dataFeedVotes[detaFeedVoteKey] = voteCount;
        emit SentinelDataSubmitted(msg.sender, data.height, block.number);
        if (isPassingThresholdVoteCount(voteCount)) {
            executedSubmissions[executedSubmissionKey] = true;
            _updateSentinelData(data);
        }


    }


    function _updateSentinelData(SentinelData memory data) internal {
        sentinelData = data;
        currentSentinelFeedBlock = block.number;
        emit SentinelDataUpdated(data.height, currentSentinelFeedBlock);
    }


    // function submitAcceptedLoanAgents(uint256 height, address[] agents) external onlyOracle {
        
    // }




    




}