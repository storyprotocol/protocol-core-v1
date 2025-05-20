// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

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
import { AccessControlled } from "../../access/AccessControlled.sol";
import { BaseModule } from "../BaseModule.sol";
import { IPAccountStorageOps } from "../../lib/IPAccountStorageOps.sol";
import { ProtocolPausableUpgradeable } from "../../pause/ProtocolPausableUpgradeable.sol";
import { IGroupingModule } from "../../interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupRewardPool } from "../../interfaces/modules/grouping/IGroupRewardPool.sol";
import { GROUPING_MODULE_KEY } from "../../lib/modules/Module.sol";
import { ILicenseTemplate } from "../../interfaces/modules/licensing/ILicenseTemplate.sol";
import { ILicenseToken } from "../../interfaces/ILicenseToken.sol";
import { IRoyaltyModule } from "../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IDisputeModule } from "../../interfaces/modules/dispute/IDisputeModule.sol";
import { IIpRoyaltyVault } from "../../interfaces/modules/royalty/policies/IIpRoyaltyVault.sol";
import { Licensing } from "../../lib/Licensing.sol";

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

    /// @notice Returns the canonical protocol-wide LicenseToken
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseToken public immutable LICENSE_TOKEN;

    /// @notice Returns the address GROUP NFT contract
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupNFT public immutable GROUP_NFT;

    /// @notice Returns the canonical protocol-wide Group IP Asset Registry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupIPAssetRegistry public immutable GROUP_IP_ASSET_REGISTRY;

    /// @notice Returns the canonical protocol-wide LicenseRegistry
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseRegistry public immutable LICENSE_REGISTRY;

    /// @notice Returns the protocol-wide dispute module
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    // keccak256(abi.encode(uint256(keccak256("story-protocol.GroupingModule")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant GroupingModuleStorageLocation =
        0x4f35861babcda7cb8a75afddcc0971d8dc0cbbd9d19afddbe94e0dcd72824100;

    /// Constructor
    /// @param accessController The address of the AccessController contract
    /// @param ipAssetRegistry The address of the IpAssetRegistry contract
    /// @param licenseToken The address of the LicenseToken contract
    /// @param licenseRegistry The address of the LicenseRegistry contract
    /// @param groupNFT The address of the GroupNFT contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAssetRegistry,
        address licenseRegistry,
        address licenseToken,
        address groupNFT,
        address royaltyModule,
        address disputeModule
    ) AccessControlled(accessController, ipAssetRegistry) {
        if (licenseToken == address(0)) revert Errors.GroupingModule__ZeroLicenseToken();
        if (licenseRegistry == address(0)) revert Errors.GroupingModule__ZeroLicenseRegistry();
        if (groupNFT == address(0)) revert Errors.GroupingModule__ZeroGroupNFT();
        if (ipAssetRegistry == address(0)) revert Errors.GroupingModule__ZeroIpAssetRegistry();
        if (royaltyModule == address(0)) revert Errors.GroupingModule__ZeroRoyaltyModule();
        if (disputeModule == address(0)) revert Errors.GroupingModule__ZeroRoyaltyModule();

        LICENSE_TOKEN = ILicenseToken(licenseToken);
        GROUP_IP_ASSET_REGISTRY = IGroupIPAssetRegistry(ipAssetRegistry);
        LICENSE_REGISTRY = ILicenseRegistry(licenseRegistry);
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        DISPUTE_MODULE = IDisputeModule(disputeModule);

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
    function registerGroup(address groupPool) external nonReentrant whenNotPaused returns (address groupId) {
        // mint Group NFT
        uint256 groupNftId = GROUP_NFT.mintGroupNft(msg.sender, msg.sender);
        // register Group NFT
        groupId = GROUP_IP_ASSET_REGISTRY.registerGroup(address(GROUP_NFT), groupNftId, groupPool, msg.sender);
        emit IPGroupRegistered(groupId, groupPool);
    }

    /// @notice Whitelists a group reward pool.
    /// @param rewardPool The address of the group reward pool.
    /// @param allowed Whether the group reward pool is whitelisted.
    function whitelistGroupRewardPool(address rewardPool, bool allowed) external restricted {
        if (rewardPool == address(0)) {
            revert Errors.GroupingModule__ZeroGroupRewardPool();
        }

        GROUP_IP_ASSET_REGISTRY.whitelistGroupRewardPool(rewardPool, allowed);
    }

    /// @notice Adds IP to group.
    /// the function must be called by the Group IP owner or an authorized operator.
    /// @param groupIpId The address of the group IP.
    /// @param ipIds The IP IDs.
    /// @param maxAllowedRewardShare The maximum reward share percentage that can be allocated to each member IP.
    function addIp(
        address groupIpId,
        address[] calldata ipIds,
        uint256 maxAllowedRewardShare
    ) external nonReentrant whenNotPaused verifyPermission(groupIpId) {
        if (maxAllowedRewardShare > 100 * 10 ** 6) {
            revert Errors.GroupingModule__MaxAllowedRewardShareExceeds100Percent(groupIpId, maxAllowedRewardShare);
        }
        if (DISPUTE_MODULE.isIpTagged(groupIpId)) {
            revert Errors.GroupingModule__DisputedGroupCannotAddIp(groupIpId);
        }
        (address groupLicenseTemplate, uint256 groupLicenseTermsId, address currencyToken) = _getGroupRevenueInfo(
            groupIpId
        );

        GROUP_IP_ASSET_REGISTRY.addGroupMember(groupIpId, ipIds);
        IGroupRewardPool pool = IGroupRewardPool(GROUP_IP_ASSET_REGISTRY.getGroupRewardPool(groupIpId));
        _collectRoyalties(groupIpId, currencyToken);
        for (uint256 i = 0; i < ipIds.length; i++) {
            if (GROUP_IP_ASSET_REGISTRY.isRegisteredGroup(ipIds[i])) {
                revert Errors.GroupingModule__CannotAddGroupToGroup(groupIpId, ipIds[i]);
            }
            if (DISPUTE_MODULE.isIpTagged(ipIds[i])) {
                revert Errors.GroupingModule__CannotAddDisputedIpToGroup(ipIds[i]);
            }

            Licensing.LicensingConfig memory lc = LICENSE_REGISTRY.verifyGroupAddIp(
                groupIpId,
                address(pool),
                ipIds[i],
                groupLicenseTemplate,
                groupLicenseTermsId
            );
            if (lc.expectMinimumGroupRewardShare > maxAllowedRewardShare) {
                revert Errors.GroupingModule__IpExpectedShareExceedsMaxAllowedShare(
                    groupIpId,
                    ipIds[i],
                    maxAllowedRewardShare,
                    lc.expectMinimumGroupRewardShare
                );
            }
            uint256 totalGroupRewardShare = pool.addIp(groupIpId, ipIds[i], lc.expectMinimumGroupRewardShare);
            if (totalGroupRewardShare > 100 * 10 ** 6) {
                revert Errors.GroupingModule__TotalGroupRewardShareExceeds100Percent(
                    groupIpId,
                    totalGroupRewardShare,
                    ipIds[i],
                    lc.expectMinimumGroupRewardShare
                );
            }
        }
        emit AddedIpToGroup(groupIpId, ipIds);
    }

    /// @notice Removes IP from group.
    /// the function must be called by the Group IP owner or an authorized operator.
    /// @param groupIpId The address of the group IP.
    /// @param ipIds The IP IDs.
    function removeIp(
        address groupIpId,
        address[] calldata ipIds
    ) external nonReentrant whenNotPaused verifyPermission(groupIpId) {
        _checkIfGroupMembersLocked(groupIpId);
        (, , address currencyToken) = _getGroupRevenueInfo(groupIpId);
        _collectRoyalties(groupIpId, currencyToken);
        _claimReward(groupIpId, currencyToken, ipIds);
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
    function claimReward(address groupId, address token, address[] calldata ipIds) external nonReentrant whenNotPaused {
        (, , address currencyToken) = _getGroupRevenueInfo(groupId);
        if (currencyToken != token) {
            revert Errors.GroupingModule__TokenNotMatchGroupRevenueToken(groupId, currencyToken, token);
        }
        _claimReward(groupId, token, ipIds);
    }

    /// @notice Collects royalties into the pool, making them claimable by group member IPs.
    /// @param groupId The address of the group.
    /// @param token The address of the token.
    function collectRoyalties(
        address groupId,
        address token
    ) external nonReentrant whenNotPaused returns (uint256 royalties) {
        (, , address currencyToken) = _getGroupRevenueInfo(groupId);
        if (currencyToken != token) {
            revert Errors.GroupingModule__TokenNotMatchGroupRevenueToken(groupId, currencyToken, token);
        }
        royalties = _collectRoyalties(groupId, token);
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
        // if the group is disputed, then the claimable reward is 0
        if (DISPUTE_MODULE.isIpTagged(groupId)) {
            return new uint256[](ipIds.length);
        }

        // get claimable reward from group pool
        IGroupRewardPool pool = IGroupRewardPool(GROUP_IP_ASSET_REGISTRY.getGroupRewardPool(groupId));
        return pool.getAvailableReward(groupId, token, ipIds);
    }

    /// @dev claim reward from group pool
    function _claimReward(address groupId, address token, address[] calldata ipIds) internal {
        if (DISPUTE_MODULE.isIpTagged(groupId)) {
            revert Errors.GroupingModule__DisputedGroupCannotClaimReward(groupId);
        }
        IGroupRewardPool pool = IGroupRewardPool(GROUP_IP_ASSET_REGISTRY.getGroupRewardPool(groupId));
        if (!GROUP_IP_ASSET_REGISTRY.isWhitelistedGroupRewardPool(address(pool))) {
            revert Errors.GroupingModule__GroupRewardPoolNotWhitelisted(groupId, address(pool));
        }
        if (!ROYALTY_MODULE.isWhitelistedRoyaltyToken(token)) {
            revert Errors.GroupingModule__RoyaltyTokenNotWhitelisted(groupId, token);
        }
        // deploy vault for each group member if not already deployed
        for (uint256 i = 0; i < ipIds.length; i++) {
            if (ROYALTY_MODULE.ipRoyaltyVaults(ipIds[i]) == address(0)) ROYALTY_MODULE.deployVault(ipIds[i]);
        }
        // trigger group pool to distribute rewards to group members vault
        uint256[] memory rewards = pool.distributeRewards(groupId, token, ipIds);
        emit ClaimedReward(groupId, token, ipIds, rewards);
    }

    /// @dev collect royalties into the pool
    function _collectRoyalties(address groupId, address token) internal returns (uint256 royalties) {
        if (DISPUTE_MODULE.isIpTagged(groupId)) {
            revert Errors.GroupingModule__DisputedGroupCannotCollectRoyalties(groupId);
        }
        IGroupRewardPool pool = IGroupRewardPool(GROUP_IP_ASSET_REGISTRY.getGroupRewardPool(groupId));
        if (!GROUP_IP_ASSET_REGISTRY.isWhitelistedGroupRewardPool(address(pool))) {
            revert Errors.GroupingModule__GroupRewardPoolNotWhitelisted(groupId, address(pool));
        }
        if (!ROYALTY_MODULE.isWhitelistedRoyaltyToken(token)) {
            revert Errors.GroupingModule__RoyaltyTokenNotWhitelisted(groupId, token);
        }
        IIpRoyaltyVault vault = IIpRoyaltyVault(ROYALTY_MODULE.ipRoyaltyVaults(groupId));

        if (address(vault) == address(0)) return 0;
        royalties = vault.claimableRevenue(address(pool), token);
        if (royalties == 0) return 0;
        royalties = vault.claimRevenueOnBehalf(address(pool), token);
        pool.depositReward(groupId, token, royalties);
        emit CollectedRoyaltiesToGroupPool(groupId, token, address(pool), royalties);
    }

    /// @dev Get the group revenue info
    function _getGroupRevenueInfo(
        address groupIpId
    ) internal view returns (address groupLicenseTemplate, uint256 groupLicenseTermsId, address currencyToken) {
        // the group IP must has license terms and minting fee is 0 to be able to add IP to group
        if (LICENSE_REGISTRY.getAttachedLicenseTermsCount(groupIpId) == 0) {
            revert Errors.GroupingModule__GroupIPHasNoLicenseTerms(groupIpId);
        }
        (groupLicenseTemplate, groupLicenseTermsId) = LICENSE_REGISTRY.getAttachedLicenseTerms(groupIpId, 0);

        IGroupRewardPool pool = IGroupRewardPool(GROUP_IP_ASSET_REGISTRY.getGroupRewardPool(groupIpId));
        (, , , currencyToken) = ILicenseTemplate(groupLicenseTemplate).getRoyaltyPolicy(groupLicenseTermsId);
        if (currencyToken == address(0)) {
            revert Errors.GroupingModule__GroupIPLicenseHasNotSpecifyRevenueToken(groupIpId);
        }
        return (groupLicenseTemplate, groupLicenseTermsId, currencyToken);
    }

    /// @dev The group members are locked if the group has derivative IPs or license tokens minted.
    function _checkIfGroupMembersLocked(address groupIpId) internal view {
        if (LICENSE_REGISTRY.hasDerivativeIps(groupIpId)) {
            revert Errors.GroupingModule__GroupFrozenDueToHasDerivativeIps(groupIpId);
        }
        if (LICENSE_TOKEN.getTotalTokensByLicensor(groupIpId) > 0) {
            revert Errors.GroupingModule__GroupFrozenDueToAlreadyMintLicenseTokens(groupIpId);
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}
}
