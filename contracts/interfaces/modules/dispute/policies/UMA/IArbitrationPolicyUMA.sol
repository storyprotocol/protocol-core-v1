// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IArbitrationPolicy } from "../IArbitrationPolicy.sol";
import { IOptimisticOracleV3CallbackRecipient } from "./IOptimisticOracleV3CallbackRecipient.sol";

/// @title Arbitration Policy UMA Interface
interface IArbitrationPolicyUMA is IArbitrationPolicy, IOptimisticOracleV3CallbackRecipient {
    /// @notice Emitted when liveness is set
    /// @param minLiveness The minimum liveness value
    /// @param maxLiveness The maximum liveness value
    event LivenessSet(uint64 minLiveness, uint64 maxLiveness);

    /// @notice Emitted when max bond is set
    /// @param token The token address
    /// @param maxBond The maximum bond value
    event MaxBondSet(address token, uint256 maxBond);

    /// @notice Emitted when a dispute is raised
    /// @param disputeId The dispute id
    /// @param caller The caller address that raised the dispute
    /// @param claim The asserted claim
    /// @param liveness The liveness time
    /// @param currency The bond currency
    /// @param bond The bond size
    /// @param identifier The UMA specific identifier
    event DisputeRaisedUMA(
        uint256 disputeId,
        address caller,
        bytes claim,
        uint64 liveness,
        address currency,
        uint256 bond,
        bytes32 identifier
    );

    /// @notice Sets the liveness for UMA disputes
    /// @param minLiveness The minimum liveness value
    /// @param maxLiveness The maximum liveness value
    function setLiveness(uint64 minLiveness, uint64 maxLiveness) external;

    /// @notice Sets the max bond for UMA disputes
    /// @param token The token address
    /// @param maxBond The maximum bond value
    function setMaxBond(address token, uint256 maxBond) external;
}
