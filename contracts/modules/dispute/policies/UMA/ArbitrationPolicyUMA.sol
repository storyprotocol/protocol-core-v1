// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";

import { IDisputeModule } from "../../../../interfaces/modules/dispute/IDisputeModule.sol";
import { IRoyaltyModule } from "../../../../interfaces/modules/royalty/IRoyaltyModule.sol";
import { IArbitrationPolicyUMA } from "../../../../interfaces/modules/dispute/policies/UMA/IArbitrationPolicyUMA.sol";
import { IOOV3 } from "../../../../interfaces/modules/dispute/policies/UMA/IOOV3.sol";
import { ProtocolPausableUpgradeable } from "../../../../pause/ProtocolPausableUpgradeable.sol";
import { BytesConversion } from "../../../../lib/BytesConversion.sol";
import { Errors } from "../../../../lib/Errors.sol";

/// @title Arbitration Policy UMA
/// @notice The arbitration policy UMA acts as an enforcement layer for IP assets that allows raising and judging
/// disputes according to the UMA protocol rules.
contract ArbitrationPolicyUMA is
    IArbitrationPolicyUMA,
    ProtocolPausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice Dispute module address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IDisputeModule public immutable DISPUTE_MODULE;

    /// @notice Royalty module address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    IRoyaltyModule public immutable ROYALTY_MODULE;

    /// @dev Storage structure for the ArbitrationPolicyUMA
    /// @param minLiveness The minimum liveness value
    /// @param maxLiveness The maximum liveness value
    /// @param ipOwnerTimePercent The percentage of liveness time the IP owner has priority to respond to a dispute
    /// @param oov3 The address of the OOV3
    /// @param maxBonds The maximum bond size for each token
    /// @param disputeIdToAssertionId The mapping of dispute id to assertion id
    /// @param assertionIdToDisputeId The mapping of assertion id to dispute id
    /// @param counterEvidenceHashes The mapping of assertion id to counter evidence hash
    /// @param ipOwnerTimePercents The mapping of dispute id to ip owner time percent of the dispute
    /// @custom:storage-location erc7201:story-protocol.ArbitrationPolicyUMA
    struct ArbitrationPolicyUMAStorage {
        uint64 minLiveness;
        uint64 maxLiveness;
        uint32 ipOwnerTimePercent;
        IOOV3 oov3;
        mapping(address token => uint256 maxBondSize) maxBonds;
        mapping(uint256 disputeId => bytes32 assertionId) disputeIdToAssertionId;
        mapping(bytes32 assertionId => uint256 disputeId) assertionIdToDisputeId;
        mapping(bytes32 assertionId => bytes32 counterEvidenceHash) counterEvidenceHashes;
        mapping(uint256 disputeId => uint32 ipOwnerTimePercent) ipOwnerTimePercents;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.ArbitrationPolicyUMA")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant ArbitrationPolicyUMAStorageLocation =
        0xbd39630b628d883a3167c4982acf741cbddb24bae6947600210f8eb1db515300;

    /// @dev Restricts the calls to the dispute module
    modifier onlyDisputeModule() {
        if (msg.sender != address(DISPUTE_MODULE)) revert Errors.ArbitrationPolicyUMA__NotDisputeModule();
        _;
    }

    /// Constructor
    /// @param disputeModule The address of the dispute module
    /// @param royaltyModule The address of the royalty module
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address disputeModule, address royaltyModule) {
        if (disputeModule == address(0)) revert Errors.ArbitrationPolicyUMA__ZeroDisputeModule();
        if (royaltyModule == address(0)) revert Errors.ArbitrationPolicyUMA__ZeroRoyaltyModule();

        DISPUTE_MODULE = IDisputeModule(disputeModule);
        ROYALTY_MODULE = IRoyaltyModule(royaltyModule);

        _disableInitializers();
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    function initialize(address accessManager) external initializer {
        if (accessManager == address(0)) revert Errors.ArbitrationPolicyUMA__ZeroAccessManager();

        __ProtocolPausable_init(accessManager);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    /// @notice Sets the OOV3 address
    /// @param oov3 The address of the OOV3
    function setOOV3(address oov3) external restricted {
        if (oov3 == address(0)) revert Errors.ArbitrationPolicyUMA__ZeroOOV3();

        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();
        $.oov3 = IOOV3(oov3);

        emit OOV3Set(oov3);
    }

    /// @notice Sets the liveness for UMA disputes
    /// @param minLiveness The minimum liveness value
    /// @param maxLiveness The maximum liveness value
    /// @param ipOwnerTimePercent The percentage of liveness time the IP owner has priority to respond to a dispute
    function setLiveness(uint64 minLiveness, uint64 maxLiveness, uint32 ipOwnerTimePercent) external restricted {
        if (minLiveness == 0) revert Errors.ArbitrationPolicyUMA__ZeroMinLiveness();
        if (maxLiveness == 0) revert Errors.ArbitrationPolicyUMA__ZeroMaxLiveness();
        if (minLiveness > maxLiveness) revert Errors.ArbitrationPolicyUMA__MinLivenessAboveMax();
        if (ipOwnerTimePercent > ROYALTY_MODULE.maxPercent())
            revert Errors.ArbitrationPolicyUMA__IpOwnerTimePercentAboveMax();

        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();
        $.minLiveness = minLiveness;
        $.maxLiveness = maxLiveness;
        $.ipOwnerTimePercent = ipOwnerTimePercent;

        emit LivenessSet(minLiveness, maxLiveness, ipOwnerTimePercent);
    }

    /// @notice Sets the max bond for UMA disputes
    /// @param token The token address
    /// @param maxBond The maximum bond value
    function setMaxBond(address token, uint256 maxBond) external restricted {
        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();
        if (maxBond < $.oov3.getMinimumBond(token)) revert Errors.ArbitrationPolicyUMA__MaxBondBelowMinimumBond();

        $.maxBonds[token] = maxBond;

        emit MaxBondSet(token, maxBond);
    }

    /// @notice Executes custom logic on raising dispute
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller which will cover the dispute bond amount
    /// @param disputeInitiator Address of the dispute initiator which will receive the bond upon winning the dispute
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to raise the dispute
    function onRaiseDispute(
        address caller,
        address disputeInitiator,
        address targetIpId,
        bytes32 disputeEvidenceHash,
        bytes32 targetTag,
        uint256 disputeId,
        bytes calldata data
    ) external nonReentrant onlyDisputeModule whenNotPaused {
        (uint64 liveness, IERC20 currencyToken, uint256 bond) = abi.decode(data, (uint64, IERC20, uint256));

        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();
        if (liveness < $.minLiveness) revert Errors.ArbitrationPolicyUMA__LivenessBelowMin();
        if (liveness > $.maxLiveness) revert Errors.ArbitrationPolicyUMA__LivenessAboveMax();
        if (bond > $.maxBonds[address(currencyToken)]) revert Errors.ArbitrationPolicyUMA__BondAboveMax();
        if (!ROYALTY_MODULE.isWhitelistedRoyaltyToken(address(currencyToken)))
            revert Errors.ArbitrationPolicyUMA__CurrencyNotWhitelisted();

        IOOV3 oov3 = $.oov3;
        currencyToken.safeTransferFrom(caller, address(this), bond);
        currencyToken.safeIncreaseAllowance(address(oov3), bond);

        bytes32 assertionId = oov3.assertTruth(
            _constructClaim(targetIpId, targetTag, disputeEvidenceHash, disputeId),
            disputeInitiator, // asserter
            address(this), // callbackRecipient
            address(0), // escalationManager
            liveness,
            currencyToken,
            bond,
            bytes32("ASSERT_TRUTH"), // identifier
            bytes32(0) // domainId
        );

        $.ipOwnerTimePercents[disputeId] = $.ipOwnerTimePercent;
        $.assertionIdToDisputeId[assertionId] = disputeId;
        $.disputeIdToAssertionId[disputeId] = assertionId;

        emit DisputeRaisedUMA(disputeId, assertionId, disputeInitiator, liveness, address(currencyToken), bond);
    }

    /// @notice Executes custom logic on disputing judgement
    /// @dev Enforced to be only callable by the DisputeModule. For UMA arbitration, no custom logic is required.
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The arbitrary data used to set the dispute judgement
    function onDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external onlyDisputeModule {}

    /// @notice Executes custom logic on disputing cancel
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to cancel the dispute
    function onDisputeCancel(address caller, uint256 disputeId, bytes calldata data) external onlyDisputeModule {
        revert Errors.ArbitrationPolicyUMA__CannotCancel();
    }

    /// @notice Executes custom logic on resolving dispute
    /// @dev Enforced to be only callable by the DisputeModule. For UMA arbitration, no custom logic is required.
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to resolve the dispute
    function onResolveDispute(address caller, uint256 disputeId, bytes calldata data) external onlyDisputeModule {}

    /// @notice Allows the IP that was targeted to dispute the assertion while providing counter evidence
    /// @param assertionId The identifier of the assertion that was disputed
    /// @param counterEvidenceHash The hash of the counter evidence
    function disputeAssertion(bytes32 assertionId, bytes32 counterEvidenceHash) external nonReentrant {
        if (counterEvidenceHash == bytes32(0)) revert Errors.ArbitrationPolicyUMA__NoCounterEvidence();

        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();
        uint256 disputeId = $.assertionIdToDisputeId[assertionId];
        if (disputeId == 0) revert Errors.ArbitrationPolicyUMA__DisputeNotFound();

        (address targetIpId, , , address arbitrationPolicy, , , , uint256 parentDisputeId) = DISPUTE_MODULE.disputes(
            disputeId
        );

        if (arbitrationPolicy != address(this)) revert Errors.ArbitrationPolicyUMA__OnlyDisputePolicyUMA();
        if (parentDisputeId > 0) revert Errors.ArbitrationPolicyUMA__CannotDisputeAssertionIfTagIsInherited();

        // Check if the address can dispute the assertion depending on the liveness and the elapsed time
        IOOV3.Assertion memory assertion = $.oov3.getAssertion(assertionId);
        uint64 liveness = assertion.expirationTime - assertion.assertionTime;
        uint64 elapsedTime = uint64(block.timestamp) - assertion.assertionTime;
        uint32 maxPercent = ROYALTY_MODULE.maxPercent();
        bool inIpOwnerTimeWindow = elapsedTime <= (liveness * $.ipOwnerTimePercents[disputeId]) / maxPercent;
        if (inIpOwnerTimeWindow && msg.sender != targetIpId)
            revert Errors.ArbitrationPolicyUMA__OnlyTargetIpIdCanDisputeWithinTimeWindow(
                elapsedTime,
                liveness,
                msg.sender
            );

        $.counterEvidenceHashes[assertionId] = counterEvidenceHash;

        IERC20 currencyToken = IERC20(assertion.currency);
        IOOV3 oov3 = $.oov3;
        currencyToken.safeTransferFrom(msg.sender, address(this), assertion.bond);
        currencyToken.safeIncreaseAllowance(address(oov3), assertion.bond);

        oov3.disputeAssertion(assertionId, msg.sender);

        emit AssertionDisputed(disputeId, assertionId, counterEvidenceHash);
    }

    /// @notice OOV3 callback function forwhen an assertion is resolved
    /// @param assertionId The resolved assertion identifier
    /// @param assertedTruthfully Indicates if the assertion was resolved as truthful or not
    function assertionResolvedCallback(bytes32 assertionId, bool assertedTruthfully) external nonReentrant {
        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();
        if (msg.sender != address($.oov3)) revert Errors.ArbitrationPolicyUMA__NotOOV3();

        uint256 disputeId = $.assertionIdToDisputeId[assertionId];

        DISPUTE_MODULE.setDisputeJudgement(disputeId, assertedTruthfully, "");
    }

    /// @notice OOV3 callback function for when an assertion is disputed
    /// @param assertionId The disputed assertion identifier
    function assertionDisputedCallback(bytes32 assertionId) external {
        ArbitrationPolicyUMAStorage storage $ = _getArbitrationPolicyUMAStorage();
        if (msg.sender != address($.oov3)) revert Errors.ArbitrationPolicyUMA__NotOOV3();
        if ($.counterEvidenceHashes[assertionId] == bytes32(0)) revert Errors.ArbitrationPolicyUMA__NoCounterEvidence();
    }

    /// @notice Returns the minimum liveness for UMA disputes
    function minLiveness() external view returns (uint64) {
        return _getArbitrationPolicyUMAStorage().minLiveness;
    }

    /// @notice Returns the maximum liveness for UMA disputes
    function maxLiveness() external view returns (uint64) {
        return _getArbitrationPolicyUMAStorage().maxLiveness;
    }

    /// @notice Returns the percentage of liveness time the IP owner has priority to respond to a dispute
    function ipOwnerTimePercent() external view returns (uint32) {
        return _getArbitrationPolicyUMAStorage().ipOwnerTimePercent;
    }

    /// @notice Returns the percentage of liveness time the IP owner has priority to respond to a dispute
    /// for a given dispute id
    function ipOwnerTimePercents(uint256 disputeId) external view returns (uint32) {
        return _getArbitrationPolicyUMAStorage().ipOwnerTimePercents[disputeId];
    }

    /// @notice Returns the OOV3 address
    function oov3() external view returns (address) {
        return address(_getArbitrationPolicyUMAStorage().oov3);
    }

    /// @notice Returns the maximum bond for a given token for UMA disputes
    /// @param token The token address
    function maxBonds(address token) external view returns (uint256) {
        return _getArbitrationPolicyUMAStorage().maxBonds[token];
    }

    /// @notice Returns the assertion id for a given dispute id
    /// @param disputeId The dispute id
    function disputeIdToAssertionId(uint256 disputeId) external view returns (bytes32) {
        return _getArbitrationPolicyUMAStorage().disputeIdToAssertionId[disputeId];
    }

    /// @notice Returns the dispute id for a given assertion id
    /// @param assertionId The assertion id
    function assertionIdToDisputeId(bytes32 assertionId) external view returns (uint256) {
        return _getArbitrationPolicyUMAStorage().assertionIdToDisputeId[assertionId];
    }

    /// @notice Constructs the claim for a given dispute
    /// @param targetIpId The ipId that is the target of the dispute
    /// @param disputeEvidenceHash The hash pointing to the dispute evidence
    /// @param targetTag The target tag of the dispute
    /// @param disputeId The dispute id
    /* solhint-disable quotes */
    function _constructClaim(
        address targetIpId,
        bytes32 targetTag,
        bytes32 disputeEvidenceHash,
        uint256 disputeId
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                '{"title": "',
                "IP dispute ",
                BytesConversion.toUtf8BytesUint(disputeId),
                '", "description": "',
                "The IP with ipId address 0x",
                BytesConversion.toUtf8BytesAddress(targetIpId),
                " is infringing beyond any reasonable doubt with dispute tag 0x",
                BytesConversion.toUtf8Bytes(targetTag),
                " given the evidence hash 0x",
                BytesConversion.toUtf8Bytes(disputeEvidenceHash),
                // solhint-disable-next-line max-line-length
                ". This dispute is original and not a duplicate of a previous dispute that has been raised against the same IP.",
                '"}'
            );
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of ArbitrationPolicyUMA
    function _getArbitrationPolicyUMAStorage() private pure returns (ArbitrationPolicyUMAStorage storage $) {
        assembly {
            $.slot := ArbitrationPolicyUMAStorageLocation
        }
    }
}
