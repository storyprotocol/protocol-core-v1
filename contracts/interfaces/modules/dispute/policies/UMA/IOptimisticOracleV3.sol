// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Optimistic Oracle V3 Interface
interface IOptimisticOracleV3 {
    // Struct grouping together the settings related to the escalation manager stored in the assertion.
    struct EscalationManagerSettings {
        bool arbitrateViaEscalationManager; // False if the DVM is used as an oracle (EscalationManager on True).
        bool discardOracle; // False if Oracle result is used for resolving assertion after dispute.
        bool validateDisputers; // True if the EM isDisputeAllowed should be checked on disputes.
        address assertingCaller; // Stores msg.sender when assertion was made.
        address escalationManager; // Address of the escalation manager (zero address if not configured).
    }

    // Struct for storing properties and lifecycle of an assertion.
    struct Assertion {
        EscalationManagerSettings escalationManagerSettings; // Settings related to the escalation manager.
        address asserter; // Address of the asserter.
        uint64 assertionTime; // Time of the assertion.
        bool settled; // True if the request is settled.
        IERC20 currency; // ERC20 token used to pay rewards and fees.
        uint64 expirationTime; // Unix timestamp marking threshold when the assertion can no longer be disputed.
        bool settlementResolution; // Resolution of the assertion (false till resolved).
        bytes32 domainId; // Optional domain to be used to relate the assertion to others in the escalationManager.
        bytes32 identifier; // UMA DVM identifier to use for price requests in the event of a dispute.
        uint256 bond; // Amount of currency that the asserter has bonded.
        address callbackRecipient; // Address that receives the callback.
        address disputer; // Address of the disputer.
    }

    /// @notice Asserts a truth about the world, using a fully custom configuration.
    /// @param claim the truth claim being asserted. This is an assertion about the world, and is verified by disputers.
    /// @param asserter account that receives bonds back at settlement. This could be msg.sender or
    /// any other account that the caller wants to receive the bond at settlement time.
    /// @param callbackRecipient if configured, this address will receive a function call assertionResolvedCallback and
    /// assertionDisputedCallback at resolution or dispute respectively. Enables dynamic responses to these events. The
    /// recipient _must_ implement these callbacks and not revert or the assertion resolution will be blocked.
    /// @param escalationManager if configured, this address will control escalation properties of the assertion. This
    /// means a) choosing to arbitrate via the UMA DVM, b) choosing to discard assertions on dispute, or choosing to
    /// validate disputes. Combining these, the asserter can define their own security properties for the assertion.
    /// escalationManager also _must_ implement the same callbacks as callbackRecipient.
    /// @param liveness time to wait before the assertion can be resolved. Assertion can be disputed in this time.
    /// @param currency bond currency pulled from the caller and held in escrow until the assertion is resolved.
    /// @param bond amount of currency to pull from the caller and hold in escrow until the assertion is resolved. This
    /// must be >= getMinimumBond(address(currency)).
    /// @param identifier UMA DVM identifier to use for price requests in the event of a dispute. Must be pre-approved.
    /// @param domainId optional domain that can be used to relate this assertion to others in the escalationManager and
    /// can be used by the configured escalationManager to define custom behavior for groups of assertions. This is
    /// typically used for "escalation games" by changing bonds or other assertion properties based on the other
    /// assertions that have come before. If not needed this value should be 0 to save gas.
    /// @return assertionId unique identifier for this assertion.
    function assertTruth(
        bytes memory claim,
        address asserter,
        address callbackRecipient,
        address escalationManager,
        uint64 liveness,
        IERC20 currency,
        uint256 bond,
        bytes32 identifier,
        bytes32 domainId
    ) external returns (bytes32 assertionId);

    /// @notice Disputes an assertion. Depending on how the assertion was configured, this may either escalate to the
    /// UMA DVM or the configured escalation manager for arbitration.
    /// @dev The caller must approve this contract to spend at least bond amount of currency for the associated
    /// assertion.
    /// @param assertionId unique identifier for the assertion to dispute.
    /// @param disputer receives bonds back at settlement.
    function disputeAssertion(bytes32 assertionId, address disputer) external;

    /// @notice Resolves an assertion. If the assertion has not been disputed, the assertion is resolved as true and the
    /// asserter receives the bond. If the assertion has been disputed, the assertion is resolved depending on the
    /// oracle result. Based on the result, the asserter or disputer receives the bond. If the assertion was disputed
    /// then an amount of the bond is sent to the UMA Store as an oracle fee based on the burnedBondPercentage.
    /// The remainder of the bond is returned to the asserter or disputer.
    /// @param assertionId unique identifier for the assertion to resolve.
    function settleAssertion(bytes32 assertionId) external;

    /// @notice Fetches information about a specific assertion and returns it.
    /// @param assertionId unique identifier for the assertion to fetch information for.
    /// @return assertion information about the assertion.
    function getAssertion(bytes32 assertionId) external view returns (Assertion memory);

    /// @notice Appends information onto an assertionId to construct ancillary data used for dispute resolution.
    /// @param assertionId unique identifier for the assertion to construct ancillary data for.
    /// @return ancillaryData stamped assertion information.
    function stampAssertion(bytes32 assertionId) external view returns (bytes memory);
}
