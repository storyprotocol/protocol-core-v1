// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ProtocolAccessManager } from "../../access-protocol/ProtocolAccessManager.sol";
import { ProtocolRoles } from "./ProtocolRoles.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

library RoleConfigHelper {
    
    function configUpgrader(ProtocolAccessManager manager, address target) {
        manager.setTargetFunctionRole(
            target,
            _asSingletonArray(UUPSUpgradeable.upgradeToAndCall.selector),
            ProtocolRoles.UPGRADER
        );
    }
}

function _asSingletonArray(
    bytes4 element
) private pure returns (bytes4[] memory) {
    bytes4[] memory array = new bytes4[](1);
    array[0] = element;

    return array;
}