// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IArbitrationPolicy } from "../IArbitrationPolicy.sol";
import { IOptimisticOracleV3CallbackRecipient } from "./IOptimisticOracleV3CallbackRecipient.sol";

/// @title Arbitration Policy UMA Interface
interface IArbitrationPolicyUMA is IArbitrationPolicy, IOptimisticOracleV3CallbackRecipient {
    /// @notice Emitted when the minimum liveness is set.
    /// @param minLiveness The minimum liveness value.
    event MinimumLivenessSet(uint64 minLiveness);

    function setMinimumLiveness(uint64 newMinLiveness) external;
}
