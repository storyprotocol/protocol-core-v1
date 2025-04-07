// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IArbitrationPolicy } from "../IArbitrationPolicy.sol";
import { IOOV3Callbacks } from "./IOOV3Callbacks.sol";

/// @title Arbitration Policy UMA Interface
interface IArbitrationPolicyUMA is IArbitrationPolicy, IOOV3Callbacks {
    /// @notice Emitted when the OOV3 address is set
    /// @param oov3 The address of the OOV3
    event OOV3Set(address oov3);

    /// @notice Emitted when liveness is set
    /// @param minLiveness The minimum liveness value
    /// @param maxLiveness The maximum liveness value
    /// @param ipOwnerTimePercent The percentage of liveness time the IP owner has priority to respond to a dispute
    event LivenessSet(uint64 minLiveness, uint64 maxLiveness, uint32 ipOwnerTimePercent);

    /// @notice Emitted when max bond is set
    /// @param token The token address
    /// @param maxBond The maximum bond value
    event MaxBondSet(address token, uint256 maxBond);

    /// @notice Emitted when a dispute is raised
    /// @param disputeId The dispute id
    /// @param assertionId The assertion id
    /// @param disputeInitiator The address that initiated the dispute
    /// @param liveness The liveness time
    /// @param currency The bond currency
    /// @param bond The bond size
    event DisputeRaisedUMA(
        uint256 disputeId,
        bytes32 assertionId,
        address disputeInitiator,
        uint64 liveness,
        address currency,
        uint256 bond
    );

    /// @notice Emitted when an assertion is disputed
    /// @param disputeId The dispute id
    /// @param assertionId The assertion id
    /// @param counterEvidenceHash The counter evidence hash
    event AssertionDisputed(uint256 disputeId, bytes32 assertionId, bytes32 counterEvidenceHash);

    /// @notice Sets the OOV3 address
    /// @param oov3 The address of the OOV3
    function setOOV3(address oov3) external;

    /// @notice Sets the liveness for UMA disputes
    /// @param minLiveness The minimum liveness value
    /// @param maxLiveness The maximum liveness value
    /// @param ipOwnerTimePercent The percentage of liveness time the IP owner has priority to respond to a dispute
    function setLiveness(uint64 minLiveness, uint64 maxLiveness, uint32 ipOwnerTimePercent) external;

    /// @notice Sets the max bond for UMA disputes
    /// @param token The token address
    /// @param maxBond The maximum bond value
    function setMaxBond(address token, uint256 maxBond) external;

    /// @notice Allows the IP that was targeted with a dispute to dispute the assertion while providing counter evidence
    /// @param assertionId The identifier of the assertion that was disputed
    /// @param counterEvidenceHash The hash of the counter evidence
    function disputeAssertion(bytes32 assertionId, bytes32 counterEvidenceHash) external;

    /// @notice Returns the minimum liveness for UMA disputes
    function minLiveness() external view returns (uint64);

    /// @notice Returns the maximum liveness for UMA disputes
    function maxLiveness() external view returns (uint64);

    /// @notice Returns the percentage of liveness time the IP owner has priority to respond to a dispute
    function ipOwnerTimePercent() external view returns (uint32);

    /// @notice Returns the percentage of liveness time the IP owner has priority to respond to a dispute
    /// for a given dispute id
    function ipOwnerTimePercents(uint256 disputeId) external view returns (uint32);

    /// @notice Returns the OOV3 address
    function oov3() external view returns (address);

    /// @notice Returns the maximum bond for a given token for UMA disputes
    /// @param token The token address
    function maxBonds(address token) external view returns (uint256);

    /// @notice Returns the assertion id for a given dispute id
    /// @param disputeId The dispute id
    function disputeIdToAssertionId(uint256 disputeId) external view returns (bytes32);

    /// @notice Returns the dispute id for a given assertion id
    /// @param assertionId The assertion id
    function assertionIdToDisputeId(bytes32 assertionId) external view returns (uint256);
}
