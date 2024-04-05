// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.23;

import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

import { GovernableUpgradeable } from "../../../../contracts/governance/GovernableUpgradeable.sol";
import { RoyaltyPolicyLAP } from "../../../../contracts/modules/royalty/policies/RoyaltyPolicyLAP.sol";
import { IRoyaltyPolicyLAP } from "../../../../contracts/interfaces/modules/royalty/policies/IRoyaltyPolicyLAP.sol";
import { Errors } from "../../../../contracts/lib/Errors.sol";

contract MockRoyaltyPolicyLAP is IRoyaltyPolicyLAP, GovernableUpgradeable, ReentrancyGuardUpgradeable, UUPSUpgradeable {
    struct RoyaltyPolicyLAPStorage {
        address ipRoyaltyVaultBeacon;
        uint256 snapshotInterval;
        mapping(address ipId => RoyaltyPolicyLAP.LAPRoyaltyData) royaltyData;
    }

    bytes32 private constant RoyaltyPolicyLAPStorageLocation =
        0x0c915ba68e2c4e37f19454bb13066f18f9db418fcefbf3c585b4b7d0fb0e0600;

    uint32 public constant TOTAL_RT_SUPPLY = 100000000;
    uint256 public constant MAX_PARENTS = 100;
    uint256 public constant MAX_ANCESTORS = 100;
    address public constant LICENSING_MODULE = address(0);
    address public constant ROYALTY_MODULE = address(0);

    constructor() {
        _disableInitializers();
    }

    function initialize() external initializer {
        __GovernableUpgradeable_init(address(0x1));
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();
    }

    function setSnapshotInterval(uint256 timestampInterval) public onlyProtocolAdmin {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        $.snapshotInterval = timestampInterval;
    }

    function setIpRoyaltyVaultBeacon(address beacon) public onlyProtocolAdmin {
        if (beacon == address(0)) revert Errors.RoyaltyPolicyLAP__ZeroIpRoyaltyVaultBeacon();
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        $.ipRoyaltyVaultBeacon = beacon;
    }

    function onLicenseMinting(address ipId, bytes calldata licenseData, bytes calldata externalData) external {}

    function onLinkToParents(
        address ipId,
        address[] calldata parentIpIds,
        bytes[] memory licenseData,
        bytes calldata externalData
    ) external {}

    function onRoyaltyPayment(address caller, address ipId, address token, uint256 amount) external {}

    function getRoyaltyData(
        address ipId
    ) external view returns (bool, address, uint32, address[] memory, uint32[] memory) {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        RoyaltyPolicyLAP.LAPRoyaltyData memory data = $.royaltyData[ipId];
        return (
            data.isUnlinkableToParents,
            data.ipRoyaltyVault,
            data.royaltyStack,
            data.ancestorsAddresses,
            data.ancestorsRoyalties
        );
    }

    function getSnapshotInterval() external view returns (uint256) {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        return $.snapshotInterval;
    }

    function getIpRoyaltyVaultBeacon() external view returns (address) {
        RoyaltyPolicyLAPStorage storage $ = _getRoyaltyPolicyLAPStorage();
        return $.ipRoyaltyVaultBeacon;
    }

    function _getRoyaltyPolicyLAPStorage() private pure returns (RoyaltyPolicyLAPStorage storage $) {
        assembly {
            $.slot := RoyaltyPolicyLAPStorageLocation
        }
    }

    /// @dev Hook to authorize the upgrade according to UUPSUgradeable
    /// @param newImplementation The address of the new implementation
    function _authorizeUpgrade(address newImplementation) internal override {}
}
