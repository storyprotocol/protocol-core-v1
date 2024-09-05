// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
// solhint-disable-next-line max-line-length
import { AccessManagedUpgradeable } from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagedUpgradeable.sol";

import { IDisputeModule } from "../../../interfaces/modules/dispute/IDisputeModule.sol";
import { IArbitrationPolicy } from "../../../interfaces/modules/dispute/policies/IArbitrationPolicy.sol";
import { Errors } from "../../../lib/Errors.sol";

/// @title Story Protocol Arbitration Policy
/// @notice The Story Protocol arbitration policy is a simple policy that requires the dispute initiator to pay a fixed
///         amount of tokens to raise a dispute and refunds that amount if the dispute initiator wins the dispute.
contract ArbitrationPolicySP is IArbitrationPolicy, AccessManagedUpgradeable, UUPSUpgradeable {
    using SafeERC20 for IERC20;

    /// @notice Returns the protocol-wide dispute module address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable DISPUTE_MODULE;
    /// @notice Returns the payment token address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    address public immutable PAYMENT_TOKEN;
    /// @notice Returns the arbitration price
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    uint256 public immutable ARBITRATION_PRICE;

    /// @dev Storage structure for the ArbitrationPolicySP
    /// @custom:storage-location erc7201:story-protocol.ArbitrationPolicySP
    struct ArbitrationPolicySPStorage {
        address treasury;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.ArbitrationPolicySP")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant ArbitrationPolicySPStorageLocation =
        0x8b56c510cd155da0a5980302e158a4f212510ffd8eb3a4388303109171a91800;

    /// @notice Restricts the calls to the DisputeModule
    modifier onlyDisputeModule() {
        if (msg.sender != DISPUTE_MODULE) revert Errors.ArbitrationPolicySP__NotDisputeModule();
        _;
    }

    /// Constructor
    /// @param disputeModule The dispute module address
    /// @param paymentToken The ERC20 payment token address
    /// @param arbitrationPrice The arbitration price
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address disputeModule, address paymentToken, uint256 arbitrationPrice) {
        if (disputeModule == address(0)) revert Errors.ArbitrationPolicySP__ZeroDisputeModule();
        if (paymentToken == address(0)) revert Errors.ArbitrationPolicySP__ZeroPaymentToken();

        DISPUTE_MODULE = disputeModule;
        PAYMENT_TOKEN = paymentToken;
        ARBITRATION_PRICE = arbitrationPrice;

        _disableInitializers();
    }

    /// @notice Allows governance set the treasury address
    /// @dev Enforced to be only callable by the governance protocol admin
    /// @param newTreasury The new address of the treasury
    function setTreasury(address newTreasury) external restricted {
        if (newTreasury == address(0)) revert Errors.ArbitrationPolicySP__ZeroTreasury();

        ArbitrationPolicySPStorage storage $ = _getArbitrationPolicySPStorage();
        $.treasury = newTreasury;
    }

    /// @notice Initializer for this implementation contract
    /// @param accessManager The address of the protocol admin roles contract
    /// @param newTreasury The new address of the treasury
    function initialize(address accessManager, address newTreasury) public initializer {
        if (accessManager == address(0)) revert Errors.ArbitrationPolicySP__ZeroAccessManager();
        if (newTreasury == address(0)) revert Errors.ArbitrationPolicySP__ZeroTreasury();

        __AccessManaged_init(accessManager);
        __UUPSUpgradeable_init();

        ArbitrationPolicySPStorage storage $ = _getArbitrationPolicySPStorage();
        $.treasury = newTreasury;
    }

    /// @notice Executes custom logic on raising dispute
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param caller Address of the caller
    /// @param data The arbitrary data used to raise the dispute
    function onRaiseDispute(address caller, bytes calldata data) external onlyDisputeModule {
        // requires that the caller has given approve() to this contract
        IERC20(PAYMENT_TOKEN).safeTransferFrom(caller, address(this), ARBITRATION_PRICE);
    }

    /// @notice Executes custom logic on disputing judgement
    /// @dev Enforced to be only callable by the DisputeModule
    /// @param disputeId The dispute id
    /// @param decision The decision of the dispute
    /// @param data The arbitrary data used to set the dispute judgement
    function onDisputeJudgement(uint256 disputeId, bool decision, bytes calldata data) external onlyDisputeModule {
        if (decision) {
            (, address disputeInitiator, , , , , ) = IDisputeModule(DISPUTE_MODULE).disputes(disputeId);
            IERC20(PAYMENT_TOKEN).safeTransfer(disputeInitiator, ARBITRATION_PRICE);
        } else {
            ArbitrationPolicySPStorage storage $ = _getArbitrationPolicySPStorage();
            IERC20(PAYMENT_TOKEN).safeTransfer($.treasury, ARBITRATION_PRICE);
        }
    }

    /// @notice Executes custom logic on disputing cancel
    /// @dev Enforced to be only callable by the DisputeModule and purposedly left empty
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to cancel the dispute
    function onDisputeCancel(address caller, uint256 disputeId, bytes calldata data) external onlyDisputeModule {}

    /// @notice Executes custom logic on resolving dispute
    /// @dev Enforced to be only callable by the DisputeModule and purposedly left empty
    /// @param caller Address of the caller
    /// @param disputeId The dispute id
    /// @param data The arbitrary data used to resolve the dispute
    function onResolveDispute(address caller, uint256 disputeId, bytes calldata data) external onlyDisputeModule {}

    /// @notice Returns the treasury address
    /// @return The treasury address
    function treasury() external view returns (address) {
        ArbitrationPolicySPStorage storage $ = _getArbitrationPolicySPStorage();
        return $.treasury;
    }

    /// @dev Hook to authorize the upgrade according to UUPSUpgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override restricted {}

    /// @dev Returns the storage struct of ArbitrationPolicySP
    function _getArbitrationPolicySPStorage() private pure returns (ArbitrationPolicySPStorage storage $) {
        assembly {
            $.slot := ArbitrationPolicySPStorageLocation
        }
    }
}
