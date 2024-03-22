// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ERC165Checker } from "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import { Errors } from "../lib/Errors.sol";
import { IGovernance } from "../interfaces/governance/IGovernance.sol";
import { IGovernable } from "../interfaces/governance/IGovernable.sol";
import { GovernanceLib } from "../lib/GovernanceLib.sol";

/// @title Governable
/// @dev All contracts managed by governance should inherit from this contract.
abstract contract GovernableUpgradeable is IGovernable, Initializable {
    /// @custom:storage-location erc7201:story-protocol.GovernableUpgradeable
    /// @param governance The address of the governance.
    struct GovernableUpgradeableStorage {
        address governance;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.GovernableUpgradeable")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 private constant GovernableUpgradeableStorageLocation =
        0xaed547d8331715caab0800583ca79170ef3186de64f009413517d98c5b905c00;

    /// @dev Ensures that the function is called by the protocol admin.
    modifier onlyProtocolAdmin() {
        GovernableUpgradeableStorage storage $ = _getGovernableUpgradeableStorage();
        if (!IGovernance($.governance).hasRole(GovernanceLib.PROTOCOL_ADMIN, msg.sender)) {
            revert Errors.Governance__OnlyProtocolAdmin();
        }
        _;
    }

    modifier whenNotPaused() {
        GovernableUpgradeableStorage storage $ = _getGovernableUpgradeableStorage();
        if (IGovernance($.governance).getState() == GovernanceLib.ProtocolState.Paused) {
            revert Errors.Governance__ProtocolPaused();
        }
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function __GovernableUpgradeable_init(address governance_) internal {
        if (governance_ == address(0)) revert Errors.Governance__ZeroAddress();
        _getGovernableUpgradeableStorage().governance = governance_;
        emit GovernanceUpdated(governance_);
    }

    /// @notice Sets a new governance address.
    /// @param newGovernance The address of the new governance.
    function setGovernance(address newGovernance) external onlyProtocolAdmin {
        GovernableUpgradeableStorage storage $ = _getGovernableUpgradeableStorage();

        if (newGovernance == address(0)) revert Errors.Governance__ZeroAddress();
        if (!ERC165Checker.supportsInterface(newGovernance, type(IGovernance).interfaceId))
            revert Errors.Governance__UnsupportedInterface("IGovernance");
        if (IGovernance(newGovernance).getState() != IGovernance($.governance).getState())
            revert Errors.Governance__InconsistentState();
        $.governance = newGovernance;
        emit GovernanceUpdated(newGovernance);
    }

    /// @notice Returns the current governance address.
    /// @return governance The address of the current governance.
    function getGovernance() external view returns (address) {
        return _getGovernableUpgradeableStorage().governance;
    }

    function _getGovernableUpgradeableStorage() private pure returns (GovernableUpgradeableStorage storage $) {
        assembly {
            $.slot := GovernableUpgradeableStorageLocation
        }
    }
}
