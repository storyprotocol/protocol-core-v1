// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { Multicall } from "@openzeppelin/contracts/utils/Multicall.sol";

import { GrantRolesToSafe } from "../../../script/foundry/migrate-to-safe/1.GrantRolesToSafe.s.sol";
import { RemoveRolesFromNonSafe } from "../../../script/foundry/migrate-to-safe/2.RemoveRolesFromNonSafe.s.sol";
import { JSONTxWriter } from "../../../script/foundry/utils/JSONTxWriter.s.sol";

import { stdJson } from "forge-std/StdJson.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";
// solhint-disable-next-line
import { console2 } from "forge-std/console2.sol";

contract GrantRolesToSafeTest is BaseTest {
    // Maximum number of transactions in JSON files
    uint256 public constant MAX_TXS_PER_JSON = 1000;

    string public constant OUTPUT_DIR = "./script/foundry/admin-actions/output-test/";

    uint64 public constant ADMIN_ROLE_ID = 0;
    uint64 public constant UPGRADER_ROLE_ID = 1;
    uint64 public constant PAUSE_ROLE_ID = 2;
    uint64 public constant GUARDIAN_ROLE_ID = 3;

    uint256 public delayMainnet;
    address public oldAdminMainnet;
    address public oldUpgraderMainnet;
    address public oldPauseAdmin1Mainnet;
    address public oldPauseAdmin2Mainnet;
    address public oldGuardianMainnet;

    uint256 public delayAeneid;
    address public oldAdminAeneid;
    address public oldUpgraderAeneid;
    address public oldPauseAdmin1Aeneid;
    address public oldPauseAdmin2Aeneid;
    address public oldGuardianAeneid;

    address public governanceSafeMultisigMainnet;
    address public securityCouncilSafeMultisigMainnet;
    address public governanceSafeMultisigAeneid;
    address public securityCouncilSafeMultisigAeneid;

    function setUp() public override {
        // Mainnet
        delayMainnet = 5 days;
        oldAdminMainnet = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
        oldUpgraderMainnet = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
        oldPauseAdmin1Mainnet = 0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24;
        oldPauseAdmin2Mainnet = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
        oldGuardianMainnet = 0x76430daA671BE12200Cd424Ea6bdd8129A769033;
        governanceSafeMultisigMainnet = address(1);
        securityCouncilSafeMultisigMainnet = address(2);

        // Aeneid
        delayAeneid = 10 minutes;
        oldAdminAeneid = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
        oldUpgraderAeneid = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
        oldPauseAdmin1Aeneid = 0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24;
        oldPauseAdmin2Aeneid = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
        oldGuardianAeneid = address(0);
        governanceSafeMultisigAeneid = address(3);
        securityCouncilSafeMultisigAeneid = address(4);
    }

    function test_RemoveRoles_Mainnet_Success() public {
        protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);
        // Fork mainnet
        uint256 forkId = vm.createFork("https://mainnet.storyrpc.io/");
        vm.selectFork(forkId);

        GrantRolesToSafe deployScript = new GrantRolesToSafe();
        deployScript.run(governanceSafeMultisigMainnet, securityCouncilSafeMultisigMainnet, true, false);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        ) = _readNonRegularTransactionFiles("grant-roles-to-safe");

        assertEq(scheduleTxs.length, 4);
        assertEq(executeTxs.length, 4);
        assertEq(cancelTxs.length, 4);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls = new bytes[](scheduleTxs.length);
        for (uint256 i = 0; i < scheduleTxs.length; i++) {
            scheduleCalls[i] = scheduleTxs[i].data;
        }

        // Convert executeTxs to bytes array for multicall
        bytes[] memory executeCalls = new bytes[](executeTxs.length);
        for (uint256 i = 0; i < executeTxs.length; i++) {
            executeCalls[i] = executeTxs[i].data;
        }

        vm.startPrank(oldAdminMainnet);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);

        skip(delayMainnet + 1);

        Multicall(address(protocolAccessManager)).multicall(executeCalls);
        vm.stopPrank();

        skip(delayMainnet + 1);

        RemoveRolesFromNonSafe deployScript2 = new RemoveRolesFromNonSafe();
        deployScript2.run(governanceSafeMultisigMainnet, securityCouncilSafeMultisigMainnet, true, false);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs2,
            JSONTxWriter.Transaction[] memory executeTxs2,
            JSONTxWriter.Transaction[] memory cancelTxs2
        ) = _readNonRegularTransactionFiles("remove-roles-from-non-safe");

        assertEq(scheduleTxs2.length, 5);
        assertEq(executeTxs2.length, 5);
        assertEq(cancelTxs2.length, 5);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls2 = new bytes[](scheduleTxs2.length);
        for (uint256 i = 0; i < scheduleTxs2.length; i++) {
            scheduleCalls2[i] = scheduleTxs2[i].data;
        }

        // Convert executeTxs to bytes array for multicall
        bytes[] memory executeCalls2 = new bytes[](executeTxs2.length);
        for (uint256 i = 0; i < executeTxs2.length; i++) {
            executeCalls2[i] = executeTxs2[i].data;
        }

        vm.startPrank(governanceSafeMultisigMainnet);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls2);

        skip(delayMainnet + 1);

        (bool hasRoleOldAdminBefore, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdminMainnet);
        (bool hasRoleOldUpgraderBefore, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgraderMainnet);
        (bool hasRoleOldPauseAdmin1Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1Mainnet);
        (bool hasRoleOldPauseAdmin2Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2Mainnet);
        (bool hasRoleOldGuardianBefore, ) = protocolAccessManager.hasRole(GUARDIAN_ROLE_ID, oldGuardianMainnet);

        Multicall(address(protocolAccessManager)).multicall(executeCalls2);

        skip(delayMainnet + 1);

        (bool hasRoleOldAdminAfter, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdminMainnet);
        (bool hasRoleOldUpgraderAfter, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgraderMainnet);
        (bool hasRoleOldPauseAdmin1After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1Mainnet);
        (bool hasRoleOldPauseAdmin2After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2Mainnet);
        (bool hasRoleOldGuardianAfter, ) = protocolAccessManager.hasRole(GUARDIAN_ROLE_ID, oldGuardianMainnet);

        (bool hasRoleSafeAdminAfter, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, governanceSafeMultisigMainnet);
        (bool hasRoleSafeUpgradeAfter, ) = protocolAccessManager.hasRole(
            UPGRADER_ROLE_ID,
            governanceSafeMultisigMainnet
        );
        (bool hasRoleSafePauseAfter, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, governanceSafeMultisigMainnet);
        (bool hasRoleSafeGuardianAfter, ) = protocolAccessManager.hasRole(
            GUARDIAN_ROLE_ID,
            securityCouncilSafeMultisigMainnet
        );

        assertEq(hasRoleOldAdminBefore, true);
        assertEq(hasRoleOldUpgraderBefore, true);
        assertEq(hasRoleOldPauseAdmin1Before, true);
        assertEq(hasRoleOldPauseAdmin2Before, true);
        assertEq(hasRoleOldGuardianBefore, true);

        assertEq(hasRoleOldAdminAfter, false);
        assertEq(hasRoleOldUpgraderAfter, false);
        assertEq(hasRoleOldPauseAdmin1After, false);
        assertEq(hasRoleOldPauseAdmin2After, false);
        assertEq(hasRoleOldGuardianAfter, false);

        assertEq(hasRoleSafeAdminAfter, true);
        assertEq(hasRoleSafeUpgradeAfter, true);
        assertEq(hasRoleSafePauseAfter, true);
        assertEq(hasRoleSafeGuardianAfter, true);
    }

    function test_RemoveRoles_Mainnet_Cancel() public {
        protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);
        // Fork mainnet
        uint256 forkId = vm.createFork("https://mainnet.storyrpc.io/");
        vm.selectFork(forkId);

        GrantRolesToSafe deployScript = new GrantRolesToSafe();
        deployScript.run(governanceSafeMultisigMainnet, securityCouncilSafeMultisigMainnet, true, false);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        ) = _readNonRegularTransactionFiles("grant-roles-to-safe");

        assertEq(scheduleTxs.length, 4);
        assertEq(executeTxs.length, 4);
        assertEq(cancelTxs.length, 4);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls = new bytes[](scheduleTxs.length);
        for (uint256 i = 0; i < scheduleTxs.length; i++) {
            scheduleCalls[i] = scheduleTxs[i].data;
        }

        // Convert executeTxs to bytes array for multicall
        bytes[] memory executeCalls = new bytes[](executeTxs.length);
        for (uint256 i = 0; i < executeTxs.length; i++) {
            executeCalls[i] = executeTxs[i].data;
        }

        vm.startPrank(oldAdminMainnet);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);

        skip(delayMainnet + 1);

        Multicall(address(protocolAccessManager)).multicall(executeCalls);
        vm.stopPrank();

        skip(delayMainnet + 1);

        RemoveRolesFromNonSafe deployScript2 = new RemoveRolesFromNonSafe();
        deployScript2.run(governanceSafeMultisigMainnet, securityCouncilSafeMultisigMainnet, true, false);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs2,
            JSONTxWriter.Transaction[] memory executeTxs2,
            JSONTxWriter.Transaction[] memory cancelTxs2
        ) = _readNonRegularTransactionFiles("remove-roles-from-non-safe");

        assertEq(scheduleTxs2.length, 5);
        assertEq(executeTxs2.length, 5);
        assertEq(cancelTxs2.length, 5);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls2 = new bytes[](scheduleTxs2.length);
        for (uint256 i = 0; i < scheduleTxs2.length; i++) {
            scheduleCalls2[i] = scheduleTxs2[i].data;
        }

        // Convert executeTxs to bytes array for multicall
        bytes[] memory cancelCalls2 = new bytes[](cancelTxs2.length);
        for (uint256 i = 0; i < cancelTxs2.length; i++) {
            cancelCalls2[i] = cancelTxs2[i].data;
        }

        vm.startPrank(governanceSafeMultisigMainnet);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls2);

        skip(delayMainnet + 1);

        (bool hasRoleOldAdminBefore, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdminMainnet);
        (bool hasRoleOldUpgraderBefore, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgraderMainnet);
        (bool hasRoleOldPauseAdmin1Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1Mainnet);
        (bool hasRoleOldPauseAdmin2Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2Mainnet);
        (bool hasRoleOldGuardianBefore, ) = protocolAccessManager.hasRole(GUARDIAN_ROLE_ID, oldGuardianMainnet);

        Multicall(address(protocolAccessManager)).multicall(cancelCalls2);

        skip(delayMainnet + 1);

        (bool hasRoleOldAdminAfter, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdminMainnet);
        (bool hasRoleOldUpgraderAfter, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgraderMainnet);
        (bool hasRoleOldPauseAdmin1After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1Mainnet);
        (bool hasRoleOldPauseAdmin2After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2Mainnet);
        (bool hasRoleOldGuardianAfter, ) = protocolAccessManager.hasRole(GUARDIAN_ROLE_ID, oldGuardianMainnet);

        (bool hasRoleSafeAdminAfter, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, governanceSafeMultisigMainnet);
        (bool hasRoleSafeUpgradeAfter, ) = protocolAccessManager.hasRole(
            UPGRADER_ROLE_ID,
            governanceSafeMultisigMainnet
        );
        (bool hasRoleSafePauseAfter, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, governanceSafeMultisigMainnet);
        (bool hasRoleSafeGuardianAfter, ) = protocolAccessManager.hasRole(
            GUARDIAN_ROLE_ID,
            securityCouncilSafeMultisigMainnet
        );

        assertEq(hasRoleOldAdminBefore, true);
        assertEq(hasRoleOldUpgraderBefore, true);
        assertEq(hasRoleOldPauseAdmin1Before, true);
        assertEq(hasRoleOldPauseAdmin2Before, true);
        assertEq(hasRoleOldGuardianBefore, true);

        assertEq(hasRoleOldAdminAfter, true);
        assertEq(hasRoleOldUpgraderAfter, true);
        assertEq(hasRoleOldPauseAdmin1After, true);
        assertEq(hasRoleOldPauseAdmin2After, true);
        assertEq(hasRoleOldGuardianAfter, true);

        assertEq(hasRoleSafeAdminAfter, true);
        assertEq(hasRoleSafeUpgradeAfter, true);
        assertEq(hasRoleSafePauseAfter, true);
        assertEq(hasRoleSafeGuardianAfter, true);
    }

    function test_RemoveRoles_Aeneid_Success() public {
        protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);
        // Fork aeneid
        uint256 forkId = vm.createFork("https://aeneid.storyrpc.io/");
        vm.selectFork(forkId);

        GrantRolesToSafe deployScript = new GrantRolesToSafe();
        deployScript.run(governanceSafeMultisigAeneid, securityCouncilSafeMultisigAeneid, true, false);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        ) = _readNonRegularTransactionFiles("grant-roles-to-safe");

        assertEq(scheduleTxs.length, 4);
        assertEq(executeTxs.length, 4);
        assertEq(cancelTxs.length, 4);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls = new bytes[](scheduleTxs.length);
        for (uint256 i = 0; i < scheduleTxs.length; i++) {
            scheduleCalls[i] = scheduleTxs[i].data;
        }

        // Convert executeTxs to bytes array for multicall
        bytes[] memory executeCalls = new bytes[](executeTxs.length);
        for (uint256 i = 0; i < executeTxs.length; i++) {
            executeCalls[i] = executeTxs[i].data;
        }

        vm.startPrank(oldAdminAeneid);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);

        skip(delayAeneid + 1);

        Multicall(address(protocolAccessManager)).multicall(executeCalls);
        vm.stopPrank();

        skip(delayAeneid + 1);

        RemoveRolesFromNonSafe deployScript2 = new RemoveRolesFromNonSafe();
        deployScript2.run(governanceSafeMultisigAeneid, securityCouncilSafeMultisigAeneid, true, false);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs2,
            JSONTxWriter.Transaction[] memory executeTxs2,
            JSONTxWriter.Transaction[] memory cancelTxs2
        ) = _readNonRegularTransactionFiles("remove-roles-from-non-safe");

        assertEq(scheduleTxs2.length, 4);
        assertEq(executeTxs2.length, 4);
        assertEq(cancelTxs2.length, 4);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls2 = new bytes[](scheduleTxs2.length);
        for (uint256 i = 0; i < scheduleTxs2.length; i++) {
            scheduleCalls2[i] = scheduleTxs2[i].data;
        }

        // Convert executeTxs to bytes array for multicall
        bytes[] memory executeCalls2 = new bytes[](executeTxs2.length);
        for (uint256 i = 0; i < executeTxs2.length; i++) {
            executeCalls2[i] = executeTxs2[i].data;
        }

        vm.startPrank(governanceSafeMultisigAeneid);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls2);
        vm.stopPrank();

        skip(delayAeneid + 1);

        (bool hasRoleOldAdminBefore, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdminAeneid);
        (bool hasRoleOldUpgraderBefore, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgraderAeneid);
        (bool hasRoleOldPauseAdmin1Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1Aeneid);
        (bool hasRoleOldPauseAdmin2Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2Aeneid);

        vm.startPrank(governanceSafeMultisigAeneid);
        Multicall(address(protocolAccessManager)).multicall(executeCalls2);
        vm.stopPrank();

        skip(delayAeneid + 1);

        (bool hasRoleOldAdminAfter, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdminAeneid);
        (bool hasRoleOldUpgraderAfter, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgraderAeneid);
        (bool hasRoleOldPauseAdmin1After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1Aeneid);
        (bool hasRoleOldPauseAdmin2After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2Aeneid);

        (bool hasRoleSafeAdminAfter, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, governanceSafeMultisigAeneid);
        (bool hasRoleSafeUpgradeAfter, ) = protocolAccessManager.hasRole(
            UPGRADER_ROLE_ID,
            governanceSafeMultisigAeneid
        );
        (bool hasRoleSafePauseAfter, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, governanceSafeMultisigAeneid);
        (bool hasRoleSafeGuardianAfter, ) = protocolAccessManager.hasRole(
            GUARDIAN_ROLE_ID,
            securityCouncilSafeMultisigAeneid
        );

        assertEq(hasRoleOldAdminBefore, true);
        assertEq(hasRoleOldUpgraderBefore, true);
        assertEq(hasRoleOldPauseAdmin1Before, true);
        assertEq(hasRoleOldPauseAdmin2Before, true);

        assertEq(hasRoleOldAdminAfter, false);
        assertEq(hasRoleOldUpgraderAfter, false);
        assertEq(hasRoleOldPauseAdmin1After, false);
        assertEq(hasRoleOldPauseAdmin2After, false);

        assertEq(hasRoleSafeAdminAfter, true);
        assertEq(hasRoleSafeUpgradeAfter, true);
        assertEq(hasRoleSafePauseAfter, true);
        assertEq(hasRoleSafeGuardianAfter, true);
    }

    function test_RemoveRoles_Aeneid_Cancel() public {
        protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);
        // Fork aeneid
        uint256 forkId = vm.createFork("https://aeneid.storyrpc.io/");
        vm.selectFork(forkId);

        GrantRolesToSafe deployScript = new GrantRolesToSafe();
        deployScript.run(governanceSafeMultisigAeneid, securityCouncilSafeMultisigAeneid, true, false);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        ) = _readNonRegularTransactionFiles("grant-roles-to-safe");

        assertEq(scheduleTxs.length, 4);
        assertEq(executeTxs.length, 4);
        assertEq(cancelTxs.length, 4);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls = new bytes[](scheduleTxs.length);
        for (uint256 i = 0; i < scheduleTxs.length; i++) {
            scheduleCalls[i] = scheduleTxs[i].data;
        }

        // Convert executeTxs to bytes array for multicall
        bytes[] memory executeCalls = new bytes[](executeTxs.length);
        for (uint256 i = 0; i < executeTxs.length; i++) {
            executeCalls[i] = executeTxs[i].data;
        }

        vm.startPrank(oldAdminAeneid);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);

        skip(delayAeneid + 1);

        Multicall(address(protocolAccessManager)).multicall(executeCalls);
        vm.stopPrank();

        skip(delayAeneid + 1);

        RemoveRolesFromNonSafe deployScript2 = new RemoveRolesFromNonSafe();
        deployScript2.run(governanceSafeMultisigAeneid, securityCouncilSafeMultisigAeneid, true, false);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs2,
            JSONTxWriter.Transaction[] memory executeTxs2,
            JSONTxWriter.Transaction[] memory cancelTxs2
        ) = _readNonRegularTransactionFiles("remove-roles-from-non-safe");

        assertEq(scheduleTxs2.length, 4);
        assertEq(executeTxs2.length, 4);
        assertEq(cancelTxs2.length, 4);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls2 = new bytes[](scheduleTxs2.length);
        for (uint256 i = 0; i < scheduleTxs2.length; i++) {
            scheduleCalls2[i] = scheduleTxs2[i].data;
        }

        // Convert cancelTxs to bytes array for multicall
        bytes[] memory cancelCalls2 = new bytes[](cancelTxs2.length);
        for (uint256 i = 0; i < cancelTxs2.length; i++) {
            cancelCalls2[i] = cancelTxs2[i].data;
        }

        vm.startPrank(governanceSafeMultisigAeneid);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls2);

        skip(delayAeneid + 1);

        (bool hasRoleOldAdminBefore, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdminAeneid);
        (bool hasRoleOldUpgraderBefore, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgraderAeneid);
        (bool hasRoleOldPauseAdmin1Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1Aeneid);
        (bool hasRoleOldPauseAdmin2Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2Aeneid);

        Multicall(address(protocolAccessManager)).multicall(cancelCalls2);
        vm.stopPrank();

        skip(delayAeneid + 1);

        (bool hasRoleOldAdminAfter, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdminAeneid);
        (bool hasRoleOldUpgraderAfter, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgraderAeneid);
        (bool hasRoleOldPauseAdmin1After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1Aeneid);
        (bool hasRoleOldPauseAdmin2After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2Aeneid);

        (bool hasRoleSafeAdminAfter, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, governanceSafeMultisigAeneid);
        (bool hasRoleSafeUpgradeAfter, ) = protocolAccessManager.hasRole(
            UPGRADER_ROLE_ID,
            governanceSafeMultisigAeneid
        );
        (bool hasRoleSafePauseAfter, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, governanceSafeMultisigAeneid);
        (bool hasRoleSafeGuardianAfter, ) = protocolAccessManager.hasRole(
            GUARDIAN_ROLE_ID,
            securityCouncilSafeMultisigAeneid
        );

        assertEq(hasRoleOldAdminBefore, true);
        assertEq(hasRoleOldUpgraderBefore, true);
        assertEq(hasRoleOldPauseAdmin1Before, true);
        assertEq(hasRoleOldPauseAdmin2Before, true);

        assertEq(hasRoleOldAdminAfter, true);
        assertEq(hasRoleOldUpgraderAfter, true);
        assertEq(hasRoleOldPauseAdmin1After, true);
        assertEq(hasRoleOldPauseAdmin2After, true);

        assertEq(hasRoleSafeAdminAfter, true);
        assertEq(hasRoleSafeUpgradeAfter, true);
        assertEq(hasRoleSafePauseAfter, true);
        assertEq(hasRoleSafeGuardianAfter, true);
    }

    /**
     * @notice Execute a single transaction
     * @param transaction The transaction to execute
     */
    function _rawTransaction(JSONTxWriter.Transaction memory transaction) internal {
        vm.startPrank(transaction.from);
        (bool success, ) = transaction.to.call{ value: transaction.value }(transaction.data);
        require(success, "Transaction execution failed");
        vm.stopPrank();
    }

    /**
     * @notice Read transactions from regular JSON files
     * @param baseFilename The base filename without suffix (-regular)
     * @return regularTxs Transaction struct from regular file
     */
    function _readRegularTransactionFiles(
        string memory baseFilename
    ) internal returns (JSONTxWriter.Transaction[] memory regularTxs) {
        // Create paths for all three file types
        string memory basePath = string.concat(OUTPUT_DIR, vm.toString(block.chainid), "/");
        string memory regularPath = string.concat(basePath, baseFilename, "-regular.json");

        // Read regular transaction
        assertTrue(vm.exists(regularPath), "Regular JSON file not found");
        string memory regularJson = vm.readFile(regularPath);
        JSONTxWriter.Transaction[] memory regularTxs = _parseTransactionsFromJson(regularJson);

        return (regularTxs);
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
        string memory basePath = string.concat(OUTPUT_DIR, vm.toString(block.chainid), "/");
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
