// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { LicenseRegistry } from "contracts/registries/LicenseRegistry.sol";

import { console2 } from "forge-std/console2.sol";

/// @custom:oz-upgrades-from LicenseRegistry
contract LicenseRegistryV2Mock is LicenseRegistry {

    /// @custom:storage-location erc7201:story-protocol.LicenseRegistryV2Mock
    struct LicenseRegistryV2MockStorage {
        string foo;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicenseRegistryV2Mock")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant LicenseRegistryV2MockStorageLocation = 0x90665a006fa2ea668045c6f86a5686b799d49b6e25a8ec866f263029ae8c4100;

    function setFoo(string calldata _foo) public {
        console2.log(_foo);
        _getLicenseRegistryV2MockStorage().foo = _foo;
        console2.log(_getLicenseRegistryV2MockStorage().foo);
    }

    function foo() public view returns (string memory) {
        return _getLicenseRegistryV2MockStorage().foo;
    }

    function _getLicenseRegistryV2MockStorage() private pure returns (LicenseRegistryV2MockStorage storage $) {
        assembly {
            $.slot := LicenseRegistryV2MockStorageLocation
        }
    }
    
}