// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

// Ref
// Access control by OpenZepplin: https://docs.openzeppelin.com/contracts/4.x/access-control
// Merkle tree spec from rocket pool: https://github.com/rocket-pool/rocketpool-research/blob/master/Merkle%20Rewards%20System/merkle-tree-spec.md
contract Oracle {
    mapping(address => bool) public isMember;
    uint64 public memberCount;

    // blockNumber => treeRoot (output of keccak256 bytes32) => votes count
    // encoding of leaf can be discussed
    mapping(uint256 => mapping(bytes32 => uint256)) private rewardsMerkleRootvotes;

    // the blockNumber that is actively voting, reject the submission that is not this block number
    // can set it to 0 as the flag of voting over
    uint256 activeBlockNumber;
    mapping(uint256 => bytes32) public confirmedRewardsMerkleRoot;

    // from 1 to 100, default 51, can be change by DAO proposal
    uint16 public consensusThreshold;

    event RewardsMerkleRootConfirmed(uint256 blockNumber, bytes32 winningRootValue);

    // Member control
    function addNewMember(address newMember) external {} // only certain Role
    function removeMember(address member) external {} // only certian role

    // Submit the cumulative earning for the block
    // when > 51% votes is gathered, will confirm the value and stop receiving votes
    // Q: Do we need to prevent the Oracle members from copying the value submitted by others and submit it?
    function submitRewardsMerkleRoot(uint256 blockNumber, bytes32 submittedRootValue) external {}

    // called when > 51% votes is gathered
    function confirmRewardMerkleRoot(uint256 blockNumber, bytes32 winningRootValue) internal {}

    // TODO: Gas related design
    // TODO: Node initialization design
}
