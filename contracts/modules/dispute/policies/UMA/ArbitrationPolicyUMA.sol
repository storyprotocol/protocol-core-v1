// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { IDisputeModule } from "../../../../interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicyUMA } from "../../../../interfaces/modules/dispute/policies/UMA/IArbitrationPolicyUMA.sol";
import { IOptimisticOracleV3 } from "../../../../interfaces/modules/dispute/policies/UMA/IOptimisticOracleV3.sol";
import { ProtocolPausableUpgradeable } from "../../../../pause/ProtocolPausableUpgradeable.sol";
import { Errors } from "../../../../lib/Errors.sol";

contract ArbitrationPolicyUMA is IArbitrationPolicyUMA, ProtocolPausableUpgradeable {
    address public immutable DISPUTE_MODULE;

    IOptimisticOracleV3 public immutable OPTIMISTIC_ORACLE_V3;

    /// @dev Storage structure for the ArbitrationPolicyUMA
    /// @custom:storage-location erc7201:story-protocol.ArbitrationPolicyUMA
    struct ArbitrationPolicyUMAStorage {
        uint64 minLiveness;
        mapping(bytes32 assertionId => uint256 disputeId) assertionIdToDisputeId;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.ArbitrationPolicyUMA")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant ArbitrationPolicyUMAStorageLocation =
        0xbd39630b628d883a3167c4982acf741cbddb24bae6947600210f8eb1db515300;

    modifier onlyDisputeModule() {
        if (msg.sender != DISPUTE_MODULE) revert Errors.ArbitrationPolicyUMA__OnlyDisputeModule();
        _;
    }

    constructor(address _disputeModule, address _optimisticOracleV3) {
        // TODO: revert if adddress(0)
        DISPUTE_MODULE = _disputeModule;
        OPTIMISTIC_ORACLE_V3 = IOptimisticOracleV3(_optimisticOracleV3);
    }

    function setMinimumLiveness(uint64 newMinLiveness) external restricted {
        if (newMinLiveness == 0) revert Errors.ArbitrationPolicyUMA__ZeroLiveness();

        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();
        $.minLiveness = newMinLiveness;

        emit MinimumLivenessSet(newMinLiveness);
    }

    /// @notice Executes custom logic on raising dispute
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller
    /// @param data The arbitrary data used to raise the dispute
    function onRaiseDispute(address caller, bytes calldata data) external onlyDisputeModule {
        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();

        (bytes memory claim, uint64 liveness, IERC20 currency, uint256 bond, bytes32 identifier) = abi.decode(
            data,
            (bytes, uint64, IERC20, uint256, bytes32)
        );

        if (liveness < $.minLiveness) revert Errors.ArbitrationPolicyUMA__LivenessTooShort();

        bytes32 assertionId = OPTIMISTIC_ORACLE_V3.assertTruth(
            claim,
            caller, // asserter
            address(this), // callbackRecipient
            address(0), // escalationManager
            liveness,
            currency,
            bond,
            identifier,
            bytes32(0) // domainId
        );

        $.assertionIdToDisputeId[assertionId] = IDisputeModule(DISPUTE_MODULE).disputeCounter();
    }

    /// @notice Executes custom logic on disputing judgement
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The arbitrary data used to set the dispute judgement
    function onDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external onlyDisputeModule {
        // TODO
        // TODO: remove access control if empty
    }

    /// @notice Executes custom logic on disputing cancel
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to cancel the dispute
    function onDisputeCancel(address caller, uint256 disputeId, bytes calldata data) external onlyDisputeModule {
        // TODO
        // TODO: remove access control if empty
    }

    /// @notice Executes custom logic on resolving dispute
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to resolve the dispute
    function onResolveDispute(address caller, uint256 disputeId, bytes calldata data) external onlyDisputeModule {
        // TODO
        // TODO: remove access control if empty
    }

    /// @notice Callback function that is called by Optimistic Oracle V3 when an assertion is resolved
    /// @param assertionId The identifier of the assertion that was resolved
    /// @param assertedTruthfully Whether the assertion was resolved as truthful or not
    function assertionResolvedCallback(bytes32 assertionId, bool assertedTruthfully) external {
        // TODO: access control

        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();
        uint256 disputeId = $.assertionIdToDisputeId[assertionId];

        IDisputeModule(DISPUTE_MODULE).setDisputeJudgement(disputeId, assertedTruthfully, "");
    }

    /// @notice Callback function that is called by Optimistic Oracle V3 when an assertion is disputed
    /// @param assertionId The identifier of the assertion that was disputed
    function assertionDisputedCallback(bytes32 assertionId) external {
        // TODO: access control
        // TODO
    }

    /// @dev Returns the storage struct of ArbitrationPolicyUMA
    function _getArbitrationPolicyUMAStorage() private pure returns (ArbitrationPolicyUMAStorage storage $) {
        assembly {
            $.slot := ArbitrationPolicyUMAStorageLocation
        }
    }
}
