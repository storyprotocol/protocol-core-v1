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

    // Mainnet
    // forge script script/foundry/migrate-to-safe/1.GrantRolesToSafe.s.sol:GrantRolesToSafe --rpc-url https://mainnet.storyrpc.io --legacy --sig "run(address,address,bool,bool)" $GOVERNANCE_SAFE_ADDRESS_MAINNET $SECURITY_COUNCIL_SAFE_ADDRESS_MAINNET false false

    // Aeneid real
    // forge script script/foundry/migrate-to-safe/1.GrantRolesToSafe.s.sol:GrantRolesToSafe --rpc-url https://aeneid.storyrpc.io --legacy --sig "run(address,address,bool,bool)" $GOVERNANCE_SAFE_ADDRESS_AENEID $SECURITY_COUNCIL_SAFE_ADDRESS_AENEID false false

    // Aeneid test
    // forge script script/foundry/migrate-to-safe/1.GrantRolesToSafe.s.sol:GrantRolesToSafe --rpc-url https://aeneid.storyrpc.io --legacy --sig "run(address,address,bool,bool)" 0x7313eC47e7686dBb26050eEAA1622A63D3F7bD30 0x22E7C79864ba144Cd514e1DBC078C374E6Aeccc9 false true

    function run(address _governanceSafeMultisig, address _securityCouncilSafeMultisig, bool _isUnitTest, bool _isAeneidTest) public {
        uint256 chainId = block.chainid;
        if (chainId != 1315 && chainId != 1514) revert("Invalid chain id");

        setAction("grant-roles-to-safe");
        setIsTest(_isUnitTest, _isAeneidTest);

        if (chainId == 1514) {
            protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);
            delay = 5 days;
            oldAdmin = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
            oldUpgrader = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
            oldPauseAdmin1 = 0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24;
            oldPauseAdmin2 = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
            oldGuardian = 0x76430daA671BE12200Cd424Ea6bdd8129A769033;
        } 
        if (chainId == 1315 && !_isAeneidTest) {
            protocolAccessManager = AccessManager(0xFdece7b8a2f55ceC33b53fd28936B4B1e3153d53);
            // Aeneid real
            delay = 10 minutes;
            oldAdmin = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
            oldUpgrader = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
            oldPauseAdmin1 = 0xdd661f55128A80437A0c0BDA6E13F214A3B2EB24;
            oldPauseAdmin2 = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
            oldGuardian = address(0);
        }
        if (chainId == 1315 && _isAeneidTest) {
            protocolAccessManager = AccessManager(0x7fc3eD9B2CC14C0872ec633c6CC290b8B9B3AA5A);
            delay = 10 minutes;
            oldAdmin = 0xe83F899BD5790e1be9b6B51ffcF32b3b2b1F5a9e;
            oldUpgrader = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
            oldPauseAdmin1 = 0x3b3fFAA254d9dCEEA4D59ae1dF28c9F84D4eE901;
            oldPauseAdmin2 = 0x4C30baDa479D0e13300b31b1696A5E570848bbEe;
            oldGuardian = 0x76430daA671BE12200Cd424Ea6bdd8129A769033; 
        }

        _checkInitialConditions(_isAeneidTest);

        governanceSafeMultisig = _governanceSafeMultisig;
        securityCouncilSafeMultisig = _securityCouncilSafeMultisig;

        super.run();        
    }

    function _checkInitialConditions(bool _isAeneidTest) internal {
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
        if (block.chainid != 1315 && !hasRoleOldGuardian) revert ("Old guardian role not present");
        // Aeneid real deployment does not have any address with guardian role so we don't need to check for it
        if (block.chainid == 1315 && _isAeneidTest) {
            if (!hasRoleOldGuardian) revert ("Old guardian role present");
        }
    }

    function _generate() internal virtual override {
        address[] memory from = new address[](3);
        from[0] = oldAdmin;
        from[1] = oldAdmin;
        from[2] = oldAdmin; // there is no guardian for grantRole() function so only admin role cancel

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