// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { ProtocolPausableUpgradeable } from "contracts/pause/ProtocolPausableUpgradeable.sol";

contract MockProtocolPausable is ProtocolPausableUpgradeable {
    function initialize(address accessManager) public initializer {
        __ProtocolPausable_init(accessManager);
    }
}
