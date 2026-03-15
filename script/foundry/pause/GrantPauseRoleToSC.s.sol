// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { AccessManagerOperations } from "../utils/AccessManagerOperations.s.sol";
import { ProtocolAdmin } from "../../../contracts/lib/ProtocolAdmin.sol";
import { GroupNFT } from "../../../contracts/GroupNFT.sol";
import { LicenseToken } from "../../../contracts/LicenseToken.sol";
import { IPGraphACL } from "../../../contracts/access/IPGraphACL.sol";
import { DisputeModule } from "../../../contracts/modules/dispute/DisputeModule.sol";
import { ArbitrationPolicyUMA } from "../../../contracts/modules/dispute/policies/UMA/ArbitrationPolicyUMA.sol";
import { GroupingModule } from "../../../contracts/modules/grouping/GroupingModule.sol";
import { RoyaltyModule } from "../../../contracts/modules/royalty/RoyaltyModule.sol";
import { VaultController } from "../../../contracts/modules/royalty/policies/VaultController.sol";
import { ProtocolPauseAdmin } from "../../../contracts/pause/ProtocolPauseAdmin.sol";
import { IPAssetRegistry } from "../../../contracts/registries/IPAssetRegistry.sol";
import { LicenseRegistry } from "../../../contracts/registries/LicenseRegistry.sol";
import { ModuleRegistry } from "../../../contracts/registries/ModuleRegistry.sol";

import { Script } from "forge-std/Script.sol";

// Mainnet
// forge script script/foundry/pause/GrantPauseRoleToSC.s.sol:GrantPauseRoleToSC --rpc-url https://mainnet.storyrpc.io --legacy --sig "run(bool)" false

// Aeneid real
// forge script script/foundry/pause/GrantPauseRoleToSC.s.sol:GrantPauseRoleToSC --rpc-url https://aeneid.storyrpc.io --legacy --sig "run(bool)" false

contract GrantPauseRoleToSC is Script, AccessManagerOperations {
    address constant ACCESS_CONTROLLER = 0xcCF37d0a503Ee1D4C11208672e622ed3DFB2275a;
    address constant DISPUTE_MODULE = 0x9b7A9c70AFF961C799110954fc06F3093aeb94C5;
    address constant ARBITRATION_POLICY_UMA = 0xfFD98c3877B8789124f02C7E8239A4b0Ef11E936;
    address constant EVEN_SPLIT_GROUP_POOL = 0xf96f2c30b41Cb6e0290de43C8528ae83d4f33F89;
    address constant GROUPING_MODULE = 0x69D3a7aa9edb72Bc226E745A7cCdd50D947b69Ac;
    address constant LICENSING_MODULE = 0x04fbd8a2e56dd85CFD5500A4A4DfA955B9f1dE6f;
    address constant ROYALTY_MODULE = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;
    address constant ROYALTY_POLICY_LAP = 0xBe54FB168b3c982b7AaE60dB6CF75Bd8447b390E;
    address constant ROYALTY_POLICY_LRP = 0x9156e603C949481883B1d3355c6f1132D191fC41;
    address constant IP_ASSET_REGISTRY = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;

    address sc1Addr = 0xc1583eF962954b123B5d043788f30Ef2450956b5;
    address sc2Addr = 0x83C24415F202e0370e164cfbd914A84138cC1Ae4;
    address sc3Addr = 0x576fa14594D1Ab7dc3fa7E08466E873321f5C95B;
    address sc4Addr = 0xBD4AD66012C443F87465E12CA91eDc42957aDD3A;
    address sc5Addr = 0xAF43958ad62389BE3E0B553dFd259Ec335814c1C;
    address sc6Addr = 0xAdCDF85a75200015B25685c453f5738333dC63A5;

    uint32 delay;
    address guardianSafeMultisig;
    address governanceSafeMultisig;

    function run(bool _isUnitTest) public {
        uint256 chainId = block.chainid;
        if (chainId != 1315 && chainId != 1514) revert("Invalid chain id");

        setAction("grant-pause-role-to-sc");
        setIsTest(_isUnitTest, false);      

        if (chainId == 1514) { 
            delay = 5 days;
            guardianSafeMultisig = 0x25D2605b2C768082A14E79713114389d0eC297D8;
            governanceSafeMultisig = 0xF07cA4b61022F0399C1511E7E668A57567f2138B;
        } else if (chainId == 1315) {
            delay = 10 minutes;
            guardianSafeMultisig = 0xC9a862Df1872402c4eAcbb8402F9BE628B52d270;
            governanceSafeMultisig = 0x4B089bF9340DdB02a011471Eaa7d8D81C60CB524;
        }

        protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);

        _checkInitialConditions();

        super.run();
    }

    function _checkInitialConditions() internal {
        // Pauser role
        (bool hasRolePauseAdmin1, ) = protocolAccessManager.hasRole(ProtocolAdmin.PAUSE_ADMIN_ROLE, governanceSafeMultisig);
        if (!hasRolePauseAdmin1) revert ("Pause admin role 1 not present");
    }

    function _generate() internal virtual override {
        address[] memory from = new address[](3);
        from[0] = governanceSafeMultisig;
        from[1] = governanceSafeMultisig;
        from[2] = governanceSafeMultisig;

        bytes4 selector = protocolAccessManager.grantRole.selector;

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, ProtocolAdmin.PAUSE_ADMIN_ROLE, sc1Addr, 0),
            delay
        );

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, ProtocolAdmin.PAUSE_ADMIN_ROLE, sc2Addr, 0),
            delay
        );

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, ProtocolAdmin.PAUSE_ADMIN_ROLE, sc3Addr, 0),
            delay
        );

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, ProtocolAdmin.PAUSE_ADMIN_ROLE, sc4Addr, 0),
            delay
        );

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, ProtocolAdmin.PAUSE_ADMIN_ROLE, sc5Addr, 0),
            delay
        );

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, ProtocolAdmin.PAUSE_ADMIN_ROLE, sc6Addr, 0),
            delay
        );
    }
}
