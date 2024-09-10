// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.26;

import { AccessControlled } from "../../../access/AccessControlled.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title LicensorApprovalChecker
/// @notice Manages the approval of derivative IP accounts by the parentIp. Used to verify
/// licensing terms like "Derivatives With Approval" in PIL.
abstract contract LicensorApprovalChecker is AccessControlled, Initializable {
    /// @notice Emits when a derivative IP account is approved by the parentIp.
    /// @param licenseTermsId The ID of the license waiting for approval
    /// @param ipId The ID of the derivative IP to be approved
    /// @param caller The executor of the approval
    /// @param approved Result of the approval
    event DerivativeApproved(
        uint256 indexed licenseTermsId,
        address indexed ipId,
        address indexed caller,
        bool approved
    );

    /// @notice Storage for derivative IP approvals.
    /// @param approvals Approvals for derivative IP.
    /// @dev License Id => parentIpId => childIpId => approved
    /// @custom:storage-location erc7201:story-protocol.LicensorApprovalChecker
    struct LicensorApprovalCheckerStorage {
        mapping(uint256 => mapping(address => mapping(address => bool))) approvals;
    }

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicensorApprovalChecker")) - 1))
    // & ~bytes32(uint256(0xff));
    bytes32 private constant LicensorApprovalCheckerStorageLocation =
        0x7a71306cccadc52d66a0a466930bd537acf0ba900f21654919d58cece4cf9500;

    /// @notice Constructor function
    /// @param accessController The address of the AccessController contract
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry
    ) AccessControlled(accessController, ipAccountRegistry) {}

    /// @notice Approves or disapproves a derivative IP account.
    /// @param parentIpId The ID of the parent IP grant the approval
    /// @param licenseTermsId The ID of the license waiting for approval
    /// @param childIpId The ID of the derivative IP to be approved
    /// @param approved Result of the approval
    function setApproval(address parentIpId, uint256 licenseTermsId, address childIpId, bool approved) external {
        _setApproval(parentIpId, licenseTermsId, childIpId, approved);
    }

    /// @notice Checks if a derivative IP account is approved by the parent.
    /// @param licenseTermsId The ID of the license NFT issued from a policy of the parent
    /// @param childIpId The ID of the derivative IP to be approved
    /// @return approved True if the derivative IP account using the license is approved
    function isDerivativeApproved(
        address parentIpId,
        uint256 licenseTermsId,
        address childIpId
    ) public view returns (bool) {
        LicensorApprovalCheckerStorage storage $ = _getLicensorApprovalCheckerStorage();
        return $.approvals[licenseTermsId][parentIpId][childIpId];
    }

    /// @notice Sets the approval for a derivative IP account.
    /// @dev This function is only callable by the parent IP account.
    /// @param parentIpId The ID of the parent IP account
    /// @param licenseTermsId The ID of the license waiting for approval
    /// @param childIpId The ID of the derivative IP to be approved
    /// @param approved Result of the approval
    function _setApproval(
        address parentIpId,
        uint256 licenseTermsId,
        address childIpId,
        bool approved
    ) internal verifyPermission(parentIpId) {
        LicensorApprovalCheckerStorage storage $ = _getLicensorApprovalCheckerStorage();
        $.approvals[licenseTermsId][parentIpId][childIpId] = approved;
        emit DerivativeApproved(licenseTermsId, parentIpId, msg.sender, approved);
    }

    /// @dev Returns the storage struct of LicensorApprovalChecker.
    function _getLicensorApprovalCheckerStorage() private pure returns (LicensorApprovalCheckerStorage storage $) {
        assembly {
            $.slot := LicensorApprovalCheckerStorageLocation
        }
    }
}
