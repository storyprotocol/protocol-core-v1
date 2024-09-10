// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { LicenseRegistry } from "../../../../contracts/registries/LicenseRegistry.sol";

contract LicenseRegistryHarness is LicenseRegistry {
    constructor(
        address _erc721Registry,
        address _erc1155Registry,
        address _ipGraphAcl
    ) LicenseRegistry(_erc721Registry, _erc1155Registry, _ipGraphAcl) {}

    function setExpirationTime(address ipId, uint256 expireTime) external {
        _setExpirationTime(ipId, expireTime);
    }
}
