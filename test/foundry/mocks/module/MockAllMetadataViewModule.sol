// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { IViewModule } from "../../../../contracts/interfaces/modules/base/IViewModule.sol";
import { IIPAccount } from "../../../../contracts/interfaces/IIPAccount.sol";
import { BaseModule } from "../../../../contracts/modules/BaseModule.sol";
import { IPAccountStorageOps } from "../../../../contracts/lib/IPAccountStorageOps.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";

/// @title MockAllMetadataViewModule
contract MockAllMetadataViewModule is BaseModule, IViewModule {
    using IPAccountStorageOps for IIPAccount;

    string public name = "MockAllMetadataViewModule";
    address public ipAssetRegistry;
    address public mockMetadataModule;

    /// @notice Creates a new MockAllMetadataViewModule instance.
    constructor(address ipAssetRegistry_, address mockMetadataModule_) {
        ipAssetRegistry = ipAssetRegistry_;
        mockMetadataModule = mockMetadataModule_;
    }

    function getName(address ipId) public view returns (string memory) {
        return IIPAccount(payable(ipId)).getString(ipAssetRegistry, "NAME");
    }

    function description(address ipId) public view returns (string memory) {
        return IIPAccount(payable(ipId)).getString(mockMetadataModule, "IP_DESCRIPTION");
    }

    function registrationDate(address ipId) public view returns (uint256) {
        return IIPAccount(payable(ipId)).getUint256(ipAssetRegistry, "REGISTRATION_DATE");
    }

    function uri(address ipId) external view returns (string memory) {
        return IIPAccount(payable(ipId)).getString(ipAssetRegistry, "URI");
    }

    function owner(address ipId) public view returns (address) {
        return IIPAccount(payable(ipId)).owner();
    }

    function ipType(address ipId) public view returns (string memory) {
        return IIPAccount(payable(ipId)).getString(mockMetadataModule, "IP_TYPE");
    }

    function tokenURI(address ipId) external view returns (string memory) {
        string memory baseJson = string(
            /* solhint-disable */
            abi.encodePacked(
                '{"name": "IP Asset #',
                Strings.toHexString(uint160(ipId)),
                '", "description": "',
                description(ipId),
                '", "attributes": ['
            )
            /* solhint-enable */
        );

        string memory ipAttributes = string(
            /* solhint-disable */
            abi.encodePacked(
                '{"trait_type": "Name", "value": "',
                getName(ipId),
                '"},'
                '{"trait_type": "Type", "value": "',
                ipType(ipId),
                '"},'
                '{"trait_type": "Owner", "value": "',
                Strings.toHexString(uint160(owner(ipId))),
                '"},'
                '{"trait_type": "Registration Date", "value": "',
                Strings.toString(registrationDate(ipId)),
                '"}'
            )
            /* solhint-enable */
        );

        return
            string(
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(string(abi.encodePacked(baseJson, ipAttributes, "]}"))))
                )
            );
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(BaseModule, IERC165) returns (bool) {
        return interfaceId == type(IViewModule).interfaceId || super.supportsInterface(interfaceId);
    }

    function isSupported(address ipAccount) external returns (bool) {
        return
            !_isEmptyString(IIPAccount(payable(ipAccount)).getString(mockMetadataModule, "IP_TYPE")) &&
            !_isEmptyString(IIPAccount(payable(ipAccount)).getString(ipAssetRegistry, "NAME"));
    }

    function _isEmptyString(string memory str) internal pure returns (bool) {
        return bytes(str).length == 0;
    }
}
