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

contract GrantNewAdminRole is Script, AccessManagerOperations {
    uint32 delay;
    address guardianSafeMultisig;
    address governanceSafeMultisig;
    address protocolAccessManagerAddr;
    address groupNftAddr;
    address licenseTokenAddr;
    address ipGraphACLAddr;
    address arbitrationPolicyUmaAddr;
    address disputeModuleAddr;
    address groupingModuleAddr;
    address ipAssetRegistryAddr;
    address licenseRegistryAddr;
    address moduleRegistryAddr;
    address royaltyModuleAddr;
    address protocolPauseAdminAddr;
    
    function run(bool _isUnitTest) public {
        uint256 chainId = block.chainid;
        if (chainId != 1315 && chainId != 1514) revert("Invalid chain id");

        setAction("grant-new-admin-role");
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

        protocolAccessManagerAddr = 0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53;
        groupNftAddr = 0x4709798FeA84C84ae2475fF0c25344115eE1529f;
        licenseTokenAddr = 0xFe3838BFb30B34170F00030B52eA4893d8aAC6bC;
        ipGraphACLAddr = 0x1640A22a8A086747cD377b73954545e2Dfcc9Cad;
        arbitrationPolicyUmaAddr = 0xfFD98c3877B8789124f02C7E8239A4b0Ef11E936;
        disputeModuleAddr = 0x9b7A9c70AFF961C799110954fc06F3093aeb94C5;
        groupingModuleAddr = 0x69D3a7aa9edb72Bc226E745A7cCdd50D947b69Ac;
        ipAssetRegistryAddr = 0x77319B4031e6eF1250907aa00018B8B1c67a244b;
        licenseRegistryAddr = 0x529a750E02d8E2f15649c13D69a465286a780e24;
        moduleRegistryAddr = 0x022DBAAeA5D8fB31a0Ad793335e39Ced5D631fa5;
        royaltyModuleAddr = 0xD2f60c40fEbccf6311f8B47c4f2Ec6b040400086;
        protocolPauseAdminAddr = 0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24;

        super.run();
    }

    function _generate() internal virtual override {
        address[] memory from = new address[](3);
        from[0] = governanceSafeMultisig;
        from[1] = governanceSafeMultisig;
        from[2] = governanceSafeMultisig;

        // add function selectors to new admin role        
        bytes4[] memory selectorsGroupNFT = new bytes4[](1);
        selectorsGroupNFT[0] = GroupNFT.setLicensingImageUrl.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, groupNftAddr, selectorsGroupNFT, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsLicenseToken = new bytes4[](1);
        selectorsLicenseToken[0] = LicenseToken.setLicensingImageUrl.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, licenseTokenAddr, selectorsLicenseToken, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsIPGraphACL = new bytes4[](2);
        selectorsIPGraphACL[0] = IPGraphACL.whitelistAddress.selector;
        selectorsIPGraphACL[1] = IPGraphACL.revokeWhitelistedAddress.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, ipGraphACLAddr, selectorsIPGraphACL, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsDisputeModule = new bytes4[](5);
        selectorsDisputeModule[0] = DisputeModule.whitelistDisputeTag.selector;
        selectorsDisputeModule[1] = DisputeModule.whitelistArbitrationPolicy.selector;
        selectorsDisputeModule[2] = DisputeModule.setArbitrationRelayer.selector;
        selectorsDisputeModule[3] = DisputeModule.setBaseArbitrationPolicy.selector;
        selectorsDisputeModule[4] = DisputeModule.setArbitrationPolicyCooldown.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, disputeModuleAddr, selectorsDisputeModule, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsArbitrationPolicyUMA = new bytes4[](3);
        selectorsArbitrationPolicyUMA[0] = ArbitrationPolicyUMA.setOOV3.selector;
        selectorsArbitrationPolicyUMA[1] = ArbitrationPolicyUMA.setLiveness.selector;
        selectorsArbitrationPolicyUMA[2] = ArbitrationPolicyUMA.setMaxBond.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, arbitrationPolicyUmaAddr, selectorsArbitrationPolicyUMA, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsGroupingModule = new bytes4[](1);
        selectorsGroupingModule[0] = GroupingModule.whitelistGroupRewardPool.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, groupingModuleAddr, selectorsGroupingModule, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsRoyaltyModule = new bytes4[](5);
        selectorsRoyaltyModule[0] = RoyaltyModule.setTreasury.selector;
        selectorsRoyaltyModule[1] = RoyaltyModule.setRoyaltyFeePercent.selector;
        selectorsRoyaltyModule[2] = RoyaltyModule.setRoyaltyLimits.selector;
        selectorsRoyaltyModule[3] = RoyaltyModule.whitelistRoyaltyPolicy.selector;
        selectorsRoyaltyModule[4] = RoyaltyModule.whitelistRoyaltyToken.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, royaltyModuleAddr, selectorsRoyaltyModule, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsVaultController = new bytes4[](1);
        selectorsVaultController[0] = VaultController.setIpRoyaltyVaultBeacon.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, royaltyModuleAddr, selectorsVaultController, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsProtocolPauseAdmin = new bytes4[](2);
        selectorsProtocolPauseAdmin[0] = ProtocolPauseAdmin.addPausable.selector;
        selectorsProtocolPauseAdmin[1] = ProtocolPauseAdmin.removePausable.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, protocolPauseAdminAddr, selectorsProtocolPauseAdmin, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsIPAssetRegistry = new bytes4[](1);
        selectorsIPAssetRegistry[0] = IPAssetRegistry.setRegistrationFee.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, ipAssetRegistryAddr, selectorsIPAssetRegistry, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsLicenseRegistry = new bytes4[](2);
        selectorsLicenseRegistry[0] = LicenseRegistry.setDefaultLicenseTerms.selector;
        selectorsLicenseRegistry[1] = LicenseRegistry.registerLicenseTemplate.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, licenseRegistryAddr, selectorsLicenseRegistry, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        bytes4[] memory selectorsModuleRegistry = new bytes4[](5);
        selectorsModuleRegistry[0] = ModuleRegistry.registerModuleType.selector;
        selectorsModuleRegistry[1] = ModuleRegistry.removeModuleType.selector;
        selectorsModuleRegistry[2] = bytes4(keccak256("registerModule(string,address)"));
        selectorsModuleRegistry[3] = bytes4(keccak256("registerModule(string,address,string)"));
        selectorsModuleRegistry[4] = ModuleRegistry.removeModule.selector;
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setTargetFunctionRole.selector, moduleRegistryAddr, selectorsModuleRegistry, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE),
            delay
        );

        // create label for role
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.labelRole.selector, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE_LABEL),
            delay
        );

        // set guardian role for new admin role
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.setRoleGuardian.selector, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE, ProtocolAdmin.GUARDIAN_ROLE),
            delay
        );

        // grant new admin role to governanceSafeMultisig
        _generateAction(
            from,
            address(protocolAccessManagerAddr),
            0,
            abi.encodeWithSelector(AccessManager.grantRole.selector, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE, governanceSafeMultisig, delay),
            delay
        );
    }
}