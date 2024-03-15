// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { AccessManager } from "@openzeppelin/contracts/access/manager/AccessManager.sol";
import { ProtocolRoles } from "../lib/access-protocol/ProtocolRoles.sol";
import { Errors } from "../lib/Errors.sol";

contract ProtocolAccessManager is AccessManager {

    constructor(
        address admin,
        address upgrader,
        uint32 grantDelay,
        uint32 execDelay
    ) AccessManager(admin) {
        _configUpgraderRole(upgrader, grantDelay, execDelay);
        _setGrantDelay(ProtocolRoles.ADMIN, grantDelay);
    }

    function _configUpgraderRole(address upgrader, uint32 grantDelay, uint32 execDelay) private {
        if (upgrader == address(0)) {
            revert Errors.ProtocolAccessManager__ZeroAddressUpgrader();
        }
        _grantRole(ProtocolRoles.UPGRADER, upgrader, 0, execDelay);
        _setGrantDelay(ProtocolRoles.UPGRADER, grantDelay);
    }

}
