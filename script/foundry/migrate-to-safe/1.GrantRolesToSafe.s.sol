// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";

import { AccessManagerOperations } from "../utils/AccessManagerOperations.s.sol";
import { Script, console } from "forge-std/Script.sol";

contract GrantRolesToSafe is Script, AccessManagerOperations {
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

    constructor(string memory _action, bool _isTest) AccessManagerOperations(_action, _isTest) {}

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

        _checkInitialConditions();

        governanceSafeMultisig = _governanceSafeMultisig;
        securityCouncilSafeMultisig = _securityCouncilSafeMultisig;

        super.run();        
    }

    function _checkInitialConditions() internal {
        // Admin role
        (bool hasRoleOldAdmin, ) = protocolAccessManager.hasRole(ADMIN_ROLE_ID, oldAdmin);
        if (!hasRoleOldAdmin) revert ("Old admin role not present");

        // Upgrader role
        (bool hasRoleOldUpgrader, ) = protocolAccessManager.hasRole(UPGRADER_ROLE_ID, oldUpgrader);
        if (!hasRoleOldUpgrader) revert ("Old upgrader role not present");

        // Pauser role
        (bool hasRoleOldPauseAdmin1, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin1);
        (bool hasRoleOldPauseAdmin2, ) = protocolAccessManager.hasRole(PAUSE_ROLE_ID, oldPauseAdmin2);
        if (!hasRoleOldPauseAdmin1) revert ("Old pause admin role 1 not present");
        if (!hasRoleOldPauseAdmin2) revert ("Old pause admin role 2 not present");

        // Guardian role
        (bool hasRoleOldGuardian, ) = protocolAccessManager.hasRole(GUARDIAN_ROLE_ID, oldGuardian);
        // Aeneid does not have any address with guardian role so we don't need to check for it
        if (block.chainid != 1315 && !hasRoleOldGuardian) revert ("Old guardian role not present"); 
    }

    function _generate() internal virtual override {
        address[] memory from = new address[](3);
        from[0] = oldAdmin;
        from[1] = oldAdmin;
        from[2] = oldAdmin;

        bytes4 selector = protocolAccessManager.grantRole.selector;

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, ADMIN_ROLE_ID, governanceSafeMultisig, delay),
            delay
        );

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, UPGRADER_ROLE_ID, governanceSafeMultisig, delay),
            delay
        );

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, PAUSE_ROLE_ID, governanceSafeMultisig, 0),
            delay
        );

        _generateAction(
            from,
            address(protocolAccessManager),
            0,
            abi.encodeWithSelector(selector, GUARDIAN_ROLE_ID, securityCouncilSafeMultisig, delay),
            delay
        );
    }
}