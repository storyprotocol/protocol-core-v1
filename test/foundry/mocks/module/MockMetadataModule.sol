// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { IModule } from "../../../../contracts/interfaces/modules/base/IModule.sol";
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { IIPAccountRegistry } from "../../../../contracts/interfaces/registries/IIPAccountRegistry.sol";
import { IPAccountChecker } from "../../../../contracts/lib/registries/IPAccountChecker.sol";
import { IPAccountStorageOps } from "../../../../contracts/lib/IPAccountStorageOps.sol";
import { AccessControlled } from "../../../../contracts/access/AccessControlled.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { BaseModule } from "../../../../contracts/modules/BaseModule.sol";

/// @title MockAccessControlledModule
/// @dev This contract is a mock implementation of an access-controlled module, used for testing purposes.
/// It demonstrates the use of access control checks in function calls.
contract MockMetadataModule is BaseModule, AccessControlled {
    using ERC165Checker for address;
    using IPAccountChecker for IIPAccountRegistry;
    using IPAccountStorageOps for IIPAccount;

    string public name = "MockMetadataModule";
    mapping(string => bool) public ipTypesSupported;

    /// @notice Creates a new MockMetadataModule instance.
    /// @param accessController The address of the AccessController contract.
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract.
    constructor(
        address accessController,
        address ipAccountRegistry
    ) AccessControlled(accessController, ipAccountRegistry) {
        ipTypesSupported["STORY"] = true;
        ipTypesSupported["CHARACTOR"] = true;
        ipTypesSupported["BOOK"] = true;
        ipTypesSupported["Photo"] = true;
    }

    modifier onlyOnce(address ipAccount, bytes32 metadataName) {
        require(
            _isEmptyString(IIPAccount(payable(ipAccount)).getString(metadataName)),
            "MockMetadataModule: metadata already set"
        );
        _;
    }

    /// @notice Set description of the IP.
    /// @param ipAccount The address of the IP account.
    /// @param description Description of the IP.
    function setIpDescription(
        address ipAccount,
        string memory description
    ) external verifyPermission(ipAccount) onlyOnce(ipAccount, "IP_DESCRIPTION") {
        IIPAccount(payable(ipAccount)).setString("IP_DESCRIPTION", description);
    }

    /// @notice Set type of the IP.
    /// @param ipAccount The address of the IP account.
    /// @param ipType Type of the IP.
    function setIpType(
        address ipAccount,
        string memory ipType
    ) external verifyPermission(ipAccount) onlyOnce(ipAccount, "IP_TYPE") {
        require(ipTypesSupported[ipType], "MockMetadataModule: ipType not supported");
        IIPAccount(payable(ipAccount)).setString("IP_TYPE", ipType);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IModule).interfaceId || super.supportsInterface(interfaceId);
    }

    function _isEmptyString(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }
}
