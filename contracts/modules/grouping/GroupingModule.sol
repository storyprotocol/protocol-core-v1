// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

// external
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IGroupNFT } from "../../interfaces/IGroupNFT.sol";
import { IIPAccount } from "../../interfaces/IIPAccount.sol";
import { IGroupIPAssetRegistry } from "../../interfaces/registries/IGroupIPAssetRegistry.sol";
import { ILicenseRegistry } from "../../interfaces/registries/ILicenseRegistry.sol";
import { Errors } from "../../lib/Errors.sol";
import { IRoyaltyModule } from "../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { AccessControlled } from "../../access/AccessControlled.sol";
import { BaseModule } from "../BaseModule.sol";
import { IPAccountStorageOps } from "../../lib/IPAccountStorageOps.sol";
import { ProtocolPausableUpgradeable } from "../../pause/ProtocolPausableUpgradeable.sol";
import { IGroupingModule } from "../../interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupRewardPool } from "../../interfaces/modules/grouping/IGroupRewardPool.sol";
import { GROUPING_MODULE_KEY } from "../../lib/modules/Module.sol";

/// @title Grouping Module
/// @notice Grouping module is the main entry point for the IPA grouping. It is responsible for:
/// - Registering a group
/// - Adding IP to group
/// - Removing IP from group
/// - Claiming reward
contract GroupingModule is
    AccessControlled,
    IGroupingModule,
    BaseModule,
    ReentrancyGuardUpgradeable,
    ProtocolPausableUpgradeable,
    UUPSUpgradeable
{
    using ERC165Checker for address;
    using Strings for *;
    using IPAccountStorageOps for IIPAccount;

    /// @notice Returns the canonical protocol-wide RoyaltyModule
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @notice Returns the address GROUP NFT contract
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupNFT public immutable GROUP_NFT;

    /// @notice Returns the canonical protocol-wide Group IP Asset Registry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupIPAssetRegistry public immutable GROUP_IP_ASSET_REGISTRY;

    /// @notice Returns the canonical protocol-wide LicenseRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    // keccak256(abi.encode(uint256(keccak256("story-protocol.GroupingModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant GroupingModuleStorageLocation =
        0x0f7178cb62e4803c52d40f70c08a6f88d6ee1af1838d58e0c83a222a6c3d3100;

    /// Constructor
    /// @param accessController The address of the AccessController contract
    /// @param ipAssetRegistry The address of the IpAssetRegistry contract
    /// @param royaltyModule The address of the RoyaltyModule contract
    /// @param licenseRegistry The address of the LicenseRegistry contract
    /// @param groupNFT The address of the GroupNFT contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licenseRegistry,
        address royaltyModule,
        address groupNFT
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (royaltyModule == address(0)) revert Errors.GroupingModule__ZeroRoyaltyModule();
        if (licenseRegistry == address(0)) revert Errors.GroupingModule__ZeroLicenseRegistry();
        if (groupNFT == address(0)) revert Errors.GroupingModule__ZeroGroupNFT();
        if (ipAssetRegistry == address(0)) revert Errors.GroupingModule__ZeroIpAssetRegistry();

        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        GROUP_IP_ASSET_REGISTRY = IGroupIPAssetRegistry(ipAssetRegistry);
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);

        if (!groupNFT.supportsInterface(type(IGroupNFT).interfaceId)) {
            revert Errors.GroupingModule__InvalidGroupNFT(groupNFT);
        }
        GROUP_NFT = IGroupNFT(groupNFT);
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

    /// @notice Registers a Group IPA.
    /// @param groupPool The address of the group pool.
    /// @return groupId The address of the newly registered Group IPA.
    function registerGroup(address groupPool) external whenNotPaused returns (address groupId) {
        // mint Group NFT
        uint256 groupNftId = GROUP_NFT.mintGroupNft(msg.sender, address(this));
        // register Group NFT
        groupId = GROUP_IP_ASSET_REGISTRY.registerGroup(address(GROUP_NFT), groupNftId, groupPool);
        // initialize royalty vault
        // transfer all royalty tokens to the  group pool
        // transfer Group NFT to msg.sender
        GROUP_NFT.safeTransferFrom(address(this), msg.sender, groupNftId);
        emit IPGroupRegistered(groupId, groupPool);
    }

    /// @notice Whitelists a group reward pool.
    /// @param rewardPool The address of the group reward pool.
    function whitelistGroupRewardPool(address rewardPool) external restricted {
        GROUP_IP_ASSET_REGISTRY.whitelistGroupRewardPool(rewardPool);
    }

    /// @notice Adds IP to group.
    /// the function must be called by the Group IP owner or an authorized operator.
    /// @param groupIpId The address of the group IP.
    /// @param ipIds The IP IDs.
    function addIp(address groupIpId, address[] calldata ipIds) external whenNotPaused verifyPermission(groupIpId) {
        GROUP_IP_ASSET_REGISTRY.addGroupMember(groupIpId, ipIds);
        for (uint256 i = 0; i < ipIds.length; i++) {
            IGroupRewardPool(GROUP_IP_ASSET_REGISTRY.getGroupRewardPool(groupIpId)).addIp(groupIpId, ipIds[i]);
        }
        emit AddedIpToGroup(groupIpId, ipIds);
    }

    /// @notice Removes IP from group.
    /// the function must be called by the Group IP owner or an authorized operator.
    /// @param groupIpId The address of the group IP.
    /// @param ipIds The IP IDs.
    function removeIp(address groupIpId, address[] calldata ipIds) external whenNotPaused verifyPermission(groupIpId) {
        if (LICENSE_REGISTRY.hasDerivativeIps(groupIpId)) {
            revert Errors.GroupingModule__GroupIPHasDerivativeIps(groupIpId);
        }
        // distribute reward to the ip to be removed
        // remove ip from group
        GROUP_IP_ASSET_REGISTRY.removeGroupMember(groupIpId, ipIds);
        for (uint256 i = 0; i < ipIds.length; i++) {
            IGroupRewardPool(GROUP_IP_ASSET_REGISTRY.getGroupRewardPool(groupIpId)).removeIp(groupIpId, ipIds[i]);
        }
        emit RemovedIpFromGroup(groupIpId, ipIds);
    }

    /// @notice Claims reward.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    /// @param ipIds The IP IDs.
    function claimReward(address groupId, address token, address[] calldata ipIds) external whenNotPaused {
        IGroupRewardPool pool = IGroupRewardPool(GROUP_IP_ASSET_REGISTRY.getGroupRewardPool(groupId));
        // claim reward from group IPA's RoyaltyVault to group pool
        pool.collectRoyalties(groupId, token);
        // trigger group pool to distribute rewards to group members vault
        uint256[] memory rewards = pool.distributeRewards(groupId, token, ipIds);
        for (uint256 i = 0; i < ipIds.length; i++) {
            emit ClaimedReward(groupId, token, ipIds[i], rewards[i]);
        }
    }

    function name() external pure override returns (string memory) {
        return GROUPING_MODULE_KEY;
    }

    /// @notice Returns the available reward for each IP in the group.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    /// @param ipIds The IP IDs.
    /// @return The rewards for each IP.
    function getClaimableReward(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external view returns (uint256[] memory) {
        // get claimable reward from group pool
        IGroupRewardPool pool = IGroupRewardPool(GROUP_IP_ASSET_REGISTRY.getGroupRewardPool(groupId));
        return pool.getAvailableReward(groupId, token, ipIds);
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
