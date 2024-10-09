// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Optimistic Oracle V3 Interface
interface IOptimisticOracleV3 {
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
}
