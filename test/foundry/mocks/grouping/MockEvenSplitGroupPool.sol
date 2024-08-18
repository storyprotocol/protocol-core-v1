// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IGroupRewardPool } from "contracts/interfaces/modules/grouping/IGroupRewardPool.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title Interface for Group IPA  Registry
/// @notice This interface manages the registration and tracking of Group IPA
contract MockEvenSplitGroupPool is IGroupRewardPool {
    using SafeERC20 for IERC20;
    struct IpInfo {
        uint amount;     // How many LP tokens the user has provided.
        uint rewardDebt; // pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebt
        uint firstDepositedTime; // keeps track of deposited time.
        uint averageDepositedTime; // use an average time for tier reward calculation.
    }

    struct PoolInfo {
        IERC20 token;           // Address of LP token contract.
        uint accBalance;       // How many allocation points assigned to this pool.
        uint availableBalance;  // Last block number that reward distribution occurs.
        // uint allocPoint;       // How many allocation points assigned to this pool.
        // uint lastRewardBlock;  // Last block number that reward distribution occurs.
        // uint accRewardPerShare; // Accumulated rewards per share, times 1e12.
    }

    // Info of each LP pool.
//    LPPoolInfo[] public lpPoolInfo;
    // Info of each token pool. groupId => { token => PoolInfo}
    mapping( address => mapping(address => PoolInfo)) public poolInfo;
    // Info of each user that stakes LP tokens. groupId => { token => { ipId => IpInfo}}
    mapping (address => mapping(address => mapping (address => IpInfo))) public ipInfo;

    function addIP(address groupId, address ipId) external {
        // set rewardDebt of IP to current availableReward of the IP
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
    ) external view returns (uint256[] memory);

    function distributeRewards(
        address groupId,
        address token,
        address[] calldata ipIds
    ) external {
        uint256[] memory rewards = getAvailableReward(groupId, token, ipIds);
        for (uint256 i = 0; i < ipIds.length; i++) {
            // calculate pending reward for each IP
            ipInfo[groupId][token][ipIds[i]].rewardDebt = rewards[i];
            // call royalty module to transfer reward to IP as royalty
            IERC20(token).safeTransfer(ipIds[i], rewards[i]);
        }
    }

    function collectRoyalties(
        address groupId,
        address token
    ) external {
        // call royalty module to collect revenue of token
        uint256 royalties = 0;
        poolInfo[groupId][token].availableBalance += royalties;
        poolInfo[groupId][token].accBalance += royalties;
    }
}
