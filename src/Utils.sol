// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "filecoin-solidity/PowerAPI.sol";
import "filecoin-solidity/PrecompilesAPI.sol";
import "filecoin-solidity/utils/FilAddresses.sol";
import "filecoin-solidity/utils/BigInts.sol";

library Utils {

    // 3 PiB
    uint256 public constant MIN_RAW_BYTE_POWER = 3 * 1024 * 1024 * 1024 * 1024 * 1024;

    function getActorId(address addr) internal view returns(uint64 ) {
        return PrecompilesAPI.resolveEthAddress(addr);
    }

    function isETHAddressEqualToFILAddress(address ethAddr, 
        CommonTypes.FilAddress memory filAddr) internal view returns(bool) {
            uint64 actorIdFromETH = PrecompilesAPI.resolveEthAddress(ethAddr);
            uint64 actorIdFromFIL = PrecompilesAPI.resolveAddress(filAddr);
            return actorIdFromETH == actorIdFromFIL;
    }


    function isOwnerOfTheMiner(address miner, address owner) internal returns(bool) {
        uint64 actorId = PrecompilesAPI.resolveEthAddress(miner);
        CommonTypes.FilActorId filActorId = actorId;
        MinerTypes.GetOwnerReturn memory minerOwner = MinerAPI.getOwner(filActorId);
        return isETHAddressEqualToFILAddress(owner, minerOwner.owner);
    }


    function isBeneficiaryOfTheMiner(address miner, address benf) internal returns(bool) {
        CommonTypes.FilActorId filActorId = PrecompilesAPI.resolveEthAddress(miner);
        MinerTypes.GetBeneficiaryReturn memory benf = MinerAPI.getBeneficiary(target);
        BeneficiaryTerm memory term = benf.active.term;
        return isETHAddressEqualToFILAddress(benf, benf.active.beneficiary) && 
            term.quota == 0 && term.expiration == 0;
    }

    function changeOwner(address miner, address newOwner) internal {
        CommonTypes.FilActorId filActorId = PrecompilesAPI.resolveEthAddress(miner);
        CommonTypes.FilAddress memory filAddress = FilAddresses.fromEthAddress(newOwner);
        MinerAPI.changeOwnerAddress(filActorId, filAddress);
    }

    function changeBenficiary(address miner, address newBenf) internal {
        CommonTypes.FilActorId filActorId = PrecompilesAPI.resolveEthAddress(miner);
        CommonTypes.FilAddress memory filAddress = FilAddresses.fromEthAddress(newBenf);
        MinerTypes.ChangeBeneficiaryParams memory params = MinerTypes.ChangeBeneficiaryParams({
            new_beneficiary: filAddress,
            new_quota: 0,
            new_expiration: 0
        });
        MinerAPI.changeBeneficiary(filActorId, params);
    }


    function withdrawAmount(address miner, uint256 amount) internal {
        CommonTypes.FilActorId filActorId = PrecompilesAPI.resolveEthAddress(miner);
        CommonTypes.BigInt memory bigIntAmount = BigInts.fromUint256(amount);
        MinerAPI.withdrawBalance(filActorId, bigIntAmount);
    }

    function getRawBytePower(address miner) internal returns(uint256) {
        uint64 minerId = PrecompilesAPI.resolveEthAddress(miner);
        PowerTypes.MinerRawPowerReturn memory powerReturn = PowerAPI.minerRawPower(minerId);
        return BigInts.toUint256(powerReturn.raw_byte_power);
    }

    function isEligibleRawBytePower(uint256 power) internal view returns(bool) {
        return power >= MIN_RAW_BYTE_POWER;
    }
    


}