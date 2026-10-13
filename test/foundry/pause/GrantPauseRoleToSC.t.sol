// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { Multicall } from "@openzeppelin/contracts/utils/Multicall.sol";

import { GrantPauseRoleToSC } from "../../../script/foundry/pause/GrantPauseRoleToSC.s.sol";
import { JSONTxWriter } from "../../../script/foundry/utils/JSONTxWriter.s.sol";

import { stdJson } from "forge-std/StdJson.sol";
import { BaseTest } from "test/foundry/utils/BaseTest.t.sol";
// solhint-disable-next-line
import { console2 } from "forge-std/console2.sol";

contract GrantPauseRoleToSCTest is BaseTest {
    // Maximum number of transactions in JSON files
    uint256 constant MAX_TXS_PER_JSON = 1000;

    string constant OUTPUT_DIR = "./script/foundry/admin-actions/output-test/";

    uint64 constant PAUSE_ROLE_ID = 2;

    uint256 delayMainnet;
    uint256 delayAeneid;
    address governanceSafeMultisigMainnet;
    address governanceSafeMultisigAeneid;
    address securityCouncilSafeMultisigMainnet;
    address securityCouncilSafeMultisigAeneid;

    address sc1Addr = 0xc1583eF962954b123B5d043788f30Ef2450956b5;
    address sc2Addr = 0x83C24415F202e0370e164cfbd914A84138cC1Ae4;
    address sc3Addr = 0x576fa14594D1Ab7dc3fa7E08466E873321f5C95B;
    address sc4Addr = 0xBD4AD66012C443F87465E12CA91eDc42957aDD3A;
    address sc5Addr = 0xAF43958ad62389BE3E0B553dFd259Ec335814c1C;
    address sc6Addr = 0xAdCDF85a75200015B25685c453f5738333dC63A5;

    function setUp() public override {
        protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);

        // Mainnet
        delayMainnet = 5 days;
        governanceSafeMultisigMainnet = 0xF07cA4b61022F0399C1511E7E668A57567f2138B;
        securityCouncilSafeMultisigMainnet = 0x25D2605b2C768082A14E79713114389d0eC297D8;

        // Aeneid
        delayAeneid = 10 minutes;
        governanceSafeMultisigAeneid = 0x4B089bF9340DdB02a011471Eaa7d8D81C60CB524;
        securityCouncilSafeMultisigAeneid = 0xC9a862Df1872402c4eAcbb8402F9BE628B52d270;
    }

    function test_GrantRoles_Mainnet_Success() public {
        // Fork mainnet
        uint256 forkId = vm.createFork("https://mainnet.storyrpc.io/");
        vm.selectFork(forkId);

        GrantPauseRoleToSC deployScript = new GrantPauseRoleToSC();
        deployScript.run(true);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        ) = _readNonRegularTransactionFiles("grant-pause-role-to-sc", false);

        assertEq(scheduleTxs.length, 6);
        assertEq(executeTxs.length, 6);
        assertEq(cancelTxs.length, 6);

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

        vm.startPrank(governanceSafeMultisigMainnet);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);

        skip(delayMainnet + 1);

        (bool hasPauseRoleSc1Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc1Addr);
        (bool hasPauseRoleSc2Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc2Addr);
        (bool hasPauseRoleSc3Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc3Addr);
        (bool hasPauseRoleSc4Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc4Addr);
        (bool hasPauseRoleSc5Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc5Addr);
        (bool hasPauseRoleSc6Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc6Addr);

        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        (bool hasPauseRoleSc1After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc1Addr);
        (bool hasPauseRoleSc2After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc2Addr);
        (bool hasPauseRoleSc3After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc3Addr);
        (bool hasPauseRoleSc4After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc4Addr);
        (bool hasPauseRoleSc5After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc5Addr);
        (bool hasPauseRoleSc6After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc6Addr);

        assertEq(hasPauseRoleSc1Before, false);
        assertEq(hasPauseRoleSc2Before, false);
        assertEq(hasPauseRoleSc3Before, false);
        assertEq(hasPauseRoleSc4Before, false);
        assertEq(hasPauseRoleSc5Before, false);
        assertEq(hasPauseRoleSc6Before, false);

        assertEq(hasPauseRoleSc1After, true);
        assertEq(hasPauseRoleSc2After, true);
        assertEq(hasPauseRoleSc3After, true);
        assertEq(hasPauseRoleSc4After, true);
        assertEq(hasPauseRoleSc5After, true);
        assertEq(hasPauseRoleSc6After, true);

        try vm.removeFile(string.concat(OUTPUT_DIR, "1514", "/grant-pause-role-to-sc-schedule.json")) {} catch {}
        try vm.removeFile(string.concat(OUTPUT_DIR, "1514", "/grant-pause-role-to-sc-cancel.json")) {} catch {}
        try vm.removeFile(string.concat(OUTPUT_DIR, "1514", "/grant-pause-role-to-sc-execute.json")) {} catch {}
    }

    function test_GrantPauseRoleToSC_Mainnet_Cancel() public {
        // Fork mainnet
        uint256 forkId = vm.createFork("https://mainnet.storyrpc.io/");
        vm.selectFork(forkId);

        GrantPauseRoleToSC deployScript = new GrantPauseRoleToSC();
        deployScript.run(true);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        ) = _readNonRegularTransactionFiles("grant-pause-role-to-sc", false);

        assertEq(scheduleTxs.length, 6);
        assertEq(executeTxs.length, 6);
        assertEq(cancelTxs.length, 6);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls = new bytes[](scheduleTxs.length);
        for (uint256 i = 0; i < scheduleTxs.length; i++) {
            scheduleCalls[i] = scheduleTxs[i].data;
        }

        // Convert cancelTxs to bytes array for multicall
        bytes[] memory cancelCalls = new bytes[](cancelTxs.length);
        for (uint256 i = 0; i < cancelTxs.length; i++) {
            cancelCalls[i] = cancelTxs[i].data;
        }

        vm.startPrank(governanceSafeMultisigMainnet);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        vm.stopPrank();

        (bool hasPauseRoleSc1Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc1Addr);
        (bool hasPauseRoleSc2Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc2Addr);
        (bool hasPauseRoleSc3Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc3Addr);
        (bool hasPauseRoleSc4Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc4Addr);
        (bool hasPauseRoleSc5Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc5Addr);
        (bool hasPauseRoleSc6Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc6Addr);

        vm.startPrank(governanceSafeMultisigMainnet);
        Multicall(address(protocolAccessManager)).multicall(cancelCalls);
        vm.stopPrank();

        (bool hasPauseRoleSc1After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc1Addr);
        (bool hasPauseRoleSc2After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc2Addr);
        (bool hasPauseRoleSc3After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc3Addr);
        (bool hasPauseRoleSc4After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc4Addr);
        (bool hasPauseRoleSc5After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc5Addr);
        (bool hasPauseRoleSc6After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc6Addr);

        assertEq(hasPauseRoleSc1Before, false);
        assertEq(hasPauseRoleSc2Before, false);
        assertEq(hasPauseRoleSc3Before, false);
        assertEq(hasPauseRoleSc4Before, false);
        assertEq(hasPauseRoleSc5Before, false);
        assertEq(hasPauseRoleSc6Before, false);

        assertEq(hasPauseRoleSc1After, false);
        assertEq(hasPauseRoleSc2After, false);
        assertEq(hasPauseRoleSc3After, false);
        assertEq(hasPauseRoleSc4After, false);
        assertEq(hasPauseRoleSc5After, false);
        assertEq(hasPauseRoleSc6After, false);

        try vm.removeFile(string.concat(OUTPUT_DIR, "1514", "/grant-pause-role-to-sc-schedule.json")) {} catch {}
        try vm.removeFile(string.concat(OUTPUT_DIR, "1514", "/grant-pause-role-to-sc-cancel.json")) {} catch {}
        try vm.removeFile(string.concat(OUTPUT_DIR, "1514", "/grant-pause-role-to-sc-execute.json")) {} catch {}
    }

    function test_GrantPauseRoleToSC_Aeneid_Success() public {
        // Fork aeneid
        uint256 forkId = vm.createFork("https://aeneid.storyrpc.io/");
        vm.selectFork(forkId);

        GrantPauseRoleToSC deployScript = new GrantPauseRoleToSC();
        deployScript.run(true);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        ) = _readNonRegularTransactionFiles("grant-pause-role-to-sc", false);

        assertEq(scheduleTxs.length, 6);
        assertEq(executeTxs.length, 6);
        assertEq(cancelTxs.length, 6);

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

        vm.startPrank(governanceSafeMultisigAeneid);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delayAeneid + 1);

        (bool hasPauseRoleSc1Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc1Addr);
        (bool hasPauseRoleSc2Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc2Addr);
        (bool hasPauseRoleSc3Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc3Addr);
        (bool hasPauseRoleSc4Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc4Addr);
        (bool hasPauseRoleSc5Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc5Addr);
        (bool hasPauseRoleSc6Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc6Addr);

        Multicall(address(protocolAccessManager)).multicall(executeCalls);

        (bool hasPauseRoleSc1After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc1Addr);
        (bool hasPauseRoleSc2After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc2Addr);
        (bool hasPauseRoleSc3After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc3Addr);
        (bool hasPauseRoleSc4After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc4Addr);
        (bool hasPauseRoleSc5After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc5Addr);
        (bool hasPauseRoleSc6After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc6Addr);

        assertEq(hasPauseRoleSc1Before, false);
        assertEq(hasPauseRoleSc2Before, false);
        assertEq(hasPauseRoleSc3Before, false);
        assertEq(hasPauseRoleSc4Before, false);
        assertEq(hasPauseRoleSc5Before, false);
        assertEq(hasPauseRoleSc6Before, false);

        assertEq(hasPauseRoleSc1After, true);
        assertEq(hasPauseRoleSc2After, true);
        assertEq(hasPauseRoleSc3After, true);
        assertEq(hasPauseRoleSc4After, true);
        assertEq(hasPauseRoleSc5After, true);
        assertEq(hasPauseRoleSc6After, true);

        try vm.removeFile(string.concat(OUTPUT_DIR, "1315", "/grant-pause-role-to-sc-schedule.json")) {} catch {}
        try vm.removeFile(string.concat(OUTPUT_DIR, "1315", "/grant-pause-role-to-sc-cancel.json")) {} catch {}
        try vm.removeFile(string.concat(OUTPUT_DIR, "1315", "/grant-pause-role-to-sc-execute.json")) {} catch {}
    }

    function test_GrantPauseRoleToSC_Aeneid_Cancel() public {
        // Fork aeneid
        uint256 forkId = vm.createFork("https://aeneid.storyrpc.io/");
        vm.selectFork(forkId);

        GrantPauseRoleToSC deployScript = new GrantPauseRoleToSC();
        deployScript.run(true);

        // Get all transaction JSONs (schedule, cancel, execute)
        (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        ) = _readNonRegularTransactionFiles("grant-pause-role-to-sc", false);

        assertEq(scheduleTxs.length, 6);
        assertEq(executeTxs.length, 6);
        assertEq(cancelTxs.length, 6);

        // Convert scheduleTxs to bytes array for multicall
        bytes[] memory scheduleCalls = new bytes[](scheduleTxs.length);
        for (uint256 i = 0; i < scheduleTxs.length; i++) {
            scheduleCalls[i] = scheduleTxs[i].data;
        }

        // Convert cancelTxs to bytes array for multicall
        bytes[] memory cancelCalls = new bytes[](cancelTxs.length);
        for (uint256 i = 0; i < cancelTxs.length; i++) {
            cancelCalls[i] = cancelTxs[i].data;
        }

        vm.startPrank(governanceSafeMultisigAeneid);
        Multicall(address(protocolAccessManager)).multicall(scheduleCalls);
        skip(delayAeneid + 1);

        (bool hasPauseRoleSc1Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc1Addr);
        (bool hasPauseRoleSc2Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc2Addr);
        (bool hasPauseRoleSc3Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc3Addr);
        (bool hasPauseRoleSc4Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc4Addr);
        (bool hasPauseRoleSc5Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc5Addr);
        (bool hasPauseRoleSc6Before, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc6Addr);

        Multicall(address(protocolAccessManager)).multicall(cancelCalls);

        (bool hasPauseRoleSc1After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc1Addr);
        (bool hasPauseRoleSc2After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc2Addr);
        (bool hasPauseRoleSc3After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc3Addr);
        (bool hasPauseRoleSc4After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc4Addr);
        (bool hasPauseRoleSc5After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc5Addr);
        (bool hasPauseRoleSc6After, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, sc6Addr);

        assertEq(hasPauseRoleSc1Before, false);
        assertEq(hasPauseRoleSc2Before, false);
        assertEq(hasPauseRoleSc3Before, false);
        assertEq(hasPauseRoleSc4Before, false);
        assertEq(hasPauseRoleSc5Before, false);
        assertEq(hasPauseRoleSc6Before, false);

        assertEq(hasPauseRoleSc1After, false);
        assertEq(hasPauseRoleSc2After, false);
        assertEq(hasPauseRoleSc3After, false);
        assertEq(hasPauseRoleSc4After, false);
        assertEq(hasPauseRoleSc5After, false);
        assertEq(hasPauseRoleSc6After, false);

        try vm.removeFile(string.concat(OUTPUT_DIR, "1315", "/grant-pause-role-to-sc-schedule.json")) {} catch {}
        try vm.removeFile(string.concat(OUTPUT_DIR, "1315", "/grant-pause-role-to-sc-cancel.json")) {} catch {}
        try vm.removeFile(string.concat(OUTPUT_DIR, "1315", "/grant-pause-role-to-sc-execute.json")) {} catch {}
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
     * @param isAeneidTest Whether the test is for Aeneid test deployment
     * @return scheduleTxs Transaction struct from schedule file
     * @return executeTxs Transaction struct from execute file
     * @return cancelTxs Transaction struct from cancel file
     */
    function _readNonRegularTransactionFiles(
        string memory baseFilename,
        bool isAeneidTest
    )
        internal
        returns (
            JSONTxWriter.Transaction[] memory scheduleTxs,
            JSONTxWriter.Transaction[] memory executeTxs,
            JSONTxWriter.Transaction[] memory cancelTxs
        )
    {
        // Create paths for all three file types
        string memory outputDir = isAeneidTest ? "./script/foundry/admin-actions/output-test/aeneid-test/" : OUTPUT_DIR;
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
