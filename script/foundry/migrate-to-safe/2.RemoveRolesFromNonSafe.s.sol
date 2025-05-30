// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { AccessManagerOperations } from "../utils/AccessManagerOperations.s.sol";
import { Script, console } from "forge-std/Script.sol";

contract RemoveRolesFromNonSafe is Script, AccessManagerOperations {
    uint64 internal constant ADMIN_ROLE_ID = 0;
    uint64 internal constant UPGRADER_ROLE_ID = 1;
    uint64 internal constant PAUSE_ROLE_ID = 2;
    uint64 internal constant GUARDIAN_ROLE_ID = 3;
    
    uint32 delay;

    address oldAdmin;
    address oldUpgrader;
    address oldPauseAdmin1;
    address oldPauseAdmin2;
    address oldGuardian;

    address governanceSafeMultisig;
    address securityCouncilSafeMultisig;

    constructor(string memory _action) AccessManagerOperations(_action) {}

    function run(address _governanceSafeMultisig, address _securityCouncilSafeMultisig) public {
        uint256 chainId = block.chainid;
        if (chainId != 1315 && chainId != 1514) revert("Invalid chain id");

        if (chainId == 1514) {
            delay = 5 days;
            oldAdmin = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
            oldUpgrader = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
            oldPauseAdmin1 = 0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24;
            oldPauseAdmin2 = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
            oldGuardian = 0x76430daA671BE12200Cd424Ea6bdd8129A769033;
        } else if (chainId == 1315) {
            delay = 10 minutes;
            oldAdmin = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
            oldUpgrader = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
            oldPauseAdmin1 = 0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24;
            oldPauseAdmin2 = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
            oldGuardian = address(0);
        }

        governanceSafeMultisig = _governanceSafeMultisig;
        securityCouncilSafeMultisig = _securityCouncilSafeMultisig;

        _checkInitialConditions();

        super.run();
    }

    function _checkInitialConditions() internal {
        // Admin role
        (bool hasRoleOldAdmin, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdmin);
        (bool hasRoleGovernanceSafeMultisig, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, governanceSafeMultisig);
        if (!hasRoleOldAdmin) revert ("Old admin role not present");
        if (!hasRoleGovernanceSafeMultisig) revert ("Governance safe multisig role not present");

        // Upgrader role
        (bool hasRoleOldUpgrader, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgrader);
        (bool hasRoleSecurityCouncilSafeMultisig, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, governanceSafeMultisig);
        if (!hasRoleOldUpgrader) revert ("Old upgrader role not present");
        if (!hasRoleSecurityCouncilSafeMultisig) revert ("Security council safe multisig role not present");

        // Pauser role
        (bool hasRoleOldPauseAdmin1, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1);
        (bool hasRoleOldPauseAdmin2, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2);
        (bool hasRoleGovernanceSafeMultisigPause, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, governanceSafeMultisig);
        if (!hasRoleOldPauseAdmin1) revert ("Old pause admin role 1 not present");
        if (!hasRoleOldPauseAdmin2) revert ("Old pause admin role 2 not present");
        if (!hasRoleGovernanceSafeMultisigPause) revert ("Governance safe multisig pause role not present");

        // Guardian role
        (bool hasRoleOldGuardian, ) = protocolAccessManager.hasRole(GUARDIAN_ROLE_ID, oldGuardian);
        (bool hasRoleSecurityCouncilSafeMultisigGuardian, ) = protocolAccessManager.hasRole(GUARDIAN_ROLE_ID, securityCouncilSafeMultisig);
        if (!hasRoleSecurityCouncilSafeMultisigGuardian) revert ("Security council safe multisig guardian role not present");
        // Aeneid does not have any address with guardian role so we don't need to check for it
        if (block.chainid != 1315 && !hasRoleOldGuardian) revert ("Old guardian role not present"); 
    }

    function _generate() internal virtual override {
        address[] memory from = new address[](3);
        from[0] = governanceSafeMultisig;
        from[1] = governanceSafeMultisig;
        from[2] = governanceSafeMultisig;

        if (block.chainid == 1514) {
            bytes4 selector = protocolAccessManager.revokeRole.selector;

            _generateAction(
                from,
                address(protocolAccessManager),
                0,
                abi.encodeWithSelector(selector, ADMIN_ROLE_ID, oldAdmin),
                delay
            );

            _generateAction(
                from,
                address(protocolAccessManager),
                0,
                abi.encodeWithSelector(selector, UPGRADER_ROLE_ID, oldUpgrader),
                delay
            );

            _generateAction(
                from,
                address(protocolAccessManager),
                0,
                abi.encodeWithSelector(selector, PAUSE_ROLE_ID, oldPauseAdmin1),
                delay
            );

            _generateAction(
                from,
                address(protocolAccessManager),
                0,
                abi.encodeWithSelector(selector, PAUSE_ROLE_ID, oldPauseAdmin2),
                delay
            );

            _generateAction(
                from,
                address(protocolAccessManager),
                0,
                abi.encodeWithSelector(selector, GUARDIAN_ROLE_ID, oldGuardian),
                delay
            );
        } else if (block.chainid == 1315) {
            bytes4 selector = protocolAccessManager.revokeRole.selector;

            _generateAction(
                from,
                address(protocolAccessManager),
                0,
                abi.encodeWithSelector(selector, ADMIN_ROLE_ID, oldAdmin),
                delay
            );

            _generateAction(
                from,
                address(protocolAccessManager),
                0,
                abi.encodeWithSelector(selector, UPGRADER_ROLE_ID, oldUpgrader),
                delay
            );

            _generateAction(
                from,
                address(protocolAccessManager),
                0,
                abi.encodeWithSelector(selector, PAUSE_ROLE_ID, oldPauseAdmin1),
                delay
            );

            _generateAction(
                from,
                address(protocolAccessManager),
                0,
                abi.encodeWithSelector(selector, PAUSE_ROLE_ID, oldPauseAdmin2),
                delay
            );
        }
    }
}