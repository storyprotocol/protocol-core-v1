// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IGroupRewardPool } from "contracts/interfaces/modules/grouping/IGroupRewardPool.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IGroupIPAssetRegistry } from "../../../../contracts/interfaces/registries/IGroupIPAssetRegistry.sol";
import { EnumerableSet } from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract MockEvenSplitGroupPool is IGroupRewardPool {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    struct IpInfo {
        uint256 rewardDebt; // pending reward = accBalance / totalIp - ip.rewardDebt
        uint256 addedTime; // keeps track of added time.
    }

    struct PoolInfo {
        uint256 accBalance;
        uint256 availableBalance;
    }

    mapping(address groupId => uint256 totalMemberIPs) public totalMemberIPs;
    mapping(address groupId => EnumerableSet.AddressSet tokens) internal groupTokens;
    // Info of each token pool. groupId => { token => PoolInfo}
    mapping(address groupId => mapping(address token => PoolInfo)) public poolInfo;
    // Info of each user that stakes LP tokens. groupId => { token => { ipId => IpInfo}}
    mapping(address groupId => mapping(address tokenId => mapping(address ipId => IpInfo))) public ipInfo;

    function addIp(address groupId, address ipId) external {
        // set rewardDebt of IP to current availableReward of the IP
        totalMemberIPs[groupId] += 1;
        EnumerableSet.AddressSet storage tokens = groupTokens[groupId];
        uint256 length = tokens.length();
        for (uint256 i = 0; i < length; i++) {
            address token = tokens.at(i);
            _collectRoyalties(groupId, token);
            uint256 totalReward = poolInfo[groupId][token].accBalance;
            uint256 rewardPerIP = totalReward / totalMemberIPs[groupId];
            ipInfo[groupId][token][ipId].rewardDebt = rewardPerIP;
            ipInfo[groupId][token][ipId].addedTime = block.timestamp;
        }
    }

    function removeIp(address groupId, address ipId) external {
        EnumerableSet.AddressSet storage tokens = groupTokens[groupId];
        uint256 length = tokens.length();
        address[] memory ipIds = new address[](1);
        ipIds[0] = ipId;
        for (uint256 i = 0; i < length; i++) {
            address token = tokens.at(i);
            _collectRoyalties(groupId, token);
            _distributeRewards(groupId, token, ipIds);
            ipInfo[groupId][token][ipId].addedTime = 0;
        }
        totalMemberIPs[groupId] -= 1;
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

    function distributeRewards(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external returns (uint256[] memory rewards) {
        return _distributeRewards(groupId, token, ipIds);
    }

    function collectRoyalties(address groupId, address token) external {
        _collectRoyalties(groupId, token);
    }

    function _getAvailableReward(
        address groupId,
        address token,
        address[] memory ipIds
    ) internal view returns (uint256[] memory) {
        uint256 totalReward = poolInfo[groupId][token].accBalance;
        uint256 rewardPerIP = totalReward / totalMemberIPs[groupId];
        uint256[] memory rewards = new uint256[](ipIds.length);
        for (uint256 i = 0; i < ipIds.length; i++) {
            rewards[i] = rewardPerIP - ipInfo[groupId][token][ipIds[i]].rewardDebt;
        }
        return rewards;
    }

    function _distributeRewards(
        address groupId,
        address token,
        address[] memory ipIds
    ) internal returns (uint256[] memory rewards) {
        rewards = _getAvailableReward(groupId, token, ipIds);
        for (uint256 i = 0; i < ipIds.length; i++) {
            // ignore if IP is not added to pool
            if (ipInfo[groupId][token][ipIds[i]].addedTime == 0) {
                continue;
            }
            // calculate pending reward for each IP
            ipInfo[groupId][token][ipIds[i]].rewardDebt += rewards[i];
            // call royalty module to transfer reward to IP as royalty
            IERC20(token).safeTransfer(ipIds[i], rewards[i]);
            poolInfo[groupId][token].availableBalance -= rewards[i];
        }
    }

    function _collectRoyalties(address groupId, address token) internal {
        // call royalty module to collect revenue of token
        uint256 royalties = 0;
        poolInfo[groupId][token].availableBalance += royalties;
        poolInfo[groupId][token].accBalance += royalties;
        groupTokens[groupId].add(token);
    }
}
