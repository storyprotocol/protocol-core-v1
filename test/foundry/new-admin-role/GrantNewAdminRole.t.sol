// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { Multicall } from "@openzeppelin/contracts/utils/Multicall.sol";

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

import { GrantNewAdminRole } from "../../../script/foundry/new-admin-role/GrantNewAdminRole.s.sol";
import { JSONTxWriter } from "../../../script/foundry/utils/JSONTxWriter.s.sol";

import { stdJson } from "forge-std/StdJson.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";
// solhint-disable-next-line
import { console2 } from "forge-std/console2.sol";

contract GrantRolesToSafeTest is BaseTest {
    event RoleLabel(uint64 indexed roleId, string label);

    // Maximum number of transactions in JSON files
    uint256 public constant MAX_TXS_PER_JSON = 1000;

    string public constant OUTPUT_DIR = "./script/foundry/admin-actions/output-test/";

    address securityCouncilSafeMultisig;
    address governanceSafeMultisig;
    uint256 delay;

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

    bytes[] scheduleCalls;
    bytes[] executeCalls;
    bytes[] cancelCalls;

    function setUp() public override {
        // Fork mainnet
        uint256 forkId = vm.createFork("https://mainnet.storyrpc.io/");
        vm.selectFork(forkId);

        // relevant addresses
        protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);
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

        uint256 chainId = block.chainid;
        if (chainId == 1514) {
            delay = 5 days;
            securityCouncilSafeMultisig = 0x25D2605b2C768082A14E79713114389d0eC297D8;
            governanceSafeMultisig = 0xF07cA4b61022F0399C1511E7E668A57567f2138B;
        } else if (chainId == 1315) {
            delay = 10 minutes;
            securityCouncilSafeMultisig = 0xC9a862Df1872402c4eAcbb8402F9BE628B52d270;
            governanceSafeMultisig = 0x4B089bF9340DdB02a011471Eaa7d8D81C60CB524;
        }

        GrantNewAdminRole deployScript = new GrantNewAdminRole();
        deployScript.run(true);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        ) = _readNonRegularTransactionFiles("grant-new-admin-role");

        assertEq(scheduleTxs.length, 15);
        assertEq(executeTxs.length, 15);
        assertEq(cancelTxs.length, 15);

        // Convert scheduleTxs to bytes array for multicall
        scheduleCalls = new bytes[](scheduleTxs.length);
        for (uint256 i = 0; i < scheduleTxs.length; i++) {
            scheduleCalls[i] = scheduleTxs[i].data;
        }

        // Convert executeTxs to bytes array for multicall
        executeCalls = new bytes[](executeTxs.length);
        for (uint256 i = 0; i < executeTxs.length; i++) {
            executeCalls[i] = executeTxs[i].data;
        }

        // Convert cancelTxs to bytes array for multicall
        cancelCalls = new bytes[](cancelTxs.length);
        for (uint256 i = 0; i < cancelTxs.length; i++) {
            cancelCalls[i] = cancelTxs[i].data;
        }
    }

    function test_cancelTxs() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);

        Multicall(address(protocolAccessManager)).multicall(cancelCalls);

        vm.expectRevert();
        Multicall(address(protocolAccessManager)).multicall(executeCalls);
    }

    function test_GroupNFT_setLicensingImageUrl() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(GroupNFT.setLicensingImageUrl.selector, "https://example.com");
        (bytes32 operationId, ) = protocolAccessManager.schedule(groupNftAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, groupNftAddr, data);

        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_LicenseToken_setLicensingImageUrl() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(LicenseToken.setLicensingImageUrl.selector, "https://example.com");
        (bytes32 operationId, ) = protocolAccessManager.schedule(licenseTokenAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, licenseTokenAddr, data);

        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_IPGraphACL_whitelistAddress() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(IPGraphACL.whitelistAddress.selector, address(1));
        (bytes32 operationId, ) = protocolAccessManager.schedule(ipGraphACLAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, ipGraphACLAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_IPGraphACL_revokeWhitelistedAddress() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(IPGraphACL.revokeWhitelistedAddress.selector, address(1));
        (bytes32 operationId, ) = protocolAccessManager.schedule(ipGraphACLAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, ipGraphACLAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_DisputeModule_whitelistDisputeTag() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(DisputeModule.whitelistDisputeTag.selector, "example", true);
        (bytes32 operationId, ) = protocolAccessManager.schedule(disputeModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, disputeModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_DisputeModule_whitelistArbitrationPolicy() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(DisputeModule.whitelistArbitrationPolicy.selector, address(1), true);
        (bytes32 operationId, ) = protocolAccessManager.schedule(disputeModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, disputeModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_DisputeModule_setArbitrationRelayer() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(
            DisputeModule.setArbitrationRelayer.selector,
            address(1),
            address(1)
        );
        (bytes32 operationId, ) = protocolAccessManager.schedule(disputeModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, disputeModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_DisputeModule_setBaseArbitrationPolicy() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(DisputeModule.setBaseArbitrationPolicy.selector, address(1));
        (bytes32 operationId, ) = protocolAccessManager.schedule(disputeModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, disputeModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_DisputeModule_setArbitrationPolicyCooldown() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(DisputeModule.setArbitrationPolicyCooldown.selector, uint256(100));
        (bytes32 operationId, ) = protocolAccessManager.schedule(disputeModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, disputeModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ArbitrationPolicyUMA_setOOV3() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(ArbitrationPolicyUMA.setOOV3.selector, address(1));
        (bytes32 operationId, ) = protocolAccessManager.schedule(arbitrationPolicyUmaAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, arbitrationPolicyUmaAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ArbitrationPolicyUMA_setLiveness() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(
            ArbitrationPolicyUMA.setLiveness.selector,
            uint64(100),
            uint64(100),
            uint32(100)
        );
        (bytes32 operationId, ) = protocolAccessManager.schedule(arbitrationPolicyUmaAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, arbitrationPolicyUmaAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ArbitrationPolicyUMA_setMaxBond() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(ArbitrationPolicyUMA.setMaxBond.selector, address(1), uint256(100));
        (bytes32 operationId, ) = protocolAccessManager.schedule(arbitrationPolicyUmaAddr, data, 0);

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, arbitrationPolicyUmaAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_GroupingModule_whitelistGroupRewardPool() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(GroupingModule.whitelistGroupRewardPool.selector, address(1), true);
        (bytes32 operationId, ) = protocolAccessManager.schedule(groupingModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, groupingModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_RoyaltyModule_setTreasury() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(RoyaltyModule.setTreasury.selector, address(1));
        (bytes32 operationId, ) = protocolAccessManager.schedule(royaltyModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, royaltyModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_RoyaltyModule_setRoyaltyFeePercent() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(RoyaltyModule.setRoyaltyFeePercent.selector, uint32(100));
        (bytes32 operationId, ) = protocolAccessManager.schedule(royaltyModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, royaltyModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_RoyaltyModule_setRoyaltyLimits() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(RoyaltyModule.setRoyaltyLimits.selector, uint256(100));
        (bytes32 operationId, ) = protocolAccessManager.schedule(royaltyModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, royaltyModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_RoyaltyModule_whitelistRoyaltyPolicy() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(RoyaltyModule.whitelistRoyaltyPolicy.selector, address(1), true);
        (bytes32 operationId, ) = protocolAccessManager.schedule(royaltyModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, royaltyModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_RoyaltyModule_whitelistRoyaltyToken() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(RoyaltyModule.whitelistRoyaltyToken.selector, address(1), true);
        (bytes32 operationId, ) = protocolAccessManager.schedule(royaltyModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, royaltyModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_VaultController_setIpRoyaltyVaultBeacon() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(VaultController.setIpRoyaltyVaultBeacon.selector, address(1));
        (bytes32 operationId, ) = protocolAccessManager.schedule(royaltyModuleAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, royaltyModuleAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ProtocolPauseAdmin_addPausable() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(ProtocolPauseAdmin.addPausable.selector, address(1));
        (bytes32 operationId, ) = protocolAccessManager.schedule(protocolPauseAdminAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, protocolPauseAdminAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ProtocolPauseAdmin_removePausable() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(ProtocolPauseAdmin.removePausable.selector, address(1));
        (bytes32 operationId, ) = protocolAccessManager.schedule(protocolPauseAdminAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, protocolPauseAdminAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_IPAssetRegistry_setRegistrationFee() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(
            IPAssetRegistry.setRegistrationFee.selector,
            address(1),
            address(1),
            uint96(100)
        );
        (bytes32 operationId, ) = protocolAccessManager.schedule(ipAssetRegistryAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, ipAssetRegistryAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_LicenseRegistry_setDefaultLicenseTerms() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(
            LicenseRegistry.setDefaultLicenseTerms.selector,
            address(1),
            uint256(1)
        );
        (bytes32 operationId, ) = protocolAccessManager.schedule(licenseRegistryAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, licenseRegistryAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_LicenseRegistry_registerLicenseTemplate() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(LicenseRegistry.registerLicenseTemplate.selector, address(1));
        (bytes32 operationId, ) = protocolAccessManager.schedule(licenseRegistryAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, licenseRegistryAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ModuleRegistry_registerModuleType() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(
            ModuleRegistry.registerModuleType.selector,
            "TestModule",
            bytes4(keccak256("testModule"))
        );
        (bytes32 operationId, ) = protocolAccessManager.schedule(moduleRegistryAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, moduleRegistryAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ModuleRegistry_removeModuleType() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(ModuleRegistry.removeModuleType.selector, "TestModule");
        (bytes32 operationId, ) = protocolAccessManager.schedule(moduleRegistryAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, moduleRegistryAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ModuleRegistry_registerModule1() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("registerModule(string,address)")),
            "TestModule",
            address(1)
        );
        (bytes32 operationId, ) = protocolAccessManager.schedule(moduleRegistryAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, moduleRegistryAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ModuleRegistry_registerModule2() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(
            bytes4(keccak256("registerModule(string,address,string)")),
            "TestModule",
            address(1),
            "TestModule"
        );
        (bytes32 operationId, ) = protocolAccessManager.schedule(moduleRegistryAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, moduleRegistryAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_ModuleRegistry_removeModule() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);
        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        bytes memory data = abi.encodeWithSelector(ModuleRegistry.removeModule.selector, "TestModule");
        (bytes32 operationId, ) = protocolAccessManager.schedule(moduleRegistryAddr, data, 0);
        vm.stopPrank();

        assertEq(protocolAccessManager.getSchedule(operationId), block.timestamp + delay);

        vm.startPrank(securityCouncilSafeMultisig);
        protocolAccessManager.cancel(governanceSafeMultisig, moduleRegistryAddr, data);
        assertEq(protocolAccessManager.getSchedule(operationId), 0);
    }

    function test_labelRole() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);

        vm.expectEmit(true, true, true, true);
        emit RoleLabel(ProtocolAdmin.CANCELLABLE_ADMIN_ROLE, ProtocolAdmin.CANCELLABLE_ADMIN_ROLE_LABEL);

        Multicall(address(protocolAccessManager)).multicall(executeCalls);
    }

    function test_setRoleGuardian() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);

        assertEq(protocolAccessManager.getRoleGuardian(ProtocolAdmin.CANCELLABLE_ADMIN_ROLE), 0);

        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        assertEq(protocolAccessManager.getRoleGuardian(ProtocolAdmin.CANCELLABLE_ADMIN_ROLE), 3);
    }

    function test_grantRole() public {
        vm.startPrank(governanceSafeMultisig);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delay + 1);

        (bool isMemberBefore, uint32 executionDelayBefore) = protocolAccessManager.hasRole(
            ProtocolAdmin.CANCELLABLE_ADMIN_ROLE,
            governanceSafeMultisig
        );

        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        (bool isMemberAfter, uint32 executionDelayAfter) = protocolAccessManager.hasRole(
            ProtocolAdmin.CANCELLABLE_ADMIN_ROLE,
            governanceSafeMultisig
        );

        assertEq(isMemberBefore, false);
        assertEq(executionDelayBefore, 0);
        assertEq(isMemberAfter, true);
        assertEq(executionDelayAfter, delay);
    }

    /**
     * @notice Read transactions from schedule, cancel, and execute JSON files
     * @param baseFilename The base filename without suffix (-schedule, -cancel, -execute)
     * @return scheduleTxs Transaction struct from schedule file
     * @return executeTxs Transaction struct from execute file
     * @return cancelTxs Transaction struct from cancel file
     */
    function _readNonRegularTransactionFiles(
        string memory baseFilename
    )
        internal
        returns (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        )
    {
        // Create paths for all three file types
        string memory outputDir = OUTPUT_DIR;
        string memory basePath = string.concat(outputDir, vm.toString(block.chainid), "/");
        string memory schedulePath = string.concat(basePath, baseFilename, "-schedule.json");
        string memory cancelPath = string.concat(basePath, baseFilename, "-cancel.json");
        string memory executePath = string.concat(basePath, baseFilename, "-execute.json");

        // Read schedule transaction
        assertTrue(vm.exists(schedulePath), "Schedule JSON file not found");
        string memory scheduleJson = vm.readFile(schedulePath);
        JSONTxWriter.Transaction[] memory scheduleTxs = _parseTransactionsFromJson(scheduleJson);

        // Read cancel transaction
        assertTrue(vm.exists(cancelPath), "Cancel JSON file not found");
        string memory cancelJson = vm.readFile(cancelPath);
        JSONTxWriter.Transaction[] memory cancelTxs = _parseTransactionsFromJson(cancelJson);

        // Read execute transaction
        assertTrue(vm.exists(executePath), "Execute JSON file not found");
        string memory executeJson = vm.readFile(executePath);
        JSONTxWriter.Transaction[] memory executeTxs = _parseTransactionsFromJson(executeJson);

        return (scheduleTxs, executeTxs, cancelTxs);
    }

    /**
     * @notice Parse a JSON string into an array of Transaction structs
     * @param json The JSON string to parse
     * @return An array of Transaction structs
     */
    function _parseTransactionsFromJson(string memory json) internal view returns (JSONTxWriter.Transaction[] memory) {
        // Get the number of transactions in the JSON array
        // Create an array to store the transactions
        JSONTxWriter.Transaction[] memory readTxs = new JSONTxWriter.Transaction[](MAX_TXS_PER_JSON);
        uint256 effectiveTxs = 0;
        // Parse each transaction in the array
        for (uint256 i = 0; i < MAX_TXS_PER_JSON; i++) {
            try this._parseTransaction(json, i) returns (JSONTxWriter.Transaction memory transaction) {
                readTxs[i] = transaction;
                effectiveTxs++;
            } catch {
                // solhint-disable-next-line
                console2.log("No more transactions in JSON");
                break;
            }
        }

        JSONTxWriter.Transaction[] memory transactions = new JSONTxWriter.Transaction[](effectiveTxs);
        for (uint256 i = 0; i < effectiveTxs; i++) {
            transactions[i] = readTxs[i];
        }
        return transactions;
    }

    function _parseTransaction(
        string memory json,
        uint256 index
    ) external pure returns (JSONTxWriter.Transaction memory transaction) {
        string memory indexPath = string.concat("[", vm.toString(index), "]");

        address from = stdJson.readAddress(json, string.concat(indexPath, ".from"));
        address to = stdJson.readAddress(json, string.concat(indexPath, ".to"));
        uint256 value = stdJson.readUint(json, string.concat(indexPath, ".value"));
        bytes memory data = stdJson.readBytes(json, string.concat(indexPath, ".data"));
        uint8 operation = uint8(stdJson.readUint(json, string.concat(indexPath, ".operation")));
        string memory comment = stdJson.readString(json, string.concat(indexPath, ".comment"));

        // Create the transaction struct
        return
            JSONTxWriter.Transaction({
                from: from,
                to: to,
                value: value,
                data: data,
                operation: operation,
                comment: comment
            });
    }
}
