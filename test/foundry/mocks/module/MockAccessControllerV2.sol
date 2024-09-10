import { AccessController } from "contracts/access/AccessController.sol";

// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

contract MockAccessControllerV2 is AccessController {
    /// @dev Storage structure for the AccessControllerV2
    /// @custom:storage-location erc7201:story-protocol.AccessControllerV2
    struct AccessControllerV2Storage {
        string newState;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.AccessControllerV2")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant AccessControllerV2StorageLocation =
        0xf328f2cdee4ae4df23921504bfa43e3156fb4d18b23549ca0a43fd1e64947a00;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address ipAccountRegistry,
        address moduleRegistry
    ) AccessController(ipAccountRegistry, moduleRegistry) {}

    function initialize() public reinitializer(2) {
        _getAccessControllerV2Storage().newState = "initialized";
    }

    function get() external view returns (string memory) {
        return _getAccessControllerV2Storage().newState;
    }

    /// @dev Returns the storage struct of AccessControllerV2.
    function _getAccessControllerV2Storage() private pure returns (AccessControllerV2Storage storage $) {
        assembly {
            $.slot := AccessControllerV2StorageLocation
        }
    }
}
