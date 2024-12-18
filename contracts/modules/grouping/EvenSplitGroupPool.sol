// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { IGroupRewardPool } from "../../interfaces/modules/grouping/IGroupRewardPool.sol";
import { IRoyaltyModule } from "../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IGroupingModule } from "../../interfaces/modules/grouping/IGroupingModule.sol";
import { IGroupIPAssetRegistry } from "../../interfaces/registries/IGroupIPAssetRegistry.sol";
import { ProtocolPausableUpgradeable } from "../../pause/ProtocolPausableUpgradeable.sol";
import { Errors } from "../../lib/Errors.sol";

contract EvenSplitGroupPool is IGroupRewardPool, ProtocolPausableUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupingModule public immutable GROUPING_MODULE;

    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IGroupIPAssetRegistry public immutable GROUP_IP_ASSET_REGISTRY;

    /// @dev Storage structure for the EvenSplitGroupPool
    /// @custom:storage-location erc7201:story-protocol.EvenSplitGroupPool
    struct EvenSplitGroupPoolStorage {
        mapping(address groupId => mapping(address ipId => uint256 addedTime)) ipAddedTime;
        mapping(address groupId => uint256 totalIps) totalMemberIps;
        mapping(address groupId => mapping(address token => uint256 balance)) poolBalance;
        mapping(address groupId => mapping(address tokenId => mapping(address ipId => uint256))) ipRewardDebt;
        mapping(address groupId => uint256 totalMinimumRewardShare) totalMinimumRewardShare;
        mapping(address groupId => mapping(address ipId => uint256 minimumRewardShare)) minimumRewardShare;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.EvenSplitGroupPool")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant EvenSplitGroupPoolStorageLocation =
        0xe17b84b8162358d82299c7eebd6a64b870d7aca42dea9a37e0604aeaf8f24700;

    /// @dev Only allows the GroupingModule to call the function
    modifier onlyGroupingModule() {
        if (msg.sender != address(GROUPING_MODULE)) {
            revert Errors.EvenSplitGroupPool__CallerIsNotGroupingModule(msg.sender);
        }
        _;
    }

    /// @notice Initializes the EvenSplitGroupPool contract
    /// @param groupingModule The address of the grouping module
    /// @param royaltyModule The address of the royalty module
    /// @param ipAssetRegistry The address of the group IP asset registry
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address groupingModule, address royaltyModule, address ipAssetRegistry) {
        if (groupingModule == address(0)) revert Errors.EvenSplitGroupPool__ZeroGroupingModule();
        if (royaltyModule == address(0)) revert Errors.EvenSplitGroupPool__ZeroRoyaltyModule();
        if (ipAssetRegistry == address(0)) revert Errors.EvenSplitGroupPool__ZeroIPAssetRegistry();
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);
        GROUPING_MODULE = IGroupingModule(groupingModule);
        GROUP_IP_ASSET_REGISTRY = IGroupIPAssetRegistry(ipAssetRegistry);
        _disableInitializers();
    }

    /// @notice initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) public initializer {
        if (accessManager == address(0)) {
            revert Errors.GroupingModule__ZeroAccessManager();
        }
        __UUPSUpgradeable_init();
        __ProtocolPausable_init(accessManager);
    }

    /// @notice Adds an IP to the group pool
    /// @dev Only the GroupingModule can call this function
    /// @param groupId The group ID
    /// @param ipId The IP ID
    /// @param minimumGroupRewardShare The minimum group reward share the IP expects to be added to the group
    /// @return totalGroupRewardShare The total group reward share after adding the IP
    function addIp(
        address groupId,
        address ipId,
        uint256 minimumGroupRewardShare
    ) external onlyGroupingModule returns (uint256 totalGroupRewardShare) {
        EvenSplitGroupPoolStorage storage $ = _getEvenSplitGroupPoolStorage();
        // ignore if IP is already added to pool
        if (_isIpAdded(groupId, ipId)) return $.totalMinimumRewardShare[groupId];
        $.ipAddedTime[groupId][ipId] = block.timestamp;
        $.totalMemberIps[groupId] += 1;
        if (minimumGroupRewardShare > 0) {
            $.minimumRewardShare[groupId][ipId] = minimumGroupRewardShare;
            $.totalMinimumRewardShare[groupId] += minimumGroupRewardShare;
        }
        totalGroupRewardShare = $.totalMinimumRewardShare[groupId];
    }

    /// @notice Removes an IP from the group pool
    /// @dev Only the GroupingModule can call this function
    /// @param groupId The group ID
    /// @param ipId The IP ID
    function removeIp(address groupId, address ipId) external onlyGroupingModule {
        // ignore if IP is not added to pool
        if (!_isIpAdded(groupId, ipId)) return;
        EvenSplitGroupPoolStorage storage $ = _getEvenSplitGroupPoolStorage();
        $.ipAddedTime[groupId][ipId] = 0;
        $.totalMemberIps[groupId] -= 1;
        if ($.minimumRewardShare[groupId][ipId] > 0) {
            $.totalMinimumRewardShare[groupId] -= $.minimumRewardShare[groupId][ipId];
            $.minimumRewardShare[groupId][ipId] = 0;
        }
    }

    /// @notice Deposits reward to the group pool directly
    /// @param groupId The group ID
    /// @param token The reward token
    /// @param amount The amount of reward
    function depositReward(address groupId, address token, uint256 amount) external onlyGroupingModule {
        if (amount == 0) return;
        _getEvenSplitGroupPoolStorage().poolBalance[groupId][token] += amount;
    }

    /// @notice Returns the reward for each IP in the group
    /// @param groupId The group ID
    /// @param token The reward token
    /// @param ipIds The IP IDs
    /// @return The rewards for each IP
    function getAvailableReward(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external view returns (uint256[] memory) {
        return _getAvailableReward(groupId, token, ipIds);
    }

    /// @notice Distributes rewards to the given IP accounts in pool
    /// @param groupId The group ID
    /// @param token The reward tokens
    /// @param ipIds The IP IDs
    function distributeRewards(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external whenNotPaused onlyGroupingModule returns (uint256[] memory rewards) {
        EvenSplitGroupPoolStorage storage $ = _getEvenSplitGroupPoolStorage();
        rewards = new uint256[](ipIds.length);
        uint256 rewardsPerIp = _getRewardPerIp(groupId, token);
        uint256 totalRewards = rewardsPerIp * ipIds.length;
        if (totalRewards == 0) return rewards;
        IERC20(token).forceApprove(address(ROYALTY_MODULE), totalRewards);
        for (uint256 i = 0; i < ipIds.length; i++) {
            if (!_isIpAdded(groupId, ipIds[i])) continue;
            // calculate pending reward for each IP
            rewards[i] = rewardsPerIp - $.ipRewardDebt[groupId][token][ipIds[i]];
            if (rewards[i] == 0) continue;
            $.ipRewardDebt[groupId][token][ipIds[i]] += rewards[i];
            // call royalty module to transfer reward to IP's vault as royalty
            ROYALTY_MODULE.payRoyaltyOnBehalf(ipIds[i], groupId, token, rewards[i]);
        }
        IERC20(token).forceApprove(address(ROYALTY_MODULE), 0);
    }

    function getTotalIps(address groupId) external view returns (uint256) {
        return _getEvenSplitGroupPoolStorage().totalMemberIps[groupId];
    }

    function getIpAddedTime(address groupId, address ipId) external view returns (uint256) {
        return _getEvenSplitGroupPoolStorage().ipAddedTime[groupId][ipId];
    }

    function getIpRewardDebt(address groupId, address token, address ipId) external view returns (uint256) {
        return _getEvenSplitGroupPoolStorage().ipRewardDebt[groupId][token][ipId];
    }

    function isIPAdded(address groupId, address ipId) external view returns (bool) {
        return _isIpAdded(groupId, ipId);
    }

    function getMinimumRewardShare(address groupId, address ipId) external view returns (uint256) {
        return _getEvenSplitGroupPoolStorage().minimumRewardShare[groupId][ipId];
    }

    function getTotalMinimumRewardShare(address groupId) external view returns (uint256) {
        return _getEvenSplitGroupPoolStorage().totalMinimumRewardShare[groupId];
    }

    function _getRewardPerIp(address groupId, address token) internal view returns (uint256) {
        EvenSplitGroupPoolStorage storage $ = _getEvenSplitGroupPoolStorage();
        uint256 totalIps = $.totalMemberIps[groupId];
        if (totalIps == 0) return 0;
        return $.poolBalance[groupId][token] / totalIps;
    }

    /// @dev Returns the available reward for each IP in the group of given token
    /// @param groupId The group ID
    /// @param token The reward token
    /// @param ipIds The IP IDs
    function _getAvailableReward(
        address groupId,
        address token,
        address[] memory ipIds
    ) internal view returns (uint256[] memory) {
        EvenSplitGroupPoolStorage storage $ = _getEvenSplitGroupPoolStorage();
        uint256 rewardPerIp = _getRewardPerIp(groupId, token);
        if (rewardPerIp == 0) return new uint256[](ipIds.length);

        uint256[] memory rewards = new uint256[](ipIds.length);
        for (uint256 i = 0; i < ipIds.length; i++) {
            // ignore if IP is not added to pool
            if (!_isIpAdded(groupId, ipIds[i])) {
                rewards[i] = 0;
                continue;
            }
            rewards[i] = rewardPerIp - $.ipRewardDebt[groupId][token][ipIds[i]];
        }
        return rewards;
    }

    /// @dev checks if IP is added to group pool
    function _isIpAdded(address groupId, address ipId) internal view returns (bool) {
        return _getEvenSplitGroupPoolStorage().ipAddedTime[groupId][ipId] != 0;
    }

    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of EvenSplitGroupPool.
    function _getEvenSplitGroupPoolStorage() private pure returns (EvenSplitGroupPoolStorage storage $) {
        assembly {
            $.slot := EvenSplitGroupPoolStorageLocation
        }
    }
}
