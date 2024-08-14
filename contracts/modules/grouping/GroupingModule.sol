// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IModule } from "../../interfaces/modules/base/IModule.sol";
import { IGroupIPAssetRegistry } from "../../interfaces/registries/IGroupIPAssetRegistry.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { ILicenseRegistry } from "../../interfaces/registries/ILicenseRegistry.sol";
import { Errors } from "../../lib/Errors.sol";
import { IPAccountChecker } from "../../lib/registries/IPAccountChecker.sol";
import { RoyaltyModule } from "../../modules/royalty/RoyaltyModule.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { BaseModule } from "../BaseModule.sol";
import { ILicenseTemplate } from "../../interfaces/modules/licensing/ILicenseTemplate.sol";
import { IPAccountStorageOps } from "../../lib/IPAccountStorageOps.sol";
import { ILicenseToken } from "../../interfaces/ILicenseToken.sol";
import { ProtocolPausableUpgradeable } from "../../pause/ProtocolPausableUpgradeable.sol";
import { IModuleRegistry } from "../../interfaces/registries/IModuleRegistry.sol";
import { IGroupingModule } from "../../interfaces/modules/grouping/IGroupingModule.sol";

/// @title Grouping Module
/// @notice Grouping module is the main entry point for the licensing system. It is responsible for:
/// - Attaching license terms to IP assets
/// - Minting license Tokens
/// - Registering derivatives
contract GroupingModule is
    AccessControlled,
    IGroupingModule,
    BaseModule,
    ReentrancyGuardUpgradeable,
    ProtocolPausableUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using Strings for *;
    using IPAccountStorageOps for IIPAccount;

    /// @inheritdoc IModule
    string public constant override name = LICENSING_MODULE_KEY;

    /// @notice Returns the canonical protocol-wide RoyaltyModule
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    RoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice Returns the protocol-wide ModuleRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IModuleRegistry public immutable MODULE_REGISTRY;

    // keccak256(abi.encode(uint256(keccak256("story-protocol.GroupingModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant GroupingModuleStorageLocation =
        0x0f7178cb62e4803c52d40f70c08a6f88d6ee1af1838d58e0c83a222a6c3d3100;

    /// Constructor
    /// @param accessController The address of the AccessController contract
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract
    /// @param royaltyModule The address of the RoyaltyModule contract
    /// @param licenseRegistry The address of the LicenseRegistry contract
    /// @param disputeModule The address of the DisputeModule contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address moduleRegistry,
        address royaltyModule
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (royaltyModule == address(0)) revert Errors.GroupingModule__ZeroRoyaltyModule();
        if (moduleRegistry == address(0)) revert Errors.GroupingModule__ZeroModuleRegistry();
        MODULE_REGISTRY = IModuleRegistry(moduleRegistry);
        ROYALTY_MODULE = RoyaltyModule(royaltyModule);
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.GroupingModule__ZeroAccessManager();
        }
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
        __ProtocolPausable_init(accessManager);
    }

    /// @notice Adds IP to group.
    /// the function must be called by the Group IP owner or an authorized operator.
    /// @param groupIpId The address of the group IP.
    /// @param ipIds The IP IDs.
    function addIp(address groupIpId, address[] calldata ipIds) external verifyPermission(groupIpId) {

    }

    /// @notice Removes IP from group.
    /// the function must be called by the Group IP owner or an authorized operator.
    /// @param groupIpId The address of the group IP.
    /// @param ipIds The IP IDs.
    function removeIp(address groupIpId, address[] calldata ipIds) external verifyPermission(groupIpId) {

    }

    /// @notice Claims reward.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    /// @param ipIds The IP IDs.
    function claimReward(address groupId, address token, address[] calldata ipIds) external;

    
    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
