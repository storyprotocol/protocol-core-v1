// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { AccessControlled } from "../../../access/AccessControlled.sol";
import { ILicenseNFT } from "../../../interfaces/registries/ILicenseNFT.sol";

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/// @title LicensorApprovalChecker
/// @notice Manages the approval of derivative IP accounts by the originalIp. Used to verify
/// licensing terms like "Derivatives With Approval" in PIL.
abstract contract LicensorApprovalCheckerV2 is AccessControlled, Initializable {
    /// @notice Emits when a derivative IP account is approved by the originalIp.
    /// @param licenseId The ID of the license waiting for approval
    /// @param ipId The ID of the derivative IP to be approved
    /// @param caller The executor of the approval
    /// @param approved Result of the approval
    event DerivativeApproved(uint256 indexed licenseId, address indexed ipId, address indexed caller, bool approved);

    /// @notice Storage for derivative IP approvals.
    /// @param approvals Approvals for derivative IP.
    /// @dev License Id => originalIpId => childIpId => approved
    /// @custom:storage-location erc7201:story-protocol.LicensorApprovalChecker
    struct LicensorApprovalCheckerStorage {
        mapping(uint256 => mapping(address => mapping(address => bool))) approvals;
    }

    /// @notice Returns the licenseNFT  address
    /// @custom:oz-upgrades-unsafe-allow state-variable-immutable
    ILicenseNFT public immutable LICENSE_NFT;

    // keccak256(abi.encode(uint256(keccak256("story-protocol.LicensorApprovalChecker")) - 1))
    // & ~bytes32(uint256(0xff));
    bytes32 private constant LicensorApprovalCheckerStorageLocation =
        0x7a71306cccadc52d66a0a466930bd537acf0ba900f21654919d58cece4cf9500;

    /// @notice Constructor function
    /// @param accessController The address of the AccessController contract
    /// @param ipAccountRegistry The address of the IPAccountRegistry contract
    /// @param licenseNFT The address of the LicenseRegistry contract
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(
        address accessController,
        address ipAccountRegistry,
        address licenseNFT
    ) AccessControlled(accessController, ipAccountRegistry) {
        LICENSE_NFT = ILicenseNFT(licenseNFT);
    }

    /// @notice Approves or disapproves a derivative IP account.
    /// @param licenseTokenId The ID of the license waiting for approval
    /// @param childIpId The ID of the derivative IP to be approved
    /// @param approved Result of the approval
    function setApproval(uint256 licenseTokenId, address childIpId, bool approved) external {
        address originalIpId = LICENSE_NFT.originalIpId(licenseTokenId);
        _setApproval(originalIpId, licenseTokenId, childIpId, approved);
    }

    /// @notice Checks if a derivative IP account is approved by the original.
    /// @param licenseTokenId The ID of the license NFT issued from a policy of the original
    /// @param childIpId The ID of the derivative IP to be approved
    /// @return approved True if the derivative IP account using the license is approved
    function isDerivativeApproved(uint256 licenseTokenId, address childIpId) public view returns (bool) {
        address originalIpId = LICENSE_NFT.originalIpId(licenseTokenId);
        LicensorApprovalCheckerStorage storage $ = _getLicensorApprovalCheckerStorage();
        return $.approvals[licenseTokenId][originalIpId][childIpId];
    }

    /// @notice Sets the approval for a derivative IP account.
    /// @dev This function is only callable by the original IP account.
    /// @param originalIpId The ID of the original IP account
    /// @param licenseTokenId The ID of the license waiting for approval
    /// @param childIpId The ID of the derivative IP to be approved
    /// @param approved Result of the approval
    function _setApproval(
        address originalIpId,
        uint256 licenseTokenId,
        address childIpId,
        bool approved
    ) internal verifyPermission(originalIpId) {
        LicensorApprovalCheckerStorage storage $ = _getLicensorApprovalCheckerStorage();
        $.approvals[licenseTokenId][originalIpId][childIpId] = approved;
        emit DerivativeApproved(licenseTokenId, originalIpId, msg.sender, approved);
    }

    /// @dev Returns the storage struct of LicensorApprovalChecker.
    function _getLicensorApprovalCheckerStorage() private pure returns (LicensorApprovalCheckerStorage storage $) {
        assembly {
            $.slot := LicensorApprovalCheckerStorageLocation
        }
    }
}
