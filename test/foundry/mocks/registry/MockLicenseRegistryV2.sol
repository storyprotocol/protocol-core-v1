// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";
import { ILicensingModule } from "contracts/interfaces/modules/licensing/ILicensingModule.sol";
import { IDisputeModule } from "contracts/interfaces/modules/dispute/IDisputeModule.sol";
import { Licensing } from "contracts/lib/Licensing.sol";

/// @custom:oz-upgrades-from LicenseRegistry
contract MockLicenseRegistryV2 is LicenseRegistry {

    // New storage
    /// @custom:storage-location erc7201:story-protocol.MockLicenseRegistryV2
    struct MockLicenseRegistryV2Storage {
        string foo;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.MockLicenseRegistryV2")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant MockLicenseRegistryV2StorageLocation = 0x6e5bb326ebeeee96c5ce55286f71e5aa42dda8a70ba2a20389e489f13b57b300;

    function setFoo(string memory _foo) external {
        _getMockLicenseRegistryV2Storage().foo = _foo;
    }

    function foo() external view returns (string memory) {
        return _getMockLicenseRegistryV2Storage().foo;
    }

    // Gets the storage of the V2 specific struct
    function _getMockLicenseRegistryV2Storage() private pure returns (MockLicenseRegistryV2Storage storage $) {
        assembly {
            $.slot := MockLicenseRegistryV2StorageLocation
        }
    }

}
