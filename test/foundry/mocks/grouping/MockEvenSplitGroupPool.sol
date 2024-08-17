// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { IGroupRewardPool } from "contracts/interfaces/modules/grouping/IGroupRewardPool.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/// @title Interface for Group IPA  Registry
/// @notice This interface manages the registration and tracking of Group IPA
contract MockEvenSplitGroupPool is IGroupRewardPool {
    struct IpInfo {
        uint amount;     // How many LP tokens the user has provided.
        uint rewardDebt; // pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebt
        uint firstDepositedTime; // keeps track of deposited time.
        uint averageDepositedTime; // use an average time for tier reward calculation.
    }

    struct GroupPoolInfo {
        IERC20 token;           // Address of LP token contract.
        uint allocPoint;       // How many allocation points assigned to this pool.
        uint lastRewardBlock;  // Last block number that reward distribution occurs.
        uint accRewardPerShare; // Accumulated rewards per share, times 1e12.
    }

    // Info of each LP pool.
    LPPoolInfo[] public lpPoolInfo;
    // Info of each user that stakes LP tokens. pid => {user address => UserLPInfo}
    mapping (uint => mapping (address => UserLPInfo)) public userLPInfo;
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

    }
}
